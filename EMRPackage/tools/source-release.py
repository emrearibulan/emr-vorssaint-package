#!/usr/bin/env python3
"""Inspect an immutable emr candidate and finalize a validated source-only release."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "emrearibulan/emr-vorssaint-package"
BRANCH = "emr/package"
SHA = re.compile(r"[0-9a-f]{40}")


class ReleaseError(ValueError):
    pass


def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()


def candidate(commit, root=ROOT):
    if not SHA.fullmatch(commit):
        raise ReleaseError("Select a full lowercase 40-character commit SHA, not a branch or tag")
    if git(root, "rev-parse", commit + "^{commit}") != commit:
        raise ReleaseError("Candidate does not resolve to the selected commit")
    ancestry = subprocess.run(["git", "merge-base", "--is-ancestor", commit,
                               "refs/remotes/origin/" + BRANCH], cwd=root)
    if ancestry.returncode:
        raise ReleaseError("Candidate must already belong to origin/" + BRANCH)

    def read(path):
        return git(root, "show", commit + ":" + path)

    data = json.loads(read("EMRPackage/package.json"))
    version = data.get("version", "")
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ReleaseError("Candidate package version must be MAJOR.MINOR.PATCH")
    if data.get("repository") != REPOSITORY or data.get("developmentBranch") != BRANCH:
        raise ReleaseError("Candidate package repository/development branch changed; review it first")
    files = git(root, "ls-tree", "-r", "--name-only", commit).splitlines()
    for required in ("README.md", "LICENSE", "EMRPackage/CHANGELOG.md",
                     "EMRPackage/tools/validate-release.sh"):
        if required not in files:
            raise ReleaseError("Candidate is missing required release file: " + required)
    private_names = {"assistant-handbook.md", "assistant-context.md", "assistant-ideas.md",
                     "assistant-access-register.md", "assistant-improvement-plan.md",
                     "apple-developer-signing-status.md", ".env", ".git-credentials",
                     "id_rsa", "id_ed25519"}
    for name in files:
        path = Path(name)
        if (path.name in private_names or path.suffix in {".p12", ".p8", ".key", ".keychain-db"}
                or name == ".codex/auth.json"):
            raise ReleaseError("Remove private notes or credential material from source: " + name)
    changelog = read("EMRPackage/CHANGELOG.md")
    entries = re.split(r"(?m)^## ", changelog)
    if len(entries) < 2 or not re.match(re.escape(version) + r"(?:\s|$)", entries[1]):
        raise ReleaseError("Candidate's first changelog entry must match its version")
    changes = entries[1].split("\n", 1)
    if len(changes) != 2 or not changes[1].strip():
        raise ReleaseError("Write release notes in the candidate changelog")
    tag = "emr-v" + version
    notes = (changes[1].strip() + "\n\n## Source verification\n\n"
             + "Source commit: `" + commit + "`.\n\n"
             + "This release contains source only. See the "
             + "[installation and update instructions](https://github.com/" + REPOSITORY
             + "/blob/" + tag + "/README.md#install-from-source).\n")
    return {"commit": commit, "tag": tag, "version": version, "notes": notes}


class GitHub:
    def command(self, *args):
        result = subprocess.run(["gh", *args], text=True, capture_output=True)
        if result.returncode:
            raise ReleaseError(result.stderr.strip() or "GitHub CLI request failed")
        return result.stdout

    def request(self, path, missing_ok=False, **fields):
        args = ["api", "repos/" + REPOSITORY + "/" + path]
        if fields:
            args += ["--method", "POST"]
            for key, value in fields.items():
                args += ["-f", key + "=" + value]
        result = subprocess.run(["gh", *args], text=True, capture_output=True)
        if result.returncode:
            if missing_ok and "HTTP 404" in result.stderr:
                return None
            raise ReleaseError(result.stderr.strip() or "GitHub API request failed")
        return json.loads(result.stdout)

    def tag_commit(self, tag):
        ref = self.request("git/ref/tags/" + tag, missing_ok=True)
        if ref is None:
            return None
        obj = ref["object"]
        for _ in range(5):
            if not SHA.fullmatch(obj.get("sha", "")):
                raise ReleaseError("GitHub returned an invalid tag object")
            if obj["type"] == "commit":
                return obj["sha"]
            if obj["type"] != "tag":
                break
            obj = self.request("git/tags/" + obj["sha"])["object"]
        raise ReleaseError("Tag must resolve to a commit")

    def release(self, tag):
        release = self.request("releases/tags/" + tag, missing_ok=True)
        if release is not None:
            return release
        # The tag endpoint does not reliably expose drafts. Authenticated release
        # listing includes drafts visible to the token; preserve retryability.
        page = 1
        while True:
            releases = self.request("releases?per_page=100&page=" + str(page))
            for release in releases:
                if release.get("tag_name") == tag:
                    return release
            if len(releases) < 100:
                return None
            page += 1

    def create_tag(self, tag, commit):
        self.request("git/refs", ref="refs/tags/" + tag, sha=commit)

    def latest(self):
        return self.request("releases/latest", missing_ok=True)

    def create_draft(self, item):
        with tempfile.TemporaryDirectory(prefix="emr-release-notes-") as folder:
            notes = Path(folder) / "notes.md"
            notes.write_text(item["notes"])
            self.command("release", "create", item["tag"], "--repo", REPOSITORY,
                         "--verify-tag", "--draft", "--title", "emr package " + item["version"],
                         "--notes-file", str(notes))

    def publish(self, tag):
        self.command("release", "edit", tag, "--repo", REPOSITORY,
                     "--draft=false", "--latest")


def verify_release(release, item, public=False):
    if not isinstance(release, dict) or release.get("tag_name") != item["tag"]:
        raise ReleaseError("Release metadata does not identify the selected tag")
    if release.get("assets") != [] or release.get("prerelease") is not False:
        raise ReleaseError("Expected a stable, source-only release with no uploaded assets")
    if release.get("body", "").strip() != item["notes"].strip():
        raise ReleaseError("Release notes differ from the selected candidate changelog and source links")
    if public and release.get("draft") is not False:
        raise ReleaseError("Release is not publicly published")
    if public and not all(release.get(key) for key in ("html_url", "tarball_url", "zipball_url")):
        raise ReleaseError("Published source release links are missing")


def finalize(commit, mode, root=ROOT, api=None):
    # These values are provided by the separate, successful validation job. This
    # command is internal to the workflow; repository admins can still bypass it.
    expected = {"GITHUB_ACTIONS": "true", "GITHUB_EVENT_NAME": "workflow_dispatch",
                "GITHUB_REF": "refs/heads/" + BRANCH, "GITHUB_REPOSITORY": REPOSITORY,
                "EMR_VALIDATED_COMMIT": commit, "EMR_VALIDATION_RESULT": "success"}
    if any(os.environ.get(key) != value for key, value in expected.items()):
        raise ReleaseError("Finalize only from the successful exact-commit release workflow")
    if os.environ.get("GITHUB_SHA") != git(root, "rev-parse", "HEAD"):
        raise ReleaseError("Finalizer checkout does not match the trusted workflow commit")
    if mode not in {"draft", "publish"}:
        raise ReleaseError("Choose draft or publish")
    item = candidate(commit, root)
    api = api or GitHub()
    remote_commit = api.tag_commit(item["tag"])
    release = api.release(item["tag"])
    if remote_commit and remote_commit != commit:
        raise ReleaseError("Existing release tag points to a different commit; never move it")
    if release is not None:
        if remote_commit != commit:
            raise ReleaseError("Existing release tag could not be verified")
        verify_release(release, item)
        if release.get("draft") is False:
            if mode == "draft":
                raise ReleaseError("This version is already public; select a new package version")
            verify_release(release, item, public=True)
            return {"status": "already published", "commit": commit, "tag": item["tag"],
                    "url": release["html_url"]}
    latest = api.latest()
    if latest is not None:
        previous = re.fullmatch(r"emr-v([0-9]+)\.([0-9]+)\.([0-9]+)", latest.get("tag_name", ""))
        if previous is None:
            raise ReleaseError("Latest stable release is outside emr versioning; review it first")
        selected_version = tuple(int(n) for n in item["version"].split("."))
        if selected_version <= tuple(int(n) for n in previous.groups()):
            raise ReleaseError("New source release version must increase beyond the latest stable release")
    if remote_commit is None:
        api.create_tag(item["tag"], commit)
    if release is None:
        api.create_draft(item)
    # Re-read remote state before publishing. Failed or colliding tags never get
    # force-updated, and reruns can finish a draft left by an interrupted request.
    if api.tag_commit(item["tag"]) != commit:
        raise ReleaseError("Remote source tag no longer matches the validated candidate")
    release = api.release(item["tag"])
    verify_release(release, item)
    if mode == "publish":
        api.publish(item["tag"])
        release = api.release(item["tag"])
        verify_release(release, item, public=True)
        if api.tag_commit(item["tag"]) != commit:
            raise ReleaseError("Post-publication source tag verification failed")
    return {"status": "published" if mode == "publish" else "draft",
            "commit": commit, "tag": item["tag"], "url": release["html_url"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    inspect = commands.add_parser("inspect", help="Read-only candidate validation")
    inspect.add_argument("--commit", required=True)
    inspect.add_argument("--output", type=Path, help="GitHub step output file")
    publish = commands.add_parser("finalize", help="Internal validated-workflow step")
    publish.add_argument("--commit", required=True)
    publish.add_argument("--mode", choices=("draft", "publish"), default="draft")
    args = parser.parse_args()
    try:
        if args.command == "inspect":
            item = candidate(args.commit)
            if args.output:
                with args.output.open("a") as output:
                    output.write("commit=" + item["commit"] + "\ntag=" + item["tag"] + "\n")
            print(json.dumps(item, indent=2))
        else:
            print(json.dumps(finalize(args.commit, args.mode), indent=2))
    except (ReleaseError, subprocess.CalledProcessError, json.JSONDecodeError, KeyError) as error:
        parser.exit(1, "Source release blocked: " + str(error) + "\n")


if __name__ == "__main__":
    main()
