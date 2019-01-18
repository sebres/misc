#!/usr/bin/tclsh

lassign $::argv fossil_clone_file fossil_marks_in fossil_marks_out

## ------------------------------------------

if {$fossil_clone_file eq "" || $fossil_marks_in eq ""} {
  puts "arguments expected, syntax:"
  puts "[file tail [info source]] fossil-clone-file fossil-marks-in ?fossil-marks-out?"
  exit -1
}

if {$fossil_marks_out eq ""} {
  set fossil_marks_out "${fossil_marks_in}.repair-export-marks-[clock format [clock seconds] -format {%Y%m%d}]"
}
if {$fossil_marks_in eq $fossil_marks_out} {
  puts "ERROR: input and output files should be different."
  exit -1
}
if {![file isfile $fossil_clone_file]} {
  puts "ERROR: wrong fossil-repository filename."
  exit -1
}
if {![file isfile $fossil_marks_in]} {
  puts "ERROR: wrong input filename."
  exit -1
}

## ------------------------------------------

namespace eval fossil {

variable fdb db

proc _db {} {variable fdb; return $fdb}

proc hash2rid {hash} {
  set fdb [_db]
  $fdb onecolumn "select rid from artifact where hash=:hash"
}
proc rid2hash {rid} {
  set fdb [_db]
  $fdb onecolumn "select hash from artifact where rid=:rid"
}

proc rid_has_checkin {rid} {
  set fdb [_db]
  if {[$fdb exists "SELECT 1 from plink WHERE pid = :rid or cid = :rid limit 1"]} {
    return 1
  }
  if {[$fdb exists "SELECT 1 from event WHERE objid = :rid limit 1"]} {
    return 1
  }
  return 0
}
proc rid_has_blob {rid} {
  set fdb [_db]
  $fdb exists "SELECT 1 from blob WHERE rid = :rid"
}

}; # / fossil

## ------------------------------------------

# loading sqlite package ...
if {[info command ::sqlite3] eq ""} {
  if {[catch { package require sqlite3 }]} {
    load sqlite3260 sqlite3
  }
}
if {[info command ::db] eq ""} {

  # open fast mode
  sqlite3 ::db file:[file normalize $fossil_clone_file]?mode=ro&cache=shared&immutable=1 -uri 1 -readonly 1

  # speedup it a bit more: 
  db eval "
    PRAGMA synchronous = OFF;
    PRAGMA journal_mode = MEMORY;
    PRAGMA temp_store = MEMORY
  "
}

## ------------------------------------------

set stat {marks 0 checkins 0 blobs 0 sane-rids 0 wrap-rids 0 wrap-checkins 0 wrap-blobs 0}
set ridmap {}
set f [open $fossil_marks_in r]
set fo [open $fossil_marks_out w]
set fm [open ${fossil_marks_out}-map w]
puts "Repair fossil export-marks: [file tail $fossil_marks_in] -> [file tail $fossil_marks_out]"
try {

  fconfigure $f -buffersize 65536
  fconfigure $fo -buffersize 65536

  while {1} {
    set l [gets $f]
    if {[eof $f]} break
    if {$l eq ""} continue
    if {![regexp {^([cb])(\d+)\s+:(\d+)\s+([\da-fA-F]{10,})$} $l _ at rid expid hash]} {
      error "expected export-mark but got \"$l\""
    }
    dict incr stat marks
    if {$at eq "c"} { dict incr stat checkins }
    if {$at eq "b"} { dict incr stat blobs }

    set nrid [fossil::hash2rid $hash]
    
    if {$nrid ne $rid} {
      if {$nrid eq ""} {
        error "no artifact for uuid \"$hash\", previously $at$rid, export-mark $expid"
      }
      # error "$nrid ne $rid for uuid \"$hash\""
      dict incr stat wrap-rids
      # check artifact type is the same:
      if {$at eq "c"} {
        dict incr stat wrap-checkins
        # if {![fossil::rid_has_checkin $nrid]} {
        #   error "WARN: invalid artifact found: no checkin for uuid \"$hash\", previously $at$rid now $at$nrid, export-mark $expid"
        # }
      } elseif {$at eq "b"} {
        dict incr stat wrap-blobs
        if {![fossil::rid_has_blob $nrid]} {
          error "invalid artifact found: no blob for uuid \"$hash\", previously $at$rid now $at$nrid, export-mark $expid"
        }
      }
      # wrap:
      ::puts $fo [format "%s%s :%s %s" $at $nrid $expid $hash]
      # entry to ridmap:
      dict set ridmap $rid $nrid
      ::puts $fm "$rid $nrid"
    } else {
      dict incr stat sane-rids
      ::puts $fo $l
    }
  }

} finally {
  close $f
  close $fo
  close $fm
  db close
}

puts "Done. ** $stat **"

return
