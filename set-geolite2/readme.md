# GeoLite2 Database for NetScaler VPX and ADM

This script is to automate the process of copying and applying the Geo Lite 2 City/Country databases to the VPX instances and ADM. This is used for analytics to identify IP's to Country/City that can be used in ADM for any Web VIP that has Analytics enabled.

The NetScaler team is working on setting up Analytics as a default for all Web services so that this information is available for additional troubleshooting of Web related VIPs.

## GitHub Workflow Triggers

The GitHub workflow can be triggered in one of two ways

1. Manually executed by selecting the action  and clicking "Run workflow"
or
2. Adding an updated Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz or Netscaler_Maxmind_GeoIP_DB_IPv64.csv.gz file in the /data/maxmind_geoip folder. Please note that these are specific filenames that must be followed for the workflow to be triggered.

## Script Requirements

- Posh-SSH powershell module - Used for SSH and SFTP
- Credentials to ADM and VPX instances
- Data files - listed below

## Script Details

Data Files:
- Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz
- Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz

Updated files should be placed in the \data\maxmind_geoip directory. To generate these files refer to the [NetScaler documentation](https://docs.netscaler.com/en-us/citrix-adc/current-release/global-server-load-balancing/configuring-static-proximity/add-a-location-file-create-static-proximity-db.html#script-to-convert-maxmind-geolite2-database-format-to-netscaler-database-format)

- netscaler.csv # A file that contains a list of NetScalers to copy the files to and set the Geo Location database

Script Workflow:

- A GitHub Action "set-geolite2.yml" has been created that can be run on demand or when new GeoLite2 database files are updated.

- Using GitHub variables and secrets for usernames and passwords for credentials to execute against each NetScaler

- Get a list of VPX's/ADM to run against
- Create a SFTP Session
- Copy the file to the NetScaler in the appropriate folder
- Disconnect SFTP session
- Create a SSH Session
- Extract the .gz using the native gunzip command on the VPX
- Disconnect SSH session
- Create a SSH session
- Apply the GeoLocation with the file for IPv4 and IPv6
- Disconnect SSH session

## Running the script locally on your Desktop

Automation of updating NetScaler Geo Location's databases with MaxMind Geo Lite 2 databases.

How to use the script locally:
Due to the fact that it needs to be run locally in a desktop there are some path dependencies built in to the script.
It was intended to be run from GitHub however due to port restrictions on the GitHub runners to the VPX's here is how you can run this locally

- Have a working directory structure as follows (Make a clone of the netscaler-ps repo and copy it over to your desktop for simplicity)

1. repos\netscaler-geolite2\set-geolite2 # Running directory of the script - need to be in this directory when running the script. (Need to look into modifying the script paths so this isn't necessary somehow)
2. repos\netscaler-geolite2\data # Used to locate the netscaler IP csv files
3. repos\netscaler-geolite2\data\maxmind_geoip # Location of gz files for database to copy to NetScalers

Running the script:

- Define a $Credential variable first by either running $Credential = Get-Credentail and then providing the information or already having one set to be passed to the script as a parameter
- You scan use the netscaler-snips.csv file located in the scripts\data directory if you intend to run this against all NetScaler. In testing sandbox-snips.csv was used. You can create a list of specific instances to run against as well. Just update the script variable accordingly.
- You should have updated 'Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz' and 'Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz' files in the \data\maxmind_geoip directory.
- Be sure that you start in the root directory, c:\repos\netscaler-geolite2\set-geolite2\ when you run the script execution command:
  Example script execution:  `.\set-geolite2.ps1 -Credential $credential` while in the root path of where the script is located.
