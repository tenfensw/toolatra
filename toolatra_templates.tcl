#!/usr/bin/env tclsh
# Toolatra - Sinatra-like web microframework for Tcl 8.5/8.6
# Copyright (C) Tim K/RoverAMD 2018-2019 <timprogrammer@rambler.ru>.
# 
# File: toolatra_templates.tcl
# Description: Addon for Toolatra that allows rendering templates
# License: MIT License

proc _toolatra_varpingpong {vr} {
	return $vr
}

proc _toolatra_template_load {relPath {context -1}} {
	if {$context != -1} {
		dict for {key val} $context {
			set $key $val
		}
	}
	foreach key [info globals] {
		global $key
	}
	set desc [open $relPath r]
	set contents [read $desc]
	close $desc
	set result ""
	set tmpEval ""
	set insideEval 0
	for {set index 0} {$index < [string length $contents]} {incr index} {
		set cchar [string index $contents $index]
		if {$cchar == "@"} {
			if {$insideEval} {
				set insideEval 0
				if {[info exists $tmpEval]} {
					set result "$result[eval "_toolatra_varpingpong \$$tmpEval"]"
				} elseif {[string index $tmpEval 0] == {!}} {
					set substrTmpEval [string trim [string range $tmpEval 1 end]]
					set result "$result[layout $substrTmpEval $context]"
				} else {
					set result "$result[eval $tmpEval]"
				}
				set tmpEval ""
			} else {
				set insideEval 1
				set tmpEval ""
			}
		} elseif {$insideEval} {
			set tmpEval "$tmpEval$cchar"
		} else {
			set result "$result$cchar"
		}
	}
	return $result
}

proc layout {name {cntx -1}} {
	set layoutsDir "[pwd]/layouts"
	set lt "$layoutsDir/$name"
	if {! [file exists $lt]} {
		return "No such file or directory - \"$lt\" (layout: $name)."
	} else {
		return [_toolatra_template_load $lt $cntx]
	}
}

proc etcl {name {cntx -1}} {
	set relPath [pwd]/templates/$name
	if {! [file exists $relPath]} {
		error "No such file or directory - \"$relPath\"."
	}
	show [_toolatra_template_load $relPath $cntx]
}

package provide ToolatraTemplates 19.11
package require Toolatra 19.10
package require Tcl 8.5
