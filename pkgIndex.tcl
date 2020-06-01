#!/usr/bin/env tclsh
global toolatraIsPackaged
set toolatraIsPackaged 1
package ifneeded Toolatra 19.12 [list source "$dir/toolatra_http.tcl"]
package ifneeded ToolatraTemplates 19.11 [list source "$dir/toolatra_templates.tcl"]
package ifneeded ToolatraAuth 19.12 [list source "$dir/toolatra_auth.tcl"]
package ifneeded ToolatraMustache 20.06 [list source "$dir/toolatra_mustache.tcl"]