# Deploy AirWatch
DeployAirWatch is a PowerShell script that will install the AirWatch console and DB using the existing installers. It's setup to be a second stage to the existing build process in Bamboo.

**NOTE:** DeployAirWatch2.ps1 is being deprecated. You need you move your environment to Dev 2.0 and being using BA-DeployAirWatch2.ps1

### Server Dependencies  
Before DeployAirWatch will work, the following things must be configured on the server you plan to install to:

* ````awsso\svcautodeploy```` must be added as a local admin on the server. You should log in with this user at least once to create a user profile.
* ````D:\Installs```` needs to be a shared folder (with R/W access) so that the deployment agent can copy the build artifacts to the Installs directory.
* Execution of PowerShell scripts must be enabled. Run the following command through an administrator PowerShell console: ````Set-ExecutionPolicy Unrestricted````
* Remote management needs to be enabled. Typically, all thats required is running the following command: ````Enable-PSRemoting –force````

#### Dev 2.0 Notes
If your machine is in Dev 2.0 ("Genesis") you will need to also run these additional statements on command line (not PowerShell) to configure WinRM to accept authentication over HTTP and without Kerberos.

* ```winrm set winrm/config/client/auth @{Basic="true"}```
* ```winrm set winrm/config/service/auth @{Basic="true"}```
* ```winrm set winrm/config/service @{AllowUnencrypted="true"}```
* ```winrm set winrm/config/client @{AllowUnencrypted="true"}```
* ```winrm set winrm/config/client @{TrustedHosts="*"}```

### What's Happening?
At a high level, this is what Deploy AirWatch does.

1. Get build artifacts.
2. Open remote PowerShell session.
3. Copy build artifacts over to server.
4. Shut down services.
5. Back up database.
6. Install DB, check to ensure it published successfully.
7. Install App, check to insure it installed successfully.
8. Start services.
9. Close remote PowerShell session.

### How to Run Script
DeployAirWatch runs specific to how our build output is formed but, to run the script you just need to call it with six or seven arguments like below.

**With six arguments:**
```
.\DeployAirWatch2.ps1 RunMode ServerFqdn ServerUrl DbServer DbName DbUser
```

**With seven arguments:**
```
.\DeployAirWatch2.ps1 RunMode ServerFqdn CnUrl DsUrl DbServer DbName DbUser
```

**NOTE:** The variable ```DsUrl``` is optional.

If you wanted to run this from outside of the build process, it's possible if you have cloned this repository, placed the build output (zip and DB exe) into the ````.\artifacts\```` (in the base directory of DeployAirWatch), and have PowerShell 4 installed on your machine.

#### Dev 2.0 Notes
The instructions above are the same for Dev 2.0 ("Genesis") except that you need to use the script prepended with ```BA-``` ("Basic Auth"). 

### Arguments
DeployAirWatch requires that six or seven arguments to be passed to it in order to run.

1. RunMode (See below)
2. ServerFqdn - Internal server FQDN.
3. CnUrl - Console URL
4. DsUrl - Device Services URL (This is usually the same on single-environment installations)
5. DbServer - Server DB is hosted on.
6. DbName - Name of the DB.
7. DbUser - User with rights to connect to DB (Needs to be the AirWatchAdmin_Environment user).

The ````RunMode```` value tells the script what it's going type of job it's going to be doing.

* 0 - Test connectivity. This run mode JUST creates a remote PowerShell session to the machine specified in the second argument then exits.
* 1 - Normal deployment. This is a typical, single-box installation. This includes DB installation.
* 2 - API installation. Only installs API-related components.
* 3 - DS installation. Only installs DS-related components.
* 4 - CN installation. Only installs Console-related components.
* 5 - DB installation. Only installs DB.
* 6 - Stop services. Connects to server and stops all AirWatch-related services.
* 7 - Start services. Connects to server and starts all AirWatch-related services.
* 8 - BAT suite deployment. This is the same as normal (1) except that it resets the Administrator users role and OG to system admin at global.
* 9 - **Experimental:** Integration tests deployment. This is the same as normal (1). This mode grabs the golden DB backup and restores it to the specified DB and then upgrades the app server specified.
* 10 - **Experimental:** Nimbus Installation. WIP. DO NOT USE.

### Exit Codes
Below is a list of the exit codes that Deploy AirWatch uses and what they mean. A non-zero exit code means the deployment failed.

* 0 - Good/Done.
* 1 - PowerShell 4+ not found.
* 2 - Failed to create remote PS session.
* 3 - Invalid run mode.
* 4 - Argument issue.
* 5 - Failed to provision Nimbus server.
* 6 - Failed to Import Posh-SSH for Nimbus deployment.
* 8 - Failed to reset Administrator role/OG.
* 9 - Failed to purge database.
* 10 - Missing dependencies.
* 20 - Failed to copy over artifacts.
* 21 - Artifact mismatch / Bad artifact.
* 30 - Failed to stop all services.
* 40 - Failed to install DB.
* 41 - Database backup failed.
* 42 - Database restore failed (Implies 40).
* 50 - Failed to install app.
* 51 - Failed to get a certificate signing token.
* 60 - Failed to start services.

### Important Note About Deploy Machines
In order to run the token tool (AirWatch Signing Service), the machine you deploy FROM must have a certificate issued from the myAirWatch team installed in the local machine personal store.