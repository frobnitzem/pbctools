mol new small_molecules.psf waitfor all
mol addfile small_molecules.pdb waitfor all

mol modstyle 0 0 lines
mol modcolor 0 0 SegName

pbc set {10.0 10.0 10.0} -all
pbc box

pbc wrap -all
pbc join connected -verbose






