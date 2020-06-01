#!/usr/bin/env tclsh
set directory "$::env(HOME)/Library/Tcl/toolatra-master"
if {[file isdirectory $directory]} {
	file delete -force $directory
}

file mkdir $directory
foreach fn {toolatra_http.tcl toolatra_templates.tcl toolatra_auth.tcl toolatra_mustache.tcl pkgIndex.tcl} {
	file copy $fn "$directory/$fn"
}

puts done
exit 0

