# Generate locale files from the source

$projName = 'ManaCostPerc'
$headerFmt = "-- This file is generated with $($MyInvocation.MyCommand.Name)
local L = LibStub(`"AceLocale-3.0`"):NewLocale(`"$projName`", `"{0}`"{1})
if not L then return end
---------- Total: {2} ----------"
$trueParam = ', true'
$loc_re = 'L\["(.+?)"\]'
$ext_re = '^L\[\"[A-Z.]+\"\]$'
$locales = @('enUS', 'ruRU')
$strings = Get-Content ".\$projName.lua" | %{if($_ -match $loc_re){ $Matches[0] } else { $null }} | ?{$_ -ne $null} | Select-Object -Unique
$total = $strings.Length
$ext_strings = $strings | ?{ $_ -cmatch $ext_re }
$strings = $strings | ?{ $_ -cnotmatch $ext_re }

$locales | %{
	$locale = $_
	$file = ".\Locales\locale-$locale.lua.new"
	Set-Content $file ([string]::Format($headerFmt, $locale, $(if($locale -eq "enUS"){ $trueParam } else { "" }), $total))

	@($strings, $ext_strings) | %{
		Add-Content $file ($_ | %{ if($locale -eq "enUS"){ "$_ = true" } else { "$_ = `"`"" } })
	}
}
