# Simple water box example
mol new water.psf waitfor all
mol addfile water.dcd waitfor all

pbc box
pbc wrap -all -cell compact
# -compound res doesn't work with -cell compact, so use a separate join step:
pbc join res -all
