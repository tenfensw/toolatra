#!/usr/bin/env tclsh
global toolatraIsPackaged
set toolatraIsPackaged 1
package ifneeded Toolatra 19.10 [list source "$dir/toolatra_http.tcl"]
package ifneeded ToolatraTemplates 19.10 [list source "$dir/toolatra_templates.tcl"]
