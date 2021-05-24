<#  
    Title:          MCAS Activity Data Connector
    Language:       PowerShell
    Version:        1.0
    Author:         Nicholas DiCola
    Last Modified:  05/12/2021
    
    DESCRIPTION
    This Function App calls the MCAS Activity REST API (https://docs.microsoft.com/cloud-app-security/api-activities) to pull the MCAS
    Activity logs. The response from the MCAS API is recieved in JSON format. This function will build the signature and authorization header 
    needed to post the data to the Log Analytics workspace via the HTTP Data Connector API. The Function App will post the data to MCASActivity_CL.
#>
# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# Main
if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)){
    Connect-AzAccount -Identity
}

#Wait-Debugger

$AzureWebJobsStorage = $env:AzureWebJobsStorage
$MCASAPIToken = $env:MCASAPIToken
$workspaceId = $env:WorkspaceId
$workspaceKey = $env:WorkspaceKey
$Lookback = $env:Lookback
$MCASURL = $env:MCASURL
$LAURI = $env:LAURI
$storageAccountContainer = "mcasactivity-logs"
$fileName = "lastrun-MCAS.json"

$StartTime = (get-date).ToUniversalTime()
$currentStartTime = $StartTime | get-date  -Format yyyy-MM-ddTHH:mm:ss:ffffffZ

if (-Not [string]::IsNullOrEmpty($LAURI)){
	if($LAURI.Trim() -notmatch 'https:\/\/([\w\-]+)\.ods\.opinsights\.azure.([a-zA-Z\.]+)$')
	{
		Write-Error -Message "MCASActivity-SecurityEvents: Invalid Log Analytics Uri." -ErrorAction Stop
		Exit
	}
}

function Write-OMSLogfile {
    <#
    .SYNOPSIS
    Inputs a hashtable, date and workspace type and writes it to a Log Analytics Workspace.
    .DESCRIPTION
    Given a  value pair hash table, this function will write the data to an OMS Log Analytics workspace.
    Certain variables, such as Customer ID and Shared Key are specific to the OMS workspace data is being written to.
    This function will not write to multiple OMS workspaces.  BuildSignature and post-analytics function from Microsoft documentation
    at https://docs.microsoft.com/azure/log-analytics/log-analytics-data-collector-api
    .PARAMETER DateTime
    date and time for the log.  DateTime value
    .PARAMETER Type
    Name of the logfile or Log Analytics "Type".  Log Analytics will append _CL at the end of custom logs  String Value
    .PARAMETER LogData
    A series of key, value pairs that will be written to the log.  Log file are unstructured but the key should be consistent
    withing each source.
    .INPUTS
    The parameters of data and time, type and logdata.  Logdata is converted to JSON to submit to Log Analytics.
    .OUTPUTS
    The Function will return the HTTP status code from the Post method.  Status code 200 indicates the request was received.
    .NOTES
    Version:        2.0
    Author:         Travis Roberts
    Creation Date:  7/9/2018
    Purpose/Change: Crating a stand alone function    
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [datetime]$dateTime,
        [parameter(Mandatory = $true, Position = 1)]
        [string]$type,
        [Parameter(Mandatory = $true, Position = 2)]
        [psobject]$logdata,
        [Parameter(Mandatory = $true, Position = 3)]
        [string]$CustomerID,
        [Parameter(Mandatory = $true, Position = 4)]
        [string]$SharedKey
    )
    Write-Verbose -Message "DateTime: $dateTime"
    Write-Verbose -Message ('DateTimeKind:' + $dateTime.kind)
    Write-Verbose -Message "Type: $type"
    write-Verbose -Message "LogData: $logdata"   

    # Supporting Functions
    # Function to create the auth signature
    function BuildSignature ($CustomerID, $SharedKey, $Date, $ContentLength, $method, $ContentType, $resource) {
        $xheaders = 'x-ms-date:' + $Date
        $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
        $bytesToHash = [text.Encoding]::UTF8.GetBytes($stringToHash)
        $keyBytes = [Convert]::FromBase64String($SharedKey)
        $sha256 = New-Object System.Security.Cryptography.HMACSHA256
        $sha256.key = $keyBytes
        $calculateHash = $sha256.ComputeHash($bytesToHash)
        $encodeHash = [convert]::ToBase64String($calculateHash)
        $authorization = 'SharedKey {0}:{1}' -f $CustomerID, $encodeHash
        return $authorization
    }
    # Function to create and post the request
    Function PostLogAnalyticsData ($CustomerID, $SharedKey, $Body, $Type) {
        $method = "POST"
        $ContentType = 'application/json'
        $resource = '/api/logs'
        $rfc1123date = ($dateTime).ToString('r')
        $ContentLength = $Body.Length
        $signature = BuildSignature `
            -customerId $CustomerID `
            -sharedKey $SharedKey `
            -date $rfc1123date `
            -contentLength $ContentLength `
            -method $method `
            -contentType $ContentType `
            -resource $resource
        
		# Compatible with previous version
		if ([string]::IsNullOrEmpty($LAURI)){
			$LAURI = "https://" + $CustomerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
		}
		else
		{
			$LAURI = $LAURI + $resource + "?api-version=2016-04-01"
		}
		
        $headers = @{
            "Authorization"        = $signature;
            "Log-Type"             = $type;
            "x-ms-date"            = $rfc1123date
            "time-generated-field" = $dateTime
        }
        $response = Invoke-WebRequest -Uri $LAURI -Method $method -ContentType $ContentType -Headers $headers -Body $Body -UseBasicParsing
        Write-Verbose -message ('Post Function Return Code ' + $response.statuscode)
        return $response.statuscode
    }

    # Check if time is UTC, Convert to UTC if not.
    # $dateTime = (Get-Date)
    if ($dateTime.kind.tostring() -ne 'Utc') {
        $dateTime = $dateTime.ToUniversalTime()
        Write-Verbose -Message $dateTime
    }

    # Add DateTime to hashtable
    #$logdata.add("DateTime", $dateTime)
    $logdata | Add-Member -MemberType NoteProperty -Name "DateTime" -Value $dateTime

    #Build the JSON file
    $logMessage = ($logdata | ConvertTo-Json -Depth 20)
    Write-Verbose -Message $logMessage

    #Submit the data
    $returnCode = PostLogAnalyticsData -CustomerID $CustomerID -SharedKey $SharedKey -Body $logMessage -Type $type
    Write-Verbose -Message "Post Statement Return Code $returnCode"
    return $returnCode
}

function SendToLogA ($Data, $customLogName) {    
    #Test Size; Log A limit is 30MB
    $tempdata = @()
    $tempDataSize = 0
    
    if ((($Data |  Convertto-json -depth 20).Length) -gt 25MB) {        
		Write-Host "Upload is over 25MB, needs to be split"									 
        foreach ($record in $Data) {            
            $tempdata += $record
            $tempDataSize += ($record | ConvertTo-Json -depth 20).Length
            if ($tempDataSize -gt 25MB) {
                Write-OMSLogfile -dateTime (Get-Date) -type $customLogName -logdata $tempdata -CustomerID $workspaceId -SharedKey $workspaceKey
                write-Host "Sending data = $TempDataSize"
                $tempdata = $null
                $tempdata = @()
                $tempDataSize = 0
            }
        }
        Write-Host "Sending left over data = $Tempdatasize"
        Write-OMSLogfile -dateTime (Get-Date) -type $customLogName -logdata $tempdata -CustomerID $workspaceId -SharedKey $workspaceKey
    }
    Else {
        #Send to Log A as is        
        Write-OMSLogfile -dateTime (Get-Date) -type $customLogName -logdata $Data -CustomerID $workspaceId -SharedKey $workspaceKey
    }
}


# header for API calls
$headers = @{
    Authorization = "Token $MCASAPIToken"
    'Content-Type' = "application/json"
}

$EndEpoch = ([int64]((Get-Date -Date $StartTime) - (get-date "1/1/1970")).TotalMilliseconds)

#check for last run file
$storageAccountContext = New-AzStorageContext -ConnectionString $AzureWebJobsStorage
$checkBlob = Get-AzStorageBlob -Blob $fileName -Container $storageAccountContainer -Context $storageAccountContext
if($checkBlob -ne $null){
    #Blob found get data
    Get-AzStorageBlobContent -Blob $fileName -Container $storageAccountContainer -Context $storageAccountContext -Destination "$env:temp\$fileName" -Force
    $lastRunContext = Get-Content "$env:temp\$fileName" | ConvertFrom-Json
    $StartEpoch = $lastRunContext.lastRunEpoch
    $lastRunContext.lastRunEpoch = $EndEpoch
    $lastRunContext | ConvertTo-Json | out-file "$env:temp\$fileName"
}
else {
    #no blob create the context
    #$StartEpoch = ([int64]((Get-Date -Date $StartTime).AddMinutes(-$Lookback) - (get-date "1/1/1970")).TotalMilliseconds)
    $StartEpoch = ([int64]((Get-Date -Date $StartTime).AddDays(-$Lookback) - (get-date "1/1/1970")).TotalMilliseconds)
    $lastRunContent = @"
{
"lastRun": "$CurrentStartTime",
"lastRunEpoch": $EndEpoch
}
"@
    $lastRunContent | Out-File "$env:temp\$fileName"
    $lastRunContext = $lastRunContent | ConvertFrom-Json
}



#Build query
$body = @"
{
    "filters": {
        "date": {
        "range": {
            "end": $EndEpoch,
            "start": $StartEpoch
        }
        }
    },
    "isScan": true
}
"@

  

#Get the Activities
Write-Host "Starting to process Tenant: $MCASURL"
$uri = $MCASURL+"/api/v1/activities/"
$loopAgain = $true 
$totalRecords = 0
do {
    $results = $null
    $results = Invoke-RestMethod -Method Post -Uri $uri -Body $body -Headers $headers -ContentType "application/json" -UseBasicParsing
    try {
        $results = $results | ConvertFrom-Json
    }
    catch {
        Write-Verbose "One or more property name collisions were detected in the response. An attempt will be made to resolve this by renaming any offending properties."
        $results = $results.Replace('"Level":', '"Level_2":')
        $results = $results.Replace('"EventName":', '"EventName_2":')
        try {
            $results = $results | ConvertFrom-Json # Try the JSON conversion again, now that we hopefully fixed the property collisions
        }
        catch {
            throw $_
        }
        Write-Verbose "Any property name collisions appear to have been resolved."
    }
    if(($results.data).Count -ne 0){
        #write to log A to be added later 
        Write-Host "Got some results: "($results.data.Count)
        $totalRecords += ($results.data.Count)
        Write-Host $totalRecords
        #SendToLogA -Data ($results.data) -customLogName "MCASActivity"
    }
    else{
        Write-Host "No new logs"
    }
    $loopAgain = $results.hasNext
    
    if($loopAgain -ne $false){
        # if there is more data update the query
        $newBody = $body | ConvertFrom-Json
        If($newBody.filters.date.lte -eq $null){
            $newBody.filters.date | Add-Member -Name lte -Value ($results.nextQueryFilters.date.lte) -MemberType NoteProperty
        }
        else {
            $newBody.filters.date.lte = ($results.nextQueryFilters.date.lte)
        }
        $Body = $newBody | ConvertTo-Json -Depth 4
        Write-Host $body
    }
    else {
        # no more data write last run to az storage
        Set-AzStorageBlobContent -Blob $fileName -Container $storageAccountContainer -Context $storageAccountContext -File "$env:temp\$fileName" -Force
    }
} until ($loopAgain -eq $false)

#clear the temp folder
Remove-Item $env:temp\* -Recurse -Force -ErrorAction SilentlyContinue