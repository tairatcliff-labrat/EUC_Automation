#
#  Copyright © 2015, 2016, 2017, 2018 VMware Inc. All rights reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of the software in this file (the "Software"), to deal in the Software 
#  without restriction, including without limitation the rights to use, copy, 
#  modify, merge, publish, distribute, sublicense, and/or sell copies of the 
#  Software, and to permit persons to whom the Software is furnished to do so, 
#  subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in 
#  all copies or substantial portions of the Software.
#  
#  The names "VMware" and "VMware, Inc." must not be used to endorse or promote 
#  products derived from the Software without the prior written permission of 
#  VMware, Inc.
#  
#  Products derived from the Software may not be called "VMware", nor may 
#  "VMware" appear in their name, without the prior written permission of 
#  VMware, Inc.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
#  VMWARE,INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
#  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

#
# Function to parse token values from a .ini configuration file
#

function ImportIni {
	param ($file)

	$ini = @{}
	switch -regex -file $file
	{
    		"^\[(.+)\]$" {
        		$section = $matches[1]
        		$ini[$section] = @{}
    		}
    		"([A-Za-z0-9#_]+)=(.+)" {
        		$name,$value = $matches[1..2]
        		$ini[$section][$name] = $value.Trim()
    		}
	}
	$ini
}

#
# Function to write an error message in red with black background
#

function WriteErrorString {
	param ($string)
	write-host $string -foregroundcolor red -backgroundcolor black
}

#
# Function to prompt the user for an UAG VM name and validate the input
#

function GetAPName {
	$valid=0
	while (! $valid) {
		$apName = Read-host "Enter a name for this VM"
		if (($apName.length -lt 1) -Or ($apName.length -gt 32)) { 
			WriteErrorString "Error: Virtual machine name must be between 1 and 32 characters in length"
		} else {
			$valid=1
		}
	}
	$apName 
}

#
# Function to decrypt an encrypted password
#

function ConvertFromSecureToPlain {
    
    param( [Parameter(Mandatory=$true)][System.Security.SecureString] $SecurePassword)
    
    # Create a "password pointer".
    $PasswordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    
    # Get the plain text version of the password.
    $PlainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($PasswordPointer)
    
    # Free the pointer.
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PasswordPointer)
    
    # Return the plain text password.
    $PlainTextPassword
    
}


#
# Function to prompt the user for an UAG root password and validate the input
#

function GetRootPwd {
	param( [Parameter(Mandatory=$true)] $apName)
	$match=0
	while (! $match) {
		$valid=0
		while (! $valid) { 
			$rootPwd = Read-Host -assecurestring "Enter a root password for" $apName
			$rootPwd = ConvertFromSecureToPlain $rootPwd
			if ($rootPwd.length -lt 6) {
				WriteErrorString "Error: Password must contain at least 6 characters"
				Continue
			}
			$valid=1
		}

		$rootPwd2 = Read-Host -assecurestring "Re-enter the root password"
		$rootPwd2 = ConvertFromSecureToPlain $rootPwd2
		if ($rootPwd -ne $rootPwd2) {
			WriteErrorString "Error: re-entered password does not match"
		} else {
			$match=1
		}
	}
	$rootPwd = $rootPwd -replace '"', '\"'
	$rootPwd = $rootPwd -replace "'", "\047"
	$rootPwd
}

#
# Function to prompt the user for an UAG admin password and validate the input
#

function GetAdminPwd {
	param( [Parameter(Mandatory=$true)] $apName)
	$match=0
	while (! $match) {
		$valid=0
		while (! $valid) { 
			$adminPwd = Read-Host -assecurestring "Enter an optional admin password for the REST API management access for" $apName
			$adminPwd = ConvertFromSecureToPlain $adminPwd
			if ($adminPwd.length -eq 0) {
				return
			}

			if ($adminPwd.length -lt 8) {
				WriteErrorString "Error: Password must contain at least 8 characters"
				WriteErrorString "Password must contain at least 8 characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
				Continue
			}
			if (([regex]"[0-9]").Matches($adminPwd).Count -lt 1 ) {
				WriteErrorString "Error: Password must contain at least 1 numeric digit"
				WriteErrorString "Password must contain at least 8 characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
				Continue
			}
			if (([regex]"[A-Z]").Matches($adminPwd).Count -lt 1 ) {
				WriteErrorString "Error: Password must contain at least 1 upper case character (A-Z)"
				WriteErrorString "Password must contain at least 8 characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
				Continue
			}
			if (([regex]"[a-z]").Matches($adminPwd).Count -lt 1 ) {
				WriteErrorString "Error: Password must contain at least 1 lower case character (a-z)"
				WriteErrorString "Password must contain at least 8 characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
				Continue
			}
			if (([regex]"[!@#$%*()]").Matches($adminPwd).Count -lt 1 ) {
				WriteErrorString "Error: Password must contain at least 1 special character (!@#$%*())"
				WriteErrorString "Password must contain at least 8 characters including an upper case letter, a lower case letter, a digit and a special character from !@#$%*()"
				Continue
			}
			$valid = 1
		}

		$adminPwd2 = Read-Host -assecurestring "Re-enter the admin password"
		$adminPwd2 = ConvertFromSecureToPlain $adminPwd2
		if ($adminPwd -ne $adminPwd2) {
			WriteErrorString "Error: re-entered password does not match"
		} else {
			$match=1
		}
	}
	$adminPwd = $adminPwd -replace '"', '\"'
	$adminPwd = $adminPwd -replace "'", "\047"
	$adminPwd
}

#
# Function to prompt the user for whether to join VMware’s Customer Experience Improvement Program (CEIP)
# Default is yes.
#

function GetCeipEnabled {
	param( [Parameter(Mandatory=$true)] $apName)
write-host "Join the VMware Customer Experience Improvement Program?

This setting is supported in UAG versions 3.1 and newer.

VMware’s Customer Experience Improvement Program (CEIP) provides VMware with information that enables VMware to
improve its products and services, to fix problems, and to advise you on how best to deploy and use our products.

As part of the CEIP, VMware collects technical information about your organization’s use of VMware products and
services on a regular basis in association with your organization’s VMware license key(s). This information does
not personally identify any individual.

Additional information regarding the data collected through CEIP and the purposes for which it is used by VMware
is set forth in the Trust & Assurance Center at http://www.vmware.com/trustvmware/ceip.html.

If you prefer not to participate in VMware’s CEIP for UAG 3.1 and newer, you should enter no.

You may join or leave VMware’s CEIP for this product at any time. In the UAG Admin UI in System Configuration,
there is a setting 'Join CEIP' which can be set to yes or no and has immediate effect.

To Join the VMware Customer Experience Improvement Program with Unified Access Gateway version 3.1 and newer,
either enter yes or just hit return as the default for this setting is yes."

    $valid=$false
	while (! $valid) { 
	    $yorn = Read-Host "Join CEIP for" $apName "? (default is yes for UAG 3.1 and newer)"
        if (($yorn -eq "yes") -Or ($yorn -eq "")) {
            $ceipEnabled = $true
            $valid=$true
            break
        } elseif ($yorn -eq "no") {
            $ceipEnabled = $false
            $valid=$true
            break
        }
        WriteErrorString 'Error: please enter "yes" or "no", or just hit return for yes.'
    }
    $ceipEnabled
}

#
# Function to prompt the user for an Airwatch password and attempt to validate the input with the
# Airwatch service. If we are not able to validate the password, we allow the user to continue.
# If we positively determine that the password is invalid (Unauthorized), we re-prompt.
#

function GetAirwatchPwd {
    param($apiServerUrl, $apiServerUsername, $organizationGroupCode)

    while (! $valid) {
        $prompt='Enter the Airwatch '+$apiServerUrl+' password for user "'+$apiServerUsername+'" (group code "'+$organizationGroupCode+'")' 
        $pwd = Read-Host -assecurestring $prompt
        if ($pwd.length -eq 0) {
            Continue
        }
        $pwd = ConvertFromSecureToPlain $pwd
        $secpasswd = ConvertTo-SecureString $pwd -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($apiServerUsername, $secpasswd)
        $valid=1
        $uri=$apiServerUrl+"/API/mdm/gateway/configuration?type=VPN&locationgroupcode="+$organizationGroupCode
        try { 
            $response = Invoke-RestMethod -Uri $uri -Method "Post"  -Credential $cred -ContentType "application/json" -Body '{"randomString" : "abc123"}'
        } catch {
            #write-host $_.Exception.Response.StatusCode
            if ($_.Exception.Response.StatusCode -eq "Unauthorized") {
                write-host "Incorrect password"
                $valid=0
            } elseif ($_.Exception.Response.StatusCode -eq "BadRequest") {
                $err='Error: Invalid Airwatch settings '+$apiServerUrl+' user "'+$apiServerUsername+'" (group code "'+$organizationGroupCode+'")'+$_
                WriteErrorString $err
                Exit
            } else {
                write-host "Warning: Unable to verify password -" $_
            }
        }
    }

    $pwd
}

function GetTrustedCertificates {
    param($edgeService)
    #Add Trusted certificates entries in json
    $allCerts = "\'trustedCertificates\': [ "
    for($i=1;;$i++)
    {
	    $cert = "trustedCert$i"
	    $cert = $settings.$edgeService.$cert
	    if($cert.length -gt 0)
	    {
		    if (!(Test-path $cert)) {
			    WriteErrorString "Error: PEM Certificate file not found ($cert)"
			    Exit
		    }
		    else
		    {
			    $content = (Get-Content $cert | Out-String) -replace "`r`n", "\\n" 

			    if ($content -like "*-----BEGIN CERTIFICATE-----*") {
	    			#Write-host "valid cert"
			    } else {
				    WriteErrorString "Error: Invalid certificate file It must contain -----BEGIN CERTIFICATE-----."
				    Exit
			    }
			    $fileName = $cert.SubString($cert.LastIndexof('\')+1)
			    #Write-Host "$fileName"
			    $allCerts += "{ \'name\': \'$fileName\'"
			    $allCerts += ","
			    $allCerts += "\'data\': \'"
			    $allCerts += $content
			    $allCerts += "\'"
			    $allCerts += "},"
		    }
	    }
	    else {
            $allCerts = $allCerts.Substring(0, $allCerts.Length-1)
		    #Write-Host "$($i-1) Certificates Added successfully"
		    break;
	    }
    }
    $allCerts += "]"

    $allCerts
}

function GetHostEntries {
    param($edgeService)
    # Add all host entries into json
    $allHosts = "\'hostEntries\': [ "
    for($i=1;;$i++)
    {
	    $hostEntry = "hostEntry$i"
	    $hostEntry = $settings.$edgeService.$hostEntry
	    if($hostEntry.length -gt 0)
	    {
		    $allHosts += "\'"+$hostEntry+"\',"
	    }
	    else {
            $allHosts = $allHosts.Substring(0, $allHosts.Length-1)
		    #Write-Host "$($i-1) Host entries Added successfully"
		    break;
	    }
    }
    $allHosts += "]"

    $allHosts
}

function GetSAMLServiceProviderMetadata {
    Param ($settings)

    $samlMetadata = "\'serviceProviderMetadataList\': { "
    $samlMetadata += "\'items\': [ "
    $spCount=0

    for($i=1;$i -lt 99;$i++)
    {
	    $spNameLabel = "spName$i"
	    $spName = $settings.SAMLServiceProviderMetadata.$spNameLabel
        $metadataXmlLabel = "metadataXml$i"
        $metadataXml = $settings.SAMLServiceProviderMetadata.$metaDataXmlLabel
	    if($spName.length -gt 0)
	    {
            if ($metaDataXml.length -eq 0) {
			    WriteErrorString "Error: Missing $metaDataXmlLabel"
			    Exit
            }

		    if (!(Test-path $metaDataXml)) {
			    WriteErrorString "Error: SAML Metada file not found ($metaDataXml)"
			    Exit
		    }
			$content = (Get-Content $metaDataXml | Out-String) -replace "`r`n", "\\n" -replace """", "\\"""

		    if ($content -like "*urn:oasis:names:tc:SAML:2.0:metadata*") {
    			#Write-host "valid metadata"
		    } else {
			    WriteErrorString "Error: Invalid metadata specified in $metaDataXml"
			    Exit
		    }
    	    if ($spCount -gt 0) {
                $samlMetadata += ", "
            }
			$samlMetadata += "{ \'spName\': \'$spName\'"
			$samlMetadata += ","
			$samlMetadata += "\'metadataXml\': \'"
			$samlMetadata += $content
			$samlMetadata += "\'"
			$samlMetadata += "}"

            $spCount++
	    }

    }
    $samlMetadata += "] }"

    $samlMetadata
}


function GetSAMLIdentityProviderMetadata {
    Param ($settings)

    $sslCertsFile=$settings.SAMLIdentityProviderMetadata.pemCerts

    if ($sslCertsFile.length -gt 0) {

	    if (!(Test-path $sslCertsFile)) {
		    WriteErrorString "Error: [SAMLIdentityProviderMetadata] PEM Certificate file not found ($sslCertsFile)"
		    Exit
	    }

	    $rsaPrivKeyFile=$settings.SAMLIdentityProviderMetadata.pemPrivKey

	    if ($rsaPrivKeyFile.length -eq 0) {
		    WriteErrorString "Error: [SAMLIdentityProviderMetadata] PEM RSA private key file pemPrivKey not specified"
		    Exit
	    }

	    if (!(Test-path $rsaPrivKeyFile)) {
		    WriteErrorString "Error: [SAMLIdentityProviderMetadata]PEM RSA private key file not found ($rsaPrivKeyFile)"
		    Exit
	    }

        #
        # Read the PEM contents and remove any preamble before ----BEGIN
        #

        $sslcerts = (Get-Content $sslCertsFile | Out-String) -replace "`r`n", "\\n" -replace """", ""
        $sslcerts = $sslcerts.Substring($sslcerts.IndexOf("-----BEGIN"))

	    if (!($sslcerts -like "*-----BEGIN*")) {
		    WriteErrorString "Error: [SAMLIdentityProviderMetadata] Invalid certs PEM file (pemCerts) specified. It must contain a certificate."
		    Exit
	    }

	    $rsaprivkey = (Get-Content $rsaPrivKeyFile | Out-String) -replace "`r`n", "\\n" -replace """", ""
        $rsaprivkey = $rsaprivkey.Substring($rsaprivkey.IndexOf("-----BEGIN"))

	    if ($rsaprivkey -like "*-----BEGIN RSA PRIVATE KEY-----*") {
		    Write-host Deployment will use the specified [SAMLIdentityProviderMetadata] certificate and private key
	    } else {
		    WriteErrorString "Error: [SAMLIdentityProviderMetadata] Invalid private key PEM file (pemPrivKey) specified. It must contain an RSA private key."
		    Exit
	    }
    }

    $samlMetadata="\'identityProviderMetaData\': { "

    #
    # If the signing certificate/key is not specified, we use {} which results in a self-signed cert/key being generated by UAG automatically
    #

    if ($sslcerts.length -gt 0) {
	    $samlMetadata="\'identityProviderMetaData\': { \'privateKeyPem\': \'"
	    $samlMetadata+=$rsaprivkey
	    $samlMetadata+="\', \'certChainPem\': \'"
	    $samlMetadata+=$sslcerts
	    $samlMetadata+="\'"
    }

    $samlMetadata+=" }"

    $samlMetadata
}

function IsPfxPasswordProtected {
    param($sslCertsFilePfx)

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

    try {
        $response = $cert.Import($sslCertsFilePfx, '','DefaultKeySet')
    } catch {
        if ($_.Exception.InnerException.HResult -eq 0x80070056) { # ERROR_INVALID_PASSWORD
            return $true
        }
    }
    return $false
}

function GetPfxPassword {
    param($sslCertsFilePfx, $section)

    $pwd = ""

    if (IsPfxPasswordProtected $sslCertsFilePfx) {

        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

        $pfxFilename = Split-Path $sslCertsFilePfx -leaf
    
        while (! $valid) {
            $prompt='Enter the password for the specified [' + $section + '] PFX certificate file '+$pfxFilename+'' 
            $pwd = Read-Host -assecurestring $prompt
            $pwd = ConvertFromSecureToPlain $pwd
            $valid=1

        
            try {
                $response = $cert.Import($sslCertsFilePfx, $pwd,'DefaultKeySet')
            } catch {
                if ($_.Exception.InnerException.HResult -eq 0x80070056) { # ERROR_INVALID_PASSWORD
                    WriteErrorString "Error: Incorrect password - please try again"
                    $valid = 0
                }
            }
        }
    }

    $pwd
}

function isValidPfxFile {
    param($sslCertsFilePfx, $pwd)

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    
    try {
        $response = $cert.Import($sslCertsFilePfx, $pwd,'DefaultKeySet')
    } catch {
        WriteErrorString "Error: The specified PFX certificate file is invalid ($sslCertsFilePfx)"
        return $false
    }

    if (!$cert.HasPrivateKey) {
        WriteErrorString "Error: The specified PFX Certificate file does not contain a private key ($sslCertsFilePfx)"
        return $false
    }

    return $true
}

#
# Processes normal 443 or Admin 9443 cert. Called as:
# GetCertificateWrapper $setings
# or GetCertificateWrapper $setings "Admin"
#

function GetCertificateWrapper {
    Param ($settings, $admin)

    $section="SSLcert" + $admin

    $sslCertsFile=$settings.$section.pemCerts

    $sslCertsFilePfx=$settings.$section.pfxCerts

    if ($sslCertsFile.length -gt 0) {

	    if (!(Test-path $sslCertsFile)) {
		    WriteErrorString "Error: PEM Certificate file not found ($sslCertsFile)"
		    Exit
	    }

	    $rsaPrivKeyFile=$settings.$section.pemPrivKey

	    if ($rsaPrivKeyFile.length -eq 0) {
		    WriteErrorString "Error: PEM RSA private key file pemPrivKey not specified"
		    Exit
	    }

	    if (!(Test-path $rsaPrivKeyFile)) {
		    WriteErrorString "Error: PEM RSA private key file not found ($rsaPrivKeyFile)"
		    Exit
	    }

        #
        # Read the PEM contents and remove any preamble before ----BEGIN
        #

        $sslcerts = (Get-Content $sslCertsFile | Out-String) -replace "`r`n", "\\n" -replace """", ""
        $sslcerts = $sslcerts.Substring($sslcerts.IndexOf("-----BEGIN"))

	    if (!($sslcerts -like "*-----BEGIN*")) {
		    WriteErrorString "Error: Invalid certs PEM file (pemCerts) specified. It must contain a certificate."
		    Exit
	    }

	    $rsaprivkey = (Get-Content $rsaPrivKeyFile | Out-String) -replace "`r`n", "\\n" -replace """", ""
        $rsaprivkey = $rsaprivkey.Substring($rsaprivkey.IndexOf("-----BEGIN"))

	    if ($rsaprivkey -like "*-----BEGIN RSA PRIVATE KEY-----*") {
		    Write-host "Deployment will use the specified SSL/TLS server certificate ($section)"
	    } else {
		    WriteErrorString "Error: Invalid private key PEM file (pemPrivKey) specified. It must contain an RSA private key."
		    Exit
	    }
    } elseif ($sslCertsFilePfx.length -gt 0) {
	    if (!(Test-path $sslCertsFilePfx)) {
		    WriteErrorString "Error: PFX Certificate file not found ($sslCertsFilePfx)"
		    Exit
	    }

        $sslCertsFilePfx = Resolve-Path -Path $sslCertsFilePfx

        $pfxPassword = GetPfxPassword $sslCertsFilePfx $section

        if (!(isValidPfxFile $sslCertsFilePfx $pfxPassword)) {
		    Exit
        }

    	$Content = Get-Content -Path $sslCertsFilePfx -Encoding Byte
	    $sslCertsFilePfxB64 = [System.Convert]::ToBase64String($Content)

        $pfxCertAlias=$settings.$section.pfxCertAlias


    } else {
	    Write-host "Deployment will use a self-signed SSL/TLS server certificate ($section)"
    }

    if ($sslcerts.length -gt 0) {
	    $certificateWrapper="\'certificateWrapper" + $admin + "\': { \'privateKeyPem\': \'"
	    $certificateWrapper+=$rsaprivkey
	    $certificateWrapper+="\', \'certChainPem\': \'"
	    $certificateWrapper+=$sslcerts
	    $certificateWrapper+="\' }"
    } elseif ($sslCertsFilePfxB64.length -gt 0) {
	    $certificateWrapper="\'pfxCertStoreWrapper" + $admin + "\': { \'pfxKeystore\': \'"
	    $certificateWrapper+=$sslCertsFilePfxB64
	    $certificateWrapper+="\', \'password\': \'"
	    $certificateWrapper+=$pfxPassword
        if ($pfxCertAlias.length -gt 0) {
	        $certificateWrapper+="\', \'alias\': \'"
	        $certificateWrapper+=$pfxCertAlias
        }
        $certificateWrapper+="\' }"
    }

    $certificateWrapper

}

#
# Horizon View settings
#

function GetEdgeServiceSettingsVIEW {
    Param ($settings)

    $proxyDestinationUrl=$settings.Horizon.proxyDestinationUrl

    if ( $proxyDestinationUrl.length -le 0) {
        return
    }

    #
    # Strip the final :443 if specified as that is the default anyway
    #

    if ($proxyDestinationUrl.Substring($proxyDestinationUrl.length - 4, 4) -eq ":443") {
        $proxyDestinationUrl=$proxyDestinationUrl.Substring(0, $proxyDestinationUrl.IndexOf(":443"))
    }
    
    $proxyDestinationUrlThumbprints=$settings.Horizon.proxyDestinationUrlThumbprints  -replace ":","="

    #
    # Remove invalid thumbprint characters
    #

    $proxyDestinationUrlThumbprints = $proxyDestinationUrlThumbprints -replace, "[^a-zA-Z0-9,= ]", ""

    $blastExternalUrl=$settings.Horizon.blastExternalUrl

    $pcoipExternalUrl=$settings.Horizon.pcoipExternalUrl
    if ($pcoipExternalUrl.length -gt 0) {
    	if (([regex]"[.]").Matches($pcoipExternalUrl).Count -ne 3 ) {
    		WriteErrorString "Error: Invalid pcoipExternalUrl value specified ($pcoipExternalUrl). It must contain an IPv4 address."
    		Exit
    	}
    }

    $tunnelExternalUrl=$settings.Horizon.tunnelExternalUrl

    $edgeServiceSettingsVIEW += "{ \'identifier\': \'VIEW\'"
    $edgeServiceSettingsVIEW += ","
    $edgeServiceSettingsVIEW += "\'enabled\': true"
    $edgeServiceSettingsVIEW += ","
    $edgeServiceSettingsVIEW += "\'proxyDestinationUrl\': \'"+$proxyDestinationUrl+"\'"
    if ($proxyDestinationUrlThumbprints.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'proxyDestinationUrlThumbprints\': \'"+$proxyDestinationUrlThumbprints+"\'"
    }

    if ($pcoipExternalUrl.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'pcoipEnabled\':true"
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'pcoipExternalUrl\': \'"+$pcoipExternalUrl+"\'"
    } else {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'pcoipEnabled\':false"
    }

    if ($blastExternalUrl.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'blastEnabled\':true"
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'blastExternalUrl\': \'"+$blastExternalUrl+"\'"
    } else {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'blastEnabled\':false"
    }

    if ($tunnelExternalUrl.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'tunnelEnabled\':true"
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'tunnelExternalUrl\': \'"+$tunnelExternalUrl+"\'"
    } else {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'tunnelEnabled\':false"
    }

    $edgeServiceSettingsVIEW += ","

    if (($settings.Horizon.trustedCert1.length -gt 0) -Or (($settings.Horizon.hostEntry1.length -gt 0))) {

        $trustedCertificates = GetTrustedCertificates "Horizon"
        $edgeServiceSettingsVIEW += $trustedCertificates
        $edgeServiceSettingsVIEW += ","

        $hostEntries = GetHostEntries "Horizon"
        $edgeServiceSettingsVIEW += $hostEntries
        $edgeServiceSettingsVIEW += ","
    }

    if ($settings.Horizon.proxyPattern.length -gt 0) {
        $settings.Horizon.proxyPattern = $settings.Horizon.proxyPattern -replace "\\", "\\\\"
        $edgeServiceSettingsVIEW += "\'proxyPattern\': \'"+$settings.Horizon.proxyPattern+"\'"
    } else {
        $edgeServiceSettingsVIEW += "\'proxyPattern\':\'(/|/view-client(.*)|/portal(.*)|/appblast(.*))\'"
    }

    $authMethods=$settings.Horizon.authMethods
    if ($authMethods.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'authMethods\': \'"+$authMethods+"\'"
    }

    $samlSP=$settings.Horizon.samlSP
    if ($samlSP.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'samlSP\': \'"+$samlSP+"\'"
    }

    $windowsSSOEnabled=$settings.Horizon.windowsSSOEnabled
    if ($windowsSSOEnabled.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'windowsSSOEnabled\': "+$windowsSSOEnabled
    }

    $matchWindowsUserName=$settings.Horizon.matchWindowsUserName
    if ($matchWindowsUserName.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'matchWindowsUserName\': "+$matchWindowsUserName
    }

    $endpointComplianceCheckProvider=$settings.Horizon.endpointComplianceCheckProvider
    if ($endpointComplianceCheckProvider.length -gt 0) {
    	$edgeServiceSettingsVIEW += ","
    	$edgeServiceSettingsVIEW += "\'devicePolicyServiceProvider\': \'"+$endpointComplianceCheckProvider+"\'"
    }


    $edgeServiceSettingsVIEW += "}"
    
    $edgeServiceSettingsVIEW
}

#
# Web Reverse Proxy settings
#

function GetEdgeServiceSettingsWRP {
    Param ($settings, $id)

    $WebReverseProxy = "WebReverseProxy"+$id

    $proxyDestinationUrl=$settings.$WebReverseProxy.proxyDestinationUrl

    if ($proxyDestinationUrl.length -le 0) {
        return
    }

    $edgeServiceSettingsWRP += "{ \'identifier\': \'WEB_REVERSE_PROXY\'"
    $edgeServiceSettingsWRP += ","
    $edgeServiceSettingsWRP += "\'enabled\': true"
    $edgeServiceSettingsWRP += ","

    $instanceId=$settings.$WebReverseProxy.instanceId

    if (!$instanceId) {
        $instanceId=""
    }

    if (!$id) {
        $id=""
    }

    if ($instanceId.length -eq 0) {
        if ($id.length -eq 0) {
            $id="0"
        }
        $instanceId=$id
    }

    $edgeServiceSettingsWRP += "\'instanceId\': \'"+$instanceId+"\'"
    $edgeServiceSettingsWRP += ","

    if (($settings.$WebReverseProxy.trustedCert1.length -gt 0) -Or (($settings.$WebReverseProxy.hostEntry1.length -gt 0))) {

        $trustedCertificates = GetTrustedCertificates $WebReverseProxy
        $edgeServiceSettingsWRP += $trustedCertificates
        $edgeServiceSettingsWRP += ","

        $hostEntries = GetHostEntries $WebReverseProxy
        $edgeServiceSettingsWRP += $hostEntries
        $edgeServiceSettingsWRP += ","
    }

    $edgeServiceSettingsWRP += "\'proxyDestinationUrl\': \'"+$proxyDestinationUrl+"\'"

    $proxyDestinationUrlThumbprints=$settings.$WebReverseProxy.proxyDestinationUrlThumbprints  -replace ":","="

    if ($proxyDestinationUrlThumbprints.length -gt 0) {

        #
        # Remove invalid thumbprint characters
        #

        $proxyDestinationUrlThumbprints = $proxyDestinationUrlThumbprints -replace, "[^a-zA-Z0-9,= ]", ""

    	$edgeServiceSettingsWRP += ","
    	$edgeServiceSettingsWRP += "\'proxyDestinationUrlThumbprints\': \'"+$proxyDestinationUrlThumbprints+"\'"
    }

    if ($settings.$WebReverseProxy.proxyPattern.length -gt 0) {
        $edgeServiceSettingsWRP += ","
        $settings.$WebReverseProxy.proxyPattern = $settings.$WebReverseProxy.proxyPattern -replace "\\", "\\\\"
        $edgeServiceSettingsWRP += "\'proxyPattern\': \'"+$settings.$WebReverseProxy.proxyPattern+"\'"
    } else {
        WriteErrorString "Error: Missing proxyPattern in [WebReverseProxy]."
    	Exit
    }

    if ($settings.$WebReverseProxy.unSecurePattern.length -gt 0) {
        $edgeServiceSettingsWRP += ","
        $edgeServiceSettingsWRP += "\'unSecurePattern\': \'"+$settings.$WebReverseProxy.unSecurePattern+"\'"
    }
    
    if ($settings.$WebReverseProxy.authCookie.length -gt 0) {
        $edgeServiceSettingsWRP += ","
        $edgeServiceSettingsWRP += "\'authCookie\': \'"+$settings.$WebReverseProxy.authCookie+"\'"
    }

    if ($settings.$WebReverseProxy.loginRedirectURL.length -gt 0) {
        $edgeServiceSettingsWRP += ","
        $edgeServiceSettingsWRP += "\'loginRedirectURL\': \'"+$settings.$WebReverseProxy.loginRedirectURL+"\'"
    }
    
    $authMethods=$settings.$WebReverseProxy.authMethods
    if ($authMethods.length -gt 0) {
    	$edgeServiceSettingsWRP += ","
    	$edgeServiceSettingsWRP += "\'authMethods\': \'"+$authMethods+"\'"
    }

    if ($settings.$WebReverseProxy.proxyHostPattern.length -gt 0) {
        $edgeServiceSettingsWRP += ","
        $edgeServiceSettingsWRP += "\'proxyHostPattern\': \'"+$settings.$WebReverseProxy.proxyHostPattern+"\'"
    }

    $edgeServiceSettingsWRP += "}"

    $edgeServiceSettingsWRP
}

#
# Function to prompt the user for an Airwatch password and attempt to validate the input with the
# Airwatch service. If we are not able to validate the password, we allow the user to continue.
# If we positively determine that the password is invalid (Unauthorized), we re-prompt.
#

function GetAirwatchPwd {
    param($apiServerUrl, $apiServerUsername, $organizationGroupCode)

    while (! $valid) {
        $prompt='Enter the Airwatch '+$apiServerUrl+' password for user "'+$apiServerUsername+'" (group code "'+$organizationGroupCode+'")' 
        $pwd = Read-Host -assecurestring $prompt
        if ($pwd.length -eq 0) {
            Continue
        }
        $pwd = ConvertFromSecureToPlain $pwd
        $secpasswd = ConvertTo-SecureString $pwd -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($apiServerUsername, $secpasswd)
        $valid=1
        $uri=$apiServerUrl+"/API/mdm/gateway/configuration?type=VPN&locationgroupcode="+$organizationGroupCode
        try { 
            $response = Invoke-RestMethod -Uri $uri -Method "Post"  -Credential $cred -ContentType "application/json" -Body '{"randomString" : "abc123"}'
        } catch {
            #write-host $_.Exception.Response.StatusCode
            if ($_.Exception.Response.StatusCode -eq "Unauthorized") {
                write-host "Incorrect password"
                $valid=0
            } elseif ($_.Exception.Response.StatusCode -eq "BadRequest") {
                $err='Error: Invalid Airwatch settings '+$apiServerUrl+' user "'+$apiServerUsername+'" (group code "'+$organizationGroupCode+'")'+$_
                Write-error-string $err
                Exit
            } else {
                write-host "Warning: Unable to verify password -" $_
            }
        }
    }

    $pwd
}

#
# Airwatch common settings
# 

function GetEdgeServiceSettingsAWCommon {
    Param ($settings)
    
    $edgeServiceSettingsAWCommon += ","
    $edgeServiceSettingsAWCommon += "\'enabled\': true"
    $edgeServiceSettingsAWCommon += ","
    $edgeServiceSettingsAWCommon += "\'proxyDestinationUrl\': \'https://null\'"
    $edgeServiceSettingsAWCommon += ","
    $apiServerUrl = $settings.Airwatch.apiServerUrl
    
    $edgeServiceSettingsAWCommon += "\'apiServerUrl\': \'"+$apiServerUrl+"\'"
    $edgeServiceSettingsAWCommon += ","
    $apiServerUsername = $settings.Airwatch.apiServerUsername
    $apiServerUsername = $apiServerUsername -replace '\\', '\\\\’
    $edgeServiceSettingsAWCommon += "\'apiServerUsername\': \'"+$apiServerUsername+"\'"

    $pwd = GetAirwatchPwd $settings.Airwatch.apiServerUrl $settings.Airwatch.apiServerUsername $settings.Airwatch.organizationGroupCode
    if ($pwd.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $edgeServiceSettingsAWCommon += "\'apiServerPassword\': \'"+$pwd+"\'"
    }
    $edgeServiceSettingsAWCommon += ","
    $edgeServiceSettingsAWCommon += "\'organizationGroupCode\': \'"+$settings.Airwatch.organizationGroupCode+"\'"
    $edgeServiceSettingsAWCommon += ","
    $edgeServiceSettingsAWCommon += "\'airwatchServerHostname\': \'"+$settings.Airwatch.airwatchServerHostname+"\'"
    $edgeServiceSettingsAWCommon += ","

    $edgeServiceSettingsAWCommon += "\'airwatchAgentStartUpMode\': \'install\'"
    
    if ($settings.Airwatch.reinitializeGatewayProcess.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $edgeServiceSettingsAWCommon += "\'reinitializeGatewayProcess\': \'"+$settings.Airwatch.reinitializeGatewayProcess+"\'"
    }

    if ($settings.Airwatch.airwatchOutboundProxy.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $edgeServiceSettingsAWCommon += "\'airwatchOutboundProxy\': \'"+$settings.Airwatch.airwatchOutboundProxy+"\'"
    }

    if ($settings.Airwatch.outboundProxyPort.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $edgeServiceSettingsAWCommon += "\'outboundProxyPort\': \'"+$settings.Airwatch.outboundProxyPort+"\'"
    }

    if ($settings.Airwatch.outboundProxyHost.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $edgeServiceSettingsAWCommon += "\'outboundProxyHost\': \'"+$settings.Airwatch.outboundProxyHost+"\'"
    }

    if ($settings.Airwatch.outboundProxyUsername.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $outboundProxyUsername = $settings.Airwatch.outboundProxyUsername
        $outboundProxyUsername = $outboundProxyUsername -replace '\\', '\\\\’
        $edgeServiceSettingsAWCommon += "\'outboundProxyUsername\': \'"+$outboundProxyUsername+"\'"

        $pwd = Read-Host -assecurestring "Enter the password for the Airwatch tunnel outbound proxy server"
        $pwd = ConvertFromSecureToPlain $pwd
        if ($pwd.length -gt 0) {
            $edgeServiceSettingsAWCommon += ","
            $edgeServiceSettingsAWCommon += "\'outboundProxyPassword\': \'"+$pwd+"\'"
        }
    }

    if ($settings.Airwatch.ntlmAuthentication.length -gt 0) {
        $edgeServiceSettingsAWCommon += ","
        $edgeServiceSettingsAWCommon += "\'ntlmAuthentication\': \'"+$settings.Airwatch.ntlmAuthentication+"\'"
    }
   
    $edgeServiceSettingsAWCommon
}

#
# Airwatch Tunnel Gateway settings
# 

function GetEdgeServiceSettingsAWTGateway {
    Param ($settings, $edgeServiceSettingsAWCommon)
        
    if ($settings.Airwatch.tunnelGatewayEnabled -ne "true") {
        return
    }
    
    $edgeServiceSettingsAWTGateway += "{ \'identifier\': \'TUNNEL_GATEWAY\'"
    $edgeServiceSettingsAWTGateway += ","
    $edgeServiceSettingsAWTGateway += "\'airwatchComponentsInstalled\':\'TUNNEL\'"
    $edgeServiceSettingsAWTGateway += $edgeServiceSettingsAWCommon

    if (($settings.Airwatch.trustedCert1.length -gt 0) -Or (($settings.Airwatch.hostEntry1.length -gt 0))) {
        $trustedCertificates = GetTrustedCertificates "Airwatch"
        $edgeServiceSettingsAWTGateway += ","
        $edgeServiceSettingsAWTGateway += $trustedCertificates

        $hostEntries = GetHostEntries "Airwatch"
        $edgeServiceSettingsAWTGateway += ","
        $edgeServiceSettingsAWTGateway += $hostEntries
    }
    $edgeServiceSettingsAWTGateway += "}"

    $edgeServiceSettingsAWTGateway 
}

#
# Airwatch Tunnel Proxy settings
# 

function GetEdgeServiceSettingsAWTProxy {
    Param ($settings, $edgeServiceSettingsAWCommon)
    
    if ($settings.Airwatch.tunnelProxyEnabled -ne "true") {
        return
    }
    
    $edgeServiceSettingsAWTProxy += "{ \'identifier\': \'TUNNEL_PROXY\'"
    $edgeServiceSettingsAWTProxy += ","
    $edgeServiceSettingsAWTProxy += "\'airwatchComponentsInstalled\':\'TUNNEL\'"
    $edgeServiceSettingsAWTProxy += $edgeServiceSettingsAWCommon
    $edgeServiceSettingsAWTProxy += "}"
    
    $edgeServiceSettingsAWTProxy 
}
    
#
# Airwatch SEG settings
# 

function GetEdgeServiceSettingsAWSEG {
    Param ($settings, $edgeServiceSettingsAWCommon)
    
    if ($settings.Airwatch.segEnabled -ne "true") {
        return
    }
    
    $edgeServiceSettingsAWSEG += "{ \'identifier\': \'SEG\'"
    $edgeServiceSettingsAWSEG += ","
    $edgeServiceSettingsAWSEG += "\'airwatchComponentsInstalled\':\'SEG\'"
    $edgeServiceSettingsAWSEG += $edgeServiceSettingsAWCommon

    if ($settings.Airwatch.memConfigId.length -gt 0) {
        $edgeServiceSettingsAWSEG += ","
        $edgeServiceSettingsAWSEG += "\'memConfigurationId\': \'"+$settings.Airwatch.memConfigId+"\'"
    }

    $edgeServiceSettingsAWSEG += "}"
    
    $edgeServiceSettingsAWSEG 
}

function GetAuthMethodSettingsCertificate {
    Param ($settings)
 
    $CertificateAuthCertsFile=$settings.CertificateAuth.pemCerts

    if ($CertificateAuthCertsFile.length -le 0) {
        return
    }

	if (!(Test-path $CertificateAuthCertsFile)) {
		WriteErrorString "Error: PEM Certificate file not found ($CertificateAuthCertsFile)"
		Exit
	}

	$CertificateAuthCerts = (Get-Content $CertificateAuthCertsFile | Out-String) -replace "`r`n", "\\n" 

	if ($CertificateAuthCerts -like "*-----BEGIN CERTIFICATE-----*") {
		Write-host Deployment will use the specified Certificate Auth PEM file
	} else {
		WriteErrorString "Error: Invalid PEM file ([CertificateAuth] pemCerts) specified. It must contain -----BEGIN CERTIFICATE-----."
		Exit
	}

	$authMethodSettingsCertificate += "{ \'name\': \'certificate-auth\'"
	$authMethodSettingsCertificate += ","
	$authMethodSettingsCertificate += "\'enabled\': true"

    if ($settings.CertificateAuth.enableCertRevocation -eq "true") {
    	$authMethodSettingsCertificate += ","
	    $authMethodSettingsCertificate += "\'enableCertRevocation\': \'true\'"
    }

    if ($settings.CertificateAuth.enableCertCRL -eq "true") {
    	$authMethodSettingsCertificate += ","
	    $authMethodSettingsCertificate += "\'enableCertCRL\': \'true\'"
    }

    if ($settings.CertificateAuth.crlLocation.length -gt 0) {
    	$authMethodSettingsCertificate += ","
	    $authMethodSettingsCertificate += "\'crlLocation\': \'"+$settings.CertificateAuth.crlLocation+"\'"
    }

    if ($settings.CertificateAuth.crlCacheSize.length -gt 0) {
    	$authMethodSettingsCertificate += ","
	    $authMethodSettingsCertificate += "\'crlCacheSize\': \'"+$settings.CertificateAuth.crlCacheSize+"\'"
    }
    
	$authMethodSettingsCertificate += ","
	$authMethodSettingsCertificate += "\'caCertificates\': \'"
	$authMethodSettingsCertificate += $CertificateAuthCerts
	$authMethodSettingsCertificate += "\'"
	$authMethodSettingsCertificate += "}"

    $authMethodSettingsCertificate
}

function GetAuthMethodSettingsSecurID {
    Param ($settings)
    $securidServerConfigFile=$settings.SecurIDAuth.serverConfigFile

    if ($securidServerConfigFile.length -le 0) {
        return
    }

	if (!(Test-path $securidServerConfigFile)) {
		WriteErrorString "Error: SecurID config file not found ($securidServerConfigFile)"
		Exit
	}

	$Content = Get-Content -Path $securidServerConfigFile -Encoding Byte
	$securidServerConfigB64 = [System.Convert]::ToBase64String($Content)

	$authMethodSettingsSecurID += "{ \'name\': \'securid-auth\'"
	$authMethodSettingsSecurID += ","
	$authMethodSettingsSecurID += "\'enabled\': true"

	$numIterations=$settings.SecurIDAuth.numIterations
	$authMethodSettingsSecurID += ","
	if ($numIterations.length -gt 0) {
		$authMethodSettingsSecurID += "\'numIterations\':  \'"+$numIterations+"\'"
	} else {
		$authMethodSettingsSecurID += "\'numIterations\': \'5\'"
	}

	$externalHostName=$settings.SecurIDAuth.externalHostName
	$authMethodSettingsSecurID += ","
	if ($externalHostName.length -gt 0) {
		$authMethodSettingsSecurID += "\'externalHostName\':  \'"+$externalHostName+"\'"
	}

	$internalHostName=$settings.SecurIDAuth.internalHostName
	$authMethodSettingsSecurID += ","
	if ($internalHostName.length -gt 0) {
		$authMethodSettingsSecurID += "\'internalHostName\':  \'"+$internalHostName+"\'"
	}

	$authMethodSettingsSecurID += ","
	$authMethodSettingsSecurID += "\'serverConfig\': \'"
	$authMethodSettingsSecurID += $securidServerConfigB64
	$authMethodSettingsSecurID += "\'"
	$authMethodSettingsSecurID += "}"

    $authMethodSettingsSecurID
}

function GetRADIUSSharedSecret {
    param($hostName)

    while (1) {
        $prompt='Enter the RADIUS server shared secret for host '+$hostName 
        $pwd = Read-Host -assecurestring $prompt

        if ($pwd.length -gt 0) {
            $pwd = ConvertFromSecureToPlain $pwd
            Break
        }
    }

    $pwd
}

function GetAuthMethodSettingsRADIUS {
    Param ($settings)

	$hostName=$settings.RADIUSAuth.hostName

	if ($hostName.length -le 0) {
        return
    }

	$authMethodSettingsRADIUS += "{ \'name\': \'radius-auth\'"
	$authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'enabled\': true"
	$authMethodSettingsRADIUS += ","
    $authMethodSettingsRADIUS += "\'hostName\':  \'"+$hostName+"\'"
	$authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'displayName\':  \'RadiusAuthAdapter\'"

    $sharedSecret = GetRADIUSSharedSecret $settings.RADIUSAuth.hostName
    $authMethodSettingsRADIUS += ","
	$authMethodSettingsRADIUS += "\'sharedSecret\':  \'"+$sharedSecret+"\'"

    $authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.authType.length -gt 0) {
    	$authMethodSettingsRADIUS += "\'authType\':  \'"+$settings.RADIUSAuth.authType+"\'"
    } else {
    	$authMethodSettingsRADIUS += "\'authType\':  \'PAP\'"
    }

    $authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.authPort.length -gt 0) {
		$authMethodSettingsRADIUS += "\'authPort\':  \'"+$settings.RADIUSAuth.authPort+"\'"
    } else {
 		$authMethodSettingsRADIUS += "\'authPort\':  \'1812\'"
    }

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.radiusDisplayHint.length -gt 0) {
		$authMethodSettingsRADIUS += "\'radiusDisplayHint\':  \'"+$settings.RADIUSAuth.radiusDisplayHint+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'radiusDisplayHint\': \'two-factor\'"
	}

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.numIterations.length -gt 0) {
		$authMethodSettingsRADIUS += "\'numIterations\':  \'"+$settings.RADIUSAuth.numIterations+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'numIterations\': \'5\'"
	}

	if ($settings.RADIUSAuth.accountingPort.length -gt 0) {
    	$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'accountingPort\':  \'"+$settings.RADIUSAuth.accountingPort+"\'"
    }

  	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.serverTimeout.length -gt 0) {
		$authMethodSettingsRADIUS += "\'serverTimeout\':  \'"+$settings.RADIUSAuth.serverTimeout+"\'"
    } else {
		$authMethodSettingsRADIUS += "\'serverTimeout\':  \'5\'"
    }

	if ($settings.RADIUSAuth.realmPrefix.length -gt 0) {
    	$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'realmPrefix\':  \'"+$settings.RADIUSAuth.realmPrefix+"\'"
    }

	if ($settings.RADIUSAuth.realmSuffix.length -gt 0) {
    	$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'realmSuffix\':  \'"+$settings.RADIUSAuth.realmSuffix+"\'"
    }

	$authMethodSettingsRADIUS += ","
	if ($settings.RADIUSAuth.numAttempts.length -gt 0) {
		$authMethodSettingsRADIUS += "\'numAttempts\':  \'"+$settings.RADIUSAuth.numAttempts+"\'"
	} else {
		$authMethodSettingsRADIUS += "\'numAttempts\': \'3\'"
	}

	if ($settings.RADIUSAuth.hostName_2.length -gt 0) {
    	$authMethodSettingsRADIUS += ","
		$authMethodSettingsRADIUS += "\'hostName_2\':  \'"+$settings.RADIUSAuth.hostName_2+"\'"

        $authMethodSettingsRADIUS += ","
	    if ($settings.RADIUSAuth.authType_2.length -gt 0) {
    	    $authMethodSettingsRADIUS += "\'authType_2\':  \'"+$settings.RADIUSAuth.authType_2+"\'"
        } else {
    	    $authMethodSettingsRADIUS += "\'authType_2\':  \'PAP\'"
        }

        $authMethodSettingsRADIUS += ","
	    if ($settings.RADIUSAuth.authPort_2.length -gt 0) {
		    $authMethodSettingsRADIUS += "\'authPort_2\':  \'"+$settings.RADIUSAuth.authPort_2+"\'"
        } else {
 		    $authMethodSettingsRADIUS += "\'authPort_2\':  \'1812\'"
        }

        if ($settings.RADIUSAuth.accountingPort_2.length -gt 0) {
    	    $authMethodSettingsRADIUS += ","
		    $authMethodSettingsRADIUS += "\'accountingPort_2\':  \'"+$settings.RADIUSAuth.accountingPort_2+"\'"
        }

	    $authMethodSettingsRADIUS += ","
	    if ($settings.RADIUSAuth.numAttempts_2.length -gt 0) {
		    $authMethodSettingsRADIUS += "\'numAttempts_2\':  \'"+$settings.RADIUSAuth.numAttempts_2+"\'"
	    } else {
		    $authMethodSettingsRADIUS += "\'numAttempts_2\': \'3\'"
	    }

        $sharedSecret_2 = GetRADIUSSharedSecret $settings.RADIUSAuth.hostName_2
   	    $authMethodSettingsRADIUS += ","
	    $authMethodSettingsRADIUS += "\'sharedSecret_2\':  \'"+$sharedSecret_2+"\'"

	    if ($settings.RADIUSAuth.realmPrefix_2.length -gt 0) {
    	    $authMethodSettingsRADIUS += ","
		    $authMethodSettingsRADIUS += "\'realmPrefix_2\':  \'"+$settings.RADIUSAuth.realmPrefix_2+"\'"
        }

	    if ($settings.RADIUSAuth.realmSuffix_2.length -gt 0) {
    	    $authMethodSettingsRADIUS += ","
		    $authMethodSettingsRADIUS += "\'realmSuffix_2\':  \'"+$settings.RADIUSAuth.realmSuffix_2+"\'"
        }

      	$authMethodSettingsRADIUS += ","
    	if ($settings.RADIUSAuth.serverTimeout_2.length -gt 0) {
	    	$authMethodSettingsRADIUS += "\'serverTimeout_2\':  \'"+$settings.RADIUSAuth.serverTimeout_2+"\'"
        } else {
		    $authMethodSettingsRADIUS += "\'serverTimeout_2\':  \'5\'"
        }

        $authMethodSettingsRADIUS += ","
        $authMethodSettingsRADIUS += "\'enabledAux\': true"

    }

	$authMethodSettingsRADIUS += "}"

    $authMethodSettingsRADIUS
}

#
# Get UAG system settings
#

function GetSystemSettings {
    Param ($settings)

    $systemSettings = "\'systemSettings\':"
    $systemSettings += "{"
    $systemSettings += "\'locale\': \'en_US\'"

    if ($settings.General.cipherSuites.length -gt 0) {
        $systemSettings += ","
        $systemSettings += "\'cipherSuites\': \'"+$settings.General.cipherSuites+"\'"
    } else {
        if ($settings.General.source -like "*-fips-*") {
            $systemSettings += ", "
            $systemSettings += "\'cipherSuites\': \'TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA\'"
        } else {
            $systemSettings += ", "
            $systemSettings += "\'cipherSuites\': \'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA\'"
        }
    }

    if ($settings.General.ssl30Enabled -eq "true" ) {
        $systemSettings += ","
        $systemSettings += "\'ssl30Enabled\': \'true\'"
    } else {
        $systemSettings += ","
        $systemSettings += "\'ssl30Enabled\': \'false\'"
    }

    if ($settings.General.tls10Enabled -eq "true" ) {
        $systemSettings += ","
        $systemSettings += "\'tls10Enabled\': \'true\'"
    } else {
        $systemSettings += ","
        $systemSettings += "\'tls10Enabled\': \'false\'"
    }

    if ($settings.General.tls11Enabled.length -gt 0 ) {
        $systemSettings += ","
        $systemSettings += "\'tls11Enabled\': \'"+$settings.General.tls11Enabled+"\'"
    } else {
        if ($settings.General.source -like "*-fips-*") {
            $systemSettings += ","
            $systemSettings += "\'tls11Enabled\': \'false\'"
        } else {
            $systemSettings += ","
            $systemSettings += "\'tls11Enabled\': \'true\'"
        }
    }

    if ($settings.General.tls12Enabled -eq "false" ) {
        $systemSettings += ","
        $systemSettings += "\'tls12Enabled\': \'false\'"
    } else {
        $systemSettings += ","
        $systemSettings += "\'tls12Enabled\': \'true\'"
    }

 #   if ($settings.General.source -like "*-fips-*") {
 #       $systemSettings += "\'cipherSuites\': \'TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA\'"
 #       $systemSettings += ", "
 #       $systemSettings += "\'ssl30Enabled\': false, \'tls10Enabled\': false, \'tls11Enabled\': false, \'tls12Enabled\': true"
 #   } else {
 #       $systemSettings += "\'cipherSuites\': \'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA\'"
 #       $systemSettings += ", "
 #       $systemSettings += "\'ssl30Enabled\': false, \'tls10Enabled\': false, \'tls11Enabled\': true, \'tls12Enabled\': true"
 #   }
 
    if ($settings.WebReverseProxy.proxyDestinationUrl.length -gt 0) {
        $systemSettings += ", "
        $systemSettings += "\'cookiesToBeCached\': \'none\'"
    }
    if ($settings.General.sessionTimeout.length -gt 0) {
        $systemSettings += ","
        $systemSettings += "\'sessionTimeout\': \'"+$settings.General.sessionTimeout+"\'"
    }
    if ($settings.General.honorCipherOrder -eq "true") {
        $systemSettings += ", "
        $systemSettings += "\'honorCipherOrder\': \'true\'"
    }
    if ($settings.General.syslogUrl.length -gt 0) {
        $systemSettings += ","
        $systemSettings += "\'syslogUrl\': \'"+$settings.General.syslogUrl+"\'"
    }
    if ($settings.General.syslogAuditUrl.length -gt 0) {
        $systemSettings += ","
        $systemSettings += "\'syslogAuditUrl\': \'"+$settings.General.syslogAuditUrl+"\'"
    }
    if ($settings.General.adminPasswordExpirationDays.length -gt 0) {
        $systemSettings += ","
        $systemSettings += "\'adminPasswordExpirationDays\': \'"+$settings.General.adminPasswordExpirationDays+"\'"
    }

    $systemSettings += "}"

    $systemSettings
}

#
# UAG Edge service settings
#

function GetEdgeServiceSettings {
    Param ($settings)

    $edgeCount = 0

    $edgeServiceSettings = "\'edgeServiceSettingsList\':"
    $edgeServiceSettings += "{ \'edgeServiceSettingsList\': ["

    #
    # Horizon View edge service
    #

    $edgeServiceSettingsVIEW += GetEdgeServiceSettingsVIEW($settings)
    if ($edgeServiceSettingsVIEW.length -gt 0) {
        $edgeServiceSettings += $edgeServiceSettingsVIEW
        $edgeCount++
    }

    #
    # Web Reverse Proxy edge services
    #

    for ($i=0; $i -lt 100; $i++) {

        if ($i -eq 0) {
            $id=""
        } else {
            $id=$i
        }
        $edgeServiceSettingsWRP = ""

        $edgeServiceSettingsWRP += GetEdgeServiceSettingsWRP $settings $id
        if ($edgeServiceSettingsWRP.length -gt 0) {
            if ($edgeCount -gt 0) {
                $edgeServiceSettings += ", "
            }
            $edgeServiceSettings += $edgeServiceSettingsWRP
            $edgeCount++
        }
    }

    if (($settings.AirwatchTunnel.tunnelGatewayEnabled -eq "true") -or ($settings.AirwatchTunnel.tunnelProxyEnabled -eq "true")) {
		WriteErrorString "Error: Invalid .INI file. Please rename group name [AirwatchTunnel] to [Airwatch] and run the command again."
		Exit
    }

    if (($settings.Airwatch.tunnelGatewayEnabled -eq "true") -or ($settings.Airwatch.tunnelProxyEnabled -eq "true") -or ($settings.Airwatch.segEnabled -eq "true")) {

        $edgeServiceSettingsAWCommon += GetEdgeServiceSettingsAWCommon($settings)

        #
        # Airwatch Tunnel Gateway edge service
        #

        $edgeServiceSettingsAWTGateway += GetEdgeServiceSettingsAWTGateway $settings $edgeServiceSettingsAWCommon

        if ($edgeServiceSettingsAWTGateway.length -gt 0) {
    	    if ($edgeCount -gt 0) {
                $edgeServiceSettings += ", "
            }
            $edgeServiceSettings += $edgeServiceSettingsAWTGateway
            $edgeCount++
        }

        #
        # Airwatch Tunnel Proxy edge service
        #

        $edgeServiceSettingsAWTProxy += GetEdgeServiceSettingsAWTProxy $settings $edgeServiceSettingsAWCommon
    
        if ($edgeServiceSettingsAWTProxy.length -gt 0) {
    	    if ($edgeCount -gt 0) {
                $edgeServiceSettings += ", "
            }
            $edgeServiceSettings += $edgeServiceSettingsAWTProxy
            $edgeCount++
        }

        #
        # Airwatch SEG edge service
        #

        $edgeServiceSettingsAWSEG += GetEdgeServiceSettingsAWSEG $settings $edgeServiceSettingsAWCommon
    
        if ($edgeServiceSettingsAWSEG.length -gt 0) {
    	    if ($edgeCount -gt 0) {
                $edgeServiceSettings += ", "
            }
            $edgeServiceSettings += $edgeServiceSettingsAWSEG
            $edgeCount++
        }
    }

    $edgeServiceSettings += "] }"

    $edgeServiceSettings
}

#
# Auth Method settings
#

function GetAuthMethodSettings {
    Param ($settings)

    $authMethodSettingsCertificate = GetAuthMethodSettingsCertificate($settings)

    $authMethodSettingsSecurID = GetAuthMethodSettingsSecurID($settings)

    $authMethodSettingsRADIUS = GetAuthMethodSettingsRADIUS($settings)

    $authMethodSettings = "\'authMethodSettingsList\':"
    $authMethodSettings += "{ \'authMethodSettingsList\': ["

    $authCount=0

    if ($authMethodSettingsCertificate.length -gt 0) {
	    $authMethodSettings += $authMethodSettingsCertificate
	    $authCount++
    }

    if ($authMethodSettingsSecurID.length -gt 0) {
	    if ($authCount -gt 0) {
		    $authMethodSettings += ","
	    }
	    $authMethodSettings += $authMethodSettingsSecurID
	    $authCount++
    }

    if ($authMethodSettingsRADIUS.length -gt 0) {
	    if ($authCount -gt 0) {
		    $authMethodSettings += ","
	    }
	    $authMethodSettings += $authMethodSettingsRADIUS
	    $authCount++
    }

    $authMethodSettings += "] }"

    $authMethodSettings
}

function GetDevicePolicySettings {
    Param ($settings)

    if ($settings.OpswatEndpointComplianceCheckSettings.clientKey.length -gt 0) {

        $devicePolicySettings = "\'devicePolicySettingsList\':"
        $devicePolicySettings += "{ \'devicePolicySettingsList\': ["
        $devicePolicySettings += "{"

 
        $devicePolicySettings += "\'name\':  \'OPSWAT\'"
        $devicePolicySettings += ", "
        $devicePolicySettings += "\'userName\':  \'"+$settings.OpswatEndpointComplianceCheckSettings.clientKey+"\'"

        if ($settings.OpswatEndpointComplianceCheckSettings.clientSecret.length -gt 0) {
            $devicePolicySettings += ", "
            $devicePolicySettings += "\'password\':  \'"+$settings.OpswatEndpointComplianceCheckSettings.clientSecret+"\'"
        } else {
            WriteErrorString "Error: Invalid .INI file. Missing clientSecret value in [OpswatEndpointComplianceCheckSettings]."
		    Exit
        }

        if ($settings.OpswatEndpointComplianceCheckSettings.hostName.length -gt 0) {
            $devicePolicySettings += ", "
            $devicePolicySettings += "\'hostName\':  \'"+$settings.OpswatEndpointComplianceCheckSettings.hostName+"\'"
        }
    
        $devicePolicySettings += "} ] }"
    }

    $devicePolicySettings

}

function GetJSONSettings {
    Param ($settings)

    $settingsJSON = "{"

    $certificateWrapper = GetCertificateWrapper ($settings)
    if ($certificateWrapper.length -gt 0) {
        $settingsJSON += $certificateWrapper
        $settingsJSON += ", "
    }

    $certificateWrapperAdmin = GetCertificateWrapper $settings "Admin"
    if ($certificateWrapperAdmin.length -gt 0) {
        $settingsJSON += $certificateWrapperAdmin
        $settingsJSON += ", "
    }
    
    $systemSettings = GetSystemSettings ($settings)

    $edgeServiceSettings = GetEdgeServiceSettings ($settings)

    $authMethodSettings = GetAuthMethodSettings ($settings)
        
    $samlServiceProviderMetadata = GetSAMLServiceProviderMetadata ($settings)

    $samlIdentityProviderMetadata = GetSAMLIdentityProviderMetadata ($settings)

    $devicePolicySettings = GetDevicePolicySettings ($settings)
    if ($devicePolicySettings.length -gt 0) {
        $settingsJSON += $devicePolicySettings
        $settingsJSON += ", "
    }

    $settingsJSON += $edgeServiceSettings+", "+$systemSettings+", "+$authMethodSettings+", "+$samlServiceProviderMetadata+", "+$samlIdentityProviderMetadata+"}"

    $settingsJSON = $settingsJSON -replace "'", '"'

    $settingsJSON

}

function AddKVPUnit {
    param($VMName, $key, $value)
    
    #
    # Add Key-Value Pairs for the VM
    #

    #if ($key.Contains("Password")) {
    #    Write-Host "Setting $key=******"
    #} else {
    #    Write-Host "Setting $key=$value"
    #}

    $VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService
    $Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }  #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter {ElementName='TEST-APP38'}     # has to be same as $VMName

    $kvpDataItem = ([WMIClass][String]::Format("\\{0}\{1}:{2}", $VmMgmt.ClassPath.Server, $VmMgmt.ClassPath.NamespacePath, "Msvm_KvpExchangeDataItem")).CreateInstance()
    $null=$KvpItem.psobject.properties
    $kvpDataItem.Name = $key
    $kvpDataItem.Data = $value
    $kvpDataItem.Source = 0
    $result = $VmMgmt.AddKvpItems($Vm, $kvpDataItem.PSBase.GetText(1))

    $job = [wmi]$result.Job

    if (!$job) {
        WriteErrorString "Error: Failed to set KVP $key on $VMName"
        Return
    }    

    if ($job) {
        $job.get()
        #write-host $job.jobstate
        #write-host $job.SystemProperties.Count.ToString()
    }

    while($job.jobstate -lt 7) {
	    $job.get()
        Start-Sleep -Seconds 2
    } 

    if ($job.ErrorCode -ne 0) {
        WriteErrorString "Error: Failed to set KVP $key on $VMName (error code $($job.ErrorCode))"
        Return
    }    
    
    if ($job.Status -ne "OK") {
        WriteErrorString "Error: Failed to set KVP $key on $VMName (status $job.Status)"
        Return
    }

    $job
}

function GetKVP {
    param($VMName, $key)

    $VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService
    $Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }  #Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter {ElementName='TEST-APP38'}     # has to be same as $VMName

    $n = $vm.GetRelated("Msvm_KvpExchangeComponent").GuestIntrinsicExchangeItems
    $n = $vm.GetRelated("Msvm_KvpExchangeComponent").GuestExchangeItems

    $n = $vm.GetRelated("Msvm_KvpExchangeComponent").GetRelated('Msvm_KvpExchangeComponentSettingData').HostExchangeItems

    $n | % {
        $GuestExchangeItemXml = ([XML]$_).SelectSingleNode(`
            "/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text()='$key']")

        if ($GuestExchangeItemXml -ne $null)
        {
            $val = $GuestExchangeItemXml.SelectSingleNode( `
                "/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value
                $val
                Return
        }
    }
}

function AddKVP {
    param($VMName, $key, $value)
    $max = 1000
    $len=$value.length
    $index=0
    if ($len -le $max) {
        $job=AddKVPUnit $VMName $key $value
    } else {
        for ($i=0; $i -lt $len; $i += $max) {
            $chunkSize = [Math]::Min($max, ($len - $i))
            $valueChunk=$value.Substring($i, $chunkSize)
            $keyChunk=$key+"."+$index.ToString(0)
            $job=AddKVPUnit $VMName $keyChunk $valueChunk
            $index++
        }
    }
    $job
}

function DeleteKVP {
    param($VMName, $key)

    $VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService
    $Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }

    $kvpDataItem = ([WMIClass][String]::Format("\\{0}\{1}:{2}", $VmMgmt.ClassPath.Server, $VmMgmt.ClassPath.NamespacePath, "Msvm_KvpExchangeDataItem")).CreateInstance()
    $null=$KvpItem.psobject.properties
    $kvpDataItem.Name = $key
    $kvpDataItem.Data = [String]::Empty
    $kvpDataItem.Source = 0
    $result = $VmMgmt.RemoveKvpItems($Vm, $kvpDataItem.PSBase.GetText(1))

    $job = [wmi]$result.Job

    if (!$job) {
        WriteErrorString "Error: Failed to set KVP $key on $VMName"
        Return
    }    

    if ($job) {
        $job.get()
        #write-host $job.jobstate
        #write-host $job.SystemProperties.Count.ToString()
    }

    while($job.jobstate -lt 7) {
	    $job.get()
        Start-Sleep -Seconds 2
    } 

    if ($job.ErrorCode -ne 0) {
        WriteErrorString "Error: Failed to set KVP $key on $VMName (error code $($job.ErrorCode))"
        Return
    }    
    
    if ($job.Status -ne "OK") {
        WriteErrorString "Error: Failed to set KVP $key on $VMName (status $job.Status)"
        Return
    }

    $job
}

function DeleteKVPAll {
    param($VMName)

    $VmMgmt = gwmi -n "Root\Virtualization\V2" Msvm_VirtualSystemManagementService
    $Vm = gwmi -n "root\virtualization\v2" Msvm_ComputerSystem|?{$_.ElementName -eq $VMName }

    $hostExchangeItems = $vm.GetRelated("Msvm_KvpExchangeComponent").GetRelated('Msvm_KvpExchangeComponentSettingData').HostExchangeItems

    $hostExchangeItems | % {

    $GuestExchangeItemXml = ([XML]$_).SelectSingleNode(`
        "/INSTANCE/PROPERTY[@NAME='Name']/VALUE")
        $key = $GuestExchangeItemXml.InnerText

        if ($key.length -gt 0) {
            $job = DeleteKVP $VMName $key
        }      
    }
}

function IsVMDeployed {
    param ($VMName, $ipAddress)
    #
    # WE consider the VM to be deployed if we can obtain an IP address from it and the ip address matches what is configured.
    #

    $out=Get-VM $VMName | ?{$_.ReplicationMode -ne “Replica”} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
    if ($ipAddress.length -gt 0) {
        #static IP address
        if (($out.IPAddresses)[0] -eq $ipAddress) {
            return $true
        }
    } else {
        #DHCP
        if  ((($out.IPAddresses)[0]).length -gt 0) {
            $wait = 0
            #sleep for 4 mins (240 secs) to give time for the appliance to be ready
            while ($wait -le 240) {
                Write-Host -NoNewline "."
                $wait += 2
                Start-Sleep -Seconds 2
            }
            return $true
        }
    }

    return $false
}

function IsVMUp {
    param ($VMName, [ref]$ipAddress)

    #
    # WE consider the VM to be up if we can obtain an IP address from it.
    #

    $out=Get-VM $VMName | ?{$_.ReplicationMode -ne “Replica”} | Select -ExpandProperty NetworkAdapters | Select IPAddresses
    if ($out.IPAddresses.Length -gt 0) {
        $ipAddress = ($out.IPAddresses)[0]
        return $true
    }

    return $false
}

function GetNetOptions {
    Param ($settings, $nic)

    $ipModeLabel = "ipMode" + $nic
    $ipMode = $settings.General.$ipModeLabel
    
    $ipLabel = "ip" + $nic
    $ip=$settings.General.$ipLabel

    $netmaskLabel = "netmask" + $nic
    $netmask=$settings.General.$netmaskLabel

    $v6ipLabel = "v6ip" + $nic
    $v6ip=$settings.General.$v6ipLabel

    $v6ipprefixLabel = "v6ipprefix" + $nic
    $v6ipprefix=$settings.General.$v6ipprefixLabel

    #
    # IPv4 address must have a netmask
    #

    if (($ip.length -gt 0) -and ($netmask.length -eq 0)) {
        WriteErrorString "Error: missing value $netmaskLabel."
        Exit
    }

    #
    # IPv6 address must have a prefix
    #

    if (($v6ip.length -gt 0) -and ($v6ipprefix.length -eq 0)) {
        WriteErrorString "Error: missing value $v6ipprefixLabel."
        Exit
    }

    #
    # If ipMode is not specified, assign a default
    #

    if ($ipMode.length -eq 0) {

        $ipMode = "DHCPV4"

        if (($ip.length -gt 0) -and ($v6ip.length -eq 0)) {
            $ipMode = "STATICV4"
        }

        if (($ip.length -eq 0) -and ($v6ip.length -gt 0)) {
            $ipMode = "STATICV6"
        }

        if (($ip.length -gt 0) -and ($v6ip.length -gt 0)) {
            $ipMode = "STATICV4+STATICV6"
        }
    }

    #
    # Assign network properties based on the 11 supported combinations
    #

    switch ($ipMode) {

           
        { ($_ -eq "DHCPV4") -or ($_ -eq "DHCPV4+DHCPV6") -or ($_ -eq "DHCPV4+AUTOV6") -or ($_ -eq "DHCPV6") -or ($_ -eq "AUTOV6") } {

            #
            # No addresses required
            #

            $options = " --prop:ipMode$nic='"+$ipMode+"'"
            $options
            return
        }

        { ($_ -eq "STATICV6") -or ($_ -eq "DHCPV4+STATICV6") } {

            #
            # IPv6 address and prefix required
            #

           if ($v6ip.length -eq 0) {
               WriteErrorString "Error: missing value $v6ipLabel."
               Exit
           }
           $options = " --prop:ipMode$nic='"+$ipMode+"' --prop:v6ip$nic='"+$v6ip+"' --prop:forceIpv6Prefix$nic='"+$v6ipprefix+"'"
           $options
           return
        }

        { ($_ -eq "STATICV4") -or ($_ -eq "STATICV4+DHCPV6") -or ($_ -eq "STATICV4+AUTOV6") } {

            #
            # IPv4 address and netmask required
            #

           if ($ip.length -eq 0) {
               WriteErrorString "Error: missing value $ipLabel."
               Exit
           }
           $options = " --prop:ipMode$nic='"+$ipMode+"' --prop:ip$nic='"+$ip+"' --prop:forceNetmask$nic='"+$netmask+"'"
           $options
           return
        }

        { "STATICV4+STATICV6" } {

            #
            # IPv4 address, netmask, IPv6 address and prefix required
            #

           if ($ip.length -eq 0) {
               WriteErrorString "Error: missing value $ipLabel."
               Exit
           }
           if ($v6ip.length -eq 0) {
               WriteErrorString "Error: missing value $v6ipLabel."
               Exit
           }
           $options = " --prop:ipMode$nic='"+$ipMode+"'  --prop:ip$nic='"+$ip+"' --prop:forceNetmask$nic='"+$netmask+"' --prop:v6ip$nic='"+$v6ip+"' --prop:forceIpv6Prefix$nic='"+$v6ipprefix+"'"
           $options
           return
        }

        #
        # Invalid
        #

        default {
            WriteErrorString "Error: Invalid value ($ipModeLabel=$ipMode)."
		    Exit
      
        }
    }
}

function SetKVPNetOptions {
    Param ($settings, $VMName, $nic)

    $ipModeLabel = "ipMode" + $nic
    $ipMode = $settings.General.$ipModeLabel
    
    $ipLabel = "ip" + $nic
    $ip=$settings.General.$ipLabel

    $netmaskLabel = "netmask" + $nic
    $netmask=$settings.General.$netmaskLabel

    $v6ipLabel = "v6ip" + $nic
    $v6ip=$settings.General.$v6ipLabel

    $v6ipprefixLabel = "v6ipprefix" + $nic
    $v6ipprefix=$settings.General.$v6ipprefixLabel

    #
    # IPv4 address must have a netmask
    #

    if (($ip.length -gt 0) -and ($netmask.length -eq 0)) {
        WriteErrorString "Error: missing value $netmaskLabel."
        Exit
    }

    #
    # IPv6 address must have a prefix
    #

    if (($v6ip.length -gt 0) -and ($v6ipprefix.length -eq 0)) {
        WriteErrorString "Error: missing value $v6ipprefixLabel."
        Exit
    }

    #
    # If ipMode is not specified, assign a default
    #

    if ($ipMode.length -eq 0) {

        $ipMode = "DHCPV4"

        if (($ip.length -gt 0) -and ($v6ip.length -eq 0)) {
            $ipMode = "STATICV4"
        }

        if (($ip.length -eq 0) -and ($v6ip.length -gt 0)) {
            $ipMode = "STATICV6"
        }

        if (($ip.length -gt 0) -and ($v6ip.length -gt 0)) {
            $ipMode = "STATICV4+STATICV6"
        }
    }

    #
    # Assign network properties based on the 11 supported combinations
    #

    switch ($ipMode) {

           
        { ($_ -eq "DHCPV4") -or ($_ -eq "DHCPV4+DHCPV6") -or ($_ -eq "DHCPV4+AUTOV6") -or ($_ -eq "DHCPV6") -or ($_ -eq "AUTOV6") } {

            #
            # No addresses required
            #

            $job=AddKVP $VMName "ipMode$nic" $ipMode

            return
        }

        { ($_ -eq "STATICV6") -or ($_ -eq "DHCPV4+STATICV6") } {

            #
            # IPv6 address and prefix required
            #

           if ($v6ip.length -eq 0) {
               WriteErrorString "Error: missing value $v6ipLabel."
               Exit
           }
           $job=AddKVP $VMName "ipMode$nic" $ipMode
           $job=AddKVP $VMName "v6ip$nic" $v6ip
           $job=AddKVP $VMName "forceIpv6Prefix$nic" $v6ipprefix

           return
        }

        { ($_ -eq "STATICV4") -or ($_ -eq "STATICV4+DHCPV6") -or ($_ -eq "STATICV4+AUTOV6") } {

            #
            # IPv4 address and netmask required
            #

           if ($ip.length -eq 0) {
               WriteErrorString "Error: missing value $ipLabel."
               Exit
           }
           $job=AddKVP $VMName "ipMode$nic" $ipMode
           $job=AddKVP $VMName "ip$nic" $ip
           $job=AddKVP $VMName "forceNetmask$nic" $netmask

           return
        }

        { "STATICV4+STATICV6" } {

            #
            # IPv4 address, netmask, IPv6 address and prefix required
            #

           if ($ip.length -eq 0) {
               WriteErrorString "Error: missing value $ipLabel."
               Exit
           }
           if ($v6ip.length -eq 0) {
               WriteErrorString "Error: missing value $v6ipLabel."
               Exit
           }
           $job=AddKVP $VMName "ipMode$nic" $ipMode
           $job=AddKVP $VMName "ip$nic" $ip
           $job=AddKVP $VMName "forceNetmask$nic" $netmask
           $job=AddKVP $VMName "v6ip$nic" $v6ip
           $job=AddKVP $VMName "forceIpv6Prefix$nic" $v6ipprefix

           return
        }

        #
        # Invalid
        #

        default {
            WriteErrorString "Error: Invalid value ($ipModeLabel=$ipMode)."
		    Exit
      
        }
    }
}
