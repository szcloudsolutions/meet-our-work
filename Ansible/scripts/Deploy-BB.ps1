[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $user,
    [Parameter(Mandatory=$true)]
    [string]
    $secret,
    [Parameter(Mandatory=$true)]
    [string]
    $templateId,
    [Parameter(Mandatory=$true)]
    [string]
    $vars,
    [Parameter(Mandatory=$true)]
    [array]
    $credentials,
    [Parameter(Mandatory=$true)]
    [string]
    $bbName
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

function Get-Token {
    param(
        $user,
        $secret,
        $towerApiUrl
    )

    # Generate Token
    $authorization = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$user`:$secret"));

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]";
    $headers.Add("Content-Type", "application/json");
    $headers.Add("Authorization", "Basic $($authorization)");

    $uri = "$($towerApiUrl)/me/";
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop;

    # Log into Tower
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]";
    $headers.Add("Content-Type", "application/json");
    $headers.Add("Authorization", "Basic $($authorization)");

    $uri = "$($towerApiUrl)/users/$($response.Results.id)/personal_tokens/";
    $response = Invoke-RestMethod -Uri $uri -Method "POST" -Headers $headers -ContentType "application/json";

    return $response.token;
}

function Launch-Job {
    param(
        $token,
        $vars,
        $credentials,
        $towerApiUrl,
        $templateId
    )

    # Run Job
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]";
    $headers.Add("Content-Type", "application/json");
    $headers.Add("Authorization", "Bearer " + $token);

    $body = '{ "extra_vars":' + $vars + ', "credentials":' + $credentials + '}';
    $body;

    $uri = "$($towerApiUrl)/job_templates/$($templateId)/launch/";
    $response = Invoke-RestMethod -Uri $uri -Method "POST" -Body $body -Headers $headers;

    Write-Host "Ansible Tower Job Id: $($response.id)";
    Write-Host "Ansible Tower Job URL: $towerBaseUrl/#/jobs/playbook/$($response.id)";

    $jobId = $($response.id);

    Check-Status -token $token -towerApiUrl $towerApiUrl -jobId $jobId;
}

function Get-ResourceData {
    param(
        $token,
        $JobId,
        $BBName
    )

    $TemplateUrl = "$towerApiUrl/jobs/$JobId/stdout/?format=txt"

    $output = Invoke-RestMethod -Method Get -Uri "$TemplateUrl" -UseBasicParsing -ContentType "application/json" -Headers $Headers

    [regex]$regex = '{0}:\\\\"/(\w+)/[a-z0-9.-]*/[a-zA-Z0-9!@#$&()\\-`.+,/\"]*' -f $BBName
    [regex]$regextsv = '{0}:/(\w+)/[a-z0-9.-]*/[a-zA-Z0-9!@#$&()\\-`.+,/\"]*' -f $BBName

    $regexResponse = $regex.Matches($output) | Select-Object -First 1 | ForEach-Object { $_.value }

    $regexName = [regex] '(\/(\w+\\))'
    $regexId = [regex] '\\(.*)\\'
    if ($null -eq $regexResponse) {
        $regexResponse = $regextsv.Matches($output) | Select-Object -First 1 | ForEach-Object { $_.value }
        $regexName = [regex] '(\/(\w+[.*]*)*")'
        $regexId = [regex] '/(.*)"'
    }
    $meaningAllNames = New-Object PSObject

    if (![string]::IsNullOrWhiteSpace($regexResponse)) {
        try {
            $name = $regexName.Match($regexResponse) | Select-Object -First 1 | ForEach-Object { $_.value }
            $id = $regexId.Match($regexResponse) | Select-Object -First 1 | ForEach-Object { $_.value }

            Write-host "Process the Name of the Resource"
            $meaningAllNames | Add-Member -MemberType NoteProperty -Name "Name" -Value $name.Replace("/", "").Replace("\", "").Replace("""", "")

            Write-host "Processing the Resource ID"
            $meaningAllNames | Add-Member -MemberType NoteProperty -Name "ID" -Value $id.Replace("\", "").Replace("""", "")
        }
        catch {
            $ErrorMessage = $_.Exception.message
            Write-host "Error while processing the Resource details. Error: $ErrorMessage"
        }

    }

    return $meaningAllNames
}

# Check Job
function Check-Status {
    param(
        $token,
        $towerApiUrl,
        $jobId
    )

    do {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]";
        $headers.Add("Content-Type", "application/json");
        $headers.Add("Authorization", "Bearer " + $token);

        $uri = "$($towerApiUrl)/jobs/$jobId/";
        $response = Invoke-RestMethod -Uri $uri -Method "GET" -Headers $headers;

        $response.status;

        Start-Sleep -Seconds 15;
    } until($response.status -eq "successful" -OR $response.status -eq "failed");

    if ($response.status -eq "successful") {
        # Fetch resource details
        $resourceResponse = Get-ResourceData -JobID $($jobId) -BBName $bbName
        $resourceName = $resourceResponse.Name
        $resourceID = $resourceResponse.ID

        Write-Output ("##vso[task.setvariable variable=name;isOutput=true]$resourceName")
        Write-Output ("##vso[task.setvariable variable=id;isOutput=true]$resourceID")

        Write-Host "Resource Name: $resourceName"
        Write-Host "Resource ID: $resourceID"

        exit 0;
    } else {
        Write-Host "Deployment failed"
        exit 1;
    }
}

## CHANGE THIS ONCE WE HAVE THE EVNTVGLOBAL SUBSCRIPTION:
##$towerBaseUrl = "https://ansible.fabricmgmt.com";
$towerBaseUrl = "https://tower.000ukso.sbp.eyclienthub.com";
$towerApiUrl = "$towerBaseUrl/api/v2";

$token = Get-Token -user $user -secret $secret -towerApiUrl $towerApiUrl;

Launch-Job -token $token -vars $vars -credentials $credentials -towerApiUrl $towerApiUrl -templateId $templateId;
