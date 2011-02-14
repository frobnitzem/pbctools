mol new long_molecules.psf waitfor all
mol addfile long_molecules.pdb waitfor all

mol modstyle 0 0 lines
mol modcolor 0 0 ResID

pbc box -style arrows -color silver -material Glossy

pbc join fragment -verbose -bondlist






