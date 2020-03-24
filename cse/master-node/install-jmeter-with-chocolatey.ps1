Param (
    [Parameter(Position=0)][string]$appInsightsJMeterListernerUrl = "https://github.com/adrianmo/jmeter-backend-azure/releases/download/0.2.1/jmeter.backendlistener.azure-0.2.1.jar"
)

try {
    # Install NuGet packace provider
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while installing NuGet package provider" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

# Set Log Directory and File path
$logDirectory = "C:\WindowsAzure\Logs"
$logFile = "$logDirectory\InstalllJMeter.log"

try {
    # Create Log Directory if not exists
    if (![System.IO.Directory]::Exists($logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory -Force
    }

    # Create log file if it does not exist
    if (!(Test-Path $logfile)) {
        New-Item $logfile -ItemType file
    }
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while creating the log folder or file" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

# Define Get-Timestamp function
Function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

# Trace parameters
Write-Output "$(Get-TimeStamp) appInsightsJMeterListernerUrl=[$appInsightsJMeterListernerUrl]" | Out-file $logFile -append

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Installing Chocolatey..." | Out-file $logFile -append

    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression

     # Log success
     Write-Output "$(Get-TimeStamp) Chocolatey has been successfully installed" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while installing Chocolatey" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Installing JMeter with Chocolatey..." | Out-file $logFile -append

    # Install JMeter with Chocolatey
    $command = "choco install jmeter --yes --force"
    Invoke-Expression $command
    $jmeterFolder = (Get-ItemProperty -Path ‘Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment’ -Name JMETER_HOME).JMETER_HOME

    # Log success
    Write-Output "$(Get-TimeStamp) JMeter has been successfully installed" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while installing JMeter" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Add settings JMeter properties file" | Out-file $logFile -append

    # Append settings to the jmeter properties file
    $content = @" 
# Parameter that controls the RMI port used by RemoteSampleListenerImpl (The Controller)
# Default value is 0 which means port is randomly assigned
# You may need to open Firewall port on the Controller machine
client.rmi.localport=4000

# Set this if you don't want to use SSL for RMI
server.rmi.ssl.disable=true
"@

    Add-Content -Path "$jmeterFolder\bin\jmeter.properties" $content

    # Log success
    Write-Output "$(Get-TimeStamp) Settings have been successfully added to JMeter properties file" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while adding settings to the JMeter properties file" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Download JMeter listener for Application Insights" | Out-file $logFile -append

    # Download Application Insights listener for JMeter
    $source = "$appInsightsJMeterListernerUrl"
    $destination = "$jmeterFolder\lib\ext\jmeter.backendlistener.azure-0.2.0.jar"
    $client = New-Object System.Net.WebClient
    $client.DownloadFile($source, $destination)

    # Log success
    Write-Output "$(Get-TimeStamp) JMeter listener for Application Insights has been successfully downloaded" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while downloading the JMeter listener for Application Insights" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Creating Windows Firewall Rules..." | Out-file $logFile -append

    # Create Firewall Inbound rule to  allow traffic to the Java RMI Port
    New-NetFirewallRule -DisplayName 'Allow Java RMI Port' -Profile 'Any' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1099
    
    # Create Firewall Inbound rule to  allow traffic to the JMeter Port range
    New-NetFirewallRule -DisplayName 'Allow JMeter Port Range' -Profile 'Any' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 4000-4002

    # Log Success
    Write-Output "$(Get-TimeStamp) Windows Firewall Rules have been successfully created" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while creating Windows Firewall Rules" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Disabling Internet Explorer Enhanced Security Configuration..." | Out-file $logFile -append
    function Disable-InternetExplorerESC {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
        Stop-Process -Name Explorer -Force
        Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
    }
    function Enable-InternetExplorerESC {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1 -Force
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1 -Force
        Stop-Process -Name Explorer
        Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
    }
    function Disable-UserAccessControl {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000 -Force
        Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green    
    }

    Disable-InternetExplorerESC

    # Log Success
    Write-Output "$(Get-TimeStamp) Internet Explorer Enhanced Security Configuration has been successfully disabled" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while disabling Internet Explorer Enhanced Security Configuration" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
}

try {
    # Log Start
    Write-Output "$(Get-TimeStamp) Installing Az PowerShell module..." | Out-file $logFile -append

    # Install Az PowerShell module
    Install-Module -Name Az -AllowClobber -Scope AllUsers -Force

    # Log Success
    Write-Output "$(Get-TimeStamp) Az PowerShell module has been successfully disabled" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while installing Az PowerShell module" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}