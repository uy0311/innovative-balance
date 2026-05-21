$filepath = "c:\Users\uy031\Documents\Paradox Interactive\Hearts of Iron IV\mod\Innova _test\common\characters\ENG.txt"

Copy-Item $filepath "$filepath.bak"

$content = [System.IO.File]::ReadAllText($filepath, [System.Text.Encoding]::UTF8)

$charPattern = [regex]'(?m)^\t(ENG_\w+)\s*=\s*\{'
$allMatches = $charPattern.Matches($content)

$charBlocks = @()
foreach ($m in $allMatches) {
    $pos = $m.Index + $m.Length
    $depth = 1
    while ($depth -gt 0 -and $pos -lt $content.Length) {
        $ch = $content[$pos]
        if ("$ch" -eq '{') {
            $depth++
        } elseif ("$ch" -eq '}') {
            $depth--
        }
        $pos++
    }
    if ($pos -lt $content.Length -and $content[$pos] -eq "`n") {
        $pos++
    }
    $charBlocks += ,@($m.Groups[1].Value, $m.Index, $pos)
}

$seen = @{}
$dupFirst = @{}
$dupSecond = @{}
foreach ($blk in $charBlocks) {
    $nm = $blk[0]
    if ($seen.ContainsKey($nm)) {
        $dupFirst[$nm] = $seen[$nm]
        $dupSecond[$nm] = $blk
    } else {
        $seen[$nm] = $blk
    }
}

Write-Output "Duplicates: $($dupFirst.Count)"

$skipStarts = @{}
foreach ($nm in $dupSecond.Keys) {
    $skipStarts[$dupSecond[$nm][1].ToString()] = $true
}

$result = [System.Text.StringBuilder]::new()
$lastEnd = 0

for ($j = 0; $j -lt $charBlocks.Count; $j++) {
    $blk = $charBlocks[$j]
    $nm = $blk[0]
    $startPos = $blk[1]
    $endPos = $blk[2]

    if ($skipStarts.ContainsKey($startPos.ToString())) {
        continue
    }

    if ($startPos -gt $lastEnd) {
        [void]$result.Append($content.Substring($lastEnd, $startPos - $lastEnd))
    }

    [void]$result.Append($content.Substring($startPos, $endPos - $startPos))
    $lastEnd = $endPos

    if ($dupFirst.ContainsKey($nm)) {
        $sec = $dupSecond[$nm]
        [void]$result.Append($content.Substring($sec[1], $sec[2] - $sec[1]))
    }
}

if ($lastEnd -lt $content.Length) {
    [void]$result.Append($content.Substring($lastEnd))
}

$newContent = $result.ToString()
[System.IO.File]::WriteAllText($filepath, $newContent, [System.Text.Encoding]::UTF8)

Write-Output "Done"

$verifyMatches = [regex]::Matches($newContent, '(?m)^\t(ENG_\w+)\s*=\s*\{')
$nameList = $verifyMatches | ForEach-Object { $_.Groups[1].Value }
$grouped = $nameList | Group-Object | Where-Object { $_.Count -gt 1 }
if ($grouped) {
    Write-Output "Still duplicated: $($grouped.Name -join ', ')"
} else {
    Write-Output "No duplicates remain"
}
Write-Output "Total chars: $($nameList.Count)"
