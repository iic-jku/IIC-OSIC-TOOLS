#!python3
# ========================================================================
# Update tool versions from YAML manifest file
#
# SPDX-FileCopyrightText: 2022-2025 Harald Pretl and Georg Zachl
# Johannes Kepler University, Institute for Integrated Circuits
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
import tools_lib.dockerfile_manipulator as df_man
import tools_lib.yaml_manipulator as yaml_man

if __name__ == "__main__":
    prs = argparse.ArgumentParser(description="Update the tool commits/revisions from a local yaml file (e.g.: tool_metadata.yml)")
    prs.add_argument("--dry-run", action="store_true", help="Disable writing the Dockerfile, just print the results.")
    prs.add_argument("--dockerfile-path", action="store", type=str, default="Dockerfile", help="Change the location of the Dockerfile involved.")
    prs.add_argument("--metadata-path", action="store", type=str, default="tool_metadata.yml", help="Change the location of the tool_metadata.yml input file.")

    args = prs.parse_args()

    print(f"Loading tool metadata from: \"{args.metadata_path}\"")
    raw_meta = yaml_man.metadata_read(args.metadata_path)
    if raw_meta is not None:
        data = yaml_man.metadata_parse(raw_meta)
        print(f"Loading Dockerfile from: \"{args.dockerfile_path}\"")
        df_contents = df_man.read_dockerfile(path=args.dockerfile_path)
        if df_contents is not None:
            tools = df_man.get_existing_tools(df_contents)
            for tool in tools:
                new_rev =  yaml_man.get_revision(data, tool)
                if new_rev is not None:
                    print(f"Found for {tool}: {new_rev}")
                    if not df_man.update_revision(df_contents, tool, new_rev):
                        print( "###########################################################")
                        print(f"ERROR: updating the revision for {tool} failed!")
                        print( "###########################################################")
        #print(df_contents)
            if not args.dry_run:
                print(f"Writing Dockerfile to {args.dockerfile_path}")
                df_man.write_dockerfile(df_contents, path=args.dockerfile_path)
    #print([x for x in data if x['name'] == 'drcu'][0])
