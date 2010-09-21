mol load psf small_molecules.psf pdb small_molecules.pdb

mol modstyle 0 0 lines
mol modcolor 0 0 SegName

pbc set {10.0 10.0 10.0} -all
pbc box

pbc wrap -all
pbc join connected -verbose






