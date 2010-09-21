# Simple water box example
mol load psf water.psf dcd water.dcd

pbc box
pbc wrap -all -compound res
