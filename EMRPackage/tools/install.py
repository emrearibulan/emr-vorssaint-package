#!/usr/bin/env python3
"""Build emr package locally and optionally install the official, notarized app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]


def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)


def metadata(root=ROOT):
    data = json.loads((root / "EMRPackage/package.json").read_text())
    if data.get("schemaVersion") != 1 or not re.fullmatch(r"\d+\.\d+\.\d+", data.get("version", "")):
        raise ValueError("Unsupported package metadata")
    if data["app"]["name"] != "Island Monitor" or data["app"]["executable"] != "IslandMonitor":
        raise ValueError("Unexpected app path in package metadata")
    if data["app"]["bundleIdentifier"] != "local.emre.islandmonitor.dev":
        raise ValueError("Refusing to change the installed companion identity")
    if data["upstream"]["repository"] != "vorssaint/vorssaint-utils":
        raise ValueError("Official application must come from Vorssaint's repository")
    ids = [feature["id"] for feature in data["features"]]
    if len(ids) != len(set(ids)) or any(not re.fullmatch(r"[a-z0-9-]+", value) for value in ids):
        raise ValueError("Feature identifiers must be unique and stable")
    return data


def validate_asset_url(url):
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "github.com" or not parsed.path.startswith(
        "/vorssaint/vorssaint-utils/releases/download/"
    ) or not parsed.path.endswith(".dmg") or parsed.username or parsed.password:
        raise ValueError("Refusing a download outside the official Vorssaint release repository")
    return url


def app_identifier(app):
    with (app / "Contents/Info.plist").open("rb") as handle:
        return plistlib.load(handle).get("CFBundleIdentifier")


def application_directory():
    system = Path("/Applications")
    return system if os.access(system, os.W_OK) else Path.home() / "Applications"


def official_installed():
    return any((folder / "Vorssaint.app").is_dir() for folder in (Path("/Applications"), Path.home() / "Applications"))


def install_official(folder, data):
    # Never replace an existing official installation or its update mechanism.
    if official_installed():
        print("Official Vorssaint is already installed; keeping its current app and updater.")
        return
    request = Request("https://api.github.com/repos/vorssaint/vorssaint-utils/releases/latest",
                      headers={"User-Agent": "emr-package-source-installer"})
    with urlopen(request, timeout=60) as response:
        release = json.load(response)
    if release.get("draft") or release.get("prerelease"):
        raise ValueError("Expected an official stable release")
    assets = [a for a in release["assets"] if a["name"].endswith(".dmg")]
    if len(assets) != 1:
        raise ValueError("The official DMG layout changed; install Vorssaint from its release page first")
    asset = assets[0]
    url = validate_asset_url(asset["browser_download_url"])
    with tempfile.TemporaryDirectory(prefix="emr-official-") as temporary:
        temp = Path(temporary)
        dmg = temp / "Vorssaint.dmg"
        print("Downloading official Vorssaint", release["tag_name"])
        with urlopen(Request(url, headers={"User-Agent": "emr-package-source-installer"}), timeout=120) as response:
            with dmg.open("wb") as handle:
                shutil.copyfileobj(response, handle)
        digest = asset.get("digest")
        if digest:
            if not digest.startswith("sha256:") or hashlib.sha256(dmg.read_bytes()).hexdigest() != digest[7:]:
                raise ValueError("Official release checksum did not match")
        mount = temp / "mount"
        mount.mkdir()
        run(["/usr/bin/hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, dmg], stdout=subprocess.DEVNULL)
        try:
            app = mount / "Vorssaint.app"
            if app_identifier(app) != data["upstream"]["officialBundleIdentifier"]:
                raise ValueError("Unexpected official app identity")
            run(["/usr/bin/codesign", "--verify", "--deep", "--strict", app])
            signature = run(["/usr/bin/codesign", "-dv", "--verbose=4", app], capture_output=True, text=True).stderr
            if "TeamIdentifier=" + data["upstream"]["officialTeamIdentifier"] not in signature.splitlines():
                raise ValueError("The official signing team changed; review the release before installing")
            run(["/usr/sbin/spctl", "--assess", "--type", "execute", app])
            folder.mkdir(parents=True, exist_ok=True)
            if (folder / "Vorssaint.app").exists():
                raise ValueError("Vorssaint appeared during installation; refusing to overwrite it")
            run(["/usr/bin/ditto", app, folder / "Vorssaint.app"])
        finally:
            run(["/usr/bin/hdiutil", "detach", mount], stdout=subprocess.DEVNULL)


def install_companion(source, folder, data):
    destination = folder / (data["app"]["name"] + ".app")
    if destination.exists() and app_identifier(destination) != data["app"]["bundleIdentifier"]:
        raise ValueError("Another app occupies the destination; refusing to replace it")
    # Updating needs a closed app; never kill an arbitrary user's process.
    executable = destination / "Contents/MacOS" / data["app"]["executable"]
    running = subprocess.run(["/usr/bin/pgrep", "-f", "^" + re.escape(str(executable)) + r"([[:space:]]|$)"],
                             capture_output=True)
    if running.returncode == 0:
        raise ValueError("Quit Island Monitor, then run this installer again. Your saved settings are retained.")
    if running.returncode != 1:
        raise ValueError("Could not check whether the companion is running")
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".emr-install-", dir=folder) as temporary:
        temporary = Path(temporary)
        staged = temporary / destination.name
        backup = temporary / "previous.app"
        run(["/usr/bin/ditto", source, staged])
        run(["/usr/bin/codesign", "--verify", "--deep", "--strict", staged])
        if destination.exists():
            destination.rename(backup)
        try:
            staged.rename(destination)
            run(["/usr/bin/codesign", "--verify", "--deep", "--strict", destination])
        except Exception:
            if destination.exists():
                shutil.rmtree(destination)
            if backup.exists():
                backup.rename(destination)
            raise
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--with-vorssaint", action="store_true", help="Install official Vorssaint too, only if missing")
    parser.add_argument("--no-launch", action="store_true")
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--dry-run", action="store_true", help="Show the plan without downloading, building or changing apps")
    args = parser.parse_args()
    data = metadata()
    folder = application_directory()
    print(f"emr package {data['version']} — source build; features: " + ", ".join(x["name"] for x in data["features"]))
    print("Companion destination:", folder / (data["app"]["name"] + ".app"))
    print("Official Vorssaint:", "keep existing app and its updater" if official_installed() else
          "install latest official stable release" if args.with_vorssaint else "not installed; companion can run on its own")
    if args.dry_run:
        return
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("This source package requires an Apple Silicon Mac running macOS 14 or newer")
    if int(platform.mac_ver()[0].split(".")[0]) < 14:
        raise ValueError("macOS 14 or newer is required")
    if subprocess.run(["/usr/bin/xcode-select", "-p"], capture_output=True).returncode:
        raise ValueError("Install Apple's Xcode Command Line Tools first: xcode-select --install")
    run(["/bin/zsh", ROOT / "build-dashboard.sh"], cwd=ROOT)
    source = ROOT / "build/stage.noindex" / (data["app"]["name"] + ".app")
    run([source / "Contents/MacOS" / data["app"]["executable"], "--selftest"])
    if args.build_only:
        print("Built app:", source)
        return
    if args.with_vorssaint:
        install_official(folder, data)
    installed = install_companion(source, folder, data)
    print("Installed:", installed)
    print("If Vorssaint's original Dynamic Island is enabled, turn it off in Vorssaint Settings to avoid overlap.")
    print("The official app keeps updating normally. emr package settings are separate and preserved between builds.")
    if not args.no_launch:
        run(["/usr/bin/open", installed])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print("Installation stopped:", error, file=sys.stderr)
        sys.exit(1)
