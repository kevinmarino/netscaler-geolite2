<#
.SYNOPSIS
    This Script is to convert a MaxMind GeoLite2 CSV database file to a NetScaler format
.DESCRIPTION
    Using GitHub Workflow Actions this script will Take the downloaded MaxMind GeoLite2-CSV.ZIP file, copy it to the NetScaler in a temp directory, unzip it, Copy the NetScaler perl script to the same temp directory, then run the perl conversion script.
    When completed it will then copy the .gz converted NetScaler_Maxmind_GeoIP_DB.gz files to the repo
    The Workflow will then commit and push the updated files to the repo.
.NOTES
    This requires 
    - Posh-SSH powershell module
    - GitHub runner with access to your NetScaler appliance

.LINK
    
.EXAMPLE
    ./convert-geolite2.ps1 -credential $Credential # Runs the script with the passed credentials. Note Varialbes can be modified to suit your needs.
#>

param(
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
)

###############
## Variables ##
###############
$NetScaler = 'netscaler.name' # Name of the VPX/MPX instance to connect to
$GitHubFilePath = '.\data\maxmind_geoip\' # Set File Path to Geo Lite 2 Database # USE THIS LINE IF RUNNING VIA GITHUB WORKFLOW
$maxminddir = '/var/tmp/maxmindtmp/' # The directory where to place the zip file and unzip and run the perl script from
$maxmindfile = 'GeoLite2-City-CSV*.zip' # Sets the File Name for the .ZIP that will be copied and later extracted (Tar) - Could do a list contents to get the actual file name should be GeoLite2-City-CSV_<date>.ZIP where Date is updated to the latest one downloaded
$perlscript = 'Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl' # The NetScaler perl script needed to convert the GeoLite2 CSV files. Copy it to the directory if it doesn't already exist
$gzipv4 = 'Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz' # Sets the File Name for the .gz that will be copied back to GitHub
$gzipv6 = 'Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz' # Sets the File Name for the .gz that will be copied back to GitHub
$perlscriptcommand = 'perl Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl -b GeoLite2-City-Blocks-IPv4.csv -i GeoLite2-City-Blocks-IPv6.csv -l GeoLite2-City-Locations-en.csv'

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
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "pwd" #Show your current directory
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "cd $RemoteFilePath" # Change to the Remote Directory
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "tar -xvzf $Filename --strip-components=1" # Unzips the .ZIP file in /var/tmp/maxmindtmp directory - This seems to work differently than the gunzip as far as directory extraction goes
    Start-Sleep -Seconds 5 # Pauses for 5 seconds to give the unzip time to complete # Is this needed if it's broken out in to 2 functions calls?
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "ls $RemoteFilePath" # Get a directory listing of the temp directory
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "exit" # Exits the shell
    Get-SSHSession | Remove-SSHSession | Out-Null # Clears out the SSH-Session
}

function get-sftpfile {
    param (
        [string]$Server,
        [string]$LocalFilePath,
        [string]$RemoteFilePath,
        [string]$Filename,
        [System.Management.Automation.PSCredential]$Credential
        #[switch]$Force
    )
    $session = New-SFTPSession -ComputerName $Server -Credential $Credential -AcceptKey # Connect to the SFTP server
    Get-SFTPItem -SFTPSession $session -Path $LocalFilePath$Filename -Destination $RemoteFilePath -Force # Download the files - Overwrite if exists - If you want to set a switch for force you can - you just have to do a if ($force) {run command with -force} else {run command without -force in it)}
    Remove-SFTPSession -SFTPSession $session # Close the SFTP session
}

function new-sftpdir {
    param (
        [string]$Server,
        [string]$DirectoryName,
        [System.Management.Automation.PSCredential]$Credential
    )
    $session = New-SFTPSession -ComputerName $Server -Credential $Credential -AcceptKey # Connect to the SFTP server
    $checkpath = Test-SFTPPath -SessionId $session.SessionId -Path $DirectoryName
    if ($checkpath) {
        Write-Host "Path already exists" # Needed otherwise if the directory existed then the WorkFlow would exit.
        Remove-SFTPSession -SFTPSession $session # Close the SFTP session
    }
    else {
        Write-Host "creating directory $DirectoryName"
        New-SFTPItem -SessionId $session.SessionId -Path $DirectoryName -ItemType Directory
        Remove-SFTPSession -SFTPSession $session # Close the SFTP session
    }
}

function invoke-perlscript {
    param (
        [string]$Server,
        [string]$RemoteFilePath,
        [string]$Command,
        [System.Management.Automation.PSCredential]$Credential
    )

    $SSHSession = New-SSHSession -ComputerName $Server -Credential $Credential # Connect to the NetScaler via SSH and start a Stream session
    $stream = $SSHSession.session.CreateShellStream("PS-SSH", 0, 0, 0, 0, 100) # Set the stream session console settings - See Posh-SSH github for more details if needed
    $stream.Read() # Displays the stream console 
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "show hostname" # Shows the hostname of the NetScaler you are connected to
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "shell" # Enterst the Shell prompt of the NetScaler you are connected to
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "pwd" #Show your current directory
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "cd $RemoteFilePath" # Change to the Remote Directory
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "pwd" #Show your current directory - should be /var/tmp/maxmindtmp/
    Write-Host "Should be in a Shell Session just before running the Perl script command"
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "$command" # Runs the perl script to convert the databases - This takes like 10 minutes - If you exit the session it seems as if the command stops running
    Write-Host "Adding a sleep of 420 seconds to wait for the perl script command to complete. If this shell exits before completing then the .gz files do not get created"
    Start-Sleep -Seconds 420 # Pauses for 300 seconds to give the conversion time complete
    Write-Host "Should be 7 minutes after the script command is run. Based on some testing the command completes in about 4.5 minutes. Adding in padding for future runs if the files get larger"
    # Can we do a directory listing for the two files expected - NetScaler_MaxMind_GeoIP_DB_IPv4.csv.gz and IPv6.csv.gz?
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "ls $RemoteFilePath" # Get a directory listing of the temp directory
    Invoke-SSHSTreamShellCommand -ShellStream $stream -Command "exit" # Exits the shell
    Write-Host "exiting the shell ssh session now"
    Get-SSHSession | Remove-SSHSession | Out-Null # Clears out the SSH-Session
}

#################
## Main Script ##
#################

# Create a New Directory to stage our files
new-sftpdir -Server $NetScaler -DirectoryName $maxminddir -Credential $Credential # Uses the New-SFTPItem -ItemType Directory to create the directory

# Only 1 NetScaler to send this to and run the conversion - no need with a foreach
send-sftpfile -Server $NetScaler -LocalFilePath $GitHubFilePath -RemoteFilePath $maxminddir -Filename $maxmindfile -Credential $Credential # Send GeoLite-City-CSV*.ZIP file to NetScaler
send-sftpfile -Server $NetScaler -LocalFilePath $GitHubFilePath -RemoteFilePath $maxminddir -Filename $perlscript -Credential $Credential # Send perl script file to NetScaler

expand-archivefiles -Server $NetScaler -RemoteFilePath $maxminddir -Filename $maxmindfile -Credential $Credential # Runs the Unzip of IPv4 file

# Run Perl Script and convert to NetScaler Format
# This works - need to figure out a better way for the script command to complete before moving on to the next streamshellcommand. Currently there's a Start-Sleep for 420 seconds to allow the perl script command to finish. Without it the script exits the shell session and the command never completes the conversion
invoke-perlscript -Server $NetScaler -RemoteFilePath $maxminddir -command $perlscriptcommand -Credential $Credential # Changes to the maxminddir and runs the perl script command in a SHELL session on the NetScaler


# Get the converted .gz files to the GitHub repo
Write-Host "Getting Converted Files From NetScaler $NetScaler"
get-sftpfile -Server $NetScaler -LocalFilePath $maxminddir -Filename $gzipv4 -RemoteFilePath $GitHubFilePath -Credential $Credential  # Gets the .gz files and copies to the GitHub Repo
get-sftpfile -Server $NetScaler -LocalFilePath $maxminddir -Filename $gzipv6 -RemoteFilePath $GitHubFilePath -Credential $Credential  # Gets the .gz files and copies to the GitHub Repo
Write-host "Converted files have been copied to $GitHubFilePath. "
Get-ChildItem $GitHubFilePath *.gz # List all .gz files in the GitHubFilePath - Should be the new files

