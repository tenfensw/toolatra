#!/usr/bin/env tclsh
# Toolatra - Sinatra-like web microframework for Tcl 8.5/8.6
# Copyright (C) Tim K/RoverAMD 2018-2020 <timprogrammer@rambler.ru>.
# 
# File: toolatra_mustache.tcl
# Description: Bare-bones support for Mustache templates for Toolatra web applications
# License: MIT License

proc mustache {fn items} {
	set fnReal "[pwd]/templates/$fn.mustache"
	if {! [file exists "$fnReal"]} {
		error "No Mustache template available with name '$fn' (looked for it at '$fnReal')"
	}
	set desc [open $fnReal r]
	set ctnt [read $desc]
	close $desc
	foreach key [info globals] {
		global $key
		dict set items $key [eval "\$$key"]
	}
	show [::mustache::mustache $ctnt $items]
}

package provide ToolatraMustache 20.06
package require Tcl 8.5
package require mustache 1.1.3