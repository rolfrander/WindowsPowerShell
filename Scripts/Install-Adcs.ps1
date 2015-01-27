# or wherever modules are located...
$env:PSModulePath += ";$env:USERPROFILE\Documents\WindowsPowerShell\Modules"

# allow local scripts to be run unsigned
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

#####################################################
# this configures AD groups through powershell, feel free to use another
# method for creating these groups
#####################################################

# install AD powershell module
Get-WindowsFeature -Name RSAT-ADDS-Tools

# create AD-groups for role separation
New-ADGroup "CA Administrators" Global
New-ADGroup "Certificate Managers" Global
New-ADGroup "CA Auditors" Global
New-ADGroup "Certificate-Template-Administrators" Global

#####################################################

Import-Module AdcsUtils -Verbose

$policy = New-Policy
New-PolicyIni $policy > C:\Windows\policy.ini

Install-CA
Setup-RootCa -CN "Issuing CA" -O "My company" -enterprise $true

Set-CaTemplateAcl
Set-CaPolicy -policy $policy -HTTP pki.folkestad-naess.name

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
