array set ::tcl::_exception_handlilng {prev {} last {} lres {} usage {
    return -code error -errorcode {TCL WRONGARGS} -level 1 \
      {wrong # args: should be "try body ?handler ...? ?finally script?"}
  }
  usage_on {
    return -code error -errorcode {TCL OPERATION TRY ON ARGUMENT} -level 1 \
      {wrong # args to on clause: must be "... on code variableList script"}
  }
  usage_trap {
    return -code error -errorcode {TCL OPERATION TRY TRAP ARGUMENT} -level 1 \
      {wrong # args to trap clause: must be "... trap pattern variableList script"}
  }
  usage_finally {
    return -code error -errorcode {TCL OPERATION TRY FINALLY ARGUMENT} -level 1 \
    {wrong # args to finally clause: must be "... finally script"}
  }
}

proc ::tcl::throw {args} {
  # throw error specified:
  if {[llength $args]} {
    lassign $args type message
    return -code error -errorcode $type -errorinfo $message -level 2 $message
  }
  # rethrow last error:
  set opt $::tcl::_exception_handlilng(last)
  dict incr opt -level
  return {*}$opt $::tcl::_exception_handlilng(lres)
}

proc ::tcl::try {args} {
  upvar ::tcl::_exception_handlilng eh
  # push previous exception in stack
  lappend eh(prev) $eh(last)

  if {![llength $args]} $eh(usage)
  set hasfinally [set i 0]
  set body [lindex $args $i]
  # command arguments (do not validate, just process to check args length):
  incr i
  while {$i < [llength $args]} {
    switch -- [lindex $args $i] \
    "on" - "trap" {
      # trap pattern variableList script
      # on code variableList script
      incr i 3
      if {[lindex $args $i] eq "-"} {
        incr i
        if {$i >= [llength $args]} {
          return -code error -errorcode {TCL OPERATION TRY BADFALLTHROUGH} -level 1 \
            {last non-finally clause must not have a body of "-"}
        }
        continue; # - next handler ...
      }
      incr i
      if {$i > [llength $args]} $eh(usage_on)
    } \
    "finally" {
      # finally script
      set hasfinally $i
      incr i 2
      if {$i > [llength $args]} $eh(usage_finally)
      break; # no further handlers
    } \
    default {
      break
    }
  }
  if {$i != [llength $args]} $eh(usage)

  set code [uplevel 1 [list ::catch $body \
    ::tcl::_exception_handlilng(lres) ::tcl::_exception_handlilng(last)]]

  # current result:
  set res $eh(lres)
  set opt $eh(last)
  if {$code == 2 && [dict get $opt -code] != 0} {
    set code [dict get $opt -code]
  }

  # process on/trap :
  if {[llength $args] > ($hasfinally ? 3 : 1)} {
    set sub_on_error {
      lassign [lindex $args [incr i]] _em _opt
      if {$_em ne {}} {upvar $_em ores; set ores $res}
      if {$_opt ne {}} {upvar $_opt oopt; set oopt $opt}
      # search body of handler if common:
      while {[set body [lindex $args [incr i]]] eq "-" && $i < [llength $args]} {
        incr i 3
      }
      # eval handler:
      set code [uplevel 1 [list ::catch $body \
        ::tcl::_exception_handlilng(ores) ::tcl::_exception_handlilng(oopt)]]
      set res $::tcl::_exception_handlilng(ores)
      set opt $::tcl::_exception_handlilng(oopt)
      if {$code == 1} {
        dict append opt -errorinfo "\n   (\"try ... [lindex $args $i-3]\" handler line [dict get $opt -errorline])"
      }
      break
    }
    set i 1
    while {$i < [llength $args]} {
      switch -- [lindex $args $i] \
      "on" {
        set oarg [lindex $args [incr i]]
        if { ![string is integer -strict $oarg]
          && [set oarg [lsearch {ok error return break continue} $oarg]] == -1
        } {
          return -code error -errorcode {TCL RESULT ILLEGAL_CODE} -level 1 \
            "bad completion code \"[lindex $args $i]\": must be ok, error, return, break, continue, or an integer"
        }
        if { $code == $oarg } $sub_on_error else {
          incr i 3; continue
        }
      } \
      "trap" {
        set oarg [lindex $args [incr i]]
        if { $code != 0 
          && [lrange [dict get $opt -errorcode] 0 [llength $oarg]-1] eq [lrange $oarg 0 end]
        } $sub_on_error else {
          incr i 3; continue
        }
      } \
      default {
        break
      }
    }
  }

  # process finally :
  if {[set i $hasfinally]} {
    set fcode [uplevel 1 [list ::catch [lindex $args [incr i]] \
      ::tcl::_exception_handlilng(ores) ::tcl::_exception_handlilng(oopt)]]
    if {$fcode != 0} {
      set res $::tcl::_exception_handlilng(ores)
      set opt $::tcl::_exception_handlilng(oopt)
      if {$fcode == 1} {
        set code $fcode
        dict append opt -errorinfo "\n   (\"try ... finally\" body line [dict get $opt -errorline])"
      }
    }
  }

  # restore:
  set eh(last) [lindex $eh(prev) end]
  set eh(prev) [lreplace $eh(prev) [set eh(prev) end] end]

  if {$code != 0} {
    if {$code == 2} {
      set code [dict get $opt -code]
    }
    if {$code != 0} {
      dict incr opt -level
    }
  }
  return {*}$opt $res
}

interp alias {} ::throw {} ::tcl::throw
interp alias {} ::try {} ::tcl::try

