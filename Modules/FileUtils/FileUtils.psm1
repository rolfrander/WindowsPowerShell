function Find-Item($dir, $filenamePattern) {
    try {
        #    Write-Host "Search item $dir $filenamePattern"
        Get-ChildItem $dir | ForEach-Object {
            if($_.basename -like $filenamePattern) {
                $_
            }
            if($_.PSIsContainer) {
                Find-Item $_.fullname $filenamePattern
            }
        }
    } catch {
        Write-Host "Cannot access $dir"
    }
}

function Import-CsvAsHash($keyColumn = 0, $delimiter = ';') {
    begin {
        $hash = @{}
        $headers = $false
    }
    process {
        ForEach-Object {
            $data = ([string]$_).split($delimiter)
            if(-not $headers) {
                $headers = $data
            } else {
                $objectHash = @{}
                for($i=0; $i -lt $headers.length ; $i++) {
                    $objectHash[$headers[$i]] = $data[$i]
                }
                $hash[$data[$keyColumn]] = $objectHash
            }
        }
    }
    end {
        $hash
    }
}

filter Decode-Rot13() {
    [CmdletBinding(DefaultParameterSetName = "ByPath")]
    param(
        ## The file to read the content from
        [Parameter(ParameterSetName = "ByPath", Position = 0)]
        [string] $Path,

        ## The input (bytes or strings) to format as hexadecimal
        [Parameter(
            ParameterSetName = "ByInput", Position = 0,
            ValueFromPipeline = $true)]
        [Object] $InputObject
    )
    
    ## If they specified the -InputObject parameter, retrieve the bytes
    ## from that input
    if(Test-Path variable:\InputObject)
    {
        ## If it's an actual byte, add it to the inputBytes array.
        if($InputObject -is [Byte])
        {
            $inputBytes = $InputObject
        }
        else
        {
            ## Otherwise, convert it to a string and extract the bytes
            ## from that.
            $inputString = [string] $InputObject
            $inputBytes = [Text.Encoding]::Unicode.GetBytes($inputString)
        }
    }

    $outputString = ""
    
    ## Now go through the input bytes
    foreach($byte in $inputBytes)
    {
        if(($byte -ge 65) -and ($byte -le 90)) {
            $byte = (($byte-65+13)%26)+65
        } elseif(($byte -ge 97) -and ($byte -le 122)) {
            $byte = (($byte-97+13)%26)+97
        } elseif($byte -eq 10) {
            $outputString
            $outputString = ""
        }
        $outputString += [char]$byte
    }
    $outputString
}

function Save-OrigFile($filename) {
    $orig = "${filename}.orig"
    $i=1
    while(test-path $orig) {
        $orig = "${filename}.orig.${i}"
        $i++
    }
    Rename-Item $filename $orig
    $orig
}


function Set-Properties($filename, $properties) {
    if(-not (Test-Path $filename)) {
        $false
        return
    }
    $orig = Save-OrigFile $filename
    Get-Content $orig | %{
        if($_.StartsWith("#")) {
            $_
        } elseif($_.trim().length -eq 0) {
            $_
        } else {
            ($key,$value) = $_ -split " *= *",2
            if($properties.containsKey($key)) {
                "$key={0}" -f $properties[$key]
            } else {
                $_
            }
        }
    } | Out-File -FilePath $filename -Encoding UTF8
    $true
}

function Replace-Xml($filename, $replacements, [switch]$WhatIf = $false) {
    if(-not (Test-Path $filename)) {
        $false
        return
    }
    if($whatif) {
        $orig = $filename
    } else {
        $orig = Save-OrigFile $filename
    }
    $xml = New-Object system.xml.xmldocument
    $xml.PreserveWhitespace = $true
    $xml.XmlResolver = $null
    $xml.load($orig)
    foreach($replace in $replacements.GetEnumerator()) {
        $xml.SelectNodes($replace.name) | %{
            if($_ | Get-Member "#text") {
                if($WhatIf) {
                    "in {0} replace {1} by {2}" -f $replace.name,$_."#text",$replace.value
                } else {
                    $_."#text" = $replace.value
                }
            } else {
                if($WhatIf) {
                    "{0} is not a text node" -f $replace.name
                }
            }
        }
    }
    if(-not $WhatIf) {
        $xml.save($filename)
    }
    $true
}

function Encode-Base64File {
    <#
    .Synopsis
     Returns an array of System.Byte[] of the file contents.
    .Parameter Path
      Path to the file as a string or as System.IO.FileInfo object.
      FileInfo object can be piped into the function.  Path as a
      string can be relative or absolute, but cannot be piped.
    #>
    [CmdletBinding()] Param (
         [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
         [Alias("FullName","FilePath")]
         $Path
    )
    $file = $(Get-Item $Path)
    "begin-base64 644 {0}" -f $file.name
    $in = [system.io.file]::OpenRead($file.fullname)
    [byte[]]$array = @()
    foreach($i in 1..60) { $array += 0 }

    do {
        $cnt = $in.Read($array, 0, 60)
        [system.convert]::ToBase64String($array[0..($cnt-1)])
    } while($cnt -eq 60)
    $in.Close()
    "end"
}

filter Decode-Base64File {
    if($_ -match "^begin-base64 ([0-7][0-7][0-7]) ([^ ]*)$") {
        $filename = $Matches[2]
        if($out) {
            $out.close()
        }
        $out = [system.io.file]::OpenWrite(( resolve-path . | Join-Path -ChildPath $filename))
        $cnt = 0
    } elseif($_ -match "^end$") {
        if($out) {
            $out.flush()
            $out.close()
            $out = $null
            "wrote $filename $cnt bytes"
        }
    } else {
        if(!$out) {
            return
        }
        $array = [System.Convert]::FromBase64String($_)
        $out.write($array, 0, $array.length)
        $cnt += $array.Length
    }
}

function Calculate-Hash {
    param (
      [string] $inFile = $(throw "Usage: Calculate-Hash file.txt [sha1|md5] "),
      [string] $hashType = "sha1"
    )

  if ($hashType -eq "")
  {
    throw "Usage: Calc-Hash.ps1 file.txt [sha1|md5] "
  }

  if ($hashType -eq "sha1")
  {
    $provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider
  }
  elseif ($hashType -eq "md5")
  {
    $provider = New-Object System.Security.Cryptography.MD5CryptoServiceProvider
  }
  else
  {
    throw "Unsupported hash type $hashType"
  }

  $inFileInfo = New-Object System.IO.FileInfo($inFile)
  if (-not $inFileInfo.Exists)
  {
    # If the file can't be found, try looking for it in the current directory.
    $inFileInfo = New-Object System.IO.FileInfo("$pwd\$inFile")
    if (-not $inFileInfo.Exists)
    {
      throw "Can't find $inFileInfo"
    }
  }

  $inStream = $inFileInfo.OpenRead()
  $hashBytes = $provider.ComputeHash($inStream)
  [void] $inStream.Close()

  trap
  {
    if ($inStream -ne $null)
    {
      [void] $inStream.Close()
    }
    break
  }

  $ret = ""
  foreach ($byte in $hashBytes)
  {
    $ret += $byte.ToString("X2")
  }

  $ret
}

function foo {
    Param([parameter(Mandatory=$true, ValueFromPipeline=$true)][byte[]]$InputObject)
    process {
    $inputObject.getType()
    $inputObject.length
    "<$inputObject>"
    $input
    }
}

# SIG # Begin signature block
# MIIEzQYJKoZIhvcNAQcCoIIEvjCCBLoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYzcFWN9x1RAN5lN8h4MuKLIz
# 1lWgggLhMIIC3TCCAcmgAwIBAgIQsmpGvQIu4I5DNLblksuozTAJBgUrDgMCHQUA
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
# SIb3DQEJBDEWBBSBGXZ7a1pPozjD/3sjQq5K5R0eYTANBgkqhkiG9w0BAQEFAASB
# gHjP+Q+WfkhpQhOL0iRGRpvblMdSiEP1rYlDHKvn/jrwfsu631B+0B5R7SzIRMfh
# VSKFSTj389C/rWBHR//hpr8Av57ayPCNTX5O7+0vAZcg/9ALMyChHSnuaeONdQlJ
# zvNcNN8u0tu+bJPc3PSslp9thAAKHzoWqN6+MNu0oZjg
# SIG # End signature block
