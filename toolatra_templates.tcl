proc _toolatra_varpingpong {vr} {
	return $vr
}

proc _toolatra_template_load {tname {context -1}} {
	if {$context != -1} {
		dict for {key val} $context {
			set $key $val
		}
	}
	foreach key [info globals] {
		global $key
	}
	set relPath [pwd]/templates/$tname
	if {! [file exists $relPath]} {
		error "No such file or directory - \"$relPath\"."
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

proc etcl {name {cntx -1}} {
	show [_toolatra_template_load $name $cntx]
}

