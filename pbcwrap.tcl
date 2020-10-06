############################################################
#
#    This file contains procedures to wrap atoms into the central
# image of a system with periodic boundary conditions. The procedures
# required the VMD unit cell properties to be set. Use the procedure
# pbcset on this behalf.
#
# $Id$
#

package provide pbctools 3.0

namespace eval ::PBCTools:: {
    namespace export pbc*

    ############################################################
    #
    # pbcwrap [OPTIONS...]
    #
    # OPTIONS:
    #   -molid $molid|top
    #   -first $first|first|now 
    #   -last $last|last|now
    #   -all|allframes
    #   -now
    #   -compact|-parallelepiped|-brick
    #   -sel $sel
    #   -nocompound|-compound res[idue]|seg[ment]|chain|fragment
    #   -nocompoundref|-compoundref $sel
    #   -center origin|unitcell|com|centerofmass|bb|boundingbox
    #   -centersel $sel
    #   -shiftcenter $shift 
    #   -shiftcenterrel $shift
    #   -verbose
    #
    # AUTHORS: Jan, Olaf, David M. Rogers
    #
    proc pbcwrap { args } {
	# Set the defaults
	set molid "top"
	set first "now"
	set last "now"
	set wraptype "brick"
	set sel "all"
	set compound ""
	set compoundref ""
	set center "unitcell"
	set centerseltext "all"
	set shiftcenter {0 0 0}
	set shiftcenterrel {}
	set verbose 0

	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr $argnum + 1]]
	    switch -- $arg {
		"-molid" { set molid $val; incr argnum; }
		"-first" { set first $val; incr argnum }
		"-last" { set last $val; incr argnum }
		"-allframes" -
		"-all" { set last "last"; set first "first" }
		"-now" { set last "now"; set first "now" }
		"-sel" { set sel $val; incr argnum }
		"-nocompound" { set compound "" }
		"-compound" { set compound $val; incr argnum }
		"-nocompoundref" { set compoundref "" }
		"-compoundref" { set compoundref $val; incr argnum }
                "-cell" { set wraptype $val; incr argnum }
		"-center" { set center $val; incr argnum }
		"-centersel" { set centerseltext $val; incr argnum }
		"-shiftcenter" { set shiftcenter $val; incr argnum }
		"-shiftcenterrel" { set shiftcenterrel $val; incr argnum }
		"-verbose" { set verbose 1 }
		"-noverbose" { set verbose 0 }
		default { error "error: pbcwrap: unknown option: $arg" }
	    }
	}
	
	if { $molid=="top" } then { set molid [ molinfo top ] }

	# Save the current frame number
	set frame_before [ molinfo $molid get frame ]

	# handle first and last frame
	if { $first=="now" }   then { set first $frame_before }
	if { $first=="first" || $first=="start" || $first=="begin" } then { 
	    set first 0 
	}
	if { $last=="now" }    then { set last $frame_before }
	if { $last=="last" || $last=="end" } then {
	    set last [molinfo $molid get numframes]
	    incr last -1
	}

	# handle compounds
	switch -- $compound {
	    "" {}
	    "resid" { set compound "resid" }
	    "res" -
	    "residue" { set compound "residue" }
	    "seg" -
	    "segid" { set compound "segid" }
	    "chain" { set compound "chain" }
	    "fragment" { set compound "fragment" }
	    default { 
		error "error: pbcwrap: bad argument to -compound: $compound" 
	    }
	}

	# Handle the reference selection
	# $wrapsel will be used as format string,
        # specifying which group to wrap
	if { [string length $compound] } then {
	    if { [string length $compoundref] } then {
		set wrapsel "($sel) and (same $compound as (($compoundref) and (%s)))"
	    } else {
		set wrapsel "($sel) and (same $compound as (%s))"
	    }
	} else {
	    # no compound case
	    set wrapsel "($sel) and (%s)"
	}
	if { $verbose } then { vmdcon -info "wrapsel=$wrapsel" }

	if { $verbose } then { vmdcon -info "Wrapping..." }
	set next_time [clock clicks -milliseconds]
	set show_step 1000
	set fac [expr 100.0/($last - $first + 1)]
	# Loop over all frames
	for { set frame $first } { $frame <= $last } { incr frame } {
	    # Switch to the next frame
	    molinfo $molid set frame $frame

	    # get the unit cell data
	    set cell [lindex [ pbcget -check -namd -now -molid $molid ] 0]
	    set A [lindex $cell 0]
	    set B [lindex $cell 1]
	    set C [lindex $cell 2]
	    set Ax [lindex $A 0]
	    set By [lindex $B 1]
	    set Cz [lindex $C 2]

	    # compute the origin (lower left corner)
	    switch -- $wraptype {
		"compact"        {
                    set origin [vecscale -0.5 [vecadd $A $B $C]]
                }
		"para" -
		"parallelepiped" {
                    set origin [vecscale -0.5 [vecadd $A $B $C]]
                }
		"orthorhombic" -
		"rectangular" -
		"brick"          { 
		    set origin [vecscale -0.5 [list $Ax $By $Cz]]
                }
		default {
 		    error "error: pbcwrap: bad argument to -cell: $wraptype" 
                }
            }

	    # compute the center of the box
	    switch -- $center {
		"unitcell" { set origin { 0 0 0 } }
		"origin" {}
		"com" -
		"centerofmass" {
		    # set the origin to the center-of-mass of the selection
		    set centersel [atomselect $molid "($centerseltext)"]
		    if { [$centersel num] == 0 } then {
			vmdcon -warn "pbcwrap: selection \"$centerseltext\" is empty!"
		    }
		    set sum [measure sumweights $centersel weight mass]
		    if { $sum > 0.0 } then {
			set com [measure center $centersel weight mass]
		    } else {
			set com [measure center $centersel]
		    }
		    $centersel delete
		    set origin [vecadd $origin $com]
		}
		"bb" -
		"boundingbox" {
		    # set the origin to the center of the bounding box
		    # around the selection
		    set centersel [atomselect $molid "($centerseltext)"]
		    if { [$centersel num] == 0 } then {
			vmdcon -warn "pbcwrap: selection \"$centerseltext\" is empty!"
		    }
		    set minmax [measure minmax $centersel]
		    set centerbb \
			[vecscale 0.5 \
			     [vecadd \
				  [lindex $minmax 0] \
				  [lindex $minmax 1] \
				 ]]
		    $centersel delete
		    set origin [vecadd $origin $centerbb]
		}
		default {
#		    error "error: pbcwrap: bad argument to -center: $center" 

		    # for backwards compatibility
		    vmdcon -warn "Using a selection as argument for the option \"-center\" is deprecated."
		    vmdcon -warn "Please use the option \"-centersel\" to specify the selection!"

		    set centerseltext $center
		    # set the origin to the center-of-mass of the selection
		    set centersel [atomselect $molid "($centerseltext)"]
		    if { [$centersel num] == 0 } then {
			vmdcon -warn "pbcwrap: selection \"$centerseltext\" is empty!"
		    }
		    set sum [measure sumweights $centersel weight mass]
		    if { $sum > 0.0 } then {
			set com [measure center $centersel weight mass]
		    } else {
			set com [measure center $centersel]
		    }
		    $centersel delete
		    set origin [vecadd $origin $com]
		}
	    }

	    # shift the origin
	    set origin [vecadd $origin $shiftcenter]
	    if { [llength $shiftcenterrel] } then {
		set shifta [lindex $shiftcenterrel 0]
		set shiftb [lindex $shiftcenterrel 1]
		set shiftc [lindex $shiftcenterrel 2]
		set origin [vecadd $origin \
				[vecscale $shifta $A] \
				[vecscale $shiftb $B] \
				[vecscale $shiftc $C] \
			       ]
	    }

	    # Wrap it
	    switch -- $wraptype {
		"compact"        {
                    wrap_compact \
                        $molid $A $B $C $origin $wrapsel
                }
		"para" -
		"parallelepiped" {
                    wrap_para \
                        $molid $A $B $C $origin $wrapsel
                }
		"orthorhombic" -
		"rectangular" -
		"brick"          { 
                    wrap_brick \
                        $molid $A $B $C $origin $wrapsel
                }
            }

	    # print timestamp
	    set time [clock clicks -milliseconds]
	    if {$verbose || $frame == $last || $time >= $next_time} then {
		set percentage [format "%3.1f" [expr $fac*($frame-$first+1)]]
		vmdcon -info "$percentage% complete (frame $frame)"
		set next_time [expr $time + $show_step]
	    }
	}

	# print final timestamp
	if  { $verbose } then {
	    set percentage [format "%3.1f" 100]
	    vmdcon -info "$percentage% complete (frame $frame)"
	    vmdcon -info "Wrapping complete."
	}

	# Rewind to original frame
        if { $frame_before != $last } then {
	  if { $verbose } then { vmdcon -info "Rewinding to frame $frame_before." }
	  #animate goto $frame_before
          molinfo $molid set frame $frame_before
        }
    }

    #########################################################
    # Wrap the selection $wrapsel of molecule $molid
    # in the current frame into the unitcell parallelepiped
    # defined by $A, $B, $C and $origin.
    #########################################################
    proc wrap_para { molid A B C origin wrapsel } {
	set L [transtranspose [list $A $B $C]]
	
	# Transform into 4x4 matrix:
	set recip2cart [transmult [transoffset $origin] [trans_from_rotate $L]]
        set cart2recip [measure inverse $recip2cart] 
	
	# apply the full selection
	set usersel [atomselect $molid [format $wrapsel "all"]]

	# Transform the unit cell to reciprocal space
	$usersel move $cart2recip
	
	# Now we can easily select the atoms outside the cell and wrap them
        wrap_brick $molid {1 0 0} {0 1 0} {0 0 1} {0 0 0} $wrapsel
	
	$usersel move $recip2cart
	$usersel delete
    }

    ########################################################
    # Wrap all atoms in $wrapsel to their closest approach
    # to the origin.  This ignores molecule selections
    # because there doesn't seem to be a way to loop
    # over resid / residues / chains / etc. inside the selection.
    #
    # TODO:
    # Maybe there's a way to select the first atom of each residue,
    # (or the cm of each) and only wrap it.
    # Then sum translation vectors over whole residues to distribute
    # to all atoms in each residue.
    ########################################################
    proc wrap_compact { molid A B C origin wrapsel } {
        package require pbc_core 3.0
	set usersel [atomselect $molid [format $wrapsel "all"]]
        $usersel set {x y z} [wrap_min [list $A $B $C] $origin [$usersel get {x y z}]]
    }

    ########################################################
    # Wrap the selection $wrapsel of molecule $molid
    # in the current frame into the orthorhombic unitcell
    # defined by $Ax, $By, $Cz and $origin.
    # $wrapsel is a format string to select groups to shift.
    ########################################################
    proc wrap_brick { molid A B C origin wrapsel } {
	foreach {ox oy oz} $origin {break}
	set cx [expr $ox + [lindex $A 0]]
	set cy [expr $oy + [lindex $B 1]]
	set cz [expr $oz + [lindex $C 2]]

	shift_sel $molid [format $wrapsel "z>=$cz"] [vecinvert $C]
	shift_sel $molid [format $wrapsel "z<$oz"] $C
	shift_sel $molid [format $wrapsel "y>=$cy"] [vecinvert $B]
	shift_sel $molid [format $wrapsel "y<$oy"] $B
	shift_sel $molid [format $wrapsel "x>=$cx"] [vecinvert $A]
	shift_sel $molid [format $wrapsel "x<$ox"] $A
    }


    ########################################################
    # Shift the selection $seltext of molecule $molid in   #
    # the current frame by $shift, until the selection is  #
    # empty.                                               #
    ########################################################
    proc shift_sel { molid seltext shift {iter 500}} {
	set sel [atomselect $molid $seltext]
	set shifted_atoms [$sel num]

	set i 0
	while { [$sel num] > 0 && $i<$iter} {
	    $sel moveby $shift
	    $sel update
	    incr i
	}
	$sel delete
	return $shifted_atoms
    }


    ########################################################
    # Scale a 4x4 matrix by factors $s1 $s2 $s3 along the  #
    # coordinate axes.                                     #
    ########################################################

    proc scale_mat { s1 s2 s3 } {
	set v1 [list $s1 0 0 0]
	set v2 [list 0 $s2 0 0]
	set v3 [list 0 0 $s3 0]
	return [list $v1 $v2 $v3 {0.0 0.0 0.0 1.0}]
    }

    # Wrap the coordinates in the variables referenced by var_xs,
    # var_ys and var_zs into the unitcell centered around the
    # coordinates in $rxs, $rys, $rzs.
    # The lists referenced by var_xs, var_ys and var_zs have to have
    # the same lengths. $rxs, $rys and $rzs may either be lists of the
    # same length, or scalar values.
    proc pbcwrap_coordinates {A B C var_xs var_ys var_zs rxs rys rzs} {
	upvar $var_xs xs $var_ys ys $var_zs zs

 	# If rxs, rys and rzs are single values, create a list of
 	# the length of $xs, 
 	if {[llength $rxs] == 1} then {
	    set rx $rxs
	    for {set i 1} {$i < [llength $xs]} {incr i} {
		lappend rxs $rx
	    }
	} elseif {[llength $rxs] != [llength $xs]} then {
	    error "pbcwrap_coordinates: rxs either has to be of length 1 or of the same length as $var_xs!"
	}
 	if {[llength $rys] == 1} then {
	    set ry $rys
	    for {set i 1} {$i < [llength $ys]} {incr i} {
		lappend rys $ry
	    }
	} elseif {[llength $rys] != [llength $ys]} then {
	    error "pbcwrap_coordinates: rys either has to be of length 1 or of the same length as $var_ys!"
	}
 	if {[llength $rzs] == 1} then {
	    set rz $rzs
	    for {set i 1} {$i < [llength $zs]} {incr i} {
		lappend rzs $rz
	    }
	} elseif {[llength $rzs] != [llength $zs]} then {
	    error "pbcwrap_coordinates: rzs either has to be of length 1 or of the same length as $var_zs!"
	}
	    
	# get the cell vectors
	set Ax   [lindex $A 0]
	set Bx   [lindex $B 0]
	set By   [lindex $B 1]
	set Cx   [lindex $C 0]
	set Cy   [lindex $C 1]
	set Cz   [lindex $C 2]
	set Ax2 [expr 0.5*$Ax]
	set By2 [expr 0.5*$By]
	set Cz2 [expr 0.5*$Cz]
	set iAx  [expr 1.0/$Ax]
	set iBy  [expr 1.0/$By]
	set iCz  [expr 1.0/$Cz]
	
	# create lists of the right lengths
	set shiftAs $xs
	set shiftBs $xs
	set shiftCs $xs
	
	# compute the differences in the z coordinate
	set dzs [vecsub $zs $rzs]
	# compute the required shift
	set i 0
	foreach dz $dzs {
	    set shift 0
	    if { $dz > $Cz2 } then {
		incr shift -1
		while { $dz+$shift*$Cz > $Cz2 } { incr shift -1 }
	    } elseif { $dz < -$Cz2 } then {
		incr shift
		while { $dz+$shift*$Cz < -$Cz2 } { incr shift }
	    }
	    lset shiftCs $i $shift
	    incr i
	}
	# apply shiftCs to zs
	set zs [vecadd $zs [vecscale $Cz $shiftCs]]
	
	# apply shiftC to ys
	set ys [vecadd $ys [vecscale $Cy $shiftCs]]
	# compute the differences in the y coordinate
	set dys [vecsub $ys $rys]
	# compute the required shift
	set i 0
	foreach dy $dys {
	    set shift 0
	    if { $dy > $By2 } then {
		incr shift -1
		while { $dy+$shift*$By > $By2 } { incr shift -1 }
	    } elseif { $dy < -$By2 } then {
		incr shift
		while { $dy+$shift*$By < -$By2 } { incr shift }
	    }
	    lset shiftBs $i $shift
	    incr i
	}
	# apply shiftB to ys
	set ys [vecadd $ys [vecscale $By $shiftBs]]
	
	# get the current x coordinates and apply shiftC and shiftB
	set xs [vecadd $xs [vecscale $Cx $shiftCs] [vecscale $Bx $shiftBs]]
	# compute the differences in the x coordinate
	set dxs [vecsub $xs $rxs]
	# compute the required shift
	set i 0
	foreach dx $dxs {
	    set shift 0
	    if { $dx > $Ax2 } then {
		incr shift -1
		while { $dx+$shift*$Ax > $Ax2 } { incr shift -1 }
	    } elseif { $dx < -$Ax2 } then {
		incr shift
		while { $dx+$shift*$Ax < -$Ax2 } { incr shift }
	    }
	    lset shiftAs $i $shift
	    incr i
	}
	# apply shiftA to xs
	set xs [vecadd $xs [vecscale $Ax $shiftAs]]
	
	return [list $shiftAs $shiftBs $shiftCs]
    }

    # Return a list of lists of atom indices. The atoms in a sublist
    # are all atoms that belong to a connected subset of $sel.
    proc get_connected {bondlist} {
	# recursive function that tags untagged atoms
	# and returns a list of atoms connected to this one
	proc grow_connected {pid} {
	    upvar 1 "tagged" tagged "bonds" bonds
	    if { ! [lindex $tagged $pid] } then {
		# mark the atom
		lset tagged $pid 1
		# add it to the list
		set res [list $pid]
		foreach pid2 $bonds($pid) {
		    foreach pid3 [grow_connected $pid2] {
			lappend res $pid3
		    }
		}
		return $res
	    } else {
		return {}
	    }
	}

	# get the bond structure
	set n [llength $bondlist]
	
	# put the bondlist into an array
	set pid 0
	foreach bs $bondlist {
	    lappend tagged 0
	    set bonds($pid) $bs
	    incr pid
	}

	# make links bidirectional
	set pid 0
	foreach bs $bondlist {
	    foreach pid2 $bs { lappend bonds($pid2) $pid }
	    incr pid
	}

	# remove duplicate links
	for { set pid 0 } { $pid < $n } { incr pid } {
	    set bonds($pid) [lsort -unique -integer $bonds($pid) ]
	}
	
	# grow connected structures recursively
	for { set pid 0 } { $pid < $n } { incr pid } {
	    if { ! [lindex $tagged $pid] } then {
		lappend connected [lsort -integer [grow_connected $pid]]
	    }
	}
	return $connected
    }
}


