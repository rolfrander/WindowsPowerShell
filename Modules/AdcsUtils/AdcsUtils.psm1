
#$SCRIPT:extendedrightsmap = @{}
#Get-ADObject -SearchBase ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext.ToString() `
#             -LDAPFilter "(&(objectclass=controlAccessRight)(rightsguid=*))"   `
#             -Properties displayName,rightsGuid |% {
#    $SCRIPT:extendedrightsmap[$_.displayName]=[System.GUID]$_.rightsGuid
#}

$SCRIPT:namingContext = ([ADSI]"LDAP://RootDSE").defaultNamingContext
$SCRIPT:configContext = ([ADSI]"LDAP://RootDSE").configurationNamingContext

function Install-CA {
    Install-WindowsFeature -Name ADCS-Cert-Authority
    Install-WindowsFeature -Name RSAT-ADCS-Mgmt
    Install-WindowsFeature -Name ADCS-Web-Enrollment
}
function Setup-RootCa($CN, $O, [switch]$enterprise = $false, $keyLength=2048, $validityYears = 8) {
    if($enterprise) {
        Install-AdcsCertificationAuthority `
             -CACommonName "$CN" `
             -CADistinguishedNameSuffix "C=NO,O=$O" `
             -CAType EnterpriseRootCA `
             -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
             -HashAlgorithmName sha256 `
             -KeyLength $keyLength `
             -ValidityPeriod Years -ValidityPeriodUnits $validityYears `
             -AllowAdministratorInteraction `
             -Verbose -force
    } else {
        Install-AdcsCertificationAuthority `
             -CACommonName "$CN" `
             -CADistinguishedNameSuffix "C=NO,O=$O" `
             -CAType StandaloneRootCA `
             -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
             -HashAlgorithmName sha256 `
             -KeyLength $keyLength `
             -ValidityPeriod Years -ValidityPeriodUnits $validityYears `
             -AllowAdministratorInteraction `
             -Verbose -force
    }
}

function Setup-IssuingCa($CN, $O, [switch]$enterprise = $false) {
    if($enterprise) {
        Install-AdcsCertificationAuthority `
            -CACommonName "$CN"   `
            -CADistinguishedNameSuffix "C=NO,O=$O" `
            -CAType StandaloneSubordinateCA `
            -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
            -HashAlgorithmName sha256 `
            -KeyLength 2048 `
            -OutputCertRequest c:\certrequest.req `
            -OverwriteExistingKey `
            -Verbose -force
    } else {
        Install-AdcsCertificationAuthority `
            -CACommonName "$CN"   `
            -CADistinguishedNameSuffix "C=NO,O=$O" `
            -CAType EnterpriseSubordinateCA `
            -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
            -HashAlgorithmName sha256 `
            -KeyLength 2048 `
            -OutputCertRequest c:\certrequest.req `
            -OverwriteExistingKey `
            -Verbose -force
    }
    certutil -hashfile c:\certrequest.req
}

function Setup-WebEnrollment() {
    Install-AdcsWebEnrollment -Force
}

function Uninstall-CA {
    UnInstall-AdcsCertificationAuthority -Force
    Uninstall-WindowsFeature -Name ADCS-Web-Enrollment
    Uninstall-WindowsFeature -Name RSAT-ADCS-Mgmt
    Uninstall-WindowsFeature -Name AD-Certificate
}

function Get-StatusCa {
    Get-WindowsFeature -name ADCS-Cert-Authority
    Get-WindowsFeature -Name AD-Certificate
}

function Manage-CA {
    certsrv.msc
}
 

function Set-CaPolicy($policy, $HTTP=$null, $DC=$null) {
    if($HTTP = $null) {
        $HTTP=$env:COMPUTERNAME+"."+$env:USERDNSDOMAIN
    }

    if($DC = $null) {
        $DC = $namingContext.toString()
    }

    $CRLurl = "1:$SystemRoot\system32\Certsrv\CertEnroll\%%3%%8.crl\n"
    $CRLurl+= "10:LDAP:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n"
    $CRLurl+= "2:HTTP://$HTTP/CRL/%3%8%9.crl"

    $AIAurl = "1:%WINDIR%\system32\Certsrv\CertEnroll\%%3%%8.crt\n"
    $AIAurl+= "2:LDAP:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n"
    $AIAurl+= "2:HTTP://$HTTP/AIA/%1_%3%4.crt"

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

function Restart-Adcs {
    net stop certsvc
    net start certsvc
}

function Set-CaTemplateAcl {
    <#
    .SYNOPSIS
     Changes access control settings for all certificate templates.
     
    .DESCRIPTION
     Give the group Certificate-Template-Administrators access to maintaining certificate templates in
     Active Directory.
     
    .PARAMETER DC
     DC-part of the LDAP-path to the templates. Defaults to env:USERDNSDOMAIN
     
    .PARAMETER $Domain
     Domain where the group belongs
    #>
    $Domain=$env:USERDOMAIN

    $Group="Certificate-Template-Administrators"

    # rights:
    #  SD: Delete an object.
    #  DT: Delete an object and all of its child objects.
    #  RC: Read security information.
    #  WD: Change security information.
    #  WO: Change owner information.
    #  LC: List the child objects of the object.
    #  WP: Write to a property. 
    #  RP: Read a property. 
    #  CC: Create a child object.
    #  DC: Delete a child object.
    #  WS: Write to a self object. 
    #  LO: List the object access.
    $rights = "SDDTRCWDWOLCWPRPCCDCWSLO"

    # https://technet.microsoft.com/en-us/library/cc771151.aspx

    $templates = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext" 
    $templates.psbase.children | select -expandproperty distinguishedName |% { 
      dsacls $_ /G "${Domain}\${Group}:${Rights}"
    }
}

function New-Policy() {
    <#
    .SYNOPSIS
     Creates a policy-object
     
    .DESCRIPTION
     The policy defines the CRL renewal period, Delta-CRL renewal period, CRL overlap period and
     default certificate validity. This is used as input to other functions manipulating the
     settings. The values in the policy-object can be set using functions: Set-CrlPeriod,
     Set-CrlOverlap, Set-CrlDelta and Set-Renewal. Default values are 7 days CRL, 3 days overlap
     no delta and 2 year certificate validity.
    #>
    $policy = @{}
    $policy["period"] = @(7, "Days")
    $policy["overlap"]= @(3, "Days")
    $policy["delta"]  = @(0, "Days")
    $policy["renewal"]= @(2, "Years")
    $policy
}

function Set-CrlPeriod($policy, $count, $units) {
    $policy["period"] = @($count, $units);
    $policy
}

function Set-CrlOverlap($policy, $count, $units) {
    $policy["overlap"] = @($count, $units);
    $policy
}

function Set-CrlDelta($policy, $count, $units) {
    $policy["delta"] = @($count, $units);
    $policy
}

function Set-Renewal($policy, $count, $units) {
    $policy["renewal"] = @($count, $units);
    $policy
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

function Get-CertTemplate($name) {
    $templates = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext" 
    $templates.psbase.children |? { $_.displayName -eq $name }
}

function Set-AuthenticatedUsersCanEnroll($template) {
    $identity = [System.Security.Principal.SecurityIdentifier]"S-1-5-11"
    $enroll = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity,"ExtendedRight", "Allow", $SCRIPT:extendedrightsmap["Enroll"])
    #$read = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity,"GenericRead", "Allow")
    $template.psbase.ObjectSecurity.AddAccessRule($enroll)
    #$template.psbase.ObjectSecurity.SetAccessRule($read)
    $template.psbase.commitchanges()
    $template
}

function Copy-CertTemplate($originalTemplateName, $newTemplateName, $attributes, [switch]$pend = $false) {

    $templates = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext" 
    $orgTempl = $templates.psbase.children |? { $_.displayName -eq $originalTemplateName }
    if($orgTempl -eq $null) {
        throw "Template not found: $originalTemplateName"
    }

    $displayName = $newTemplateName
    $name = $newTemplateName.replace(" ","")

    $newTempl = $templates.Create("pKICertificateTemplate", "CN=$name") 
    $null = $newTempl.put("distinguishedName","CN=$name,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext") 
    $null = $newTempl.put("displayName","$displayName")
    $null = $newTempl.put("revision", "100")
    $null = $NewTempl.put("msPKI-Template-Minor-Revision","0")
    # $NewTempl.put("msPKI-Cert-Template-OID","1.3.6.1.4.1.311.21.8.7638725.13898300.1985460.3383425.7519116.119.16408497.1716 293")
    # endring i forhold til utgangspunkt: denne malen kan endres
    # CT_FLAG_IS_MODIFIED
    $null = $newTempl.put("flags","131649")

    $oid=$orgTempl.get("msPKI-Cert-Template-OID") -replace "\.[0-9]*\.[0-9]*$",(".{0}.{1}" -f (get-random),(get-random))
    $null = $newTempl.put("msPKI-Cert-Template-OID", $oid)
    try {
        $null = $newTempl.SetInfo()
    } catch {
        throw $_
    }

    # https://msdn.microsoft.com/en-us/library/cc226546.aspx
    # 2 = CT_FLAG_PEND_ALL_REQUESTS
    if($pend) {
        $null = $newTempl.put("msPKI-Enrollment-Flag","2")
        $null = $newTempl.put("msPKI-RA-Signature", "0")
    } else {
        $null = $newTempl.put("msPKI-Enrollment-Flag","0")
    }

    $allflags=@("msPKI-Certificate-Name-Flag",
                "msPKI-Private-Key-Flag",
                "msPKI-Minimal-Key-Size",
                "msPKI-Template-Minor-Revision",
                "msPKI-Template-Schema-Version",
                "pkiCriticalExtensions",
                "pKIDefaultCSPs",
                "pKIDefaultKeySpec",
                "pKIExpirationPeriod",
                "pKIExtendedKeyUsage",
                "pKIKeyUsage",
                "pkiMaxIssuingDepth",
                "pKIOverlapPeriod")

    $allflags |% { $null = $newTempl.put($_, $orgTempl.get($_)) }

    # uklart hva dette betyr...
    $null = $newTempl.put("msPKI-Private-Key-Flag","16842752")

    # $NewTempl.put("pKIExtendedKeyUsage","1.3.6.1.5.5.7.3.1, 1.3.6.1.5.5.7.3.2")
    if($attributes) {
        $attributes.keys |% { $null = $newTempl.put($_, $attributes[$_]) }
    }

    $null = $newTempl.put("msPKI-Certificate-Application-Policy", $newTempl.get("pKIExtendedKeyUsage"))

    $null = $newTempl.SetInfo()
    $newTempl
}

function Add-UserToCertificateManagers($user) {
    Get-ADGroup -Identity "Certificate Managers"
}

Export-ModuleMember -Function Set-CaPolicy,Restart-Adcs,Set-CaTemplateAcl,New-Policy,`
                              New-PolicyIni,Set-CrlDelta,Set-CrlOverlap,Set-CrlPeriod,`
                              Set-Renewal,Install-CA,Setup-RootCA,Setup-IssuingCA,`
                              Uninstall-CA,Get-StatusCa,Manage-CA,Setup-WebEnrollment
