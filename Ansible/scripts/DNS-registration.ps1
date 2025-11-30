[CmdletBinding()]
param (
    [Parameter(Mandatory= $true)]
    [string]
    $dnsfqdn,
    [Parameter(Mandatory= $true)]
    [string]
    $AppGWpublicIP,
    [Parameter(Mandatory= $true)]
    [string]
    $deploymentId,
    [Parameter(Mandatory= $true)]
    [string]
    $dnsAction,
    [Parameter(Mandatory= $true)]
    [string]
    $dnsType,
    [Parameter(Mandatory= $true)]
    [string]
    $owner,
    [Parameter(Mandatory= $true)]
    [string]
    $ansibleUser,
    [Parameter(Mandatory= $true)]
    [string]
    $ansibleSecret
)

$uname = $ansibleUser
$passwd = $ansibleSecret
$TowerApiUrl = 'https://tower.000ukso.sbp.eyclienthub.com/api/v2'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$credPair = "$($uname):$($passwd)"
$Authorization = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($credPair))
$MeUri = $TowerApiUrl + '/me/'
$MeResult = Invoke-RestMethod -Uri $MeUri -Headers @{ "Authorization" = "Basic $Authorization" ; "Content-Type" = 'application/json'} -ErrorAction Stop

## Obtain Token
$PATUri = $TowerApiUrl + '/users/' + $($MeResult.Results.id) + '/personal_tokens/'
$Tokens = Invoke-RestMethod -Uri $PATUri -Method POST -Headers @{ "Authorization" = "Basic $Authorization" ; "Content-Type" = 'application/json'} -ContentType "application/json"
$Tokens

## Run job
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$tokenId = $Tokens.id
$headers.Add("Authorization", "Bearer " + $Tokens.token);

## Launch Template
$templateNumber = 4068;
$bodyParameters = @{
    extra_vars= @{
        var_action= $dnsAction;
        var_fqdn= $dnsfqdn;
        var_owner= $owner;
        var_owner_group= "IT-SAT-DevOps_MSP01-Team";
        var_record_type= $dnsType;
        var_value= $AppGWpublicIP;
        var_view= "both";
        var_deployment_id= $deploymentId
    }
};

$body = ($bodyParameters | convertTo-Json)
$body
$urlTemplate = $TowerApiUrl + "/workflow_job_templates/$templateNumber/launch/";
$ansibleResponse = Invoke-RestMethod -Uri $urlTemplate -Method Post -Body $body -Headers $headers

#Check job status
do {
    $urlTemplate = $TowerApiUrl + "/workflow_jobs/$($ansibleResponse.id)/";
    $ansibleResponse = Invoke-RestMethod -Uri $urlTemplate -Method Get -Headers $headers
    $ansibleResponse.status
    Start-Sleep -Seconds 10
} until($ansibleResponse.status -eq 'successful' -OR $ansibleResponse.status -eq 'failed')

if($ansibleResponse.status -eq 'successful') {
    Write-Host "Registration successful"
    exit 0
} else {
    Write-Host "Registration failed"
    exit 1
}
