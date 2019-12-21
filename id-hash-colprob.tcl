#!/usr/bin/env tclsh

if {![llength $argv]} {
  puts "usage: $argv0 K k N ?TM?
  # K  - cards in deck
  # k  - cards we will take from the deck
  # N  - variants of different card types (we can \"hash\" at all)
  # TM - time to run estimation (iterate)"
  return
}

set K [lindex $argv 0]   ; # K cards in deck
set k [lindex $argv 1]   ; # k cards we will take from the deck
set N [lindex $argv 2]   ; # N variants of different card types (we can "hash" at all)
set TM [lindex $argv 3]  ; # time to run estimation (iterate)

if {$K % $N} {
  puts "Warning: n is not decimal, we have rest by $K / $N ($K % $N != 0), estimated and calculated probabilities may vary"
}

set n [expr {$K / $N}]
puts "k = $k cards from K = $K max, by sieve N = 1..$N, repeated n = $n times:"

# calculate (recursive probability tree):

# example to calculate coll-probality by k = 4:
#
# puts Calc-P(collision)=[expr {
#   (1*$n-1.0)/($K-1) + ($K-$n*1.0)/($K-1) * ((2*$n-2.0)/($K-2) + ($K-$n*2.0)/($K-2) * (3*$n-3.0)/($K-3))
# }]
proc calcp {d k} {
  upvar K K n n
  set v [expr {double($d*$n-$d)/($K-$d)}]
  if {$k > 2} {
    set v [expr {$v + (double($K-$n*$d)/($K-$d) * [calcp [expr {$d+1}] [expr {$k-1}]])}]
  }
  set v
}
puts Calc-P(collision)=[calcp 1 $k]

# estimation (simulate playing):
if {$TM ne {}} {

  # fill the array NewDck with a card deck (K cards in deck, repeats K/N times of N variants of the cards):
  set NewDck {}
  set v 0
  for {set i 0} {$i < $K} {incr i} {
    dict set NewDck $i [incr v]
    if {$v >= $N} {set v 0}
  }
  # puts $NewDck

  # run estimation cycle:
  set col(yes) 0
  set col(no) 0
  set tr [timerate {
    set Dck $NewDck
    set Tk {}
    # take k cards and check for a collision:
    set fnd 0
    for {set x 1} {$x <= $k} {incr x} {
      while 1 {
        set i [expr {int(rand()*$K)}]; # random index in deck
        if {[set t [dict get $Dck $i]] != -1} break; # unused card
      }
      if {[dict exists $Tk $t]} {set fnd 1; break}; # same type of card (collision) found
      dict set Tk $t _;   # add new know type in subset of cards
      dict set Dck $i -1; # mark card as used in deck
    }
    if {$fnd} { # incr count of collision / success
      incr col(yes)
    } else {
      incr col(no)
    }
  } $TM]

  set col(iter) [expr { $col(no)+$col(yes) }]
  puts Estm-P(collision)=[expr { double($col(yes))/$col(iter) }]
  puts "Results: [array get col]"
  puts $tr
  # puts $Tk
  # puts $Dck
}

