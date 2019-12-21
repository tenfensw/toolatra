#!/usr/bin/env tclsh
# Toolatra - Sinatra-like web microframework for Tcl 8.5/8.6
# Copyright (C) Tim K/RoverAMD 2018-2019 <timprogrammer@rambler.ru>.
# 
# File: toolatra_auth.tcl
# Description: Authorization module for Toolatra framework
# License: MIT License

proc _toolatra_auth_isValid {vt} {
    if {[string length $vt] != 4} {
        return 0
    }
    set charactersMet {}
    for {set index 0} {$index < 4} {incr index} {
        set chr [string index $vt $index]
        if {[lsearch -exact $charactersMet $chr] >= 0} {
            return 0
        } else {
            lappend charactersMet $chr
        }
    }
    return 1
}

if {! [info exists toolatra_auth] || ! [_toolatra_auth_isValid $toolatra_auth]} {
    error "Please set the value of the global variable \"toolatra_auth\" to a 4-character string, where each character must be unique. Notice that the variable must exist before including the ToolatraAuth module."
}

proc _toolatra_auth_mkMap {vt} {
    set map [dict create + [string index $vt 0] / [string index $vt 1] x [string index $vt 2] M [string index $vt 3]]
    return $map
}

proc _toolatra_auth_reverseMap {mp} {
    set result [dict create]
    dict for {keyVar valueVar} $mp {
        dict set result $valueVar $keyVar
    }
    return $result
}

proc _toolatra_auth_pretifyBase {bs} {
    global toolatra_auth
    set map [_toolatra_auth_mkMap $toolatra_auth]
    return [string map $map $bs]
}

proc _toolatra_auth_decodeToken {tkn} {
    global toolatra_auth
    set splitTkn [split $tkn +]
    if {[llength $splitTkn] < 2} {
        return {}
    }
    set tknV [join [lreplace $splitTkn 0 0] +]
    #puts "tknV is $tknV"
    set map [_toolatra_auth_reverseMap [_toolatra_auth_mkMap $toolatra_auth]]
    set tknDec [string map $map $tknV]
    return [base64::decode $tknDec]
}

proc token {ctnt {expires -1}} {
    set finalDate [expr {[clock seconds] + $expires}]
    if {$expires < 0} {
        set finalDate [expr {[clock seconds] + (int(rand() * 1000) * 60 * 60 * 24)}]
    }
    set formatted "$finalDate+$ctnt"
    return "$finalDate+[_toolatra_auth_pretifyBase [base64::encode $formatted]]"
}

proc tokenValid {tkn} {
    global toolatra_auth
    set date1 [lindex [split $tkn +] 0]
    if {! [string is integer $date1]} {
        return 0
    }
    set decTkn [_toolatra_auth_decodeToken $tkn]
    set date2 [lindex [split $decTkn +] 0]
    if {! [string is integer $date2]} {
        return 0
    }
    if {$date2 == $date1 && [clock seconds] <= $date2} {
        return 1
    }
    return 0
}

proc tokenValue {tkn} {
    global toolatra_auth
    if {! [tokenValid $tkn]} {
        return {}
    }
    set decTkn [_toolatra_auth_decodeToken $tkn]
    set decTknSplit [split $decTkn +]
    return [join [lreplace $decTknSplit 0 0] +]
}

package provide ToolatraAuth 19.12
package require Toolatra 19.12
package require base64
package require Tcl 8.5
