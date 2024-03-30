# Automation for converting a GeoLite2 CSV in ZIP format database file

Currently a workflow has been created to automatically download the GeoLite2 database via a GitHub workflow - get-geolite2database.yml. This script is dependent on the GeoLite2-City-CSV*.zip existing.

- The workflow is triggered manually at this time but can be setup to run on a CRON job
- Additionally it needs to be setup so that will look for the latest files only and if it is newer than the current one then over delete the old and update with the new

You can also reference NetScaler's documentation [here](https://docs.netscaler.com/en-us/citrix-adc/current-release/global-server-load-balancing/configuring-static-proximity/add-a-location-file-create-static-proximity-db.html#script-to-convert-maxmind-geolite2-database-format-to-netscaler-database-format)

Script Build layout

- Copy files from GitHub Repo to Sandbox NetScaler (Need to run the perl script conversion from a NetScaler so using sandbox is a logical choice)
- unzip the file `tar -xvzf <filename.zip>` to extract the files. Creates a number of CSV files
- copy the perl script to the same directory as the extracted files
- run the command `perl Convert_GeoIPDB_To_Netscaler_Format_WithContinent.pl -b GeoLite2-City-Blocks-IPv4.csv -i GeoLite2-City-Blocks-IPv6.csv -l GeoLite2-City-Locations-en.csv`
- Copy the output files `Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz` and `Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz` back to GitHub
- The copy of the .gz files in GitHub should trigger the workflow action to run
