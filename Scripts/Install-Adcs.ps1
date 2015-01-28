Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 100.92.82.121
Add-Computer -DomainName folkestad-naess.name -Credential folkestad-naess\ladmin -Restart

ping domain

# or wherever modules are located...
$env:PSModulePath += ";c:\users\ladmin\Documents\WindowsPowerShell\Modules"

# allow local scripts to be run unsigned
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

#####################################################
# this configures AD groups through powershell, feel free to use another
# method for creating these groups
#####################################################

# install AD powershell module
Install-WindowsFeature -Name RSAT-AD-PowerShell

# create AD-groups for role separation
New-ADGroup "CA Administrators" Global
New-ADGroup "Certificate Managers" Global
New-ADGroup "CA Auditors" Global
New-ADGroup "Certificate-Template-Administrators" Global

#####################################################

#Remove-Module AdcsUtils
Import-Module AdcsUtils

# https://technet.microsoft.com/en-us/library/jj125373.aspx
$policy = New-Policy
New-PolicyIni $policy > C:\Windows\CAPolicy.inf

Install-CA
Setup-RootCa -CN "Enterprise Root CA" -O "Company" -enterprise $true

Uninstall-AdcsCertificationAuthority -Force
Set-CaTemplateAcl
# dette er DNS-navnet hvor CRL blir publisert
$hostname=$env:COMPUTERNAME+"."+$env:USERDNSDOMAIN
Set-CaPolicy -policy $policy -HTTP $hostname

Restart-Adcs

Setup-WebEnrollment

# set up ACL:
#  - authenticated users may "request certificates"
#  - certificate managers may "issue and manage certificates"
#  - ca administrators may "manage CA"

# set up certificate templates
#  - copy "web server" to "Server Authentication Manual Enroll"
#  - set minimum key size: 2048
#  - issuance requirements: CA certificate manager approval
#  - extensions: "application policy": server authentication and client authentication

# add "Server Authentication Manual Enroll" to CA -> Certificate Templates
