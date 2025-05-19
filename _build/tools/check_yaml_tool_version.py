#!python3
# ========================================================================
# Check for newer versions of YAML packages
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

def check_newer_versions(repos, token):
    headers = {'Authorization': f'token {token}'}
    
    for repo in repos:
        name = repo['name']
        repo_url = repo['repo']
        current_version = repo['commit']
        
        # Check if the repository URL is a GitHub URL
        if not re.match(r'https://github\.com/[^/]+/[^/]+\.git', repo_url):
            print(f"Skipping non-GitHub repository: {repo_url}")
            continue
        
        # Extract the owner and repo name from the URL
        match = re.search(r'github\.com/([^/]+)/([^/]+)\.git', repo_url)
        if not match:
            print(f"Error parsing repository URL: {repo_url}")
            continue
        
        owner, repo_name = match.groups()
        
        if re.match(r'^[0-9a-f]{40}$', current_version):  # Check if the commit is a hash
            # Get the latest commit from GitHub API
            response = requests.get(f'https://api.github.com/repos/{owner}/{repo_name}/commits', headers=headers)
            if response.status_code != 200:
                print(f"Error fetching data for {name} from GitHub: {response.status_code}")
                continue
            
            data = response.json()
            latest_commit = data[0]['sha']
            
            if current_version != latest_commit:
                print(f"Repository: {name}, Current Commit: {current_version}, Newer Commit: {latest_commit}")
        else:  # Assume the commit is a tag
            # Get the tags from GitHub API
            response = requests.get(f'https://api.github.com/repos/{owner}/{repo_name}/tags', headers=headers)
            if response.status_code != 200:
                print(f"Error fetching data for {name} from GitHub: {response.status_code}")
                continue
            
            data = response.json()
            tags = [tag['name'] for tag in data]
            
            # Filter tags to match the style of the current version
            tag_style = re.escape(current_version)
            matching_tags = [tag for tag in tags if re.match(tag_style, tag)]
            
            if not matching_tags:
                print(f"No matching tags found for {name}.")
                continue
            
            latest_tag = matching_tags[0]
            
            if current_version != latest_tag:
                print(f"Repository: {name}, Current Tag: {current_version}, Newer Tag: {latest_tag}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python check_repos.py <yaml_file> <github_token>")
        sys.exit(1)
    
    yaml_file = sys.argv[1]
    github_token = sys.argv[2]
    repos = get_repos_from_yaml(yaml_file)
    check_newer_versions(repos, github_token)