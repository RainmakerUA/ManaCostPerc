# Generate locale files from the source

$headerFmt = "-- This file is generated with $($MyInvocation.MyCommand.Name)
local L = LibStub(`"AceLocale-3.0`"):NewLocale(`"ManaCostPerc`", `"{0}`"{1})
if not L then return end
---------- Total: {2} ----------"
$trueParam = ', true'
$loc_re = 'L\["(.+?)"\]'
$locales = @('enUS', 'ruRU')
$strings = Get-Content .\ManaCostPerc.lua | %{if($_ -match $loc_re){ $Matches[0] } else { $null }} | ?{$_ -ne $null} | Select-Object -Unique
#$strings = $strings | Sort-Object -Property @{Expr = {if(){0}elseif([int][char]$_[4] -ge [int][char]'A' -and [int][char]$_[4] -le [int][char]'Z'){1}else{2}} }

$locales | %{
    $locale = $_
    $file = ".\Locales\$locale.lua.new"
    Set-Content $file ([string]::Format($headerFmt, $locale, $(if($locale -eq "enUS"){ $trueParam } else { "" }), $strings.Length))

    $out = $strings | ?{ [int][char]$_[4] -ge [int][char]'a' -and [int][char]$_[4] -le [int][char]'z' }
    Add-Content $file ($out | %{ if($locale -eq "enUS"){ "$_ = true" } else { "$_ = `"`"" } })

    $out = $strings | ?{ [int][char]$_[4] -ge [int][char]'A' -and [int][char]$_[4] -le [int][char]'Z' }
    Add-Content $file ($out | %{ if($locale -eq "enUS"){ "$_ = true" } else { "$_ = `"`"" } })
    
    $out = $strings | ?{ -not ([int][char]$_[4] -ge [int][char]'A' -and [int][char]$_[4] -le [int][char]'Z') `
                           -and -not ([int][char]$_[4] -ge [int][char]'a' -and [int][char]$_[4] -le [int][char]'z')}
    Add-Content $file ($out | %{ if($locale -eq "enUS"){ "$_ = true" } else { "$_ = `"`"" } })

    #Add-Content $file "-- Total strings: $($strings.Length)"
}
