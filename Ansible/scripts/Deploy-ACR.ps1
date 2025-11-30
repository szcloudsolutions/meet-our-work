[CmdletBinding()]
param (
    [Parameter(Mandatory= $true)]
    [string]
    $environment,
    [Parameter(Mandatory= $true)]
    [string]
    $resourceGroupName,
    [Parameter(Mandatory= $true)]
    [string]
    $location,
    [Parameter(Mandatory= $true)]
    [string]
    $templateId,
    [Parameter(Mandatory= $true)]
    [string]
    $owner,
    [Parameter(Mandatory= $true)]
    [string]
    $ansibleUser,
    [Parameter(Mandatory= $true)]
    [string]
    $ansibleSecret,
    [Parameter(Mandatory= $true)]
    [string]
    $acrName
)

#generate token
$uname = $ansibleUser
$passwd = $ansibleSecret
$TowerApiUrl = 'https://tower.000ukso.sbp.eyclienthub.com/api/v2'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Authorization = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$uname`:$passwd"))

$MeUri = $TowerApiUrl + '/me/'
$MeResult = Invoke-RestMethod -Uri $MeUri -Headers @{ "Authorization" = "Basic $Authorization" ; "Content-Type" = 'application/json'} -ErrorAction Stop

### Logging in to Tower...
$PATUri = $TowerApiUrl + '/users/' + $($MeResult.Results.id) + '/personal_tokens/'
$Tokens = Invoke-RestMethod -Uri $PATUri -Method POST -Headers @{ "Authorization" = "Basic $Authorization" ; "Content-Type" = 'application/json'} -ContentType "application/json"


#run job
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$tokenId = $Tokens.id
$headers.Add("Authorization", "Bearer " + $Tokens.token);

$templateNumber = $templateId;
$bodyParameters  = @{
    extra_vars= @{
        var_location=  "$location" ;
        var_RSG= $resourceGroupName ;
        var_environment= $environment ;
        var_devopsOwner= "$owner";
        var_deployKeyVault = "NO" ;
        var_deployStorageAccount = "NO" ;
        var_deploySQLServer = "NO" ;
        var_deploySQLElasticPool = "NO" ;
        var_deploycosmosdb = "NO" ;
        var_deployAppGW = "NO" ;
        var_deployAppService = "NO" ;
        var_deployWebApp = "NO" ;
        var_deployRedisCache = "NO" ;
        var_appInsights = "NO" ;
        var_deployMaps = "NO" ;
        var_deployACR = "YES" ;
        var_acrName = "$acrName" ;
    }
};

$body = ($bodyParameters | convertTo-Json)
$body
$urlTemplate = $TowerApiUrl + "/job_templates/$templateNumber/launch/";
$ansibleResponse = Invoke-RestMethod -Uri $urlTemplate -Method Post -Body $body -Headers $headers

#Check job status
do {
    $urlTemplate = $TowerApiUrl + "/jobs/$($ansibleResponse.id)/";
    $ansibleResponse = Invoke-RestMethod -Uri $urlTemplate -Method Get -Headers $headers
    $ansibleResponse.status
    Start-Sleep -Seconds 10
} until($ansibleResponse.status -eq 'successful' -OR $ansibleResponse.status -eq 'failed')

if($ansibleResponse.status -eq 'successful') {
    Write-Host "Deployment successful"
    exit 0
} else {
    Write-Host "Deployment failed"
    exit 1
}
