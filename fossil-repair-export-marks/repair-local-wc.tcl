#!/usr/bin/tclsh

lassign $::argv fossil_local_file fossil_clone_file fossil_marks_ridmap process

## ------------------------------------------

if {$process eq ""} {set process 0}

if {$fossil_local_file eq "" || $fossil_clone_file eq "" || $fossil_marks_ridmap eq ""} {
  puts "arguments expected, syntax:"
  puts "[file tail [info source]] fossil-local-file fossil-clone-file ?fossil-marks-ridmap-file|--? ?process?"
  exit -1
}

if {$fossil_marks_out eq ""} {
  set fossil_marks_out "${fossil_marks_in}.repair-export-marks-[clock format [clock seconds] -format {%Y%m%d}]"
}
if {($fossil_local_file eq "" || [file is directory $fossil_local_file]) && ![file isfile [file join $fossil_local_file _FOSSIL_]]} {
  puts "ERROR: wrong file name of fossil local working-copy database \"$fossil_local_file\"."
  exit -1
}
if {![file isfile $fossil_clone_file]} {
  puts "ERROR: wrong fossil-repository filename."
  exit -1
}

## ------------------------------------------

set ridmap {}
if {$fossil_marks_ridmap ni {"" "--"}} {
  set f [open $fossil_marks_ridmap r]
  try { set ridmap [read $f] } finally { close $f }
  if {![dict size $ridmap]} {
    puts "WARN: no read map entries in [file tail $fossil_marks_ridmap]"
  }
}
puts "rid-map size: [dict size $ridmap]"

## ------------------------------------------

# direct loading sqlite ...
if {[info command ::sqlite3] eq ""} {
  load sqlite3260 sqlite3
}
if {[info command ::fdb] eq ""} {
  # open fast mode (RO)
  sqlite3 ::fdb file:[file normalize $fossil_clone_file]?mode=ro&cache=shared&immutable=1 -uri 1 -readonly 1
}
if {[info command ::ldb] eq ""} {
  if {$process} {
    # open fast mode (RW)
    sqlite3 ::ldb file:[file normalize $fossil_local_file]?mode=rw&cache=shared -uri 1
  } else {
    # open fast mode (RO)
    sqlite3 ::ldb file:[file normalize $fossil_local_file]?mode=ro&cache=shared&immutable=1 -uri 1 -readonly 1
  }
}

## ------------------------------------------

proc cutstr {s {l 50}} {
  if {[string length $s] <= 50} {
    return $s
  } 
  return [format %.*s $l $s]...
}

proc rid2branch {rid} {
  fdb onecolumn "SELECT value FROM tagxref WHERE rid=:rid AND tagid=8"
}
proc fid2mtime {fid} {
  ## mtime of first event for all mid's of fid
  fdb onecolumn "select mtime from event where objid in (select mid from mlink where fid = :fid) order by mtime asc limit 1"
}
# proc fid2rids {fid branch} {
#   fdb eval "SELECT mid from mlink WHERE fid = :fid and EXISTS (select 1 FROM tagxref where rid = mlink.mid and value = :branch and tagid=8)"
# }
proc fid2branches {fid {fidOnly 0} {directonly 1}} {
  if {$fidOnly} {
    fdb eval "SELECT DISTINCT value FROM tagxref WHERE rid in (select mid from mlink where fid = :fid) AND tagid=8"
  } else {
    fdb eval "WITH RECURSIVE
      forks(rid, mtime, branch) AS (
        SELECT m.mid, 0, (SELECT value FROM tagxref WHERE rid=m.mid AND tagid=8) branch
          FROM mlink m WHERE m.fid = :fid
        UNION
        SELECT p.cid, p.mtime, (SELECT value FROM tagxref WHERE rid=p.cid AND tagid=8) branch
          FROM forks f, plink p
         WHERE p.pid = f.rid [expr {$directonly ? "AND p.isPrim" : ""}]
      )
      SELECT distinct branch FROM forks ORDER BY mtime DESC LIMIT 10000
    "
  }
}
proc branch2lastrid {branch} {
  fdb onecolumn "SELECT rid FROM tagxref WHERE value=:branch AND tagid=8 order by rowid desc limit 1"
}
proc allbranches_of_vfiles {} {
  set fids [ldb eval "select mrid from vfile"]
  set fids [join $fids ,]
  fdb eval "SELECT DISTINCT value FROM tagxref 
  WHERE rid in (select mid from mlink where fid in ($fids)) AND tagid=8 order by mtime desc"
}
proc lastcheckin_of_vfiles {fids branch} {
  set brcrit "= :branch"
  if {[llength $branch] > 1} {
    set brcrit "in ('[join $branch "','"]')"
  }
  set fids [join $fids ,]
  fdb onecolumn "SELECT e.objid FROM event e
  WHERE e.objid in (select mid from mlink where fid in ($fids))
  AND EXISTS (select 1 FROM tagxref where rid = e.objid and value $brcrit and tagid=8)
  ORDER BY e.mtime desc limit 1
  "
}
proc rid2hash {rid} {
  fdb onecolumn "select hash from artifact where rid=:rid"
}

proc _update_table_rids {ldb table ufield idfield ridmap {process 0}} {
  set sql "UPDATE $table $ufield = :nrid WHERE $idfield = :rid"
  puts "\n$table: swap [dict size $ridmap] ${ufield}(s) ..."
  puts "   $sql"
  foreach {rid nrid} $ridmap {
    puts -nonewline "\t nrid = $nrid <-- rid = $rid ... "
    if {$process} {
      puts [$ldb eval $sql]
    } else {
      puts "TEST"
    }
  }
}

proc _update_table_multrids {ldb table idfield mulridmap {process 0}} {
  puts "\n$table: swap [dict size $mulridmap] entries ..."
  set sql ""
  foreach {id val} $mulridmap {
    set upd {}
    set act {}
    foreach {fld rid} $val {
      set r($fld) $rid
      lappend upd "$fld = :r($fld)"
      lappend act "$fld = $r($fld)"
    }
    set nsql "UPDATE $table [join $upd ", "] WHERE $idfield = :id"
    if {$sql ne $nsql} {
      set sql $nsql
      puts "   $sql"
    }
    puts -nonewline "\t [join $act ", "] <-- $idfield = $id ... "
    if {$process} {
      puts [$ldb eval $sql]
    } else {
      puts "TEST"
    }
  }
}

## ------------------------------------------

# analyse:

set stashvidmap {}
set sfileridmap {}
set vvarridmap {}
set vfileridmap {}
set lastbr ""

set lastfidcheckin ""
set lastfidmtime 0
set wcpath [file dirname $fossil_local_file]
set mfiles {}

# vfile:
puts ""
set allbr {}
set allfids {}
if {[ldb exists "SELECT name FROM sqlite_master WHERE type ='table' AND name = 'vfile'"]} {
  puts "vfile ..."
  unset -nocomplain r
  foreach br [allbranches_of_vfiles] { dict set allbr $br 1 }
  puts "[dict size $allbr] branch(es) found: [cutstr [dict keys $allbr] 150]"
  set unswap [set unmod [set mod 0]]
  ldb eval "select id, vid, rid, mrid, mtime, datetime(mtime, 'unixepoch') lftimestr, pathname, origname 
  from vfile order by mrid asc" r {
    set val {}
    set act {}
    set m " "
    if { ![file exists [set fn [file join $wcpath $r(pathname)]]] } {
      set m "D"; incr mod
      dict set mfiles $r(pathname) $m
    } elseif { [file mtime $fn] != $r(mtime) } {
      set m "M"; incr mod
      dict set mfiles $r(pathname) $m
    } else {
      incr unmod
    }
    foreach fld {vid rid mrid} {
      if {[dict exists $ridmap [set nfid $r($fld)]]} {
        set nfid [dict get $ridmap $nfid]
        dict set val $fld $nfid
      }
      lappend act [format "%s (%8s --> %-8s, %s)" $fld $r($fld) $nfid [expr {$r($fld) ne $nfid ? "SWAP" : "----"}]]
    }
    if {[dict size $val]} {
      dict set vfileridmap $r(id) $val
    } else {
      incr unswap
    }
    #puts " $r(id)\t [join $act ", "] \t$r(lftimestr) $m $r(pathname) / $r(origname)..."
    # filter until only one branch remains:
    if {[dict size $allbr] > 1} {
      set mtime [fid2mtime $nfid]; # nfid is new vfile.mrid
      if {$mtime > $lastfidmtime} {
        # filter branches not existsing for this fid:
        set fbr [fid2branches $nfid]
        if {[llength $fbr]} {
          set fltbr [dict filter $allbr script {br _} {expr {$br in $fbr}}]
          if {[llength $fltbr]} {
            if {[llength $fltbr] < [llength $allbr]} {
              set allbr $fltbr
              puts " $r(id)\t [join $act ", "] \t$r(lftimestr) $m $r(pathname) ..."
              puts "     $nfid: [dict size $allbr] branch(es) [cutstr [dict keys $allbr]], after filter with [llength $fbr] branches ([cutstr $fbr])"
            } else {
              # unchanged (allbr is the same)
            }
          } else {
            puts " $r(id)\t [join $act ", "] \t$r(lftimestr) $m $r(pathname) ..."
            puts "     $nfid: **INVALID** reference, fid branch(es): [cutstr $fbr])"
          }
        }
        set lastfidmtime $mtime
        set lastfidcheckin $nfid
        set lastbr [lindex [dict keys $allbr] 0]
      }
    }
    lappend allfids $nfid
  }
  puts "\nvfile:\tswap [dict size $vfileridmap] entries ($unswap unswapped), $mod modified, $unmod unmodified ..."
  foreach {fn m} $mfiles {
    puts "    $m: $fn"
  }
} else {
  puts "INFO: local _FOSSIL_ DB does not contains vfile"
}
# last assumed branch:
set asbr $lastbr
puts "\nassumed branch: $asbr, possible: [dict keys $allbr]"
set asrid [lastcheckin_of_vfiles $allfids $allbr]
puts "assumed checkout rid: $asrid"

# vvar:
puts ""
if {[ldb exists "SELECT name FROM sqlite_master WHERE type ='table' AND name = 'vvar'"]} {
  puts "vvar ..."
  unset -nocomplain r
  ldb eval "select value, name from vvar where name = 'checkout'" r {
    set act "----"
    if {[dict exists $ridmap [set nrid $r(value)]]} {
      set nrid [dict get $ridmap $nrid]
      set act "****"
      if {![dict exists $vvarridmap $r(value)]} {
        set act "SWAP"
        dict set vvarridmap $r(name) $nrid
      }
      set br [rid2branch $nrid]
    } elseif {$asrid ne "" && $nrid ne $asrid} {
      set br [rid2branch $nrid]
      if {$br ni $allbr} {
        set act "SWAP to assumed checkin"
        dict set vvarridmap $r(name) [set nrid $asrid]
        set br $asbr
      }
    }
    puts " $r(name)\t [format "(%8s --> %-8s, %s )" $r(value) $nrid $act] ..."
    puts "   branch found: $br"
    if {$r(value) ne $nrid} {
      puts "   use `fossil checkout -f --keep [rid2hash $nrid]` to clean checkout (and vfiles)"
    }
  }
  puts "\nvvar:\tswap [dict size $vvarridmap] rids ..."
} else {
  puts "INFO: local _FOSSIL_ DB does not contains vvar"
}

# stashes:
puts ""
if {[ldb exists "SELECT name FROM sqlite_master WHERE type ='table' AND name = 'stash'"]} {

  set stbr $asbr
  unset -nocomplain r
  ldb eval "select stashid, vid, comment, datetime(ctime) ctime from stash" r {
    set extra ""
    set act "------"
    if {[dict exists $ridmap [set nvid $r(vid)]]} {
      set nvid [dict get $ridmap $nvid]
      set act "******"
      if {![dict exists $stashvidmap $r(vid)]} {
        dict set stashvidmap $r(vid) $nvid
        set act "SWAP-S"
      }
    }
    set lastbr $stbr
    set stbr [rid2branch $nvid]
    # if branch not found (invalid vid, rather fid etc):
    if {$stbr eq ""} {
      set stbr $lastbr
      if {$asrid ne ""} {
        append extra "\n   rid **INVALID**, branch assumed: $asbr"
        if {$asrid ne $nvid} {
          append extra ", swap to assumed rid of branch: $nvid -> $asrid"
          dict set stashvidmap $r(vid) [set nvid $asrid]
          set act "SWAP-A"
        }
      } else {
        set brvid [branch2lastrid $stbr]
        append extra "\n   rid **INVALID**, branch last-used: $lastbr"
        if {$brvid ne $nvid} {
          append extra ", swap to last rid of branch: $nvid -> $brvid"
          dict set stashvidmap $r(vid) [set nvid $brvid]
          set act "SWAP-L"
        }
      }
    } else {
      append extra "\n   branch found: $stbr"
    }
    puts "stash [format "%3d (%8s --> %-8s, %s )" $r(stashid) $r(vid) $nvid $act] : $r(ctime) - $r(comment) ...$extra"
    # stashfile's:
    ldb eval "select rid, origname from stashfile where stashid = :r(stashid)" fr {
      set act "------"
      if {[dict exists $ridmap [set nrid $fr(rid)]]} {
        set nrid [dict get $ridmap $nrid]
        set act "******"
        if {![dict exists $sfileridmap $fr(rid)]} {
          set act "SWAP-F"
          dict set sfileridmap $fr(rid) $nrid
        }
      }
      set fbr [fid2branches $nrid]
      puts "   file \t [format "(%8s --> %-8s, %s )" $fr(rid) $nrid $act] :    $fr(origname) ..."
      if {$stbr ni $fbr} {
        puts "      belongs to \"[join $fbr "\", \""]\""
      }
    }
  }

  puts "\nstashes:\tswap [dict size $stashvidmap] vids, [dict size $sfileridmap] rids ..."

} else {
  puts "INFO: local _FOSSIL_ DB does not contains stashes"
}

# process:

puts "\n[string repeat = 80]"

# table stash:
if {[dict size $stashvidmap]} {
  _update_table_rids ldb stash vid vid $stashvidmap $process
  set stashvidmap {}
}

# table stashfile:
if {[dict size $sfileridmap]} {
  _update_table_rids ldb stashfile rid rid $sfileridmap $process
  set sfileridmap {}
}

if 0 {;#
  # table vvar:
  if {[dict size $vvarridmap]} {
    _update_table_rids ldb vvar value name $vvarridmap $process
    set vvarridmap {}
  }

  # table vfile:
  if {[dict size $vfileridmap]} {
    _update_table_multrids ldb vfile id $vfileridmap $process
    set vfileridmap {}
  }
} else {
  if {[dict size $vvarridmap]} {
    set nrid [dict get $vvarridmap checkout]
    puts "\nvvar/vfile: swap checkout to $nrid ..."
    puts "   cd [file nativename [file dirname $fossil_local_file]]"
    puts "   fossil checkout -f --keep [rid2hash $nrid]"
  }
}

