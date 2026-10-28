import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "source_release", Path(__file__).parents[1] / "tools/source-release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class FakeGitHub:
    def __init__(self, commit=None, draft=None):
        self.commit = commit
        self.data = None if draft is None else {
            "tag_name": "emr-v0.2.0", "draft": draft, "prerelease": False,
            "assets": [], "html_url": "https://github.com/example/release",
            "tarball_url": "source.tar.gz", "zipball_url": "source.zip"}
        self.writes = []
        self.latest_data = None
        if self.data is not None and commit is not None:
            self.data["body"] = fixture_notes(commit)

    def latest(self):
        return self.latest_data

    def tag_commit(self, tag):
        return self.commit

    def release(self, tag):
        return copy.deepcopy(self.data)

    def create_tag(self, tag, commit):
        self.writes.append("tag")
        self.commit = commit

    def create_draft(self, item):
        self.writes.append("draft")
        self.data = FakeGitHub(draft=True).data
        self.data["body"] = item["notes"]

    def publish(self, tag):
        self.writes.append("publish")
        self.data["draft"] = False


def fixture_notes(commit):
    return ("- Fixture change.\n\n## Source verification\n\nSource commit: `" + commit
            + "`.\n\nThis release contains source only. See the "
            + "[installation and update instructions](https://github.com/"
            + release.REPOSITORY + "/blob/emr-v0.2.0/README.md#install-from-source).\n")


class SourceReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.metadata = {"version": "0.2.0", "repository": release.REPOSITORY,
                         "developmentBranch": release.BRANCH}
        self.write("EMRPackage/package.json", json.dumps(self.metadata))
        self.write("README.md", "Install from the versioned source tag")
        self.write("LICENSE", "Fixture license")
        self.write("EMRPackage/tools/validate-release.sh", "#!/bin/bash\nexit 0\n")
        self.write("EMRPackage/CHANGELOG.md", "# Changes\n\n## 0.2.0 — today\n\n- Fixture change.\n")
        self.commit = self.commit_changes()

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, text=True).strip()

    def write(self, path, text):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def commit_changes(self):
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")
        commit = self.git("rev-parse", "HEAD")
        self.git("update-ref", "refs/remotes/origin/" + release.BRANCH, commit)
        return commit

    def environment(self, **changes):
        env = {"GITHUB_ACTIONS": "true", "GITHUB_EVENT_NAME": "workflow_dispatch",
               "GITHUB_REF": "refs/heads/" + release.BRANCH,
               "GITHUB_REPOSITORY": release.REPOSITORY,
               "EMR_VALIDATED_COMMIT": self.commit, "EMR_VALIDATION_RESULT": "success",
               "GITHUB_SHA": self.git("rev-parse", "HEAD")}
        env.update(changes)
        return patch.dict(os.environ, env)

    def test_inspection_is_immutable_and_does_not_need_network(self):
        self.write("EMRPackage/package.json", "working tree is deliberately invalid")
        with patch.object(release, "GitHub", side_effect=AssertionError("unexpected network")):
            item = release.candidate(self.commit, self.root)
        self.assertEqual(item["tag"], "emr-v0.2.0")
        self.assertIn(self.commit, item["notes"])
        self.assertIn("/blob/emr-v0.2.0/README.md", item["notes"])

    def test_rejects_mutable_refs_and_shell_like_inputs(self):
        for ref in ("HEAD", "emr/package", self.commit[:7], self.commit + ";echo x"):
            with self.subTest(ref=ref), self.assertRaises(release.ReleaseError):
                release.candidate(ref, self.root)

    def test_unmerged_candidate_is_rejected(self):
        self.write("unmerged.txt", "work")
        self.git("add", ".")
        self.git("commit", "-qm", "Unmerged")
        with self.assertRaisesRegex(release.ReleaseError, "already belong"):
            release.candidate(self.git("rev-parse", "HEAD"), self.root)

    def test_private_notes_and_credentials_block_source_release(self):
        for filename in ("outputs/assistant-handbook.md", "secrets/signing.p12", ".env"):
            with self.subTest(filename=filename):
                self.write(filename, "fixture only")
                commit = self.commit_changes()
                with self.assertRaisesRegex(release.ReleaseError, "private notes"):
                    release.candidate(commit, self.root)
                self.git("rm", filename)
                self.commit_changes()

    def test_changelog_must_describe_current_version(self):
        self.write("EMRPackage/CHANGELOG.md", "# Changes\n\n## 0.1.0\n\n- Old.\n")
        with self.assertRaisesRegex(release.ReleaseError, "first changelog"):
            release.candidate(self.commit_changes(), self.root)

    def test_repository_identity_cannot_be_changed(self):
        self.metadata["repository"] = "different/repository"
        self.write("EMRPackage/package.json", json.dumps(self.metadata))
        with self.assertRaisesRegex(release.ReleaseError, "repository/development"):
            release.candidate(self.commit_changes(), self.root)

    def test_unvalidated_or_wrong_commit_cannot_write(self):
        for changes in ({"EMR_VALIDATION_RESULT": "failure"},
                        {"EMR_VALIDATED_COMMIT": "0" * 40},
                        {"GITHUB_REF": "refs/heads/unreviewed"},
                        {"GITHUB_SHA": "0" * 40}):
            api = FakeGitHub()
            with self.subTest(changes=changes), self.environment(**changes):
                with self.assertRaises(release.ReleaseError):
                    release.finalize(self.commit, "publish", self.root, api)
            self.assertEqual(api.writes, [])

    def test_draft_does_not_publish(self):
        api = FakeGitHub()
        with self.environment():
            result = release.finalize(self.commit, "draft", self.root, api)
        self.assertEqual(result["status"], "draft")
        self.assertEqual(api.writes, ["tag", "draft"])
        self.assertTrue(api.data["draft"])

    def test_publish_creates_then_verifies_source_only_release(self):
        api = FakeGitHub()
        with self.environment():
            result = release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(result["status"], "published")
        self.assertEqual(api.writes, ["tag", "draft", "publish"])
        self.assertEqual(result["commit"], self.commit)

    def test_existing_matching_draft_is_retryable(self):
        api = FakeGitHub(self.commit, draft=True)
        with self.environment():
            result = release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(result["status"], "published")
        self.assertEqual(api.writes, ["publish"])

    def test_existing_public_release_is_not_modified(self):
        api = FakeGitHub(self.commit, draft=False)
        with self.environment():
            result = release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(result["status"], "already published")
        self.assertEqual(api.writes, [])

    def test_existing_wrong_tag_is_never_moved(self):
        api = FakeGitHub("0" * 40)
        with self.environment(), self.assertRaisesRegex(release.ReleaseError, "different commit"):
            release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(api.writes, [])

    def test_version_cannot_downgrade_the_latest_source_release(self):
        api = FakeGitHub()
        api.latest_data = {"tag_name": "emr-v0.3.0"}
        with self.environment(), self.assertRaisesRegex(release.ReleaseError, "must increase"):
            release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(api.writes, [])

    def test_new_version_can_follow_the_previous_stable_release(self):
        api = FakeGitHub()
        api.latest_data = {"tag_name": "emr-v0.1.9"}
        with self.environment():
            self.assertEqual(release.finalize(self.commit, "draft", self.root, api)["status"], "draft")

    def test_uploaded_assets_block_publication(self):
        api = FakeGitHub(self.commit, draft=True)
        api.data["assets"] = [{"name": "unexpected.pkg"}]
        with self.environment(), self.assertRaisesRegex(release.ReleaseError, "source-only"):
            release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(api.writes, [])

    def test_changed_draft_notes_block_publication(self):
        api = FakeGitHub(self.commit, draft=True)
        api.data["body"] = "Unreviewed notes"
        with self.environment(), self.assertRaisesRegex(release.ReleaseError, "notes differ"):
            release.finalize(self.commit, "publish", self.root, api)
        self.assertEqual(api.writes, [])

    def test_publication_that_remains_a_draft_is_not_success(self):
        api = FakeGitHub(self.commit, draft=True)
        api.publish = lambda tag: api.writes.append("publish did not complete")
        with self.environment(), self.assertRaisesRegex(release.ReleaseError, "not publicly"):
            release.finalize(self.commit, "publish", self.root, api)


class GitHubResponseTests(unittest.TestCase):
    def test_draft_lookup_falls_back_to_authenticated_listing(self):
        api = release.GitHub()
        draft = FakeGitHub(draft=True).data
        with patch.object(api, "request", side_effect=[None, [draft]]) as request:
            self.assertEqual(api.release("emr-v0.2.0"), draft)
        self.assertIn("releases?per_page", request.call_args.args[0])

    def test_annotated_tags_are_peeled_to_the_exact_commit(self):
        api = release.GitHub()
        tag, commit = "1" * 40, "2" * 40
        with patch.object(api, "request", side_effect=[
                {"object": {"type": "tag", "sha": tag}},
                {"object": {"type": "commit", "sha": commit}}]):
            self.assertEqual(api.tag_commit("emr-v0.2.0"), commit)


if __name__ == "__main__":
    unittest.main()
