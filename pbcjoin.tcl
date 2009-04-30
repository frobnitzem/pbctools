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
	set first "now"
	set last "now"
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
	set compoundsel ""
	set refsel ""

	switch -- $compound {
	    "seg" -
	    "segid" {
		set compoundlist [lsort -integer -unique [$sel get segid]]
		set compoundseltext "segid %s"
	    }
	    "res" -
	    "resid" -
	    "residue" {
		set compoundlist [lsort -integer -unique [$sel get residue]]
		set compoundseltext "residue %s"
	    }
	    "chain" {
		set compoundlist [lsort -unique [$sel get chain]]
		set compoundseltext "chain %s"
	    }
	    "bonded" -
	    "fragment" {
		set compoundlist [lsort -unique [$sel get fragment]]
		set compoundseltext "fragment %s"
	    }
	    default { error "ERROR: pbcjoin: unknown compound type $compound" }
	}
	
	if { $seltext ne "all" } then {
	    set seltext "($seltext) and ($compoundseltext)"
	    set refseltext "($seltext) and ($compoundseltext)"
	} else {
	    set seltext "($compoundseltext)"
	    set refseltext "($compoundseltext)"
	}
	if { $ref ne "all" } then {
	    set refseltext "($ref) and $refseltext"
	}

	if { $verbose } then {
	    set length [llength $compoundlist]
	    vmdcon -info "Will join $length compounds."
	}

	set next_time [clock clicks -milliseconds]
	set show_step 1000
	set fac [expr 100.0/($last - $first + 1)]

	for {set frame $first} { $frame <= $last } { incr frame } {
	    if { $verbose } then { 
		vmdcon -info "Joining frame $frame..." 
	    } 
	    molinfo $molid set frame $frame

	    # get the current cell 
	    set cell [lindex [pbc get -molid $molid -namd] 0]
	    set A [lindex $cell 0]
	    set B [lindex $cell 1]
	    set C [lindex $cell 2]

	    set cell [lindex [pbc get -molid $molid -vmd] 0]
	    pbc_check_cell $cell

	    # determine half the box size
	    set a [expr 0.5 * [lindex $cell 0]]
	    set b [expr 0.5 * [lindex $cell 1]]
	    set c [expr 0.5 * [lindex $cell 2]]

	    set joincompounds {}
	    set xs {}
	    set ys {}
	    set zs {}
	    set rxs {}
	    set rys {}
	    set rzs {}

	    # loop over all compounds
	    foreach compoundid $compoundlist {
		# select the next compound
		set compound [atomselect $molid [format $seltext $compoundid] frame $frame]

		# now test whether the compound needs to be joined
		set minmax [measure minmax $compound]
		set dx [expr [lindex $minmax 1 0] - [lindex $minmax 0 0]]
		set dy [expr [lindex $minmax 1 1] - [lindex $minmax 0 1]]
		set dz [expr [lindex $minmax 1 2] - [lindex $minmax 0 2]]
		if { $dx > $a || $dy > $b || $dz > $c } then {
		    set x $compound get x
		    set y $compound get y
		    set z $compound get z

		    lappend xs $x
		    lappend ys $y
		    lappend zs $z
		    lappend joincompounds $compoundid

		    # get the coordinates of the reference atom in the compound
		    set ref [atomselect $molid [format $refseltext $compoundid] frame $frame]
		    set r [lindex [$ref get { x y z }] 0]
		    set rx [lindex $r 0]
		    set ry [lindex $r 1]
		    set rz [lindex $r 2]

		    foreach x $xs {
			lappend rxs $rx
			lappend rys $ry
			lappend rzs $rz
		    }

		    $ref delete
		}
		$compound delete
	    }

	    if { [llength $joincompounds] > 0 } then {
		set sel [atomselect $molid [format $seltext $joincompounds] frame $frame]

		# wrap the coordinates
		pbcwrap_coordinates $A $B $C xs ys zs $rxs $rys $rzs

		# set the new coordinates
		$sel set x $xs
		$sel set y $ys
		$sel set z $zs

		$sel delete
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
