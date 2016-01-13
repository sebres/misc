#!/usr/bin/tclsh

# -------------------------------------------------------------------------
#  Test valid email, using simple regexp's and dig+idn pair for domain --
# 
#  [WARNING] Please don't prohibit a submit if check of the email failed. 
#            Just notify with a warning instead ...
# -------------------------------------------------------------------------
proc test_mail {mail} {
  if {![catch {
    ## some simple checks before @ ...
    if {![regexp {^(?:\"(.+)\"|[^\"]\S*)@} $mail]} {
      return -code error -errorcode EINVARG "Неверное имя"
    }
    ## exists @ and domain?
    if {![regexp {.@([^@]+)$} $mail _ mdomain]} {
      return -code error -errorcode EINVARG "Без домена"
    }
    ## valid domain?
    if {[set mdomain [exec idn $mdomain]] eq "" || 
       ([exec dig +short -t MX -q "${mdomain}."] eq "" && [exec dig +short -q "${mdomain}."] eq "")
    } {
      return -code error -errorcode EINVARG "Неверный домен"
    }
  } err opt]} {
    puts "<script>ok('OK.');</script>"
    log MSG "check of \"$mail\" succeeds (OK)"
  } else {
    set msg $err
    if {[dict get $opt -errorcode] ne {EINVARG}} {
      set msg "Очепятка в домене"
      log ERROR "check of \"$mail\" failed ($msg): $err"
    } else {
      log MSG "check of \"$mail\" failed ($err)"
    }
    puts "<script>warn('Возможна очепятка в поле E-Mail ($msg)?! Перепроверьте, пжста...')</script>"
  }
}
if {[info command ::log] eq ""} {
  proc log {args} {
    after idle [list ::puts [format "# %s \[%-6s\] %s" [clock format [clock seconds] -format %H:%M:%S] {*}$args]]
  }
}

# -------------------------------------------------------------------------
#  Test cases (examples):
# -------------------------------------------------------------------------
foreach mail {
  я@кто.рф
  test@gmail.com
  {"vaild with space"@gmail.com}
  {wrong with space@gmail.com}
  @кто.рф
  test@
  {я-хакер@ && echo 'test' > wget ...}
  с-точкой-в-конце@кто.рф.
  только-tld-1@рф
  только-tld-2@.com
  короткий@a.com
} {
  puts -nonewline "test [format %-32s "<$mail>"] ...  "
  test_mail $mail
}
puts ""
## log:
update idle

# -------------------------------------------------------------------------
#  Test output:
# -------------------------------------------------------------------------
if 0 {;#
test <я@кто.рф>                       ...  <script>ok('OK.');</script>
test <test@gmail.com>                 ...  <script>ok('OK.');</script>
test <"vaild with space"@gmail.com>   ...  <script>ok('OK.');</script>
test <wrong with space@gmail.com>     ...  <script>warn('Возможна очепятка в поле E-Mail (Неверное имя)?! Перепроверте, пжста...')</script>
test <@кто.рф>                        ...  <script>warn('Возможна очепятка в поле E-Mail (Неверное имя)?! Перепроверте, пжста...')</script>
test <test@>                          ...  <script>warn('Возможна очепятка в поле E-Mail (Без домена)?! Перепроверте, пжста...')</script>
test <я-хакер@ && echo 'test' > wget ...> ...  <script>warn('Возможна очепятка в поле E-Mail (Очепятка в домене)?! Перепроверте, пжста...')</script>
test <с-точкой-в-конце@кто.рф.>       ...  <script>warn('Возможна очепятка в поле E-Mail (Очепятка в домене)?! Перепроверте, пжста...')</script>
test <только-tld-1@рф>                ...  <script>warn('Возможна очепятка в поле E-Mail (Неверный домен)?! Перепроверте, пжста...')</script>
test <только-tld-2@.com>              ...  <script>warn('Возможна очепятка в поле E-Mail (Очепятка в домене)?! Перепроверте, пжста...')</script>
test <короткий@a.com>                 ...  <script>warn('Возможна очепятка в поле E-Mail (Неверный домен)?! Перепроверте, пжста...')</script>

# 16:51:56 [MSG   ] check of "я@кто.рф" succeeds (OK)
# 16:51:56 [MSG   ] check of "test@gmail.com" succeeds (OK)
# 16:51:56 [MSG   ] check of ""vaild with space"@gmail.com" succeeds (OK)
# 16:51:56 [MSG   ] check of "wrong with space@gmail.com" failed (Неверное имя)
# 16:51:56 [MSG   ] check of "@кто.рф" failed (Неверное имя)
# 16:51:56 [MSG   ] check of "test@" failed (Без домена)
# 16:51:56 [ERROR ] check of "я-хакер@ && echo 'test' > wget ..." failed (Очепятка в домене): idn: idna_to_ascii_4z: Output would be too large or too small
# 16:51:56 [ERROR ] check of "с-точкой-в-конце@кто.рф." failed (Очепятка в домене): dig: 'xn--j1ail.xn--p1ai..' is not a legal name (empty label)
# 16:51:56 [MSG   ] check of "только-tld-1@рф" failed (Неверный домен)
# 16:51:56 [ERROR ] check of "только-tld-2@.com" failed (Очепятка в домене): idn: idna_to_ascii_4z: Output would be too large or too small
# 16:51:56 [MSG   ] check of "короткий@a.com" failed (Неверный домен)
};#