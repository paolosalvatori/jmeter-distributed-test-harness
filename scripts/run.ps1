Param (
    [Parameter(Position=0)][string]$jMeterTest,
    [Parameter(Position=1)][string]$keyVaultResourceGroupName = "IndigoHapiRG",
    [Parameter(Position=2)][string]$keyVaultName = "IndigoHapiKeyVault",
    [Parameter(Position=3)][string]$tenantName = "hennesandmauritz.onmicrosoft.com",
    [Parameter(Position=4)][string]$remote = "",
    [Parameter(Position=5)][ValidateRange(1, [int]::MaxValue)][int]$numThreads = 20,
    [Parameter(Position=6)][ValidateRange(1, [int]::MaxValue)][int]$duration = 600,
    [Parameter(Position=7)][ValidateRange(1, [int]::MaxValue)][int]$warmupTime = 30,
    [Parameter(Position=8)][bool]$useAuthentication = $false,
    [Parameter(Position=9)][bool]$logParameters = $true
)

if ($logParameters -eq $true)
{
    $line = [System.String]::new("-", 80)
    Write-Host $line
    Write-Host "Parameters"
    Write-Host $line
    Write-Host 'jMeterTest:' $jMeterTest
    Write-Host 'keyVaultResourceGroupName:' $keyVaultResourceGroupName
    Write-Host 'keyVaultName:' $keyVaultName
    Write-Host 'tenantName:' $tenantName
    Write-Host 'remote:' $remote
    Write-Host 'useAuthentication:' $useAuthentication
    Write-Host 'numThreads:' $numThreads
    Write-Host 'warmupTime:' $warmupTime
    Write-Host 'duration:' $duration
    Write-Host $line
}


#
# parameters validation
#
if ([System.String]::IsNullOrWhiteSpace($jMeterTest)) {
    Write-Host "ERROR: the -TestFileAndPath parameter cannot be null."
    exit -10
}
if (![System.String]::IsNullOrWhiteSpace($remote)) {
    $prefix = "-" + $remote -replace "\.", ""
} 
else {
    $prefix = "-127001"
}

[System.IO.Directory]::SetCurrentDirectory((Get-Location).ToString())
$testFileFullPath = [System.IO.Path]::GetFullPath($jMeterTest)

if (![System.IO.File]::Exists($testFileFullPath)) {
    Write-Host "ERROR:" $jMeterTest "file does not exists."
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
$rootFolderName = [System.IO.Path]::Combine($currentPath, "test-runs")

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
if($useAuthentication) {
    # Get the ClientID, ClientSecret and ResourceURI from Azure Key Vault
    $clientId = Get-AzKeyVaultSecret -vaultName "$keyVaultName" -SecretName "$jmeterClientIdSecretName" -ErrorAction Stop
    $clientSecret = Get-AzKeyVaultSecret -vaultName "$keyVaultName" -SecretName "$jmeterClientSecretSecretName" -ErrorAction Stop
    $resourceUri = Get-AzKeyVaultSecret -vaultName "$keyVaultName" -SecretName "$jmeterResourceUriSecretName" -ErrorAction Stop

    if( !($clientId) -or !($clientSecret) -or !($resourceUri)) {
        Write-Host "ERROR: Missing secrets in" $keyVaultName "Azure Key Vault. Secrets $jmeterClientIdSecretName, $jmeterClientSecretSecretName and $jmeterResourceUriSecretName are required!"
        exit -10
    }
}

# Define the common part of the JMeter command
$jMeterFolder = (Get-ChildItem Env:JMETER_HOME).Value
$jMeterPath = "$jMeterFolder\bin\jmeter"
$parameters = @("-n", "-t", "`"$jMeterTest`"", "-l", "`"$testRunResultsFolderName\resultfile.jtl`"", "-e", "-o", "`"$testRunOutputFolderName`"", "-j", "`"$testRunLogsFolderName\jmeter.jtl`"", "-Jmode=Standard")

if (![System.String]::IsNullOrWhiteSpace($remote)) {
    # Set general parameters
    $parameters += "-Gnum_threads=$($numThreads)" 
    $parameters += "-Gramp_time=$($warmupTime)"
    $parameters += "-Gduration=$($duration)"
    
    # Define additional part of JMeter command when running the test remotely on slave nodes
    $ip = Invoke-RestMethod -Uri 'https://api.ipify.org'
    $parameters += "-Djava.rmi.server.hostname=$ip"
    $parameters += "-R"
    $parameters += "`"$remote`""

    if ($useAuthentication) {
        # Use authenication credentials from Key Vault
        $parameters += "-Gtenant_name=`"$($tenantName)`""
        $parameters += "-Gclient_id=`"$($clientId.SecretValueText)`""
        $parameters += "-Gclient_secret=`"$($clientSecret.SecretValueText)`""
        $parameters += "-Gresource_uri=`"$($resourceUri.SecretValueText)`""
    } 
} else {
    # Set general parameters
    $parameters += "-Jnum_threads=$($numThreads)" 
    $parameters += "-Jramp_time=$($warmupTime)"
    $parameters += "-Jduration=$($duration)"

    if ($useAuthentication) {
        # Use authenication credentials from Key Vault
        $parameters += "-Jtenant_name=`"$($tenantName)`""
        $parameters += "-Jclient_id=`"$($clientId.SecretValueText)`""
        $parameters += "-Jclient_secret=`"$($clientSecret.SecretValueText)`""
        $parameters += "-Jresource_uri=`"$($resourceUri.SecretValueText)`""
    } 
}

#Write-Host $jmeter $parameters
& $jMeterPath $parameters