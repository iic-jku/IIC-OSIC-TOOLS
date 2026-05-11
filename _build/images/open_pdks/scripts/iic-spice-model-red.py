#!/usr/bin/env python3
# ========================================================================
# SPDX-FileCopyrightText: 2021-2022 Harald Pretl
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
#
# This script traverses SPICE model files (e.g. from SKY130) and
# extracts only the wanted model section, removes all comments and
# empty lines, and resolves all includes so that a flat model file
# results. This should speed up ngspice starts.
#
# Duplicate .subckt definitions (caused by the same file being included
# more than once through different paths) are detected and silently
# dropped so that simulators do not emit "redefined subcircuit" warnings.
# ========================================================================

import sys,re,os

def process_file(file_in_name, top_file):
    global is_warning, seen_subcircuits, skip_subckt_depth
    try:
        f_in = open(file_in_name, 'r')
    except FileNotFoundError:
        print('Warning! File ' + file_in_name + ' not found.')
        is_warning = True
        return;

    # process_file can be called recursively, so that nested include
    # files can be traversed

    # write_active indicates whether we are in the right model section; in
    # include files, it is always true

    if top_file == True:
        write_active = False
    else:
        write_active = True

    for line in f_in:
        line_trim = (line.lower()).strip()

        if top_file == True:
            # we assume that .lib statements are only used in the main file
            if '.lib' in line_trim:
                if model_section in line_trim:
                    write_active = True
                else:
                    write_active = False

            if '.endl' == line_trim:
                write_active = False
                f_out.write(line)

        if len(line_trim) > 0: # write no empty lines
            if (line_trim[0] != '*'): # write no comments
                if (write_active == True):
                    words = line_trim.split()

                    if words[0] == '.subckt':
                        if skip_subckt_depth > 0:
                            # Nested .subckt inside an already-skipped block
                            skip_subckt_depth += 1
                        elif len(words) >= 2 and words[1] in seen_subcircuits:
                            # Duplicate definition: skip entire block
                            skip_subckt_depth = 1
                        else:
                            # New definition: record name and write
                            if len(words) >= 2:
                                seen_subcircuits.add(words[1])
                            f_out.write(line)

                    elif skip_subckt_depth > 0:
                        # Inside a skipped .subckt block: only track nesting depth
                        if words[0] == '.ends':
                            skip_subckt_depth -= 1

                    elif '.include' in line_trim:
                        # need to save and restore working dir so that nested
                        # includes work
                        current_wd = os.getcwd()
                        newfile = re.findall(r'"(.*?)(?<!\\)"', line_trim)
                        print('Reading ',newfile[0])

                        # enter new working dir
                        new_wd = os.path.dirname(newfile[0])
                        if len(new_wd) > 0:
                            try:
                                os.chdir(new_wd)
                            except OSError:
                                print('Warning: Could not enter directory ' + new_wd)
                                is_warning = True

                        # traverse into new include file
                        new_file_name = os.path.basename(newfile[0])
                        process_file(new_file_name, False)

                        # restore old working dir after return
                        os.chdir(current_wd)

                    else:
                        f_out.write(line)

    f_in.close()
    return;

# main routine

if len(sys.argv) == 3:
    model_section = sys.argv[2]
else:
    model_section = 'tt'

if (len(sys.argv) == 2) or (len(sys.argv) == 3):
    infile_name = sys.argv[1]
    outfile_name = infile_name + '.' + model_section + '.red'

    try:
        f_out = open(outfile_name, 'w')
    except OSError:
        print('Error: Cannot write file ' + outfile_name + '.')
        sys.exit(1)

    is_warning = False
    seen_subcircuits = set()
    skip_subckt_depth = 0
    process_file(infile_name, True)
    f_out.close()

    print()
    print('Model file ' + outfile_name + ' written.')
    if is_warning == True:
        print('There have been warnings! Please check output log.')
        sys.exit(0)
    else:
        sys.exit(0)
else:
    print()
    print('iic-spice-model-red.py    SPICE model file reducer')
    print('                          (c) 2021 Harald Pretl, JKU')
    print()
    print('Usage: iic-spice-model-red <inputfile> [corner] (default corner = tt)')
    print()
    print('Return codes for script automation:')
    print('  0 = all OK or warnings')
    print('  1 = errors')
    print('  2 = call of script w/o parameters (= showing this message)')
    print()
    sys.exit(2)
