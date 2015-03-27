<#
	Test 
#>
function Check-CurrentPageForBadWebPart(){
	[CmdletBinding()]
	param(
		
		[Microsoft.SharePoint.SPFile] $File,
		[Microsoft.SharePoint.SPWeb] $web				
	)	
	
	#$wpManager = $file.GetLimitedWebPartManager([System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
	$wpManager = $web.GetLimitedWebPartManager("http://redactie-slo-710.pggm-o.nl/Paginas/default.aspx",[System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
	foreach($wp in $wpManager.WebParts){
		write-host $file.Url
		write-host $wp.ID
		write-host $wp.DisplayTitle
		write-host $wp.Title
		write-host $wp.ChromeType
		write-host $wp.HelpMode
		write-host $wp.GetType().ToString() 
		write-host $wp.WebBrowsableObject.ToString() 
		write-host $wp.ZoneIndex
		write-host $wp.Zone.ID
		write-host $wp.Zone.Title
	#Microsoft.SharePoint.WebPartPages.ErrorWebPart
	}
}

$site = new-object Microsoft.SharePoint.SPSite("http://redactie-slo-710.pggm-o.nl/Paginas/default.aspx")
$web = $site.OpenWeb()
$file = $web.GetFile("http://redactie-slo-710.pggm-o.nl/Paginas/default.aspx")
if($file){
	Check-CurrentPageForBadWebPart -File $file -web $web
}
else{
	Write-Host "File could not be loaded"
}