
function Check-CurrentPageForBadWebPart(){
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.SPFile] $file		
	)
	if(CheckOut-File($file)){
		$wpManager = $file.GetLimitedWebPartManager([System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
		$webPartCollection = @()
		$webPartCollection += $wpManager.WebParts |? {$_.GetType().ToString() -eq "Microsoft.SharePoint.WebPartPages.ErrorWebPart"}
		if($webPartCollection.Count -eq 0 -or $webPartCollection[0] -eq $null){
			$file.UndoCheckOut()
		}
		else{
			foreach($wp in $webPartCollection){
				$wpManager.DeleteWebPart($wp)
			}		
		}
	}
}

function CheckOut-File(){
	[CmdletBinding()]
	param(
	[Microsoft.SharePoint.SPFile] $file	
	)
	try{
		if($file.SPCheckOutType  -eq "None"){		
			try{
				$file.CheckOut()	
				return $true
			}
			catch{
				$file.CheckOut("online",$null)
				return $true
			}
		}
		else{
			#File is already checked out 
			if($file.CheckedOutByUser.LoginName.split("|")[1] -eq [System.Security.Principal.WindowsIdentity]::GetCurrent().Name){
				# the file is checked out by the same current user
				return $true
			}
			else{
				return $false
			}	 
		}
	}
	catch{return $false}
}
Function Save-File(){
	[CmdletBinding()]
	param(
		[Microsoft.SharePoint.SPFile] $file,
		[string]$CheckinMessage,
		[string]$PublishMessage
	)
	try{
		$file.Checkin($CheckinMessage)
		$file.Publish($PublishMessage)
	}
	catch{}
}
function Delete-Versions(){
	[CmdletBinding()]
	param(
		[System.Data.DataSet]$DataSet
	)
	try{
		foreach($row in $DataSet.Tables[0].Rows){
			if($row["SiteId"] -ne $null -and $row["DirName"] -ne $null -and $row["LeafName"] -ne $null -and $row["WebId"] -ne $null -and $row["Id"] -ne $null){				
					$pageUrl = "$($row["DirName"])/$($row["LeafName"])"
					$site = Get-SPSite -Identity $row["SiteId"]
					$web = $site.openWeb($row["WebId"])
					$fullPageURL =  "$($web.Url)/$($pageUrl.Substring($pageUrl.IndexOf("/Paginas/")+1))"
					$file = $web.GetFile([GUID]$row["Id"])
					if(CheckOut-File($file)){
					Check-CurrentPageForBadWebPart($file)
						if($file -ne $null){ 
							if($file.Versions.Count -gt 0){
								$file.Versions.DeleteAll()
								Write-Verbose "Old version of the page '$($file.Url)' are now deleted" -ForegroundColor Green					
							}				
						}
						else{
							Write-Verbose "Page '$($file.Url)' does not exist" -ForegroundColor Yellow
						}	
						Save-File -file $file -CheckinMessage "Checkin from PowerShell on webpart changes" -PublishMessage "Publish from PowerShell on webpart changes"
						$web.RecycleBin.DeleteAll()
						$web.RecycleBin.MoveAllToSecondStage()
						$site.RecycleBin.DeleteAll()
					}
					$web.Dispose()
					$site.Dispose()			
			}
		}
	}
	catch{
		Write-Host "Failed to remove the old version of the page." -ForegroundColor Red
	}
}

function Run-SQLQuery (){
	[CmdletBinding()]
	param(
		[string]$SqlServer,
		[string]$SqlDatabase,
		[string]$SqlQuery
	)
	try{
		$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
		$sqlConnection.ConnectionString = "Server =" + $SqlServer + "; Database =" + $SqlDatabase + "; Integrated Security = True"
		$sqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$sqlCmd.CommandText = $SqlQuery
		$sqlCmd.Connection = $sqlConnection
		$sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$sqlAdapter.SelectCommand = $sqlCmd
		$dataSet = New-Object System.Data.DataSet
		$sqlAdapter.Fill($dataSet)
		$sqlConnection.Close()
		return $dataSet
	}
	catch{
		Write-Verbose "Failed to get component details from the database." -ForegroundColor Red
	}
}

function Remove-MissingWebPart(){
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		[String]$WebPartGUID,
		[Parameter(Mandatory=$true)]
		[String]$ContentDB,
		[Parameter(Mandatory=$true)]
		[String]$DBServer
	)	
	
	$query = "SELECT Id, SiteId, DirName, LeafName, WebId, ListId, tp_ZoneID  from AllDocs inner join AllWebParts on AllDocs.Id = AllWebParts.tp_PageUrlID where AllWebParts.tp_WebPartTypeID = '$WebPartGUID'" 
	#Get-SPWebApplication | Get-SPSite -Limit ALL |%{
	#	$contentDb = Get-SPContentDatabase -site $_.Url
	#	if($contentDb -ne $null){
	#		$dataSet = Run-SQLQuery -SqlServer $contentDb.Server -SqlDatabase $contentDb.Name -SqlQuery $query
	#		if($dataSet.Tables[0].Rows -ne $null -and $dataSet.Tables[0].Rows.Count -gt 0){
	#			Delete-Versions($dataSet)
	#		}
	#	}
	#}
	$dataSet = Run-SQLQuery -SqlServer $DBServer -SqlDatabase $ContentDB -SqlQuery $query
	if($dataSet.Tables[0].Rows -ne $null -and $dataSet.Tables[0].Rows.Count -gt 0){
		Delete-Versions($dataSet)
	}
}

function Remove-MissingSetupFile(){
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true)]
		[String] $SetupPath
	)	
	
	$query = "SELECT Id, SiteId, DirName, LeafName, WebId, ListId  from AllDocs where SetupPath = '$SetupPath'" 
	Get-SPWebApplication | Get-SPSite -Limit ALL |%{
		$contentDb = Get-SPContentDatabase -site $_.Url
		if($contentDb -ne $null){
			$dataSet = Run-SQLQuery -SqlServer $contentDb.Server -SqlDatabase $contentDb.Name -SqlQuery $query
			if($dataSet.Tables[0].Rows -ne $null -and $dataSet.Tables[0].Rows.Count -gt 0){
					
			}
		}
	}
}
function Remove-MissingDependancies(){
	$Sites =  Get-SPWebApplication -includecentraladministration | where {$_.IsAdministrationWebApplication} | Get-SPSite 
	$ListItems = $Sites[0].RootWeb.Lists["Review problems and solutions"].Items
	foreach($item in $ListItems){
		if($item.Title -eq "Missing server side dependencies."){
			$delimiters =@("[Missing")
			$option = [System.StringSplitOptions]::None
			$issues = @()
			$item["HealthReportExplanation"].split($delimiters,$option)|%{if($_){$issues+= "[Missing$($_)"}}
			foreach( $msg in $issues){                
					if($msg.StartsWith("[MissingWebPart]","CurrentCultureIgnoreCase")){                        						
						$RegExp = [regex]"([a-z0-9]{8}[-][a-z0-9]{4}[-][a-z0-9]{4}[-][a-z0-9]{4}[-][a-z0-9]{12})"
						$0utput = $RegExp.Match($msg)
						$webPartGUID = $0utput.Captures[0].value
						$contentDB = $msg.Split(@("] times in the database ["),$option)[1].Split(@("],"),$option)[0]
						$db = Get-SPContentDatabase $contentDB
						$dbServer = $db.Server
						#Now you have the complete message, webpartGUID, ContentDB and the DB server. invoke the other module to fix it.
						Write-Verbose "Troubleshooting the [MissingWebPart] error for the webpart ID : $($webPartGUID)"
						Remove-MissingWebPart -WebPartGUID $webPartGUID -ContentDB $contentDB -DBServer $dbServer
					}
					elseif($msg.StartsWith("[MissingAssembly]","CurrentCultureIgnoreCase")){
						#Write-Verbose "Checking for the [MissingAssembly] error"
						Write-Verbose "Fix for [MissingAssembly] is not available in this release"
						
					}
					elseif($msg.StartsWith("[MissingSetupFile]","CurrentCultureIgnoreCase")){
						#[MissingSetupFile] File [Features\SharePointProject3_Feature1\WebPart1\WebPart1.webpart] is referenced [1] times in the database [Content_PGGM_O], 
						#but is not installed on the current farm. Please install any feature/solution which contains this file. One or more setup files are referenced in 
						#the database [Content_PGGM_O], but are not installed on the current farm. Please install any feature or solution which contains these files.
                        
						#Write-Verbose "Checking for the [MissingSetupFile] error"
						Write-Verbose "Fix for [MissingSetupFile] is not available in this release"
					}
			}
		}
	}

}