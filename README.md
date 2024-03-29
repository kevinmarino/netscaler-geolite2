# netscaler-geolite2
NetScaler GitHub Automation Script to update GeoLite2 IP Location Databases on ADM and VPX's

This is a project that I am currently working on that in it's current state will take converted files, Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz and Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz files and copy them to a NetScaler VPX instance, extract them and then add the locationfile and locationfile6 databases to the configuration.

Additional steps that are in progress are the following that will fully automate the GeoLite2 database update
- Add support for ADM as the upgrade process is a slightly different procedrue
- Download the MaxMind GeoLite2 database
- Copy the raw MaxMind GeoLite2 database to a VPX instance and run the perl script to convert the raw databased to NetScaler format
- Copy the converted .gz NetScaler formated databases back to a GitHub Repo
- On update of the .gz database in the GitHub Repo trigger the workflow action to upgrade VPX's with the new GeoLite2 databases.
