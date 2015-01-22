
param($username)

$SCRIPT:AD_DOMAIN = [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain()
$controllers = $SCRIPT:AD_DOMAIN.domaincontrollers | %{ $_.name }
$SCRIPT:AD_PRIMARY = $controllers[0] | %{ ($_ -split "\.",2)[0] }
$SCRIPT:ldapSearchBase = (($SCRIPT:AD_DOMAIN.Forest -split "\.") | %{ "dc={0}" -f $_ }) -join ","

function Format-Hashtable($h) {
    $r = "@{"
    $r += ($h.GetEnumerator() | %{ "{0}=`"{1}`"" -f $_.key,$_.value }) -join ";"
    $r += "}"
    $r
}

function Search-Ldap($controller, $base, $filter, [switch]$findAll = $false) {
    <#
    .SYNOPSIS
     Search LDAP, return object or list of objects
     
    .PARAMETER controller
     The LDAP-server to search
     
    .PARAMETER base
     the Distinguished Name of the node to start the search
     
    .PARAMETER filter
     Hash-table with keys and values to filter for
     
    .PARAMETER findAll
     If set, returns all matching objects.  Otherwise, returning just the first found.
    #>
    #write-host ("Search-Ldap $controller $base {0}" -f (Format-Hashtable $filter))
    $ldap = "LDAP://{0}/{1}" -f $controller, $base
    $domain = [adsi] $ldap
    $searcher = [adsisearcher]$domain
    if($filter.count -gt 1) {
        $searcher.filter = "(&{0})" -f -join ($filter.getEnumerator() | %{ "({0}={1})" -f $_.name, $_.value })
    } elseif($filter.count -eq 1) {
        $searcher.filter = ($filter.getEnumerator() | %{ "({0}={1})" -f $_.name, $_.value })
    }
    Write-Host $ldap
    Write-Host $searcher.filter
    if($findAll) {
        $searcher.findAll()
    } else {
        $searcher.findOne()
    }
}

function Get-Account($class="User", $sAMAccountName="") {
    <#
    .SYNOPSIS
     Searches for an account in the configured LDAP.
     
    .DESCRIPTION
     Searches LDAP using the AD Controller and LDAP Search Base configured in the script.  
     Return the Distinguished Name of the account found, or $False if none is found.
     
    .PARAMETER class
     The LDAP class to search for
     
    .PARAMETER sAMAccountName
     The account to search for
    #>
    if($SCRIPT:AD_PRIMARY) {
        $account = Search-Ldap $SCRIPT:AD_PRIMARY $SCRIPT:ldapSearchBase @{objectClass=$class; sAMAccountName=$sAMAccountName}
        if($account) {
            $account.GetDirectoryEntry().distinguishedName.value
            return
        }
    }
    $false
}

Get-Account "User" $username

# SIG # Begin signature block
# MIIEzQYJKoZIhvcNAQcCoIIEvjCCBLoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9NhMSBokO0WLnYr2AG0CpHyy
# 8S6gggLhMIIC3TCCAcmgAwIBAgIQsmpGvQIu4I5DNLblksuozTAJBgUrDgMCHQUA
# MCIxIDAeBgNVBAMTF0FjYW5kbyBSUk4gVGVzdCBDQSAyMDEzMB4XDTEzMDExNzA5
# NDAyNVoXDTM5MTIzMTIzNTk1OVowUTFPME0GA1UEAx5GAFIAbwBsAGYAIABSAGEA
# bgBkAGUAcgAgAE4A5gBzAHMALwBBAGMAYQBuAGQAbwAgAEMAbwBkAGUAcwBpAGcA
# bgBpAG4AZzCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA42jGJjYd4JQ2L3pk
# rVzsrZ934GJ0Rv05ugcREqbQ2zbhw2NSqdr4bJkZFGVXS5aJXKolDZSvnFeVU//6
# UFzs3XD9sDgUxDo11vjiTzopk2BnTeqR+t2wsM0qT/BAzVrJ7oSieqaqKPDtmUj/
# h39febm62gJMCkjgcJqIspzCKfMCAwEAAaNsMGowEwYDVR0lBAwwCgYIKwYBBQUH
# AwMwUwYDVR0BBEwwSoAQ9+kCHwia9k32GWW0qr6Yi6EkMCIxIDAeBgNVBAMTF0Fj
# YW5kbyBSUk4gVGVzdCBDQSAyMDEzghBIsGHc/rfMiUQkgzw8D166MAkGBSsOAwId
# BQADggEBADIYe8TeeqELF/uo+1Ocfc5/XrfOYQ6InWwDnKzMPbsRf+/0ewnCYvqW
# db2bpSLpNP+Vh4lC6y0PcZYxKXXBwy1JN8+nHz9pW3vh1T4Mmu8QVvuc/u3jmqCd
# LmEIOav+A6lFa2cewOO4eye2OHwtS6SJu0fCO2D/Uq6kwkzpXfV7KWH8bJ1JDsmi
# YofnQLN1XkNepGUoeViLScXX5ff0Xd0xF7K3RGRAdJePY5YfKEZPkk4iDKNLC0jT
# ZO2F6iByE1BnkgA7ZABxmEWHC2xBd+FC/97lXhSCknwo+xe5Ic4tdqLKN1+GkTAu
# 4MlAk0q2UbkdhmLHgpz+Mph5ZdSheR0xggFWMIIBUgIBATA2MCIxIDAeBgNVBAMT
# F0FjYW5kbyBSUk4gVGVzdCBDQSAyMDEzAhCyaka9Ai7gjkM0tuWSy6jNMAkGBSsO
# AwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqG
# SIb3DQEJBDEWBBSqu/LyzyUfNzXjJEeyVoZldK3y3DANBgkqhkiG9w0BAQEFAASB
# gG2a3eiRBh6rLpCx46S37LhAxxWDZJH16F2GQW9Ztgu1jpIwW4svhLsqy8OvCbWu
# trLc0PSn5LtXMBX2AOnWG2MF37EZCPfx4LiWxk2QtDLgP4vEabEoCB+nGfOIYk2Y
# ycckr5AKDGwQnabe/LtUucVovhgJePFSlDliwC+SlSLT
# SIG # End signature block
