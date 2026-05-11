#!/usr/bin/env python3
# ========================================================================
# SPDX-FileCopyrightText: 2021-2026 Harald Pretl
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
# results. Duplicate .subckt and .model definitions (which can occur
# via repeated includes) are emitted only once. This should speed up
# ngspice starts.
# ========================================================================

import sys, re, os

written_subcircuits = set()
written_models = set()

def process_file(file_in_name, top_file):
    global is_warning
    try:
        f_in = open(file_in_name, 'r', encoding='utf-8', errors='replace')
    except FileNotFoundError:
        print('[WARNING] File ' + file_in_name + ' not found.')
        is_warning = True
        return

    # process_file can be called recursively, so that nested include
    # files can be traversed

    # write_active indicates whether we are in the right model section; in
    # include files, it is always true

    if top_file == True:
        write_active = False
    else:
        write_active = True

    subckt_depth = 0
    subckt_skip = False           # currently inside a duplicate .subckt block
    prev_line_skipped = False     # tracks whether the previous non-blank,
                                  # non-comment line was suppressed, so that
                                  # '+' continuation lines follow the same fate

    for line in f_in:
        line_trim = (line.lower()).strip()

        # skip empty lines and comments
        if len(line_trim) == 0 or line_trim[0] == '*':
            continue

        tokens = line_trim.split()
        first_token = tokens[0] if tokens else ''
        is_continuation = first_token.startswith('+')

        if top_file == True and not is_continuation:
            # .lib <section>   (definition form, e.g. sky130 corner sections)
            # match section name as a separate token, not as a substring
            if first_token == '.lib' and len(tokens) >= 2:
                if tokens[1] == model_section:
                    write_active = True
                else:
                    write_active = False
                # do not write the .lib marker itself
                prev_line_skipped = True
                continue

            # .endl  or  .endl <section>  -> end of current .lib section
            if first_token == '.endl':
                was_active = write_active
                write_active = False
                if was_active:
                    f_out.write(line)
                    prev_line_skipped = False
                else:
                    prev_line_skipped = True
                continue

        if not write_active:
            prev_line_skipped = True
            continue

        # continuation lines inherit the previous line's write/skip decision
        if is_continuation:
            if not prev_line_skipped:
                f_out.write(line)
            continue

        # .include handling (only outside a skipped subcircuit)
        if first_token == '.include' and not subckt_skip:
            current_wd = os.getcwd()
            newfile = re.findall(r'"(.*?)(?<!\\)"', line_trim)
            if not newfile:
                print('[WARNING] Malformed .include line: ' + line_trim)
                is_warning = True
                prev_line_skipped = True
                continue
            print('[INFO] Reading ', newfile[0])

            new_wd = os.path.dirname(newfile[0])
            if len(new_wd) > 0:
                try:
                    os.chdir(new_wd)
                except OSError:
                    print('[WARNING] Could not enter directory ' + new_wd)
                    is_warning = True

            new_file_name = os.path.basename(newfile[0])
            process_file(new_file_name, False)

            os.chdir(current_wd)
            prev_line_skipped = False
            continue

        # subcircuit start: dedup on the outermost level only
        if first_token == '.subckt':
            if subckt_depth == 0:
                subckt_name = tokens[1] if len(tokens) > 1 else ''
                if subckt_name in written_subcircuits:
                    subckt_skip = True
                else:
                    written_subcircuits.add(subckt_name)
                    subckt_skip = False
            subckt_depth += 1
            if not subckt_skip:
                f_out.write(line)
                prev_line_skipped = False
            else:
                prev_line_skipped = True
            continue

        # subcircuit end
        if first_token == '.ends':
            if not subckt_skip:
                f_out.write(line)
                prev_line_skipped = False
            else:
                prev_line_skipped = True
            if subckt_depth > 0:
                subckt_depth -= 1
            if subckt_depth == 0 and subckt_skip:
                subckt_skip = False
            continue

        # .model dedup (only at top level, not inside subcircuits)
        if first_token == '.model' and subckt_depth == 0:
            model_name = tokens[1] if len(tokens) > 1 else ''
            duplicate_model = model_name in written_models
            if not duplicate_model:
                written_models.add(model_name)
            if subckt_skip or duplicate_model:
                prev_line_skipped = True
            else:
                f_out.write(line)
                prev_line_skipped = False
            continue

        # regular line: skip if inside duplicate subcircuit
        if subckt_skip:
            prev_line_skipped = True
        else:
            f_out.write(line)
            prev_line_skipped = False

    f_in.close()
    return

# main routine

if len(sys.argv) == 3:
    model_section = sys.argv[2]
else:
    model_section = 'tt'

if (len(sys.argv) == 2) or (len(sys.argv) == 3):
    infile_name = sys.argv[1]
    outfile_name = infile_name + '.' + model_section + '.red'

    try:
        f_out = open(outfile_name, 'w', encoding='utf-8')
    except OSError:
        print('[ERROR] Cannot write file ' + outfile_name + '.')
        sys.exit(1)
    
    is_warning = False
    process_file(infile_name, True)
    f_out.close()

    print()
    print('Model file ' + outfile_name + ' written.')
    if is_warning:
        print('[WARNING] There have been warnings! Please check output log.')
    sys.exit(0)
else:
    print()
    print('sak-spice-model-red.py    SPICE model file reducer')
    print('                          (c) 2021-2026 Harald Pretl, JKU')
    print()
    print('Usage: sak-spice-model-red <inputfile> [corner] (default corner = tt)')
    print()
    print('Flattens included SPICE files, strips comments/empty lines, and')
    print('emits duplicate .subckt / .model definitions only once.')
    print()
    print('Return codes for script automation:')
    print('  0 = all OK or warnings')
    print('  1 = errors')
    print('  2 = call of script w/o parameters (= showing this message)')
    print()
    sys.exit(2)
