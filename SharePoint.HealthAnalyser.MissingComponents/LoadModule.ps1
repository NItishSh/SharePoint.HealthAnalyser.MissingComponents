
$Path = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\SharePoint.HealthAnalyser.MissingComponents"
Write-Verbose "Module path is located as $Path"

Write-Host ""
Write-Verbose "Removing old content"

if(Test-Path $Path){
	Remove-Item $Path -Confirm:$false -Recurse
}
Write-Verbose "Copying new content"
New-Item $Path -Type Directory | Out-Null
Copy-Item ..\SharePoint.HealthAnalyser.MissingComponents\SharePoint.HealthAnalyser.MissingComponents.* $Path 
#Copy-Item ..\Solution\WarmupSites\About* $Path 

Write-Verbose "Completed the process successfully"
