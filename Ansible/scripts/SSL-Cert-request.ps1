[CmdletBinding()]
param (
    [Parameter(Mandatory= $true)]
    [string]
    $sslfqdn,
    [Parameter(Mandatory= $true)]
    [string]
    $keyvault,
    [Parameter(Mandatory= $true)]
    [string]
    $deploymentId,
    [Parameter(Mandatory= $true)]
    [string]
    $var_domainName,
    [Parameter(Mandatory= $true)]
    [string]
    $sslAction,
    [Parameter(Mandatory= $true)]
    [string]
    $certificate_owner,
    [Parameter(Mandatory= $true)]
    [string]
    $environment,
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

## Launch Template with extra vars
$templateNumber = 3494;
$bodyParameters = @{
    "extra_vars"= @{
        "var_request_type" = $sslAction
        "var_provisioning_model" = 'Full'
        "var_certificate_authority" = 1
        "var_certificate_name" = $sslfqdn
        "var_certificate_owner" = $certificate_owner
        "var_application_contact" = $certificate_owner
        "var_deployment_id" = $deploymentId
        "var_domain_name" = $var_domainName # default: 'sbp.eyclienthub.com'
        "var_project_chargecode" = '65866968'
        "var_smu_chargecode" = '65866968'
        "var_device_input" = @(
            @{
            "PlatformType" = 'AzureKeyVault'
              "DeviceName" = $keyvault
              "ApplicationInput" = @(
                @{
                "TenantName" = 'eygs.onmicrosoft.com'
                  "PasswordRequired" = 1
                }
              )
            }
          )
        }
};

# Launch job

$body = ($bodyParameters | convertTo-Json -Depth 8)
$body
$urlTemplate = $TowerApiUrl + "/job_templates/$templateNumber/launch/";
$ansibleResponse = Invoke-RestMethod -Uri $urlTemplate -Method Post -Body $body -Headers $headers
$ansibleResponse.status

#Loop to check for job to complete

do {
    $urlTemplate = $TowerApiUrl + "/jobs/$($ansibleResponse.id)/";
    $ansibleResponse = Invoke-RestMethod -Uri $urlTemplate -Method Get -Headers $headers
    $ansibleResponse.status
    Start-Sleep -Seconds 10
} until($ansibleResponse.status -eq 'successful' -OR $ansibleResponse.status -eq 'failed')

if($ansibleResponse.status -eq 'successful') {
    Write-Host "SSl operation successful"
    exit 0
} else {
    Write-Host "SSL operation failed"
    exit 1
}


## Optional simple request for "Status" and "Revoke" for reference

# # Body request for checking Status
# $extraVars = @{
#     "extra_vars"=  @{
#             "var_certificate_name"= $sslfqdn
#             "var_request_type"= "status"
#     }
# }

# # Body request for certificate revocation
# $extraVars = @{
#     "extra_vars"=  @{
#             "var_certificate_name"= $sslfqdn
#             "var_request_type"= "revoke"
#     }
# }
