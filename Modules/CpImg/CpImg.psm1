Import-Module image

function Get-RemovableDriveLetters
{
    Get-Volume |? { $_.DriveType -eq 'Removable' -and $_.FileSystem -ne ''} |%{$_.DriveLetter}
}

function Get-CD
{
    Get-Volume |? { $_.DriveType -eq 'CD-ROM' }
}

function Get-SourcePaths
{
    Get-RemovableDriveLetters |% { Get-Item "${_}:\DCIM\[0-9][0-9][0-9]*" -ErrorAction Ignore }
}

function Get-SourceFiles
{
    process{
        Get-ChildItem -Path $_ -Recurse -include *.cr2,*.jpg,*.mov,*.3gp,*.mpg
    }
}

function Dismount-CD($drive = $null)
{
    if($drive -ne $null) {
        $src = $drive
    } else {
        $src = (Get-CD).driveletter
    }
    $sa = New-Object -comObject Shell.Application
    @($src) |% { $sa.Namespace(17).ParseName("${_}:").InvokeVerb("Eject") }
}

function Copy-FilesToDates($destination, $count=0)
{
    begin {
        $i=0
    }
    process{
        $srcfile = "{0}\{1}" -f ($_.directoryname, $_.name)
        try {
            #$datetaken = (get-exif $srcfile).datetaken
            $dstdir  = "{0}\{1:yyyy}\{1:MM}\{1:dd}" -f ($destination, $_.LastWriteTime)
            $dstfile = "{0}\{1}" -f ($dstdir, $_.name.tolower())
            if($count -gt 0) {
                Write-Progress -Id 1 -Activity "Kopierer bilder" -Status "$srcfile -> $dstdir" -PercentComplete ($i*100/$count)
            }
            if(Test-Path $dstfile) {
                #Write-Host "$dstfile exists"
            } else {
                $ignore = (New-Item $dstdir -ItemType directory -ErrorAction Ignore)
                Copy-Item $srcfile $dstfile 
            }
        } catch [Exception] {
            Write-Host "Could not handle $srcfile"
        }
        $i++
    }
    end {
        if($count -gt 0) {
            Write-Progress -Id 1 -Activity "Kopierer bilder - ferdig" -Completed
        }
    }
}

function Copy-All($source = $null, $destination = "z:\img")
{
    if($source -ne $null) {
        if(! (Test-Path $source)) {
            throw "$source does not exist"
        }
        $files = Get-Item $source | Get-SourceFiles
    } else {
        $files = Get-SourcePaths | Get-SourceFiles
    }
    $files  | Copy-FilesToDates $destination -count $files.length
}


# SIG # Begin signature block
# MIIGhwYJKoZIhvcNAQcCoIIGeDCCBnQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUgKHGBzgPwTjSyr3avsvy7p3K
# KE6gggRuMIIEajCCAlKgAwIBAgIJANJHlYy0i5I5MA0GCSqGSIb3DQEBBQUAMFYx
# CzAJBgNVBAYTAk5PMSIwIAYDVQQKExlGb2xrZXN0YWQtbmFlc3MgaW50ZXJuZXR0
# MSMwIQYDVQQDExpIZWxsZXJ1ZCBWUE4gUm90c2VydGlmaWthdDAeFw0xMzAxMjky
# MjMxMDFaFw0xNjAxMjkyMjMxMDFaMGIxCzAJBgNVBAYTAk5PMSIwIAYDVQQKDBlG
# b2xrZXN0YWQtTmFlc3MgSW50ZXJuZXR0MS8wLQYDVQQDDCZSb2xmIFJhbmRlciBO
# w6Zzcy9Tam9zdGEgS29kZXNpZ25lcmluZzCBnzANBgkqhkiG9w0BAQEFAAOBjQAw
# gYkCgYEAshl74KLEMfMKD22Ic4VA3RWdh5unoGLJCi/z7N/FLtXLOEr0B4JEwEr2
# 0A+aAKNgyv7ef8/jzVgzct9kvDDgISGJah/Cejb8/+M4f7ht6Nd8sNMruxP0VMI3
# MDIt5uTYWLrzYEXJzkDP8qm5kxoG7+AEgNfne06DuiJnBWRd1jkCAwEAAaOBsjCB
# rzALBgNVHQ8EBAMCBkAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFKYm
# 9rwI0j3NuEbW1x77BdTbl0KyMB8GA1UdIwQYMBaAFIlEdXZi1TucrWYyppSeUzFC
# sErnMC4GCWCGSAGG+EIBDQQhFh9KdWtlYm94IGNvZGVzaWduaW5nIGNlcnRpZmlj
# YXRlMBsGCSsGAQQBgjcVCgQOMAwwCgYIKwYBBQUHAwMwDQYJKoZIhvcNAQEFBQAD
# ggIBAHAGx3nKZqz8OCo7zdwJa3O5SR2hMjVd92cQYWwLH27+WhO7SUp1bwAQttJ9
# cGo+JS/0z48m32lJpTrJoWdPbrhr2wvzqaHwfzefnKqKuq5QhIqO0l/reuamTxgo
# 1hFZpynAGGpdjlKOJoIcSa+zsr2pxXeVPFSeKWl4EE7DodOyMiFRGGGD7xI2KV/J
# 85fN4aMmlnSn3YDQ9YjFPJ16I8uTmE5glSHCZAe0XiVZDq22dQIpqnif1ZQdE/41
# 8lgB3Pl0Vvl4YyRABLGF+5F6G2zjyxyX69B70J9qxATkFRF7QnrU1Kz9OvlTtO0l
# 2SJ9xypekLz0ZZTzeWEo/UOR49l40KZ6LfjuhWtqYwi7isRnNWFKQ+CllriWTrrB
# dN9AkzW/yg7VzZlfR6pQ1WH7odT/H9ECYw0nsdaFto1VYiEGBH+umZcb8/g9DufA
# zGVrjSkTAc62qERPS8E12h6WZL4Jn2WHBSN0iNY0NMhKvnThFtu3w/PP+nvQhjbm
# 6L44p5o4uaawSHuUPV/aqLlmmHfXSqMRnmhJLdbyIWRu3scakBusJFUK/c2bmcJr
# Fr7USG8F/QHa9AqsZs+DHpIT0xan9cWeg8iwtifJNW7jiesOsQREi3LTA55ovHZ6
# SArll8mSDPEMISi9xYtoV//AjpEiQfaym4UTkpwzAEZ76yubMYIBgzCCAX8CAQEw
# YzBWMQswCQYDVQQGEwJOTzEiMCAGA1UEChMZRm9sa2VzdGFkLW5hZXNzIGludGVy
# bmV0dDEjMCEGA1UEAxMaSGVsbGVydWQgVlBOIFJvdHNlcnRpZmlrYXQCCQDSR5WM
# tIuSOTAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUq0eqv1A0fFx+rOhTEpeoRFXE8PMwDQYJKoZI
# hvcNAQEBBQAEgYCdKGLdFw8nfARxVOm8fOc8lpBmSVZZljGH4BKfT7qce+KB8QXz
# gjfBBsD9CFmV1fLhCaUcgmauoBXqtLboLt0SMuAMp7q+ydxY66bNW72AnmM2sRCC
# KUBS1quGjpCXKAI3a4eWxiTseHlfQs7zAyfv9kC1ImcYDJS8hEcGtL/cLg==
# SIG # End signature block
