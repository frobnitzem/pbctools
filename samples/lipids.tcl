# Non-orthogonal system with varying unit cell parameters
mol load vtf lipids.vtf

# Draw the box
pbc wrap -orthorhombic -all -verbose -center com -centersel "residue 146" -compound res
pbc box -orthorhombic -center com -centersel "residue 146"
