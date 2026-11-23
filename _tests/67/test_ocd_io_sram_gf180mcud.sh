#!/bin/bash
# SPDX-FileCopyrightText: 2026 Simon Dorrer
# Johannes Kepler University, Department for Integrated Circuits
# SPDX-License-Identifier: Apache-2.0
#
# Check the split-voltage IO library gf180mcu_ocd_io and the 3.3 V SRAM gf180mcu_ocd_ip_sram of gf180mcuD, which ciel installs only on request (see install_ciel.sh).
# OpenROAD links one instance of every SRAM size, each driving a bi_t pad, against their LEF and gzipped Liberty, and times it at the three 3.3 V corners.
# One OpenROAD run per corner, since the multi-corner commands differ between OpenROAD versions (define_corners, define_scene).
# The IO Liberty of each corner is the file the PDK's LibreLane PAD_LIBS names for it.

if [ -z "${RAND}" ]; then
    RAND=$(hexdump -v -e '/1 "%02x"' -n4 < /dev/urandom)
fi

# test output is kept out of the bind-mounted source tree (see run_integration_tests.sh)
RUNS_DIR=${IIC_TEST_RUNDIR:-/tmp/iic-osic-tools-tests}
DEBUG=${DEBUG:-0}

WORKDIR=${RUNS_DIR}/${RAND}/67
LOG=$WORKDIR/openroad.log
TEST_NAME="gf180mcu_ocd_io and gf180mcu_ocd_ip_sram with gf180mcuD"
mkdir -p "$WORKDIR"

# shellcheck source=/dev/null
source sak-pdk-script.sh gf180mcuD gf180mcu_as_sc_mcu7t3v3 > /dev/null
REF=$PDK_ROOT/$PDK/libs.ref
IO_CFG=$PDK_ROOT/$PDK/libs.tech/librelane/gf180mcu_ocd_io/config.tcl
SRAMS="64x8 256x8 512x8 1024x8"
CORNERS="tt_025C_3v30 ss_125C_3v00 ff_n40C_3v60"

FAILED=""
for lib in gf180mcu_ocd_io gf180mcu_ocd_ip_sram; do
    [ -d "$REF/$lib" ] || FAILED="${FAILED:+$FAILED, }$lib is not installed"
done

# One read_liberty file per corner, the IO file taken from the PAD_LIBS entry of that corner
if [ -z "$FAILED" ]; then
    for c in $CORNERS; do
        io_corner=$(awk -v key="*_$c" '$4 == key { getline; if (match($0, /__[A-Za-z0-9_]+\.lib\.gz/)) print substr($0, RSTART + 2, RLENGTH - 9); exit }' "$IO_CFG")
        files="$REF/gf180mcu_ocd_io/lib/gf180mcu_ocd_io__${io_corner:-none}.lib.gz"
        for s in $SRAMS; do
            files="$files $REF/gf180mcu_ocd_ip_sram/lib/gf180mcu_ocd_ip_sram__sram${s}m8wm1__${c}.lib.gz"
        done
        : > "$WORKDIR/liberty_$c.tcl"
        for f in $files; do
            if [ -f "$f" ]; then
                echo "read_liberty $f" >> "$WORKDIR/liberty_$c.tcl"
            else
                FAILED="${FAILED:+$FAILED, }missing $(basename "$f") for corner $c"
            fi
        done
    done
fi

if [ -z "$FAILED" ]; then
    {
        echo "module ocd_top (clk, cen, gwen, wen, a, d, ctl, pad);"
        echo "  input clk, cen, gwen, ctl;"
        echo "  input [7:0] wen, d;"
        echo "  input [9:0] a;"
        echo "  inout [3:0] pad;"
        i=0
        for s in $SRAMS; do
            aw=$(grep -o -E 'input +\[[0-9]+:0\] +A\b' "$REF/gf180mcu_ocd_ip_sram/verilog/gf180mcu_ocd_ip_sram__sram${s}m8wm1__blackbox_pp.v" | grep -o -E '[0-9]+' | head -1)
            echo "  wire [7:0] q$i;"
            echo "  gf180mcu_ocd_ip_sram__sram${s}m8wm1 sram$i (.CLK(clk), .CEN(cen), .GWEN(gwen), .WEN(wen), .A(a[${aw}:0]), .D(d), .Q(q$i));"
            echo "  gf180mcu_ocd_io__bi_t io$i (.A(q${i}[0]), .OE(ctl), .IE(ctl), .CS(ctl), .SL(ctl), .PU(ctl), .PD(ctl), .PDRV0(ctl), .PDRV1(ctl), .PAD(pad[$i]));"
            i=$((i + 1))
        done
        echo "endmodule"
    } > "$WORKDIR/ocd_top.v"

    : > "$LOG"
    for c in $CORNERS; do
        {
            cat "$WORKDIR/liberty_$c.tcl"
            echo "read_lef $REF/gf180mcu_as_sc_mcu7t3v3/techlef/gf180mcu_as_sc_mcu7t3v3__nom.tlef"
            echo "read_lef $REF/gf180mcu_ocd_io/lef/gf180mcu_ocd_io.lef"
            for s in $SRAMS; do
                echo "read_lef $REF/gf180mcu_ocd_ip_sram/lef/gf180mcu_ocd_ip_sram__sram${s}m8wm1.lef"
            done
            echo "read_verilog $WORKDIR/ocd_top.v"
            echo "link_design ocd_top"
            # shellcheck disable=SC2016 # $inst is Tcl
            echo 'foreach inst [get_cells *] { if {[get_lib_cells -quiet -of_objects $inst] == ""} { puts "NO_LIBERTY [get_full_name $inst]" } }'
            echo "create_clock -name clk -period 40 [get_ports clk]"
            echo "set_input_delay 0 -clock clk [get_ports {cen gwen ctl wen[*] a[*] d[*]}]"
            echo "set_output_delay 0 -clock clk [get_ports {pad[*]}]"
            echo "puts \"CORNER $c\""
            echo "report_checks -path_delay max -to [get_ports {pad[*]}]"
        } > "$WORKDIR/check_$c.tcl"

        (cd "$WORKDIR" && openroad -exit -no_splash "check_$c.tcl") >> "$LOG" 2>&1
        OR_RC=$?
        [ "$OR_RC" -eq 0 ] || FAILED="${FAILED:+$FAILED, }openroad exited with $OR_RC at corner $c"
    done
    if [ -z "$FAILED" ] && grep -q -E '\[ERROR|^Error' "$LOG"; then
        FAILED="error in the OpenROAD log"
    fi
    if [ -z "$FAILED" ] && grep -q "NO_LIBERTY" "$LOG"; then
        FAILED="instances without a Liberty cell: $(grep NO_LIBERTY "$LOG" | cut -d' ' -f2 | sort -u | tr '\n' ' ')"
    fi
    # A timed path to a pad in every corner, so each corner's SRAM and IO Liberty were read and linked
    if [ -z "$FAILED" ]; then
        TIMED=$(awk '/^CORNER/ { c = $2 } /slack \((MET|VIOLATED)\)/ && c != "" { print c; c = "" }' "$LOG" | wc -l)
        [ "$TIMED" -eq 3 ] || FAILED="timed paths found in $TIMED of 3 corners"
    fi
fi

[ "$DEBUG" = "1" ] && [ -f "$LOG" ] && cat "$LOG"

if [ -n "$FAILED" ]; then
    LOGS=""
    [ -f "$LOG" ] && LOGS=" Check the log <$LOG>."
    echo "[ERROR] Test <$TEST_NAME> FAILED ($FAILED).$LOGS"
    exit 1
else
    echo "[INFO] Test <$TEST_NAME> passed."
    exit 0
fi
