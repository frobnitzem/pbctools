############################################################
#
#   This file contains procedures to join compounds of atoms that are
# wrapped around unit cell boundaries.
#
# $Id$
#

package provide pbctools 2.5

namespace eval ::PBCTools:: {
    namespace export pbc*
    ############################################################
    #
    # pbcjoin $compound [OPTIONS...]
    #
    #   Joins compounds of type $compound of atoms that have been
    # split due to wrapping around the unit cell boundaries, so that
    # they are not split anymore. $compound must be one of the values
    # "residue", "chain", "segment" or "fragment".
    # 
    # OPTIONS:
    #   -molid $molid|top
    #   -first $first|first|now 
    #   -last $last|last|now
    #   -all|allframes
    #   -now
    #   -sel $sel
    #   -noref|-ref $sel
    #   -[no]verbose
    #
    # AUTHOR: Olaf
    #
    proc pbcjoin { compound args } {
	# Set the defaults
	set molid "top"
	set first "first"
	set last "last"
	set seltext "all"
	set ref "all"
	set verbose 0
	
	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr {$argnum + 1}]]
	    switch -- $arg {
		"-molid" { set molid $val; incr argnum; }
		"-first" { set first $val; incr argnum }
		"-last" { set last $val; incr argnum }
		"-allframes" -
		"-all" { set last "last"; set first "first" }
		"-now" { set last "now"; set first "now" }
		"-sel" { set seltext $val; incr argnum }
		"-ref" { set ref $val; incr argnum }
		"-noref" { set ref "all"; }
		"-verbose" { set verbose 1 }
		"-noverbose" { set verbose 0 }
		default { error "pbcjoin: unknown option: $arg" }
	    }
	}
	
	if { $molid=="top" } then { set molid [ molinfo top ] }

	# Save the current frame number
	set frame_before [ molinfo $molid get frame ]

	if { $first=="now" }   then { set first $frame_before }
	if { $first=="first" || $first=="start" || $first=="begin" } then { 
	    set first 0 
	}
	if { $last=="now" }    then { set last $frame_before }
	if { $last=="last" || $last=="end" } then {
	    set last [expr {[molinfo $molid get numframes]-1}]
	}

	set sel [atomselect $molid $seltext]

	# create a list of all compounds
	set compoundlist {}
	set reflist {}

	switch -- $compound {
	    "seg" -
	    "segid" {
		set segids [lsort -integer -unique [$sel get segid]]
		foreach segid $segids {
		    lappend compoundlist \
			[atomselect $molid "($seltext) and (segid $segid)"]
		    lappend reflist \
			[atomselect $molid "($ref) and ($seltext) and (segid $segid)"]
		}
	    }
	    "res" -
	    "resid" -
	    "residue" {
		set residues [lsort -integer -unique [$sel get residue]]
		foreach residue $residues {
		    lappend compoundlist \
			[atomselect $molid "($seltext) and (residue $residue)"]
		    lappend reflist \
			[atomselect $molid "($ref) and ($seltext) and (residue $residue)"]
		}
	    }
	    "chain" {
		set chains [lsort -unique [$sel get chain]]
		foreach chain $chains {
		    lappend compoundlist \
			[atomselect $molid "($seltext) and (chain $chain)"]
		    lappend reflist \
			[atomselect $molid "($ref) and ($seltext) and (chain $chain)"]
		}
	    }
	    "bonded" -
	    "fragment" {
		set fragments [lsort -unique [$sel get fragment]]
		foreach fragment $fragments {
		    lappend compoundlist \
			[atomselect $molid "($seltext) and (fragment $fragment)"]
		    lappend reflist \
			[atomselect $molid "($ref) and ($seltext) and (fragment $fragment)"]
		}
	    }
	    default { error "ERROR: pbcjoin: unknown compound type $compound" }
	}

	set next_time [clock clicks -milliseconds]
	set show_step 1000
	set fac [expr 100.0/($last - $first + 1)]

	for {set frame $first} { $frame <= $last } { incr frame } {
	    if { $verbose } then { 
		vmdcon -info "Joining frame $frame..." 
		continue
	    } 
	    molinfo $molid set frame $frame

	    # get the current cell 
	    set cell [lindex [pbc get -molid $molid -namd] 0]
	    set A [lindex $cell 0]
	    set B [lindex $cell 1]
	    set C [lindex $cell 2]

	    pbc_check_cell $cell

	    # loop over all compounds
	    foreach compound $compoundlist ref $reflist {
		$compound frame $frame
		$ref frame $frame

		# get the coordinates of all atoms in the compound
		set xs [$compound get x]
		set ys [$compound get y]
		set zs [$compound get z]
		# get the coordinates of the reference atom in the compound
		set rx [lindex [$ref get x] 0]
		set ry [lindex [$ref get y] 0]
		set rz [lindex [$ref get z] 0]

		# wrap the coordinates
		pbcwrap_coordinates $A $B $C xs ys zs $rx $ry $rz

		# set the new coordinates
		$compound set x $xs
		$compound set y $ys
		$compound set z $zs
	    }

	    set time [clock clicks -milliseconds]
	    if {$verbose || $frame == $last || $time >= $next_time} then {
		set percentage [format "%3.1f" [expr $fac*($frame-$first+1)]]
		vmdcon -info "$percentage% complete (frame $frame)"
		set next_time [expr $time + $show_step]
	    }
	}

	# Rewind to original frame
	if { $verbose } then { vmdcon -info "Rewinding to frame $frame_before." }
	animate goto $frame_before
    }

    # > pbcwrap -compound $compound -compundref $ref
    # is equivalent to
    # > pbcwrap -sel $ref
    # > pbcjoin $compound -ref $ref

}
