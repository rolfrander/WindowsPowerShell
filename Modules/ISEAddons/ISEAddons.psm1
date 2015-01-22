Import-Module ScriptUtils

function Add-SignatureCurrentFile() {
    Save-CurrentFile
    Add-Signature $psISE.CurrentFile.FullPath
}

function Save-CurrentFile() {
    $psISE.CurrentFile.Save([Text.Encoding]::UTF8) 
}

function Save-AllFiles() {
    $psISE.CurrentPowerShellTab.Files | %{
        if(-not $_.issaved) {
            $_.save([Text.Encoding]::UTF8)
        }
    }
}

function Update-CurrentFile() {
    if($psISE.CurrentFile.IsSaved) {
        $file = $psISE.CurrentFile.FullPath
        $line = $psISE.CurrentFile.Editor.CaretLine
        $col = $psISE.CurrentFile.Editor.CaretColumn
        $psISE.CurrentPowerShellTab.Files.Remove($psISE.CurrentFile)
        $psISE.CurrentPowerShellTab.Files.Add($file)
        $psISE.CurrentFile.Editor.SetCaretPosition($line, $col)
    }
}

function Open-Profile () {
    if(-not (Test-Path $profile)) {
        New-Item $profile -type file
    }
    $psISE.CurrentPowerShellTab.files.Add($profile)
}

function Add-AddOnsMenu() {
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Clear()
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Save _all files", {Save-AllFiles}, "Ctrl+Shift+S")
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("_Sign current file", {Add-SignatureCurrentFile}, "Alt+S")
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("_Reload current file", {Update-CurrentFile}, "Alt+R")
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Open _profile", {Open-Profile}, "Alt+P")
    $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Import current file as _module", {Import-Module $psISE.CurrentFile.FullPath -Verbose}, "Alt+M")
}

# SIG # Begin signature block
# MIIEzQYJKoZIhvcNAQcCoIIEvjCCBLoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrtqTwkGkRkU+Bo2vWuZVBMGP
# YUmgggLhMIIC3TCCAcmgAwIBAgIQsmpGvQIu4I5DNLblksuozTAJBgUrDgMCHQUA
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
# SIb3DQEJBDEWBBSDOFMYdlbdIQeavIxdNUkChwfW4TANBgkqhkiG9w0BAQEFAASB
# gOJwNka5j2WaYuxsFPscsxgDEBm+3t6Pxcihlbs/S+CxCc8MLpsB9l8/mAmYqVkw
# bndPfEhhl8w3sumB1wVnRpMKWEbA3r5FUF8b7cKwcUqCP4j3+NJpZQ/pgCB/H+JF
# UTeipXIRfIjJ9Mqlrn1YQJioGBuLCnjxH7sEBNsBqNzH
# SIG # End signature block
