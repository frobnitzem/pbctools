load ./libpbc_core.so

set L [list {1 0 0} {0.5 0.8660254 0} {0.5 0.28 0.81649658}]
set x [list {1 1 1} {2 2 2} {3 3 3}]

set xp [wrap_min $L {0. 0. 0.} $x]

lindex $xp 0

