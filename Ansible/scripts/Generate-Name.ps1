[CmdletBinding()]
param (
    [Parameter(Mandatory= $true)]
    [string]
    $resource,
    [Parameter(Mandatory= $true)]
    [string]
    $variableName,
    [Parameter(Mandatory= $true)]
    [string]
    $environment,
    [Parameter(Mandatory= $true)]
    [string]
    $product_name,
    [Parameter(Mandatory= $true)]
    [string]
    $project_name,
    [Parameter(Mandatory= $true)]
    [string]
    $region,
    [Parameter(Mandatory= $true)]
    [string]
    $spnID,
    [Parameter(Mandatory= $true)]
    [string]
    $spnSecret
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Function Get-Token {
  param( $connection,[string]$uri)
  $formData = @{
    client_id = $connection.client_id
    client_secret = $connection.client_secret
    scope = 'openid profile offline_access'
    grant_type = 'client_credentials'
    resource = $connection.resource_id
  }

  Write-Host "getting token"
  $azureAdToken = Invoke-RestMethod -Uri $uri -Method Post -Body $formData -ContentType "application/x-www-form-urlencoded"
  return $azureAdToken.access_token
}

Function Invoke-Request {
  param( [string]$token,[string]$requestUri, $body)
  $res = Invoke-RestMethod -Header @{'Authorization' = 'Bearer ' + $token;'Api-Version'='1.1'} -Uri $requestUri -Method 'POST' -ContentType 'application/json' -Verbose -Body ($body| ConvertTo-Json)
  return $res
}

Function generate-names {
    param( [string]$resource,[string]$environment,[string]$region,[string]$product_name,[string]$project_name)
    $request = ''
    $names = @()
    $checkUri = "https://meaningful.000ukso.sbp.eyclienthub.com/api/Meaning/Generated"
    $requestUri = "https://meaningful.000ukso.sbp.eyclienthub.com/api/Meaning"
    $body = @{
        ProductName= $product_name
        ProjectName= $project_name
        ResourceTypeName= $resource
        RoleName= ""
        EngagementName= ""
        RegionName= $region
        EnvironmentName = $environment
    }

    $request = Invoke-Request $token $requestUri -Body $body

    return $request.name
}

$connection = @{
    client_id = $spnID
    client_secret = $spnSecret
    tenant_id = "5b973f99-77df-4beb-b27d-aa0c70b8482c"
    resource_id = "b9f00528-2605-4c9a-b639-b5a69fdd7c9e"
}

$uri = 'https://login.microsoftonline.com/' + $connection.tenant_id + '/oauth2/token'
$token = Get-Token $connection $uri

Write-Output $resource

$output = generate-names $resource $environment $region $product_name $project_name

Write-Host ("##vso[task.setvariable variable=$variableName]$output")

return $output
