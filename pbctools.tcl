##
## PBC Tools
##
## A plugin for the handling of periodic boundary conditions.
##
## Authors: 
##   Jerome Henin <Jerome.Henin _at_ edam.uhp-nancy.fr>
##   Olaf Lenz <olenz _at_ icp.uni-stuttgart.de>
##   Cameron Mura <cmura _at_ mccammon.ucsd.edu>
##   Jan Saam <saam _at_ charite.de>
##
## The pbcbox procedure copies a lot of the ideas of Axel Kohlmeyer's
## script vmd_draw_unitcell.
##
## $Id$
##
package provide pbctools 2.6

###################################################
# Main namespace procedures
###################################################
# Main UI
proc pbc { args } {
    proc usage {} {
	vmdcon -info {usage: pbc <command> [args...]

	Setting/getting PBC information:
	  set cell [options...]
	  get [options...]
	  readxst $xstfile [options...]
	
	Drawing a box:
	  box [options...]
	  box_draw [options...]
	
	(Un)Wrapping atoms:
	  wrap [options...]
	  unwrap [options...]
	    }
	return
    }

    if { [llength $args] < 1 } then { usage; return }
    set command [ lindex $args 0 ]
    set args [lrange $args 1 end]
    set fullcommand "::PBCTools::pbc$command"

#     vmdcon -info "command=$command"
#     vmdcon -info "fullcommand=$fullcommand"
#     vmdcon -info "args=$args"

    if { [ string length [namespace which -command $fullcommand]] } then {
	eval "$fullcommand $args"
    } else { usage; return }
}

# Provide a vmdcon tcl command for versions that don't have it 
# compiled in. This will allow to convert plugins transparently.
if { ! [string equal [info commands vmdcon] vmdcon]} then {
    uplevel \#0 {
	set vmd_console_status 2; # textmode is default
	global vmd_console_status
	proc vmdcon {args} {
	    proc usage {} {
		puts {usage: vmdcon ?-nonewline? ?options? [arguments]
         print data to the VMD console or change console behavior

         Output options:
           with no options 'vmdcon' copies all arguments to the current console
           -info      -- prepend output with '(Info) '
           -warn      -- prepend output with '(Warning) '
           -err       -- prepend output with '(ERROR) '
           -nonewline -- don't append a newline to the output

         Console mode options:
           -register <widget_path> ?<mark>?  -- register a tk text widget as console
                    optionally provide a mark as reference for insertions. otherwise 'end' is used
           -unregister                       -- unregister the currently registered console widget
           -textmode                         -- switch to text mode console (using stdio)
           -widgetmode                       -- switch to tk (registered) text widget as console
 	 
 	 General options:
           -status   -- report current console status (text|widget|none)
           -help     -- print this help message
		    }
	    }

	    global vmd_console_status
	    
	    set newline 1
	    set argc [llength $args]
	    set idx 0
	    set prefix {}
	
	    if {$argc == 0} { puts; return }
	    
	    if {[string equal [lindex $args $idx] {-nonewline}]} then {
		set newline 0
		incr idx
		# nothing to do...
		if {$argc == $idx} { return }
	    }
	    switch -exact -- [lindex $args $idx] {
		-info        {incr idx; set prefix {(Info) }}
		-warn        {incr idx; set prefix {(Warning) }}
		-err         {incr idx; set prefix {(ERROR) }}
		-register    -
		-unregister  { return }
		-textmode    { set vmd_console_status 2; return }
		-widgetmode  { set vmd_console_status 1; return }
		-status      { return [lindex {none widget text} $vmd_console_status] }
		-help        { usage; return }
	    }
	    set string [concat $prefix [lrange $args $idx end]]
	    if {$newline} then {
		puts $string
	    } else {
		puts -nonewline $string
	    }
	}
    }
}

