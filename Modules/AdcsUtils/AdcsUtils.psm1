function Set-CaPolicy($policy, $HTTP=$null, $DC=$null) {
    if($HTTP = $null) {
        $HTTP=$env:COMPUTERNAME+"."+$env:USERDNSDOMAIN
    }

    if($DC = $null) {
        $DC = ([ADSI]"LDAP://RootDSE").defaultNamingContext
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

function Set-CaTemplateAcl($DC = $null, $Domain = $null) {
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
    if($DC = $null) {
        $DC = ([ADSI]"LDAP://RootDSE").defaultNamingContext
    }
    if($Domain = $null) {
        $Domain=$env:USERDOMAIN
    }

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

    certutil -template |% { if($_ -match "TemplatePropCommonName = (.*)") { $Matches[1] } } |% { 
      dsacls "CN=$_,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$DC" /G $Domain\$Group:$Rights
    }
}

function Create-CertificateTemplate() {

}

function Create-Policy() {
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

function Create-PolicyIni($policy) {

$ini=@"
[Version]
Signature="$$Windows NT$$"
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
