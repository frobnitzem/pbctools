
mol load psf DPD_den_solv_s.psf 

set i_start 0
set i_end 9
set L 10

for {set i $i_start} {$i <= $i_end } {incr i} {

animate read pdb DPD_den_solv_s$i.pdb

}



mol modstyle 0 0 line 

mol modcolor 0 0 SegName

pbc set "$L $L $L" -all
set box0 [pbc box_draw -shiftcenterrel "0 0 0" ]

pbc wrap -all
pbc join connected -verbose  -all





