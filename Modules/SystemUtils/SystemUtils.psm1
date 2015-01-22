
function New-ServiceOnServer($name, $BinaryPathName, $displayname, $description, $start="auto", $server=$null) {
    # mapping parameters from "New-Service" to sc.exe, to be compatible with cmdlet New-Service
    switch ($start) {
    "automatic" { $start = "auto"    ; break }
    "manual"    { $start = "demand"  ; break }
    "disabled"  { $start = "disabled"; break }
    }
    
    sc.exe "\\$server" create      $name "binPath=" "$BinaryPathName" "start=" $start "DisplayName=" "$displayname" | Out-Null
    sc.exe "\\$server" description $name "$description" | Out-Null
    if($server) {
        Get-Service -ComputerName $server -name $name
    } else {
        Get-Service -Name $name
    }
}

function Start-Service($service, $server=$null) {
    if($server) {
        Set-Service -ComputerName $server -Name $service -Status Running
    } else {
        Set-Service -Name $service -Status Running
    }
}


function SCRIPT:Get-EnvironmentRegistry($server) {
    $envkey='SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment'
    if(-not $server) {
        $server = $Env:COMPUTERNAME
    }
    [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Localmachine', $server).openSubKey($envkey, $true)
}

function Get-SystemEnvironment($server = $null) {
    $ret = @{}
    $environment = Get-EnvironmentRegistry -server $server
    foreach($name in $envionment.getValueNames()) {
        $ret[$name] = $environment.getValue($name)
    }
    $ret
}

function Get-SystemEnvironmentVariable($name, $server = $null) {
    $environment = Get-EnvironmentRegistry -server $server
    $environment.getValue($name)
}

function Set-SystemEnvironmentVariable($name, $value, $server = $null) {
    $environment = Get-EnvironmentRegistry -server $server
    $environment.setValue($name, $value)
}

# SIG # Begin signature block
# MIIEzQYJKoZIhvcNAQcCoIIEvjCCBLoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtlUpBuHguh0PfMfMg7JA0uYS
# uuqgggLhMIIC3TCCAcmgAwIBAgIQsmpGvQIu4I5DNLblksuozTAJBgUrDgMCHQUA
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
# SIb3DQEJBDEWBBSfdIcK/RYn9F2lrJW5ygzAApCY5DANBgkqhkiG9w0BAQEFAASB
# gE0Rc1V8j3Ak/a/IRIE1zEJVki9ax1Z1W4t1NdScbwW5UXSyqdMgA1eRdg994wo6
# PDji+oLZvdR8y35FEOrSGCQGikYBFQwx5UczcIuInm3NHjrLTrz7OYyaU85715h+
# vqR1zCKk1wWUSX70UjOa6gt7jtJqwxRSRV7YUFdzwz46
# SIG # End signature block
