set _toolatra_http_requesthandlers {}
set _toolatra_http_response [dict create]
set _toolatra_version_major 9
set _toolatra_version_minor 1

proc _toolatra_http_evalrequest {type url} {
	global _toolatra_http_requesthandlers
	foreach rq $_toolatra_http_requesthandlers {
		if {[lindex $rq 0] == $type && [lindex $rq 1] == $url} {
			return [lindex $rq 2]
		}
	}
	return ?
}

proc _toolatra_server_welcome {} {
	set content "<html><head><title>Welcome to Toolatra!</title></head><body style=\"font-family: Helvetica Arial sans;\">"
	set content "$content<center><img src=\"http://www.tcl.tk/images/tclp.gif\" /><h2>Welcome to Toolatra!</h2>"
	set content "$content<p>Congratulations! It appears that you've successfully installed Toolatra and that everything seems to be fine.</p>"
	set content "$content<p>Now that you've tested that everything is working file, add some pages to your web app.</p>"
	set content "$content<p>Consult the <a href=\"http://timkoi.gitlab.io/toolatra/tutorial\">Toolatra tutorial</a> for more info.</p>"
	set content "$content</center></body></html>"
	return $content
}

proc _toolatra_server_finderror {errc} {
	set errorCodes [dict create 200 OK 302 "Moved Temporarily" 301 "Moved Permenently" 500 "Internal Server Error" 401 "Bad Request" 404 "Not Found" 403 Forbidden]
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
	set result "<html><head><title>Toolatra framework error</title></head>"
	set result "$result<body><h1 style=\"color: red\">Toolatra Server Error</h1>"
	set result "$result<p><b>URL:</b> $url</p>"
	set result "$result<p><b>Error:</b> $message</p>"
	set result "$result<br><p>An error that is specified above has occured while processing your request. You should contact the developers of this application if you know that this has worked previously.</p></body></html>"
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

proc _toolatra_server_processrequest {sock addr time} {
	global _toolatra_http_response
	set _toolatra_http_response [dict create sender $addr when $time]
	puts ------------------------------------------------------
	puts "Processing incoming connection by $addr on [clock format $time -format {%Y-%m-%d %H:%M:%S}]"
	set headersDict [dict create]
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
	set requestType [lindex $requestSplit 0]
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
		puts $sock "HTTP/1.1 200 OK"
		puts $sock "Content-type: $mimeType"
		puts $sock "Connection: closed"
		puts $sock "X-ToolatraFramework-FoundResource: $cwdPublic"
		puts $sock ""
		chan configure $sock -translation binary -encoding binary
		puts $sock $everythingTmp
		puts ------------------------------------------------------	
		close $sock
		return
	}
	if {$requestHttp != "HTTP/1.1"} {
		puts "Invalid HTTP version ($requestHttp), not handling it in any way."
	} elseif {[_toolatra_has_request $requestType $requestUrl]} {
		eval [_toolatra_http_evalrequest $requestType $requestUrl]
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
			puts $sock "HTTP/1.1 $errcv [_toolatra_server_finderror $errcv]"
		} else {
			puts $sock "HTTP/1.1 200 OK"
		}
		set hdrs [_toolatra_server_genheaders $_toolatra_http_response]
		foreach hdr $hdrs {
			puts $sock $hdr
		}
	} elseif {$requestUrl == "/" && $requestType == "GET"} {
		puts $sock "HTTP/1.1 200 OK"
		puts $sock "Content-type: text/html"
		puts $sock "Connection: close"
		puts $sock ""
		puts $sock [_toolatra_server_welcome]
	} else {
		puts "No handler for request $requestUrl ($requestType), returning an error."
		puts $sock "HTTP/1.1 404 Not Found"
		puts $sock "Content-type: text/html"
		puts $sock ""
		puts $sock [_toolatra_server_error $requestUrl "There is no handler registered for this URL."]
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

proc show {content {mimetype text/html}} {
	global _toolatra_http_response
	if {! [dict exists $_toolatra_http_response toolatra_ctnt]} {
		dict set _toolatra_http_response toolatra_ctnt ""
	}
	dict set _toolatra_http_response toolatra_ctnt "[dict get $_toolatra_http_response toolatra_ctnt]$content"
	dict set _toolatra_http_response Content-type $mimetype
}

proc status {errc} {
	global _toolatra_http_response
	dict set _toolatra_http_response error $errc
}

proc error {errc} {
	status $errc
}

proc render {content {mimetype text/html}} {
	show $content $mimetype
}

proc run {{port 5050}} {
	_toolatra_server_kickstart $port
}

proc post {url handler} {
	_toolatra_request POST $url $handler
}

proc put {url handler} {
	_toolatra_request PUT $url $handler
}

proc header {name text} {
	global _toolatra_http_response
	dict set _toolatra_http_response $name $text
}

