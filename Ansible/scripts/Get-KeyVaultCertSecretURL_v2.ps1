param(
[Parameter(Mandatory = $true)]
    [string]$VaultName,
[Parameter(Mandatory = $true)]
    [string]$CertName,
[Parameter(Mandatory = $true)]
    [string]$CertVariableName
)
Begin {
    Write-Output "Script initializing"
}
Process {

    $flag = 0
    $j = 0

    for(;;){
        $certs = az keyvault certificate list --vault-name $VaultName
        $cs=$certs | ConvertFrom-Json
        $len = $cs.length

        if ($len -ne 0){
            for ($i = 0; $i -lt $len; $i++){
                if($cs[$i].name -eq $CertName){
                    $flag = 1
                    $crts = az keyvault certificate show --vault-name $VaultName -n $CertName
                    $cs2=$crts | ConvertFrom-Json
                    $output=$cs2.sid
                    Write-Host ("##vso[task.setvariable variable=$CertVariableName;isOutput=true]$output")
                    Write-Output "The certificate $CertName was found"
                    Write-Output "The certificate $CertName has the ID: $output"
                }
            }
            if ($flag -eq 1){
                break;
            } else {
                $j++
                Write-Output "The certificate $CertName was not found, attempt $j $(Get-Date -Format hh:mm:ss)"
    	        Start-Sleep -s 300  
            }
        }else {
            $j++
            Write-Output "The certificate $CertName was not found, attempt $j $(Get-Date -Format hh:mm:ss)"
    	    Start-Sleep -s 300  
        }
    }

}
End {
    Write-Output "Script Finalized"
}
