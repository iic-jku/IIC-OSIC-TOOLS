#!python3
# ========================================================================
# Check for newer versions of PIP packages
#
# SPDX-FileCopyrightText: 2025 Harald Pretl
# Johannes Kepler University, Institute for Integrated Circuits and
# Quantum Computing (IICQC)
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

import sys
import re
import requests

def get_installed_packages(shell_script):
    try:
        with open(shell_script, 'r') as file:
            content = file.read()
    except FileNotFoundError:
        print(f"[ERROR] File {shell_script} not found.")
        sys.exit(1)
    
    # Extract package names and versions from the shell script content
    installed_packages = re.findall(r'([\w\-]+)==([\d\.]+)', content)
    return installed_packages

def check_newer_versions(packages):
    for package, current_version in packages:
        # Get the latest version of the package from PyPI
        response = requests.get(f'https://pypi.org/pypi/{package}/json')
        if response.status_code != 200:
            print(f"[ERROR] Could not fetch data for {package} from PyPI.")
            continue
        
        data = response.json()
        latest_version = data['info']['version']
        
        if current_version != latest_version:
            print(f"Package: {package}, Current Version: {current_version}, Newer Version: {latest_version}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python check_packages.py <shell_script>")
        sys.exit(1)
    
    shell_script = sys.argv[1]
    installed_packages = get_installed_packages(shell_script)
    check_newer_versions(installed_packages)
