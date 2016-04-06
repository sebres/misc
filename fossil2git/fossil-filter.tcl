#! /usr/bin/env tclsh
# -------------------------------------
# Filter example for fossil export, using tcl.
#
# Makes export backwards compatible to export of fossil before version 1.3x
# -------------------------------------
# Wrap committer, because:
#   - fossil since 1.3x has confused user name and email (committer / author field wrong)
#   - fossil before 1.3x has exported a user name in email field, so thus will prevent a rebase of whole tree
# Remove trailing newline at end of message
# -------------------------------------
# Copyright (c) 2015 Serg G. Brester (sebres)
# -------------------------------------

set reset_tags 1
set remove_email_before_date ""
#set remove_email_before_date [clock scan "28.04.2015" -format "%d.%m.%Y"]
set norm_message 0
array set mails {
  andreas_kupries     akupries@shaw.ca
  andreask            akupries@shaw.ca
  chengyemao          chengyemao@users.sourceforge.net
  coldstore           coldstore@users.sourceforge.net
  das                 das@users.sourceforge.net
  davygrvy            davygrvy@users.sourceforge.net
  dgp                 dgp@users.sourceforge.net
  dkf                 dkf@users.sourceforge.net
  drh                 drh@users.sourceforge.net
  ericm               ericm@users.sourceforge.net
  ferrieux            ferrieux@users.sourceforge.net
  hobbs               hobbs@users.sourceforge.net
  jan.nijtmans        nijtmans@users.sourceforge.net
  jenglish            jenglish@users.sourceforge.net
  kennykb             kennykb@users.sourceforge.net
  kupries             akupries@shaw.ca
  mdejong             mdejong@users.sourceforge.net
  mig                 msofer@users.sourceforge.net
  mistachkin          mistachkin@users.sourceforge.net
  msofer              msofer@users.sourceforge.net
  nijtmans            nijtmans@users.sourceforge.net
  oehhar              oehhar@users.sourceforge.net
  patthoyts           patthoyts@users.sourceforge.net
  pvgoran             pvgoran@users.sourceforge.net
  redman              redman@users.sourceforge.net
  rmax                rmax@users.sourceforge.net
  sandeep             sandeep@users.sourceforge.net
  seandeelywoods      seandeelywoods@users.sourceforge.net
  sebres              sebres@users.sourceforge.net
  sergey.brester      sebres@users.sourceforge.net
  stanton             stanton@users.sourceforge.net
  stwo                stwo@users.sourceforge.net
  twylite             twylite@users.sourceforge.net
  vasiljevic          vasiljevic@users.sourceforge.net
  vbwagner            vbwagner@users.sourceforge.net
  vincentdarley       vincentdarley@users.sourceforge.net
  welch               welch@users.sourceforge.net
  wolfsuit            wolfsuit@users.sourceforge.net
}

# -------------------------------------

fconfigure stdin -encoding binary -translation lf -eofchar {} -buffersize 1024000
fconfigure stdout -encoding binary -translation lf -eofchar {} -buffersize 1024000
set commit 0
set tag 0
while 1 {
  set l [::gets stdin]
  if {$l == {} && [::eof stdin]} {
    break
  }
  if {!$tag && [regexp {^data\s+(\d+)$} $l _ n]} {
    ## read blob or message :
    fconfigure stdout -translation binary
    fconfigure stdin -translation binary
    set data [read stdin $n]
    ## if message - remove multiple leading and trailing whitespaces:
    if {$commit} {
      set dorg $data
      ## because of conflict resp. completelly different messages handling between 1.2x and 1.3x, 
      ## not possible to normalize it, so just trim trailing spaces and normalize committer e-mail...
      if $norm_message {;#
      ## normalize message (make it equal to previous fossil version):
      set data [norm_message $data]
      };#
      ## remove trailing spaces (add exact one newline, because of export/import):
      if {[regsub {\s+$} $data "\n" data] || [string length $dorg] != [string length $data]} {
        set l "data [string length $data]"
      }
      set commit 0
    }
    ## write :
    ::puts stdout $l
    ::puts -nonewline stdout $data
    fconfigure stdout -translation lf
    fconfigure stdin -translation lf
    continue
  }
  ## recognize commit, wrap committer :
  if {[regexp {^committer\s+} $l] && [regexp {^committer\s+([^<]+)\s+\<(.+)\>\s+(.*)$} $l _ usr email rest]} {
    set commit 1; set tag 0
    ## check confused user/email :
    if {[regexp {\S+@\S+} $usr] && ![regexp {\S+@\S+} $email]} {
      lassign [list $usr $email] email usr
      set l "committer $usr <${email}> $rest"
    ## check no email :
    } elseif {![regexp {\S+@\S+} $email]} {
      # wrap if we can:
      if {![catch {set email $mails($usr)}] || ![catch {set email $mails($email)}]} {
        set l "committer $usr <${email}> $rest"
      }
    }
    ## prevent completelly rebase tree (old fossil was without email - user name only):
    if {$remove_email_before_date != "" &&
      [regexp {^(\d+)\s+([+\-]\d{4})} $rest _ tm {}] && $tm < $remove_email_before_date
    } {
      set l "committer $usr <${usr}> $rest"
    }
  } elseif {!$commit && $reset_tags} {
    if {!$tag && [regexp {^tag\s+(.+)$} $l _ ref]} {
      set tag 1
      set l "reset refs/tags/$ref"
    } elseif {$tag} {
      if {[regexp {^tagger\s} $l]} {
        # ignore "tagger <tagger>" within mode "reset_tags" ...
        if {[incr tag] > 2} {set tag 0}
        continue
      } elseif {[regexp {^data\s+0$} $l]} {
        # ignore "data 0" within mode "reset_tags" ...
        if {[incr tag] > 2} {set tag 0}
        continue
      }
    }
  }
  ::puts stdout $l
}