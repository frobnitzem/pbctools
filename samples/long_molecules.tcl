mol load psf long_molecules.psf pdb long_molecules.pdb

mol modstyle 0 0 lines
mol modcolor 0 0 ResID

pbc box -style arrows -color silver -material Glossy

pbc join fragment -verbose -bondlist






