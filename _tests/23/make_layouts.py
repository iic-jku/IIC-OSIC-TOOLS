# Builds the layouts of test 23 that are not a plain copy of a standard cell:
#   <pdk>/inv.gds                  the inverter standard cell with the top cell renamed to "inv" (for inv.sch)
#   ihp-sg13g2/invchain.gds        two sg13g2_inv_1 instances in series, hierarchical (for invchain.v)
#   ihp-sg13g2/invchain_psd.gds    invchain with the pSD implant of the inverters drawn in the top cell (for -F)
#   ihp-sg13g2/invchain_joined.gds invchain with a second label VSS2 on the VSS strap (for -J)
#   ihp-sg13g2/invchain_wrap.gds   invchain inside a top cell without labels (for -W)
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
W = 1440


def invchain(ly, inv, name):
    top = ly.create_cell(name)
    top.insert(kdb.CellInstArray(inv.cell_index(), kdb.Trans(0, 0)))
    top.insert(kdb.CellInstArray(inv.cell_index(), kdb.Trans(W, 0)))
    m1, m1pin, m1txt = ly.layer(8, 0), ly.layer(8, 2), ly.layer(8, 25)
    top.shapes(m1).insert(kdb.Box(1085, 1520, W + 310, 1850))                       # Y(0) to A(1)
    pins = {'A': kdb.Box(310, 1520, 625, 1850), 'Y': kdb.Box(W + 855, 610, W + 1085, 3175),
            'VDD': kdb.Box(0, 3560, 2 * W, 4000), 'VSS': kdb.Box(0, -220, 2 * W, 220)}
    for pin, box in pins.items():
        top.shapes(m1).insert(box); top.shapes(m1pin).insert(box)
        top.shapes(m1txt).insert(kdb.Text(pin, kdb.Trans(box.center().x, box.center().y)))
    return top


def read_inv():
    ly = kdb.Layout(); ly.read(os.path.join(src, 'ihp-sg13g2', 'sg13g2_inv_1.gds'))
    return ly, ly.top_cell()


ly, inv = read_inv()
invchain(ly, inv, 'invchain')
ly.write(os.path.join(out, 'ihp-sg13g2', 'invchain.gds'))

# invchain_psd: the pSD implant of the inverters moves into the top cell, as in IO cells that take an implant from a
# neighbour. Magic extracts the inverter cell on its own without it, KLayout and a flat read see it.
ly, inv = read_inv()
inv.name = 'inv_psd'
psd = ly.layer(14, 0)
implant = kdb.Region(inv.shapes(psd))
assert not implant.is_empty()
inv.shapes(psd).clear()
top = invchain(ly, inv, 'invchain_psd')
for x in (0, W):
    top.shapes(psd).insert(implant.moved(x, 0))
ly.write(os.path.join(out, 'ihp-sg13g2', 'invchain_psd.gds'))

# invchain_joined: a second label on the VSS strap, as on a chip whose core and IO grounds the substrate joins
ly, inv = read_inv()
top = invchain(ly, inv, 'invchain_joined')
top.shapes(ly.layer(8, 25)).insert(kdb.Text('VSS2', kdb.Trans(W + W // 2, 0)))
ly.write(os.path.join(out, 'ihp-sg13g2', 'invchain_joined.gds'))

# invchain_wrap: invchain one level down in a top cell without labels, as a chip in its fill wrapper
ly, inv = read_inv()
chain = invchain(ly, inv, 'invchain')
wrap = ly.create_cell('invchain_wrap')
wrap.insert(kdb.CellInstArray(chain.cell_index(), kdb.Trans(0, 0)))
ly.write(os.path.join(out, 'ihp-sg13g2', 'invchain_wrap.gds'))
