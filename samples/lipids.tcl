# Non-orthogonal system with varying unit cell parameters
mol new lipids.vtf waitfor all

# Draw the box
pbc wrap -orthorhombic -all -verbose -center com -centersel "residue 146" -compound res
pbc box -orthorhombic -center com -centersel "residue 146"
