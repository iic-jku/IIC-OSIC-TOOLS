#!python3
# ========================================================================
# Check for newer versions of YAML packages from various Git hosting services
# Supports GitHub, GitLab, and Codeberg repositories
#
# SPDX-FileCopyrightText: 2025 Harald Pretl
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

import sys
import yaml
import requests
import re

try:
    from packaging import version
    HAS_PACKAGING = True
except ImportError:
    HAS_PACKAGING = False

def get_repos_from_yaml(yaml_file):
    try:
        with open(yaml_file, 'r') as file:
            repos = yaml.safe_load(file)
    except FileNotFoundError:
        print(f"Error: File {yaml_file} not found.")
        sys.exit(1)
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML file: {exc}")
        sys.exit(1)
    
    return repos

def normalize_version(version_string):
    """Normalize version string for comparison."""
    # Remove common prefixes
    version_string = re.sub(r'^[vr]', '', version_string, flags=re.IGNORECASE)
    # Handle release- prefix
    version_string = re.sub(r'^release[-_]', '', version_string, flags=re.IGNORECASE)
    # Handle trilinos-release- prefix
    version_string = re.sub(r'^trilinos-release[-_]', '', version_string, flags=re.IGNORECASE)
    # Handle ngspice- prefix
    version_string = re.sub(r'^ngspice[-_]', '', version_string, flags=re.IGNORECASE)
    # Handle underscores at start
    version_string = re.sub(r'^_', '', version_string)
    return version_string

def is_version_newer(current_tag, latest_tag):
    """Compare two version tags to determine if latest is newer than current."""
    try:
        # Normalize both versions
        current_norm = normalize_version(current_tag)
        latest_norm = normalize_version(latest_tag)
        
        # Try semantic versioning comparison if packaging is available
        if HAS_PACKAGING:
            try:
                return version.parse(latest_norm) > version.parse(current_norm)
            except Exception:
                pass  # Fall through to manual comparison
        
        # Manual version comparison for basic semantic versions
        current_parts = [int(x) if x.isdigit() else x for x in re.split(r'[.-]', current_norm)]
        latest_parts = [int(x) if x.isdigit() else x for x in re.split(r'[.-]', latest_norm)]
        
        # Pad with zeros to make them same length
        max_len = max(len(current_parts), len(latest_parts))
        current_parts.extend([0] * (max_len - len(current_parts)))
        latest_parts.extend([0] * (max_len - len(latest_parts)))
        
        for i in range(max_len):
            if isinstance(latest_parts[i], int) and isinstance(current_parts[i], int):
                if latest_parts[i] > current_parts[i]:
                    return True
                elif latest_parts[i] < current_parts[i]:
                    return False
            else:
                # String comparison for non-numeric parts
                if str(latest_parts[i]) > str(current_parts[i]):
                    return True
                elif str(latest_parts[i]) < str(current_parts[i]):
                    return False
        
        return False  # Versions are equal
    except Exception:
        # Ultimate fallback to string comparison
        current_norm = normalize_version(current_tag)
        latest_norm = normalize_version(latest_tag)
        return latest_norm > current_norm

def find_latest_tag(tags, current_tag):
    """Find the latest tag that is newer than the current tag."""
    # Filter out non-version-like tags (avoid branches, weird tags)
    version_tags = []
    for tag in tags:
        # Skip tags that look like commit hashes
        if re.match(r'^[0-9a-f]{7,40}$', tag):
            continue
        # Skip tags that are obviously not versions (like "main", "master", "HEAD")
        if tag.lower() in ['main', 'master', 'head', 'latest', 'dev', 'development']:
            continue
        # Include tags that contain version-like patterns
        if re.search(r'\d+(\.\d+)*', tag):
            version_tags.append(tag)
    
    if not version_tags:
        return None
    
    # Sort tags to process them in a reasonable order
    # This helps with finding the actual latest version
    try:
        if HAS_PACKAGING:
            version_tags.sort(key=lambda x: version.parse(normalize_version(x)), reverse=True)
        else:
            # Basic sorting fallback
            version_tags.sort(reverse=True)
    except Exception:
        version_tags.sort(reverse=True)
    
    # Find the latest version that's newer than current
    for tag in version_tags:
        if is_version_newer(current_tag, tag):
            return tag
    
    return None

def get_repo_info(repo_url):
    """Extract hosting service, owner, and repo name from repository URL."""
    # GitHub
    github_match = re.search(r'github\.com/([^/]+)/([^/]+)\.git', repo_url)
    if github_match:
        return 'github', github_match.groups()
    
    # GitLab.com
    gitlab_match = re.search(r'gitlab\.com/([^/]+)/([^/]+)\.git', repo_url)
    if gitlab_match:
        return 'gitlab', gitlab_match.groups()
    
    # Codeberg
    codeberg_match = re.search(r'codeberg\.org/([^/]+)/([^/]+)\.git', repo_url)
    if codeberg_match:
        return 'codeberg', codeberg_match.groups()
    
    return None, None

def check_newer_versions(repos, token):
    for repo in repos:
        name = repo['name']
        repo_url = repo['repo']
        current_version = repo['commit']
        
        # Get repository hosting service and info
        service, repo_info = get_repo_info(repo_url)
        
        if not service:
            print(f"Skipping unsupported repository: {repo_url}")
            continue
            
        owner, repo_name = repo_info
        
        # Set up headers and API URLs based on service
        if service == 'github':
            headers = {'Authorization': f'token {token}'}
            commits_url = f'https://api.github.com/repos/{owner}/{repo_name}/commits'
            tags_url = f'https://api.github.com/repos/{owner}/{repo_name}/tags'
        elif service == 'gitlab':
            headers = {'Authorization': f'Bearer {token}'}
            # URL encode the project path for GitLab API
            project_path = f"{owner}/{repo_name}"
            commits_url = f'https://gitlab.com/api/v4/projects/{owner}%2F{repo_name}/repository/commits'
            tags_url = f'https://gitlab.com/api/v4/projects/{owner}%2F{repo_name}/repository/tags'
        elif service == 'codeberg':
            headers = {'Authorization': f'token {token}'}
            commits_url = f'https://codeberg.org/api/v1/repos/{owner}/{repo_name}/commits'
            tags_url = f'https://codeberg.org/api/v1/repos/{owner}/{repo_name}/tags'
        
        if re.match(r'^[0-9a-f]{40}$', current_version):  # Check if the commit is a hash
            # Get the latest commit from API
            response = requests.get(commits_url, headers=headers)
            if response.status_code != 200:
                print(f"Error fetching data for {name} from {service}: {response.status_code}")
                continue
            
            data = response.json()
            
            # Extract commit hash based on service response format
            if service == 'github' or service == 'codeberg':
                latest_commit = data[0]['sha']
            elif service == 'gitlab':
                latest_commit = data[0]['id']
            
            if current_version != latest_commit:
                print(f"Repository: {name}, Current Commit: {current_version}, Newer Commit: {latest_commit}")
        else:  # Assume the commit is a tag
            # Get the tags from API
            response = requests.get(tags_url, headers=headers)
            if response.status_code != 200:
                print(f"Error fetching data for {name} from {service}: {response.status_code}")
                continue
            
            data = response.json()
            tags = [tag['name'] for tag in data]
            
            # Find the latest tag that's newer than the current tag
            latest_tag = find_latest_tag(tags, current_version)
            
            if latest_tag:
                print(f"Repository: {name}, Current Tag: {current_version}, Newer Tag: {latest_tag}")
            else:
                print(f"Repository: {name}, Current Tag: {current_version} - No newer version found")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python check_repos.py <yaml_file> <access_token>")
        print("Note: Supports GitHub, GitLab, and Codeberg repositories")
        print("      Use appropriate access token for the hosting service")
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    access_token = sys.argv[2]
    repos = get_repos_from_yaml(yaml_file)
    check_newer_versions(repos, access_token)