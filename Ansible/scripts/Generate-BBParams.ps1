[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("Create", "Destroy")]
    [string]
    $action="Create",
    [Parameter(Mandatory=$false)]
    [object]
    $extravars=@{},
    [Parameter(Mandatory=$false)]
    [bool]
    $castInts=$true
)


# Auxiliar Functions
## Turns strings into their right base type (boolean, int, string)
function Fix-BaseType {
  param(
    [Parameter(Mandatory=$true)]
    [string]
    $inputString
  )

  if ($inputString.ToLower() -eq "true") {
    return $true;
  } elseif ($inputString.ToLower() -eq "false") {
    return $false;
  } elseif ($inputString -match "^\d+$" -And $castInts) {
    return [int]$inputString;
  }

  return $inputString;
}

## Turns an array's items into the right types (boolean, int, string, array, object)
function Fix-ArrayItems {
  param(
    [Parameter(Mandatory=$true)]
    [system.array]
    $inputArray
  )

  if ($inputArray.Length -eq 1 -And $inputArray[0] -is [string]) {
    if ($inputArray[0] -eq " ") {
      $inputArray = @();
    } else {
      $inputArray = $inputArray[0].Split(" ");
    }
  } elseif ($inputArray.Count -ge 1) {
    $outputArray = @();

    $inputArray | Foreach-Object {
      if ($_ -is [string]) {
        $_ = Fix-BaseType -inputString $_;
      } elseif ($_ -is [system.array]) {
        $_ = [array](Fix-ArrayItems -inputArray $_);

        if ($_ -eq $null) {
          $_ = @();
        }
      } elseif ($_.GetType().Name -eq "Hashtable" -Or $_.GetType().Name -eq "PSCustomObject") {
        $_ = Fix-ObjectProperties -inputObject $_ -outputObject @{};
      }

      $outputArray += $_;
    }

    return $outputArray;
  }

  return $inputArray;
}

## Turns an object's properties into the right types (boolean, int, string, array, object)
function Fix-ObjectProperties {
  param(
    [Parameter(Mandatory=$true)]
    [object]
    $inputObject,
    [Parameter(Mandatory=$true)]
    [object]
    $outputObject
  )

  $inputObject.PSObject.Properties | Foreach {
    $name = $_.Name;
    $value = $_.Value;

    if ($value -is [string]) {
      $value = Fix-BaseType -inputString $value;
    } elseif ($value -is [system.array]) {
      $value = [array](Fix-ArrayItems -inputArray $value);

      if ($value -eq $null) {
        $value = @();
      }
    } elseif ($value.GetType().Name -eq "Hashtable" -Or $value.GetType().Name -eq "PSCustomObject") {
      $value = Fix-ObjectProperties -inputObject $value -outputObject @{};
    }

    $outputObject[$name] = $value;
  }

  return $outputObject;
}


# Creates a PS1 Object with the base params
if ($action -eq "Create") {
    $vars = @{
        var_environment = '$(var_environment)'
        var_azure_rm_subid = '$(var_subscriptionId)'
        var_subscriptionId = '$(var_subscriptionId)'
        var_productApp = '$(var_productApp)'
        var_location = '$(var_location)'
        var_deploymentId = '$(var_deploymentId)'
        var_chargeCode = '$(var_chargeCode)'
        var_owner = '$(var_owner)'
        var_omsSubscriptionId = '$(var_omsSubscriptionId)'
        var_omsResourceGroup = '$(var_omsResourceGroup)'
        var_omsWorkspaceName = '$(var_omsWorkspaceName)'
    };
} else {
    $vars = @{
        var_azure_rm_subid = '$(var_subscriptionId)'
        var_subscriptionId = '$(var_subscriptionId)'
        var_location = '$(var_location)'
        var_resourceGroupName = '$(var_resourceGroupName)'
    };
}


# Add extravars to the previously created object
if ($extravars -ne @{}) {
    $vars = Fix-ObjectProperties -inputObject $extravars -outputObject $vars;
}


# Converts the params object to a compressed json, and stores it in a pipeline variable
$vars = $vars | ConvertTo-Json -Depth 5 -Compress;

Write-Host "##vso[task.setvariable variable=params]$vars";
