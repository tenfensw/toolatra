#!/usr/bin/env tclsh
if {$::env(USER) != {root}} {
	puts "Please run this script as root."
	exit 1
}

set dirv /usr/local/lib
set dirb "$dirv/toolatra"
if {! [file isdirectory $dirb]} {
	file mkdir -- $dirb
}

foreach fn {toolatra_http.tcl toolatra_auth.tcl toolatra_templates.tcl pkgIndex.tcl} {
	file copy $fn "$dirb/$fn"
}

puts done
exit 0
