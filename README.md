# netscaler-geolite2
NetScaler GitHub Automation Script to update GeoLite2 IP Location Databases on ADM and VPX's

This is a project that I am currently working on that in it's current state will take converted files, Netscaler_Maxmind_GeoIP_DB_IPv4.csv.gz and Netscaler_Maxmind_GeoIP_DB_IPv6.csv.gz files and copy them to a NetScaler VPX instance, extract them and then add the locationfile and locationfile6 databases to the configuration. With the additions of the Get-Geolite2database.yml, convert-geolite2.yml and convert-geoltie2.ps1 powershell script this should give you a complete package from start to finish for getting a new GeoLite2-CSV database, converting it and then deploying it to your instances.

Additional steps that are in progress are the following that will fully automate the GeoLite2 database update
- Add support for ADM as the upgrade process is a slightly different procedrue
- Download the MaxMind GeoLite2 database - Completed with the get-geolite2database.yml workflow action
- Copy the raw MaxMind GeoLite2 database to a VPX instance and run the perl script to convert the raw databased to NetScaler format - Completed with the convert-geolite2.yml and convert-geolite2.ps1 script.
- Copy the converted .gz NetScaler formated databases back to a GitHub Repo - Completed with the convert-geolite2.yml and convert-geolite2.ps1 script.
- On update of the .gz database in the GitHub Repo trigger the workflow action to upgrade VPX's with the new GeoLite2 databases. - I'm still working on how to trigger the workflows from one to the other so that this becomes a fully automated process.

## Challenges

My work environment has firewall restrictions so by default the local on-prem GitHub Runners do not have internet access and direct access to the NetScaler environment. To get around the Internet access issue I used a different set of GitHub runners to download the MaxMind GeoLite2-CSV.ZIP file and save to the Repo. Then using my on-prem GitHub Runners I'm able to take the necessary files to copy to my NetScaler instance, convert the GeoLite2 database, copy it back to the Repo and then using another workflow copy the converted database to all my NetScaler instances and apply the LocationFile's accordingly.

Running this GeoLite2 database process in my work enviorment makes it difficult to produce something that would suite the needs of everyone. This should be taken as a base foundation that could be tweaked to work in your environment. Hopefully you find this helpful enough to get started from a basic powershell and GitHub workflow standpoint. I'm open to suggestions and ways to make this work even better. I've never had any formal programming training and consider myself a poor-mans script kitty. So for those of you in a similar situation take this for what it is and I hope it makes sense to you.

## Things to workthrough

The workflow actions is something still new to me. My scripting skill set is not that advanced and I continue to learn and re-shape things that have been created to attempt to build re-usable and parameter friendly code. There are some things that could be tweaked but for a working solution this is what I've come up with so far.

As I continue to run, tweak and learn how to do things better I'll re-visit this and update.

## Things to Add

- ADM support. Currently this script does not account for updating the ADM GeoLocation file. To be done in a future revision.