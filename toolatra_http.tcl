#!/usr/bin/env tclsh
# Toolatra - Sinatra-like web microframework for Tcl 8.5/8.6
# Copyright (C) Tim K/RoverAMD 2018-2019 <timprogrammer@rambler.ru>.
# 
# File: toolatra_http.tcl
# Description: Toolatra framework itself
# License: MIT License

if {[lsearch -exact [info globals] toolatraIsPackaged] < 0 || ! $toolatraIsPackaged} {
	puts "IMPORTANT WARNING! Please notice that as of version 19.10.2, support for Tcl package command was added and so it is now recommended to use \"package require Toolatra\" instead of \"source toolatra_http.tcl\"."
}

set _toolatra_http_requesthandlers {}
set _toolatra_http_response [dict create]
set _toolatra_version_major 19
set _toolatra_version_minor 12
set _toolatra_http_responsenohandle -1
set _toolatra_http_mergeableUrlParams [dict create]

proc _toolatra_tclext_urlmatch {url1 url2} {
	global _toolatra_http_mergeableUrlParams
	set _toolatra_http_mergeableUrlParams [dict create]
	set splitCompared [split $url2 /]
	set splitCurrent [split $url1 /]
	if {[llength $splitCurrent] != [llength $splitCompared]} {
		return 0
	}
	for {set index 0} {$index < [llength $splitCompared]} {incr index} {
		set itm [lindex $splitCurrent $index]
		set itmN [lindex $splitCompared $index]
		if {[string length $itmN] > 0 && [string index $itmN 0] == {+}} {
			dict set _toolatra_http_mergeableUrlParams [string range $itmN 1 end] $itm
		} elseif {$itmN != $itm} {
			return 0
		}
	}
	return 1
}

proc _toolatra_http_evalrequest {type url} {
	global _toolatra_http_requesthandlers
	foreach rq $_toolatra_http_requesthandlers {
		if {[lindex $rq 0] == $type && [_toolatra_tclext_urlmatch $url [lindex $rq 1]]} {
			return [lindex $rq 2]
		}
	}
	return ?
}


proc _toolatra_server_finderror {errc} {
	set errorCodes [dict create 200 OK \
								201 Created \
								202 Accepted \
								204 {No Content} \
								302 {Moved Temporarily} \
								301 {Moved Permenently} \
								500 {Internal Server Error} \
								400 {Bad Request} \
								404 {Not Found} \
								403 Forbidden]
	
	if {! [dict exists $errorCodes $errc]} {
		error "HTTP error code not supported by Toolatra: $errc"
	}
	return [dict get $errorCodes $errc]
}

proc _toolatra_server_genheaders {response} {
	global _toolatra_version_major
	global _toolatra_version_minor
	set listing [list "X-ToolatraFramework-TclVersion: [info patchlevel]" "X-ToolatraFramework-Version: $_toolatra_version_major.$_toolatra_version_minor"]
	set content ""
	dict for {key val} $response {
		if {$key != "toolatra_ctnt"} {
			if {$key != "sender" && $key != "when" && $key != "error"} {
				lappend listing "$key: $val"
			} else {
				lappend listing "X-ToolatraFramework-RequestRelatedVars-$key: $val"
			}
		} else {
			set content "$val"
		}
	}
	lappend listing "Connection: closed"
	lappend listing {}
	lappend listing $content
	return $listing
}

proc _toolatra_has_request {type url} {
	if {[_toolatra_http_evalrequest $type $url] != "?"} {
		return 1
	}
	return 0
}


proc _toolatra_server_error {url message} {
	global _toolatra_http_responsenohandle
	if {$_toolatra_http_responsenohandle == -1} {
		set result "<html><head><title>Toolatra framework error</title></head>"
		set result "$result<body><h1 style=\"color: red\">Toolatra Server Error</h1>"
		set result "$result<p><b>URL:</b> $url</p>"
		set result "$result<p><b>Error:</b> $message</p>"
		set result "$result<br><p>An error that is specified above has occured while processing your request. You should contact the developers of this application if you know that this has worked previously.</p></body></html>"
	} else {
		set result [string map [list {@message@} $message {@url} $url] $_toolatra_http_responsenohandle]
	}
	return $result
}

proc _toolatra_has_qs {url} {
	for {set index 0 } { $index < [string length $url] } { incr index } {
 		if {[string index $url $index] == "?"} {
			return 1
		}
	}
	return 0
}

proc _toolatra_server_mimetypefn {fn} {
	set extension [file extension $fn]
	set extension [string range $extension 1 end]
	if {$extension == "html" || $extension == "htm"} {
		return text/html
	} elseif {$extension == "css"} {
		return text/css
	} elseif {$extension == "js"} {
		return application/javascript
	} elseif {$extension == "jpeg" || $extension == "jpg" || $extension == "jpe"} {
		return image/jpeg
	} elseif {$extension == "gif"} {
		return image/gif
	} elseif {$extension == "png"} {
		return image/png
	} elseif {$extension == "txt"} {
		return text/plain
	} else {
		return application/octet-stream
	}
}

proc _toolatra_tclext_nolast {lst} {
	return [string range $lst 0 [expr {[string length $lst] - 2}]]
}

proc _toolatra_server_collectheaders {sockt} {
	set result [dict create]
	while {! [catch {gets $sockt rqctnt}]} {
		if {[string length $rqctnt] < 3} {
			break
		}
		set splitrq [split $rqctnt :]
		dict set result [_toolatra_tclext_nolast [lindex $rqctnt 0]] [string trim [lindex $rqctnt 1]]
		
	}
	return $result
}

proc _toolatra_tclext_rmempty {listing} {
	set result {}
	foreach itm $listing {
		if {[string length [string trim $itm]] >= 1} {
			lappend result $itm
		}
	}
	return $result
}

proc _toolatra_socket_secureputs {sock what} {
	if {[catch {puts $sock $what}]} {
		return 0
	}
	return 1
}

proc _toolatra_server_processrequest {sock addr time} {
	global _toolatra_http_response
	set _toolatra_http_response [dict create sender $addr when $time]
	puts ------------------------------------------------------
	puts "Processing incoming connection by $addr on [clock format $time -format {%Y-%m-%d %H:%M:%S}]"
	set headersDict [dict create]
	chan configure $sock -encoding utf-8
	if {[eof $sock] || [catch {gets $sock rqctnt}]} {
		close $sock
		puts "Connection closed"
	} else {
		puts "Connection kept open"
		set headersDict [_toolatra_server_collectheaders $sock]
		puts $headersDict
	}
	set requestSplit [split $rqctnt { }]
	if {[llength $requestSplit] < 3} {
		close $sock
		puts "Invalid request sent by $addr's browser, not handling it in any way."
		puts ------------------------------------------------------	
		return		
	}
	set requestType [string toupper [lindex $requestSplit 0]]
	set requestUrl [lindex $requestSplit 1]
	set requestHttp [lindex $requestSplit 2]
	set params $headersDict
	if {[_toolatra_has_qs $requestUrl]} {
		puts "(Query string CGI parameters specified)"
		set paramsStr [lindex [split $requestUrl ?] 1]
		set requestUrl [lindex [split $requestUrl ?] 0]
		set paramsStr [split $paramsStr &]
		foreach prm $paramsStr {
			set splitPrm [split $prm =]
			set key [lindex $splitPrm 0]
			set value [join [lreplace $splitPrm 0 0] =]
			dict set params $key $value
		}
	}
	puts "URL: $requestUrl"
	set cwdPublic "[pwd]/public/$requestUrl"
	if {[file exists $cwdPublic] && [file isdirectory $cwdPublic] != 1} {
		puts "Static resource found in $cwdPublic"
		set mimeType [_toolatra_server_mimetypefn $cwdPublic]
		puts "Mime-type: $mimeType"
		set ctntTmp [open $cwdPublic]
		fconfigure $ctntTmp -translation binary -encoding binary
		set everythingTmp [read $ctntTmp]
		close $ctntTmp
		_toolatra_socket_secureputs $sock "HTTP/1.1 200 OK"
		_toolatra_socket_secureputs $sock "Content-type: $mimeType"
		_toolatra_socket_secureputs $sock "Connection: closed"
		_toolatra_socket_secureputs $sock "X-ToolatraFramework-FoundResource: $cwdPublic"
		_toolatra_socket_secureputs $sock ""
		chan configure $sock -translation binary -encoding binary
		_toolatra_socket_secureputs $sock $everythingTmp
		puts ------------------------------------------------------	
		close $sock
		return
	}
	if {$requestHttp != "HTTP/1.1"} {
		puts "Invalid HTTP version ($requestHttp), not handling it in any way."
	} elseif {[_toolatra_has_request $requestType $requestUrl]} {
		set rawData {}
		global _toolatra_http_mergeableUrlParams
		set params [dict merge $params $_toolatra_http_mergeableUrlParams]
		set _toolatra_http_mergeableUrlParams [dict create]
		if {$requestType != {GET}} {
			set countOfChars 0
			if {! [dict exists $params Content-Length]} {
				puts "Invalid $requestType request without Content-Length, not reading any data."
				return
			} else {
				set countOfChars [dict get $params Content-Length]
				set rawData [read $sock $countOfChars]
				puts "Read $countOfChars bytes of data"
			}
		}
		#set rawData [_toolatra_tclext_rmempty $rawData]
		set me $requestUrl
		if {[catch {eval [_toolatra_http_evalrequest $requestType $requestUrl]} reason]} {
			puts "Exception thrown, displaying an error (reason = '$reason')"
			_toolatra_socket_secureputs $sock "HTTP/1.1 500 Internal Server Error"
			_toolatra_socket_secureputs $sock "Content-type: text/html"
			_toolatra_socket_secureputs $sock ""
			_toolatra_socket_secureputs $sock [_toolatra_server_error $requestUrl "Tcl exception was thrown:<br><br><i>[string map [list "\r\n" "<br>" "\n" "<br>"] $::errorInfo]</i>"]
			close $sock
			puts ------------------------------------------------------
			return
		}
		if {! [dict exists $_toolatra_http_response toolatra_ctnt]} {
			dict set _toolatra_http_response toolatra_ctnt ""
		}
		if {[dict exists $_toolatra_http_response error]} {
			set errcv [dict get $_toolatra_http_response error]
			if {[string length [string trim [dict get $_toolatra_http_response toolatra_ctnt]]] < 1} {
				if {[_toolatra_has_request GET /$errcv]} {
					eval [_toolatra_http_evalrequest GET /$errcv]
				} else {
					dict set _toolatra_http_response Content-type text/html
					dict set _toolatra_http_response toolatra_ctnt [_toolatra_server_error $requestUrl [_toolatra_server_finderror $errcv]]
				}
				dict set _toolatra_http_response error $errcv
			}
			_toolatra_socket_secureputs $sock "HTTP/1.1 $errcv [_toolatra_server_finderror $errcv]"
		} else {
			_toolatra_socket_secureputs $sock "HTTP/1.1 200 OK"
		}
		set hdrs [_toolatra_server_genheaders $_toolatra_http_response]
		if {[lsearch -exact [info globals] toolatra_noCORSAllow] < 0 && [dict exists $params Origin]} {
			dict set _toolatra_http_response Access-Control-Allow-Origin [dict get $params Origin]
		}
		if {[dict exists $_toolatra_http_response X-ToolatraFramework-IsBinary] && [dict get $_toolatra_http_response X-ToolatraFramework-IsBinary]} {
			_toolatra_socket_secureputs $sock [join [lreplace $hdrs end end] "\n"]
			chan configure $sock -encoding binary -translation binary -buffering none
			_toolatra_socket_secureputs $sock [lindex $hdrs [expr {[llength $hdrs] - 1}]]
		} else {
			foreach hdr $hdrs {
				_toolatra_socket_secureputs $sock $hdr
			}
		}
	} elseif {$requestUrl == "/" && $requestType == "GET"} {
		_toolatra_socket_secureputs $sock "HTTP/1.1 302 Moved Temporarily"
		_toolatra_socket_secureputs $sock "Content-type: text/plain"
		_toolatra_socket_secureputs $sock "X-ToolatraFramework-FirstRun: 1"
		_toolatra_socket_secureputs $sock "Location: http://timkoi.gitlab.io/toolatra/welcome"
		_toolatra_socket_secureputs $sock "URI: http://timkoi.gitlab.io/toolatra/welcome"
		_toolatra_socket_secureputs $sock "Connection: close"
		_toolatra_socket_secureputs $sock ""
		_toolatra_socket_secureputs $sock "If you are not being redirected, manually go to http://timkoi.gitlab.io/toolatra/welcome"
	} else {
		puts "No handler for request $requestUrl ($requestType), returning an error."
		_toolatra_socket_secureputs $sock "HTTP/1.1 404 Not Found"
		_toolatra_socket_secureputs $sock "Content-type: text/html"
		_toolatra_socket_secureputs $sock ""
		_toolatra_socket_secureputs $sock [_toolatra_server_error $requestUrl "There is no handler registered for this URL."]
	}
	close $sock
	puts ------------------------------------------------------
}

proc _toolatra_server_queuerequest {sock addr port} {
	puts ------------------------------------------------------
	puts "Incoming connection added to Toolatra's socket queue"
	puts "Sender: $addr:$port"
	puts "Time: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
	puts ------------------------------------------------------
	fconfigure $sock -buffering line
	fileevent $sock readable [list _toolatra_server_processrequest $sock $addr [clock seconds]]
}

proc _toolatra_server_kickstart {port} {
	set skt [socket -server _toolatra_server_queuerequest $port]
	puts "Toolatra's built-in HTTPD is up and running and you can go to http://localhost:$port to enjoy your web app!"
	vwait forever
}

proc _toolatra_request {type url handler} {
	set inlineList [list $type $url $handler]
	if {[_toolatra_has_request $type $url]} {
		error "$type request handler for URL \"$url\" was already declared earlier."
	}
	global _toolatra_http_requesthandlers
	lappend _toolatra_http_requesthandlers $inlineList
}

proc get {url handler} {
	_toolatra_request GET $url $handler
}

proc show {content {mimetype {text/html; charset=utf-8}}} {
	global _toolatra_http_response
	if {! [dict exists $_toolatra_http_response toolatra_ctnt]} {
		dict set _toolatra_http_response toolatra_ctnt ""
	}
	dict set _toolatra_http_response toolatra_ctnt "[dict get $_toolatra_http_response toolatra_ctnt]$content"
	dict set _toolatra_http_response Content-type $mimetype
}

proc bshow {content {mimetype {application/octet-stream}}} {
    global _toolatra_http_response
	dict set _toolatra_http_response toolatra_ctnt $content
	dict set _toolatra_http_response X-ToolatraFramework-IsBinary 1
	dict set _toolatra_http_response Content-type $mimetype
}

proc brender {content {mimetype {application/octet-stream}}} {
	bshow $content $mimetype
}

proc status {errc} {
	global _toolatra_http_response
	dict set _toolatra_http_response error $errc
}

proc error {errc} {
	status $errc
}

proc render {content {mimetype {text/html; charset=utf-8}}} {
	show $content $mimetype
}

proc run {{port 5050}} {
	if {[info exists ::env(TOOLATRA_FORCEDPORT)]} {
		set port $::env(TOOLATRA_FORCEDPORT)
	}
	_toolatra_server_kickstart $port
}

proc post {url handler} {
	_toolatra_request POST $url $handler
}

proc put {url handler} {
	_toolatra_request PUT $url $handler
}

proc delete {url handler} {
	_toolatra_request DELETE $url $handler
}

proc header {name text} {
	global _toolatra_http_response
	dict set _toolatra_http_response $name $text
}

proc cookie {name {val {}}} {
	upvar params params
	if {$val != {}} {
		header Set-Cookie "$name=$val"
		return $val
	} else {
		if {! [dict exists $params Cookie]} {
			return {}
		}
		set cookiesStr [dict get $params Cookie]
		set cookiesSplit [split $cookiesStr ";"]
		foreach kvp $cookiesSplit {
			set kvp [string trimleft $kvp]
			set kvpSplit [split $kvp {=}]
			if {[lindex $kvpSplit 0] == $name} {
				return [join [lreplace $kvpSplit 0 0] {=}]
			}
		}
		return {}
	}
}

proc redirect {url} {
	global _toolatra_http_response
	dict set _toolatra_http_response Content-type text/html
	dict set _toolatra_http_response Location $url
	dict set _toolatra_http_response URI $url
	dict set _toolatra_http_response toolatra_ctnt "If you aren't getting redirected, click <a href=\"$url\">here</a>."
	dict set _toolatra_http_response error 302
}

proc unhandled_show {what} {
	global _toolatra_http_responsenohandle
	set _toolatra_http_responsenohandle $what
}


package provide Toolatra $_toolatra_version_major.$_toolatra_version_minor
package require Tcl 8.5

if {[info exists argv0] && $argv0 == [info script]} {
	puts "Toolatra must be included from a Tcl script and cannot be run as a standalone script itself, because it is a framework, not a fully-featured program."
	exit 1
}
