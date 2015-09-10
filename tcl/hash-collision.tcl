package require md5

proc test_md5_col {a b} {
  regsub -all {[\s\[\]]+} $a "" a
  regsub -all {[\s\[\]]+} $b "" b
  if {$a eq $b} {return -code error "test md5-collision for the equal strings"}
  puts A:[set A [md5::md5 -hex [hex -mode decode $a]]]
  puts B:[set B [md5::md5 -hex [hex -mode decode $b]]]
  puts C=[if {$A eq $B} {set _ **MD5-COLLISION**} else {set _ NONE}]
}

## ------------------------

## no collision:
test_md5_col aaaa bbbb

puts ""

## md5 collision:
test_md5_col \
  {
   d131dd02c5e6eec4693d9a0698aff95c   2fcab5[8]712467eab4004583eb8fb7f89
   55ad340609f4b30283e4888325[7]1415a 085125e8f7cdc99fd91dbd[f]280373c5b
   d8823e3156348f5bae6dacd436c919c6   dd53e2[b]487da03fd02396306d248cda0
   e99f33420f577ee8ce54b67080[a]80d1e c69821bcb6a8839396f965[2]b6ff72a70
  } \
  {
   d131dd02c5e6eec4693d9a0698aff95c   2fcab5[0]712467eab4004583eb8fb7f89
   55ad340609f4b30283e4888325[f]1415a 085125e8f7cdc99fd91dbd[7]280373c5b
   d8823e3156348f5bae6dacd436c919c6   dd53e2[3]487da03fd02396306d248cda0
   e99f33420f577ee8ce54b67080[2]80d1e c69821bcb6a8839396f965[a]b6ff72a70
  }