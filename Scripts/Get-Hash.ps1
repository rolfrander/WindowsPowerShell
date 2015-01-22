param(
    [string[]] $files = $(throw 'a filename is required'),
    [string] $algorithm = 'sha256'
)

function Get-HashFile($file) {
    $fileStream = [system.io.file]::openread($file.fullname)
    $hasher = [System.Security.Cryptography.HashAlgorithm]::create($algorithm)
    $hash = $hasher.ComputeHash($fileStream)
    $fileStream.close()
    $fileStream.dispose()

    new-object psobject -property @{"Name"=$file.name; "Size"=$file.Length; "Date"=$file.LastWriteTime; $algorithm=([system.bitconverter]::tostring($hash) -replace "-"," ") }
}

$files |% { Get-ChildItem $_ } |% { if($_ -isnot [System.IO.DirectoryInfo]) { get-hashfile $_ } } | select name,size,date,$algorithm | ft -AutoSize



# SIG # Begin signature block
# MIIGhwYJKoZIhvcNAQcCoIIGeDCCBnQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUt9TTzF+aV8kcT4EDdBIbtbgL
# QmagggRuMIIEajCCAlKgAwIBAgIJANJHlYy0i5I5MA0GCSqGSIb3DQEBBQUAMFYx
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
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUTPsLZQF2BY3IuVFprbsrJn/3RiwwDQYJKoZI
# hvcNAQEBBQAEgYB8wt2K5Z6oiVP2oHheA/5vZ58iWmqIVh4a6lGFMNyfwU6BXAGO
# cfDOtwCiVmGNuk0dNZf+8QfpZ/MjUOd0eY6TTZ3u/RzWqVKMoDhch7ke8m3Eo3Tf
# 2LGPQ3AYQe5fKpxxbIHKsgM/Vm82BHJovsEa8DmUEOdH+heaYdhi1T/V8w==
# SIG # End signature block
