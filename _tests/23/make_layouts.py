# Builds the layouts of test 23 that are not a plain copy of a standard cell:
#   <pdk>/inv.gds          the inverter standard cell with the top cell renamed to "inv" (for inv.sch)
#   ihp-sg13g2/invchain.gds two sg13g2_inv_1 instances in series, hierarchical (for invchain.v)
# usage: python3 make_layouts.py <dir with the test 23 data> <output dir>
import sys, os
import klayout.db as kdb
src, out = sys.argv[1], sys.argv[2]
cells = {'ihp-sg13g2': 'sg13g2_inv_1', 'ihp-sg13cmos5l': 'sg13cmos5l_inv_1',
         'gf180mcuD': 'gf180mcu_fd_sc_mcu7t5v0__inv_1', 'sky130A': 'sky130_fd_sc_hd__inv_1'}
for pdk, cell in cells.items():
    ly = kdb.Layout(); ly.read(os.path.join(src, pdk, cell + '.gds'))
    assert ly.top_cell().name == cell
    ly.top_cell().name = 'inv'
    os.makedirs(os.path.join(out, pdk), exist_ok=True)
    ly.write(os.path.join(out, pdk, 'inv.gds'))

# invchain: instance 0 at x=0, instance 1 one cell width to the right. Y of instance 0 and A of instance 1 are
# connected by a Metal1 strap between the two pin shapes. The top cell repeats the pin shapes it labels.
ly = kdb.Layout(); ly.read(os.path.join(src, 'ihp-sg13g2', 'sg13g2_inv_1.gds'))
inv = ly.top_cell(); W = 1440
top = ly.create_cell('invchain')
top.insert(kdb.CellInstArray(inv.cell_index(), kdb.Trans(0, 0)))
top.insert(kdb.CellInstArray(inv.cell_index(), kdb.Trans(W, 0)))
m1, m1pin, m1txt = ly.layer(8, 0), ly.layer(8, 2), ly.layer(8, 25)
top.shapes(m1).insert(kdb.Box(1085, 1520, W + 310, 1850))                       # Y(0) to A(1)
pins = {'A': kdb.Box(310, 1520, 625, 1850), 'Y': kdb.Box(W + 855, 610, W + 1085, 3175),
        'VDD': kdb.Box(0, 3560, 2 * W, 4000), 'VSS': kdb.Box(0, -220, 2 * W, 220)}
for name, box in pins.items():
    top.shapes(m1).insert(box); top.shapes(m1pin).insert(box)
    top.shapes(m1txt).insert(kdb.Text(name, kdb.Trans(box.center().x, box.center().y)))
ly.write(os.path.join(out, 'ihp-sg13g2', 'invchain.gds'))
