Param (
    [Parameter(Position=0)][string]$JMeterTest,
    [Parameter(Position=1)][string]$KeyVaultResourceGroupName = "key-vault-resource-group",
    [Parameter(Position=2)][string]$KeyVaultName = "key-vault-name",
    [Parameter(Position=3)][string]$TenantName = "your-tenant.onmicrosoft.com",
    [Parameter(Position=4)][string]$Remote = "",
    [Parameter(Position=5)][ValidateRange(1, [int]::MaxValue)][int]$NumThreads = 20,
    [Parameter(Position=6)][ValidateRange(1, [int]::MaxValue)][int]$Duration = 600,
    [Parameter(Position=7)][ValidateRange(1, [int]::MaxValue)][int]$WarmupTime = 30,
    [Parameter(Position=8)][ValidateSet("Standard", `
                                        "Hold", `
                                        "DiskStore", `
                                        "StrippedDiskStore", `
                                        "Batch", "Statistical", `
                                        "Stripped", `
                                        "StrippedBatch", `
                                        "Asynch", `
                                        "StrippedAsynch")][string]$Mode = "Standard",
    [Parameter(Position=9)][bool]$UseAuthentication = $false,
    [Parameter(Position=10)][bool]$LogParameters = $true
)

if ($LogParameters -eq $true)
{
    $line = [System.String]::new("-", 80)
    Write-Host $line
    Write-Host "Parameters"
    Write-Host $line
    Write-Host 'JMeterTest:' $JMeterTest
    Write-Host 'KeyVaultResourceGroupName:' $KeyVaultResourceGroupName
    Write-Host 'KeyVaultName:' $KeyVaultName
    Write-Host 'TenantName:' $TenantName
    Write-Host 'Remote:' $Remote
    Write-Host 'NumThreads:' $NumThreads
    Write-Host 'WarmupTime:' $WarmupTime
    Write-Host 'Duration:' $Duration
    Write-Host 'Mode:' $Mode
    Write-Host 'UseAuthentication:' $UseAuthentication
    Write-Host $line
}


#
# parameters validation
#
if ([System.String]::IsNullOrWhiteSpace($JMeterTest)) {
    Write-Host "ERROR: the -TestFileAndPath parameter cannot be null."
    exit -10
}
if (![System.String]::IsNullOrWhiteSpace($Remote)) {
    $prefix = "_" + $Remote -replace "\.", ""
    $prefix = $prefix -replace ",", ""
    $prefix = $prefix -replace " ", "_"
} 
else {
    $prefix = "_local"
}

[System.IO.Directory]::SetCurrentDirectory((Get-Location).ToString())
$testFileFullPath = [System.IO.Path]::GetFullPath($JMeterTest)

if (![System.IO.File]::Exists($testFileFullPath)) {
    Write-Host "ERROR:" $JMeterTest "file does not exists."
    exit -10
}

$testName = [System.IO.Path]::GetFileNameWithoutExtension($testFileFullPath)

$folderName = $testName + $prefix

#
# A few variables
#
$jmeterClientIdSecretName="JMeterTestDriverClientId"
$jmeterClientSecretSecretName="JMeterTestDriverClientSecret"
$jmeterResourceUriSecretName="JMeterTestDriverResourceUri"

#
# Create the test_runs folder
#
$currentPath = (Get-Location).ToString()
$rootFolderName = [System.IO.Path]::Combine($currentPath, "test_runs")

if (![System.IO.Directory]::Exists($rootFolderName)) {
    New-Item -Path $rootFolderName -ItemType Directory
}

$folderName = $testName+$prefix

$testFolderName = [System.IO.Path]::Combine($rootFolderName, $folderName)
if (![System.IO.Directory]::Exists($testFolderName)) {
    New-Item -Path $testFolderName -ItemType Directory
}

$testRunFolderName = [System.IO.Path]::Combine($testFolderName, "test_" + (Get-Date -Format "yyyyMMdd_hhmmss").ToString())
$testRunOutputFolderName = [System.IO.Path]::Combine($testRunFolderName, "output")
$testRunLogsFolderName = [System.IO.Path]::Combine($testRunFolderName, "logs")
$testRunResultsFolderName = [System.IO.Path]::Combine($testRunFolderName, "results")

if (![System.IO.Directory]::Exists($testRunFolderName)) {
    New-Item -Path $testRunFolderName -ItemType Directory
    New-Item -Path $testRunOutputFolderName -ItemType Directory
    New-Item -Path $testRunLogsFolderName -ItemType Directory
    New-Item -Path $testRunResultsFolderName -ItemType Directory
}

#
# If Authentication is used, read the secrets from KV
#
if($UseAuthentication) {
    # Get the ClientID, ClientSecret and ResourceURI from Azure Key Vault
    $clientId = Get-AzKeyVaultSecret -vaultName "$KeyVaultName" -SecretName "$jmeterClientIdSecretName" -ErrorAction Stop
    $clientSecret = Get-AzKeyVaultSecret -vaultName "$KeyVaultName" -SecretName "$jmeterClientSecretSecretName" -ErrorAction Stop
    $resourceUri = Get-AzKeyVaultSecret -vaultName "$KeyVaultName" -SecretName "$jmeterResourceUriSecretName" -ErrorAction Stop

    if( !($clientId) -or !($clientSecret) -or !($resourceUri)) {
        Write-Host "ERROR: Missing secrets in" $KeyVaultName "Azure Key Vault. Secrets $jmeterClientIdSecretName, $jmeterClientSecretSecretName and $jmeterResourceUriSecretName are required!"
        exit -10
    }
}

# Define the common part of the JMeter command
$jMeterFolder = (Get-ChildItem Env:JMETER_HOME).Value
$jMeterPath = "$jMeterFolder\bin\jmeter"
$parameters = @("-n", "-t", "`"$JMeterTest`"", "-l", "`"$testRunResultsFolderName\resultfile.jtl`"", "-e", "-o", "`"$testRunOutputFolderName`"", "-j", "`"$testRunLogsFolderName\jmeter.jtl`"", "-Jmode=$Mode")

if (![System.String]::IsNullOrWhiteSpace($Remote)) {
    # Set general parameters
    $parameters += "-Gnum_threads=$($NumThreads)" 
    $parameters += "-Gramp_time=$($WarmupTime)"
    $parameters += "-Gduration=$($Duration)"
    
    # Define additional part of JMeter command when running the test remotely on slave nodes
    $ip = Invoke-RestMethod -Uri 'https://api.ipify.org'
    $parameters += "-Djava.rmi.server.hostname=$ip"
    $parameters += "-R"
    $parameters += "`"$Remote`""

    if ($UseAuthentication) {
        # Use authenication credentials from Key Vault
        $parameters += "-Gtenant_name=`"$($TenantName)`""
        $parameters += "-Gclient_id=`"$($clientId.SecretValueText)`""
        $parameters += "-Gclient_secret=`"$($clientSecret.SecretValueText)`""
        $parameters += "-Gresource_uri=`"$($resourceUri.SecretValueText)`""
    } 
} else {
    # Set general parameters
    $parameters += "-Jnum_threads=$($NumThreads)" 
    $parameters += "-Jramp_time=$($WarmupTime)"
    $parameters += "-Jduration=$($Duration)"

    if ($UseAuthentication) {
        # Use authenication credentials from Key Vault
        $parameters += "-Jtenant_name=`"$($TenantName)`""
        $parameters += "-Jclient_id=`"$($clientId.SecretValueText)`""
        $parameters += "-Jclient_secret=`"$($clientSecret.SecretValueText)`""
        $parameters += "-Jresource_uri=`"$($resourceUri.SecretValueText)`""
    } 
}

#Write-Host $jmeter $parameters
& $jMeterPath $parameters