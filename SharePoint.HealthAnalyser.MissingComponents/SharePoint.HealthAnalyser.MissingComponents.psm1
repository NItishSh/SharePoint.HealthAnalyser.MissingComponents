
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
		[String]$WebPartGUID
	)	
	
	$query = "SELECT Id, SiteId, DirName, LeafName, WebId, ListId, tp_ZoneID  from AllDocs inner join AllWebParts on AllDocs.Id = AllWebParts.tp_PageUrlID where AllWebParts.tp_WebPartTypeID = '$WebPartGUID'" 
	Get-SPWebApplication | Get-SPSite -Limit ALL |%{
		$contentDb = Get-SPContentDatabase -site $_.Url
		if($contentDb -ne $null){
			$dataSet = Run-SQLQuery -SqlServer $contentDb.Server -SqlDatabase $contentDb.Name -SqlQuery $query
			if($dataSet.Tables[0].Rows -ne $null -and $dataSet.Tables[0].Rows.Count -gt 0){
				Delete-Versions($dataSet)
			}
		}
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
