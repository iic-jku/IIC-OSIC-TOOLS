#!/usr/bin/env python3
# ========================================================================
# Check for newer versions of PIP packages (and optionally update them)
#
# SPDX-FileCopyrightText: 2025-2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
# ========================================================================

import argparse
import sys
import os
import re
import requests

from packaging import version


def get_installed_packages(shell_script):
    """Extract package==version pairs from a shell script."""
    try:
        with open(shell_script, 'r') as file:
            content = file.read()
    except FileNotFoundError:
        print(f"[ERROR] File {shell_script} not found.")
        sys.exit(1)

    # Match package names (with optional extras like [builtin-yosys]) and versions.
    # Handles quoted entries like "amaranth[builtin-yosys]==0.5.6"
    installed_packages = re.findall(
        r'([\w][\w\-]*(?:\[[^\]]*\])?)=='          # package name with optional extras
        r'(\d+(?:\.\d+)*)',                          # version: digits separated by dots
        content
    )
    # Strip extras brackets for PyPI lookups (e.g. "amaranth[builtin-yosys]" -> "amaranth")
    cleaned = [(re.sub(r'\[.*\]', '', pkg), ver) for pkg, ver in installed_packages]
    return cleaned


def get_latest_version(package):
    """Query PyPI for the latest version of a package.

    Returns the latest version string, or None on error.
    """
    try:
        response = requests.get(
            f'https://pypi.org/pypi/{package}/json',
            timeout=15
        )
    except requests.RequestException as e:
        print(f"[ERROR] Network error for {package}: {e}")
        return None

    if response.status_code != 200:
        print(f"[ERROR] Could not fetch data for {package} from PyPI (HTTP {response.status_code}).")
        return None

    try:
        data = response.json()
        return data['info']['version']
    except (ValueError, KeyError) as e:
        print(f"[ERROR] Unexpected PyPI response for {package}: {e}")
        return None


def is_newer(latest_version, current_version):
    """Return True if latest_version is strictly newer than current_version."""
    try:
        return version.parse(latest_version) > version.parse(current_version)
    except Exception:
        # Fallback to string comparison
        return current_version != latest_version


def check_newer_versions(packages):
    """Query PyPI for each package and report newer versions."""
    for package, current_version in packages:
        latest_version = get_latest_version(package)
        if latest_version is None:
            continue

        if is_newer(latest_version, current_version):
            print(f"Package: {package}, Current Version: {current_version}, "
                  f"Newer Version: {latest_version}")


def update_version_in_file(file_path, package, new_version, dry_run=False):
    """Update the version of a package in the shell script (in-place).

    Returns True if the version was changed, False otherwise.
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except (FileNotFoundError, IOError) as e:
        print(f"[ERROR] Could not read {file_path}: {e}")
        return False

    # Match the package name (with optional extras) followed by ==version
    # e.g.  amaranth[builtin-yosys]==0.5.6  or  cocotb==2.0.1
    pattern = re.compile(
        r'(' + re.escape(package) + r'(?:\[[^\]]*\])?)=='
        r'(\d+(?:\.\d+)*)'
    )

    match = pattern.search(content)
    if not match:
        print(f"[ERROR] Could not find {package}==<version> in {file_path}")
        return False

    old_version = match.group(2)
    if old_version == new_version:
        return False  # already up-to-date

    new_content = pattern.sub(rf'\g<1>=={new_version}', content, count=1)

    if not dry_run:
        try:
            with open(file_path, 'w') as f:
                f.write(new_content)
        except IOError as e:
            print(f"[ERROR] Could not write {file_path}: {e}")
            return False

    print(f"  {package}: {old_version} -> {new_version}")
    return True


def update_versions(shell_script, packages, tool_filter=None, dry_run=False):
    """Check PyPI and update versions in the shell script.

    If tool_filter is given (list of package names), only those packages
    are considered for updating.
    """
    errors = 0
    updated = 0

    for package, current_version in packages:
        # If a tool filter is specified, skip packages not in the list
        if tool_filter and package not in tool_filter:
            continue

        latest_version = get_latest_version(package)
        if latest_version is None:
            errors += 1
            continue

        if is_newer(latest_version, current_version):
            if update_version_in_file(shell_script, package, latest_version, dry_run=dry_run):
                updated += 1
            else:
                errors += 1

    if updated > 0:
        action = "would be updated" if dry_run else "updated"
        print(f"\n{updated} package(s) {action}.")
    else:
        print("\nAll packages are up-to-date.")

    if errors > 0:
        print(f"{errors} error(s) occurred during processing.")
        sys.exit(1)


if __name__ == "__main__":
    default_script = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  '..', 'tool_pip.sh')

    prs = argparse.ArgumentParser(
        description="Check for newer versions of PIP packages "
                    "(and optionally update them in tool_pip.sh).")
    prs.add_argument("script", nargs="?", default=default_script,
                     help="Path to the shell script with pip packages "
                          f"(default: {default_script}).")
    prs.add_argument("-u", "--update", action="store_true",
                     help="Update the pip tool versions in the shell script.")
    prs.add_argument("-t", "--tools", nargs="+", metavar="PKG",
                     help="Only update the specified packages (used with -u).")
    prs.add_argument("--dry-run", action="store_true",
                     help="Show what would be updated without writing changes.")

    args = prs.parse_args()

    installed_packages = get_installed_packages(args.script)

    if args.update:
        print(f'Updating pip versions in: "{args.script}"')
        if args.tools:
            print(f"Filtering packages: {', '.join(args.tools)}")
        update_versions(args.script, installed_packages,
                        tool_filter=args.tools, dry_run=args.dry_run)
    else:
        check_newer_versions(installed_packages)
