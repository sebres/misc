proc h1 {s} { ## r * 8 (SHL 3)
  set r 0; foreach c [binary scan $s c* c; set c] {
    set r [expr {((($r << 3) & 0xffffffff) + $c) & 0xffffffff}]
  }; set r
}
proc h2 {s} { ## r * 10 (SHL 3 + SHL 1)
  set r 0; foreach c [binary scan $s c* c; set c] {
    set r [expr {((($r * 10) & 0xffffffff) + $c) & 0xffffffff}]
  }; set r
}
proc h3 {s} { ## r ROL 3 (r SHL 3 | r SHR 29) + c XOR (c << 8)
  set r 0; foreach c [binary scan $s c* c; set c] {
    set r [expr {((((($r << 3) | ($r >> 29)) & 0xffffffff) + $c) ^ ($c << 8)) & 0xffffffff}]
  }; set r
}

## -------------------------------------------------------------

set ::CT {abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789}
set ::MAXCOL 1000
set ::COLMSG {$hf [format %5s [llength [dict get $hu coll]]] collisions after [format %7s [dict get $hu hnum]] hashes by [format %08X $h] for $v and [dict get $hu $h]}
set ::hash_val {
  upvar $_hu hu
  set h [$hf $v]
  dict incr hu hnum
  if {[dict exists $hu $h]} {
    dict lappend hu coll [list $h $v [dict get $hu $h]]
    if {[llength [dict get $hu coll]] >= $::MAXCOL} {
      error [subst $::COLMSG]
    }
    if {[llength [dict get $hu coll]] in {1 10 100 1000 10000 100000}} {
      puts [subst $::COLMSG]
    }
  }
  dict set hu $h $v
  if {[dict size $hu] > 1e7} { error "too many iterations for $hf, [llength [dict get $hu coll]] collisions after [dict get $hu hnum] hashes: [dict get $hu coll]" }
}
proc hash_rec {_hu hf {p {}} {rnd 0} {len 10}} {
  upvar $_hu hu
  set ctl [string length $::CT]
  set ct $::CT
  if {!$rnd} {
    for {set i 0} {$i < $ctl} {incr i} {
      set v $p[string index $::CT $i]
      #puts $v
      if 1 $::hash_val
      if {[string length $v] < $len} {
        hash_rec hu $hf $v 0 $len
      }
    }
  } else {
    set ap {}; # table with already processed keys
    while 1 {
      set v {}
      for {set i 0} {$i < $rnd} {incr i} {
        append v [string index $::CT [expr {int(rand() * $ctl)}]]
      }
      # random, so check against table with already processed keys
      if {![dict exists $ap $v]} $::hash_val
      dict set ap $v 1
    }
  }
  if {$p eq ""} {
    return "$hf [format %5s [llength [dict get $hu coll]]] collisions after [format %7s [dict get $hu hnum]] hashes"
  }
}

## -------------------------------------------------------------

proc read_wordlist {} {
  set fn [file join [info script]--t8.shakespeare.txt]
  if {[file exists ${fn}.lst]} {
    set f [::open ${fn}.lst r]
    set wlst [::read $f]
    ::close $f
    return $wlst
  }
  if {![file exists $fn]} {
    # download https://ocw.mit.edu/ans7870/6/6.006/s08/lecturenotes/files/t8.shakespeare.txt
    exec curl https://ocw.mit.edu/ans7870/6/6.006/s08/lecturenotes/files/t8.shakespeare.txt > $fn
  }
  set f [::open $fn r]
  set data [::read $f]
  ::close $f
  set wlst [lsort -unique [regexp -all -inline {\w+} $data]]
  set f [::open ${fn}.lst w]
  ::puts -nonewline $f $wlst
  ::close $f
  return $wlst
}
proc hash_wlst {_hu hf wlst {min 3}} {
  upvar $_hu hu
  foreach v $wlst {
    if {[string length $v] < $min} continue
    if 1 $::hash_val
  }
  puts "$hf [format %5s [llength [dict get $hu coll]]] collisions after [format %7s [dict get $hu hnum]] hashes"
}

## -------------------------------------------------------------

set testh {h1 h2 h3}

foreach hf $testh { set hu {}; catch {hash_rec hu $hf {} 0} e; puts $e\n }; puts [string repeat = 60]\n
foreach hf $testh { set hu {}; catch {hash_rec hu $hf {} 5} e; puts $e\n }; puts [string repeat = 60]\n
foreach hf $testh { set hu {}; catch {hash_rec hu $hf {} 8} e; puts $e\n }; puts [string repeat = 60]\n
puts ""
set wlst [read_wordlist]
puts "[llength $wlst] words:\n"
foreach hf $testh { set hu {}; catch {hash_wlst hu $hf $wlst 3} e; puts $e\n }; puts [string repeat = 60]\n
foreach hf $testh { set hu {}; catch {hash_wlst hu $hf $wlst 5} e; puts $e\n }; puts [string repeat = 60]\n
foreach hf $testh { set hu {}; catch {hash_wlst hu $hf $wlst 8} e; puts $e\n }; puts [string repeat = 60]\n
set wlst [lsort -unique [string tolower $wlst]]
puts "[llength $wlst] words in lowercase:\n"
foreach hf $testh { set hu {}; catch {hash_wlst hu $hf $wlst 5} e; puts $e\n }; puts [string repeat = 60]\n
foreach hf $testh { set hu {}; catch {hash_wlst hu $hf $wlst 8} e; puts $e\n }; puts [string repeat = 60]\n
