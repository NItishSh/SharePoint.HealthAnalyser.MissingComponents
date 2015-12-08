<#
	Test 
#>

function Get-ScriptLocation
{
	write-host $MyInvocation.PSCommandPath
	write-host $MyInvocation.CommandOrigin
	$scriptPath = split-path -parent $Script:MyInvocation.MyCommand.Path
	write-host $scriptPath
}
Get-ScriptLocation