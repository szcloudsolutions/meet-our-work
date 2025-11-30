param (
    [Parameter(Mandatory= $true)]
    [string]
    $requester_email,
    [Parameter(Mandatory= $true)]
    [string]
    $requester_dn,
    [Parameter(Mandatory= $true)]
    [string]
    $request_type,
    [Parameter(Mandatory= $true)]
    [string]
    $display_name,
    [Parameter(Mandatory= $true)]
    [string]
    $home_page,
    [Parameter(Mandatory= $true)]
    [string]
    $reply_page,
    [Parameter(Mandatory= $true)]
    [string]
    $permission,
    [Parameter(Mandatory= $true)]
    [string]
    $keyVault,
    [Parameter(Mandatory= $true)]
    [string]
    $resourceGroup,
    [Parameter(Mandatory= $true)]
    [string]
    $subscription_id,
    [Parameter(Mandatory= $true)]
    [string]
    $app_id,
    [Parameter(Mandatory= $true)]
    [string]
    $ansibleUser,
    [Parameter(Mandatory= $true)]
    [string]
    $ansibleSecret,
    [Parameter(Mandatory= $true)]
    [string]
    $app_environment,
    #[Parameter(Mandatory= $true)]
    #[string]
    #$ad_groups,
    [Parameter(Mandatory= $true)]
    [string]
    $update_key        
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
$templateNumber = 4418;
$bodyParameters = @{
    "extra_vars"= @{
        "var_request_type" = $request_type
        "var_display_name" = $display_name
        "var_naming_convention" = @{

                "var_country" = 'GBL'
                "var_service_line" = 'TAS'
                "var_appreg_type" = 'R'
                "var_application_type" = 'W'
                "var_release_version" = 'V1'
                "var_appreg_env" = $app_environment
            } 
        "var_home_page" = $home_page
        "var_reply_url" = $reply_page + ',http://localhost:3000,https://localhost:3000'
        "var_allow_token" = 'Yes'
        "var_update_key" = $update_key
        "var_permissions" = $permission.Trim()
        "var_keyvault_name" = $keyVault
        "var_resourcegroupe_name" = $resourceGroup
        "var_subscription_id" = $subscription_id
        "var_requester" = $requester_dn
        "var_requester_email" = $requester_email
        "var_appid" = $app_id.Trim()
        #"var_azure_ad_groups" = $ad_groups.Trim()

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
    Write-Host "Registration operation successful"
    exit 0
} else {
    Write-Host "Registration operation failed"
    exit 1
}
