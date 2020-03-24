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
$logFile = "$logDirectory\InstallJMeter.log"

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
server.rmi.localport=4000

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
    # Create Public IP
    $retryCount = 0
    $retryInterval = 3
    $maxRetryCount = 5
    $success = $false

    do {
        try {
            $ip = Invoke-RestMethod -Uri 'https://api.ipify.org'
            Write-Output "$(Get-TimeStamp) Public IP address is: $ip" | Out-file $logFile -append
            $success = $true
        }
        catch {
            Write-Output "Next attempt in 5 seconds"
            Start-sleep -Seconds $retryInterval
        }
        
        $retryCount++
        
    } until ($retryCount -eq $maxRetryCount -or $success)

    if (-not($success)) {
        exit
    }
    
    # Create Script File
    $content = @" 
cd $jmeterFolder\bin
jmeter-server -Dclient.rmi.localport=4000 -Djava.rmi.server.hostname=$ip 
"@
    New-Item -Path C:\Scripts -ItemType Directory -Force
    New-Item -Path C:\Scripts\JMeterServer.bat -ItemType File -Force
    Set-Content C:\Scripts\JMeterServer.bat $content
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while creating the JmeterServer.bat file" | Out-file $logFile -append
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
    Write-Output "$(Get-TimeStamp) Configuring a task to start the JMeter server at each reboot" | Out-file $logFile -append

    # Define a task trigger to run the task at startup
    $Trigger1= New-ScheduledTaskTrigger -AtStartup

    # Deine another trigger to run the task in 30 seconds
    $Time = (Get-Date).AddMinutes(1)
    $Trigger2= New-ScheduledTaskTrigger -Once -At ($Time.TimeOfDay.ToString("hh\:mm"))


    # Define the user account running the task
    $User= "NT AUTHORITY\SYSTEM" 

    # Specify what program to run and with its parameters
    $Action= New-ScheduledTaskAction -Execute "C:\Scripts\JMeterServer.bat" 

    # Register the task
    Register-ScheduledTask -TaskName "RunJMeterServer" -Trigger $Trigger1, $Trigger2 -User $User -Action $Action -RunLevel Highest –Force 

    # Log success
    Write-Output "$(Get-TimeStamp) The task has been successfully created" | Out-file $logFile -append
}
catch {
    # Log error
    Write-Output "$(Get-TimeStamp) An error occurred while setting the task" | Out-file $logFile -append
    $ErrorMessage = $_.Exception.Message
    Write-Output "$ErrorMessage" | Out-file $logFile -append
    throw $_.Exception
}