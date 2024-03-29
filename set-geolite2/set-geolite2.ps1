<#
.SYNOPSIS
    The goal of this script is to copy the GeoLite2 database files from a central repository to all NetScalers and then update the database location
.DESCRIPTION
    Automation of updating NetScaler Geo Location's databases with MaxMind Geo Lite 2 databases.

    Running this script should be done through the GitHub workflow - set-geolite2. 

    How to use the script if running Locally.
    Due to the fact that it needs to be run locally in a Privelege desktop there are some path dependencies built in to the script. 
    It is intended to be run from GitHub however you can run this locally

    .POWERSHELL REQUIREMENTS
    Powershell Module - POSH-SSH (https://github.com/darkoperator/Posh-SSH)

    - Have a working directory structure as follows
    1. \set-geolite2 # Running directory of the script - need to be in this directory when running the script. # Fix path so this isn't necessary somehow
    2. \data # Used to locate the netscaler IP csv files
    3. \data\maxmind_geoip # Location of gz files for database to copy to NetScalers

    Running the script:
    - Define a $Credential variable first by either running $Credential = Get-Credentail and then providing the information or already having one set to be passed to the script
    - You should update the netscaler.csv file you intend to run this against.
    - You should have updated 'Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz' and 'Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz' files in the \data\maxmind_geoip directory
    - Be sure that you start in the root directory, \set-geolite2\ when you run the script execution command:
      - .\set-geolite2.ps1 -Credential $credential
      

.NOTES
    This assumes that the MaxMind Geo Lite 2 database has been converted to the NetScaler format.
    If we use the .gz (Zipped) file we can put this in GitHub and therefore run a workflow that will update all the NetScalers.
    Version 1.0
    Author: Kevin Marino
    Date (Last Updated): 3/25/2024
    Update Notes:
        - 3/25/2024 
          - Added to netscaler-geolite2 GitHub repo for inital deployment and use
          - Added parameter of $Credential to the script so that username/password can be passed as GitHub secrets
          - If you use On-Prem GitHub Runners you need to have SSH or SFTP port 22 access to your NetScaler infrastructure - This script will not work via GitHub actions if you do not.
            - Instead copy the script locally and run from a system with access to your NetScaler infrastructure.
        - 3/27/2024
          - Fixed Firewall permissions for Local GitHub Runners. Updated workflow so that this works in GitHub now to run. No need to run locally anymore if your infrastructure configuration and firewall rules support it.
.LINK
    
.EXAMPLE
    From the root folder run .\set-geolite2.ps1 -credential $Credential
    - Be sure to have your credentials defined with permissions to your NetScaler infrastructure
#>

param(
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty # Credentials can be passed to the script as a parameter
)

###############
## Variables ##
###############
#$NetScalers = Get-Content '..\data\sandbox-snips.csv' # Gets a list of NetScalers # USE THIS LINE IF RUNNING LOCALLY IN POWERSHELL
#$FilePath = '..\data\maxmind_geoip\' # Set File Path to Geo Lite 2 Database # USE THIS LINE IF RUNNING LOCALLY IN POWERSHELL
$NetScalers = Get-Content '.\data\netscaler.csv' # Gets a list of NetScalers # USE THIS LINE IF RUNNING VIA GITHUB WORKFLOW
$FilePath = '.\data\maxmind_geoip\' # Set File Path to Geo Lite 2 Database # USE THIS LINE IF RUNNING VIA GITHUB WORKFLOW
$gzipv4 = 'Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz' # Sets the File Name for the .gz that will be copied and later gunzip'd
$gzipv6 = 'Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz' # Sets the File Name for the .gz that will be copied and later gunzip'd
$netscalerpath = '/var/netscaler/inbuilt_db/' # Sets the NetScaler Geo Location Database Directory path - Where we will copy the file to and then gunzip it.
$addlocationipv4 = "add locationFile /var/netscaler/inbuilt_db/Netscaler_Maxmind_GeoIP_DB_IPv4.csv -format netscaler"
$addlocationipv6 = "add locationFile6 /var/netscaler/inbuilt_db/Netscaler_Maxmind_GeoIP_DB_IPv6.csv -format netscaler6"

###############
## Functions ##
###############
function send-sftpfile {
    param (
        [string]$Server,
        [string]$LocalFilePath,
        [string]$RemoteFilePath,
        [string]$Filename,
        [System.Management.Automation.PSCredential]$Credential
        #[switch]$Force
    )
    $session = New-SFTPSession -ComputerName $Server -Credential $Credential -AcceptKey # Connect to the SFTP server
    Set-SFTPItem -SFTPSession $session -Path $LocalFilePath\$Filename -Destination $RemoteFilePath -Force # Upload the file - Overwrite if exists - If you want to set a switch for force you can - you just have to do a if ($force) {run command with -force} else {run command without -force in it)}
    Remove-SFTPSession -SFTPSession $session # Close the SFTP session
}

function expand-archivefiles {
    param (
        [string]$Server,
        [string]$RemoteFilePath,
        [string]$Filename,
        [System.Management.Automation.PSCredential]$Credential
    )

    $SSHSession = New-SSHSession -ComputerName $Server -Credential $Credential # Connect to the NetScaler via SSH and start a Stream session
    $stream = $SSHSession.session.CreateShellStream("PS-SSH", 0, 0, 0, 0, 100) # Set the stream session console settings - See Posh-SSH github for more details if needed
    $stream.Read() # Displays the stream console 
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "show hostname" # Shows the hostname of the NetScaler you are connected to
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "shell" # Enterst the Shell prompt of the NetScaler you are connected to
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "gunzip $RemoteFilePath\$Filename -f" # Unzips the .gz file 
    Start-Sleep -Seconds 5 # Pauses for 5 seconds to give the unzip time to complete # Is this needed if it's broken out in to 2 functions calls?
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "exit" # Exits the shell
    Get-SSHSession | Remove-SSHSession | Out-Null # Clears out the SSH-Session
}

function add-locationsettings {
    param (
        [string]$Server,
        [string]$Command,
        [System.Management.Automation.PSCredential]$Credential
    )
    $SSHSession = New-SSHSession -ComputerName $Server -Credential $Credential # Connect to the NetScaler via SSH - NOTE this is not a stream so each command is run like the first time connecting to the CLI
    Invoke-SSHCommand -Index 0 -Command "show hostname" # Shows the Hostname of the NetScaler you are connected to - Can remove used just for verbose information in testing
    Write-Host "Checking the location settings before running CLI command: $Command" # Verbose testing information - see the settings before any changes
    Invoke-SSHCommand -Index 0 -Command "show locationparameter" -ShowStandardOutputStream -StandardOutputStreamColor Yellow # CLI Command with Invoke-SSHCommand syntax to see the output of the command in yellow
    Invoke-SSHCommand -Index 0 -Command $Command ## Command to set the location file (IPv4 or IPv6)
    Write-Host "Checking the location settings After running CLI command: $Command" # Verbose testing information - see the settings after ipv4 changes
    Invoke-SSHCommand -Index 0 -Command "show locationparameter" -ShowStandardOutputStream -StandardOutputStreamColor Blue # CLI Command with Invoke-SSHCommand syntax to see the output of the command in Blue
    Invoke-SSHCommand -Index 0 -Command "exit" # Exits the CLI of the NetScaler
    Get-SSHSession | Remove-SSHSession | Out-Null # Clears the SSHSession
}


#################
## Main Script ##
#################

foreach ($NetScaler in $NetScalers) {

    send-sftpfile -Server $NetScaler -LocalFilePath $FilePath -RemoteFilePath $netscalerpath -Filename $gzipv4 -Credential $Credential # Send gzipv4 file to NetScaler
    send-sftpfile -Server $NetScaler -LocalFilePath $FilePath -RemoteFilePath $netscalerpath -Filename $gzipv6 -Credential $Credential # Send gzipv6 file to NetScaler - Will wait for the first function run to compelte

    expand-archivefiles -Server $NetScaler -RemoteFilePath $netscalerpath -Filename $gzipv4 -Credential $Credential # Runs the Unzip of IPv4 file
    expand-archivefiles -Server $NetScaler -RemoteFilePath $netscalerpath -Filename $gzipv6 -Credential $Credential # Runs the Unzip of IPv6 file

    add-locationsettings -Server $NetScaler -Command $addlocationipv4 -Credential $Credential # Runs the IPv4 Location Command
    add-locationsettings -Server $NetScaler -Command $addlocationipv6 -Credential $Credential # Runs the IPv6 Location Command

}
