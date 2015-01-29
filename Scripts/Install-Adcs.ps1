
# allow local scripts to be run unsigned
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

$policy = @{}
$policy["period"] = @(7, "Days")
$policy["overlap"]= @(3, "Days")
$policy["delta"]  = @(0, "Days")
$policy["renewal"]= @(2, "Years")

# dns-name for crl/aia-distribution
$hostname=$env:COMPUTERNAME+"."+$env:USERDNSDOMAIN

# name of root certificate
$CA_CommonName   = "Enterprise CA"
$CA_Organization = "Company"

$configContext = ([ADSI]"LDAP://RootDSE").configurationNamingContext

function Set-CaPolicy($policy, $HTTP=$null, $DC=$null) {
    if($HTTP = $null) {
        $HTTP=$env:COMPUTERNAME+"."+$env:USERDNSDOMAIN
    }

    if($DC = $null) {
        $DC = $namingContext.toString()
    }

    $CRLurl = "1:$SystemRoot\system32\Certsrv\CertEnroll\%8.crl\n"
    $CRLurl+= "10:LDAP:///CN=%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n"
    $CRLurl+= "2:HTTP://$HTTP/CRL/%8.crl"

    $AIAurl = "1:%WINDIR%\system32\Certsrv\CertEnroll\%8.crt\n"
    $AIAurl+= "2:LDAP:///CN=%8,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n"
    $AIAurl+= "2:HTTP://$HTTP/AIA/%8.crt"

    certutil -setreg ca\DSConfigDN            "CN=Configuration,$DC"
    certutil -setreg CA\CRLPublicationURLs    $CRLurl
    certutil -setreg CA\CACertPublicationURLs $AIAurl

    # Define CRL Publication Intervals
    certutil -setreg CA\CRLPeriodUnits        $policy["period"][0]
    certutil -setreg CA\CRLPeriod             $policy["period"][1]
    certutil -setreg CA\CRLDeltaPeriodUnits   $policy["delta"][0]
    certutil -setreg CA\CRLDeltaPeriod        $policy["delta"][1]
    certutil -setreg CA\CRLOverlapUnits       $policy["overlap"][0]
    certutil -setreg CA\CRLOverlapPeriod      $policy["overlap"][1]

    certutil -setreg CA\ValidityPeriodUnits   $policy["renewal"][0]
    certutil -setreg CA\ValidityPeriod        $policy["renewal"][1]

    # Audit everything
    certutil -setreg CA\AuditFilter 127
    auditpol /set /subcategory:"Certification Services" /failure:enable /success:enable

    # enable role separation
    certutil -setreg CA\RoleSeperationEnabled 1

    # allow setting Subject Alternative Name when submiting a request
    certutil -setreg policy\EditFlags         +EDITF_ATTRIBUTESUBJECTALTNAME2
}

function Set-CaTemplateAcl {
    $Domain=$env:USERDOMAIN
    $Group="Certificate-Template-Administrators"

    $rights = "SDDTRCWDWOLCWPRPCCDCWSLO"

    # https://technet.microsoft.com/en-us/library/cc771151.aspx

    $templates = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext" 
    $templates.psbase.children | select -expandproperty distinguishedName |% { 
      dsacls $_ /G "${Domain}\${Group}:${Rights}"
    }
}

function Restart-Adcs {
    net stop certsvc
    net start certsvc
}

function periodstring($element, $crlpolicy, $policyelement) {
    $units=$crlpolicy[$policyelement][0]
    $type=$crlpolicy[$policyelement][1]
    @"
${element}Units=$units
${element}=$type

"@
}

function New-PolicyIni($policy) {

    $ini=@"
[Version]
Signature="`$Windows NT`$"
[certsrv_server]
RenewalKeyLength=2048

"@

    $ini += periodstring "RenewalValidityPeriod" $policy "renewal"
    $ini += periodstring "CRLPeriod"  $policy "period"
    $ini += periodstring "CRLOverlap" $policy "overlap"
    $ini += periodstring "CRLDelta"   $policy "delta"

    $ini+=@"
LoadDefaultTemplates=0
DiscreteSignatureAlgorithm=0
[BasicConstrainsExtension]
Pathlength=0

"@

    $ini
}


#####################################################
# this configures AD groups through powershell, feel free to use another
# method for creating these groups
#####################################################

# install AD powershell module
#Install-WindowsFeature -Name RSAT-AD-PowerShell

# create AD-groups for role separation
#New-ADGroup "CA Administrators" Global
#New-ADGroup "Certificate Managers" Global
#New-ADGroup "CA Auditors" Global
#New-ADGroup "Certificate-Template-Administrators" Global

#####################################################

# https://technet.microsoft.com/en-us/library/jj125373.aspx
New-PolicyIni $policy > C:\Windows\CAPolicy.inf

Install-WindowsFeature -Name ADCS-Cert-Authority
Install-WindowsFeature -Name RSAT-ADCS-Mgmt

Install-AdcsCertificationAuthority `
        -CACommonName "Enterprise ROOT CA" `
        -CADistinguishedNameSuffix "C=NO,O=Company" `
        -CAType EnterpriseRootCA `
        -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
        -HashAlgorithmName sha256 `
        -KeyLength 2048 `
        -ValidityPeriod Years -ValidityPeriodUnits 8 `
        -OverwriteExistingKey -Force

# Uninstall-AdcsCertificationAuthority -Force
Set-CaTemplateAcl
Set-CaPolicy -policy $policy -HTTP $hostname

Restart-Adcs

Install-WindowsFeature -Name ADCS-Web-Enrollment
Install-AdcsWebEnrollment -Force

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
