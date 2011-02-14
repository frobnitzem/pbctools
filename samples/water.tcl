# Simple water box example
mol new water.psf waitfor all
mol addfile water.dcd waitfor all

pbc box
pbc wrap -all -compound res
