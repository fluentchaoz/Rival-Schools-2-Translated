"""Assemble the public wrapper; English packet stays a private runtime input."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
s=(r/'build_locations_names_english_v25.ps1').read_text();pre,b=s.split("$Rust = @'\n",1);_,post=b.split("\n'@",1)
def update(t):
 return t.replace('v25','v26').replace('V25','V26').replace('v24','v25').replace('locations-names-v26','shared-dates-v26').replace('locations_names_v26','shared_dates_v26').replace('LOCATIONS_NAMES_V26','SHARED_DATES_V26').replace('field-trip-dates-v25','locations-names-v25').replace('LOCATIONS AND NAME INSERTIONS','SHARED DATES AND DAILY NARRATION').replace('c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f','5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453')
pre=update(pre);post=update(post);rust=(r/'patches/shared_dates_v26.rs').read_text();packet_hash=re.search(r'const PACKET_HASH:&str="([0-9a-f]{64})"',rust)[1]
pre=pre.replace('    [switch]$CheckOnly','    [string]$PacketPath = "",\n    [switch]$CheckOnly')
packet_reader=r'''
$ExpectedPacketHash = "PACKET_HASH"
function HashBytes([byte[]]$Data) {
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Hasher.ComputeHash($Data))).Replace("-","").ToLowerInvariant() } finally { $Hasher.Dispose() }
}
function Read-PrivatePacket([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing private packet or ZIP: $Path" }
    if ([IO.Path]::GetExtension($Path) -ieq ".zip") {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $Entry = $Archive.GetEntry("shared_daily_dates_v26.json")
            if ($null -eq $Entry -or $Entry.Length -gt 2MB) { throw "ZIP does not contain the expected bounded v26 packet." }
            $Stream = $Entry.Open(); $Memory = [IO.MemoryStream]::new()
            try { $Stream.CopyTo($Memory); [byte[]]$Data = $Memory.ToArray() } finally { $Stream.Dispose(); $Memory.Dispose() }
        } finally { $Archive.Dispose() }
    } else {
        if ((Get-Item -LiteralPath $Path).Length -gt 2MB) { throw "Private packet exceeds size limit." }
        [byte[]]$Data = [IO.File]::ReadAllBytes($Path)
    }
    if ((HashBytes $Data) -ne $ExpectedPacketHash) { throw "Private packet hash mismatch: $Path" }
    return ,$Data
}
[byte[]]$PacketBytes = $null
if ($PacketPath) {
    $PacketPath = FullPath $PacketPath
    $PacketBytes = Read-PrivatePacket $PacketPath
} else {
    foreach ($Folder in @((Join-Path $RecoveryRoot "private-inputs"),(Join-Path $env:USERPROFILE "Downloads"),$PSScriptRoot)) {
        if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { continue }
        $Direct = Join-Path $Folder "shared_daily_dates_v26.json"
        $Candidates = @()
        if (Test-Path -LiteralPath $Direct -PathType Leaf) { $Candidates += Get-Item -LiteralPath $Direct }
        $Candidates += @(Get-ChildItem -LiteralPath $Folder -File -Filter "JG2-Shared-Dates-v26-Inputs*.zip" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Candidate in $Candidates) {
            try { $PacketBytes = Read-PrivatePacket $Candidate.FullName; $PacketPath = $Candidate.FullName; break } catch { $PacketBytes = $null }
        }
        if ($null -ne $PacketBytes) { break }
    }
    if ($null -eq $PacketBytes) { throw "Download JG2-Shared-Dates-v26-Inputs.zip from the translation conversation into Downloads, or pass -PacketPath with that ZIP or the exact shared_daily_dates_v26.json. No game or source files changed." }
}
Write-Host ("Verified private v26 translation input: " + $PacketPath)
'''.replace('PACKET_HASH',packet_hash)
pre=pre.replace('$OriginalFontHash = Hash $FontPath',packet_reader+'\n$OriginalFontHash = Hash $FontPath')
pre=pre.replace('Verified original and v25 images, font, source availability, output ownership, and free space.','Verified original and v25 images, private packet, font, source availability, output ownership, and free space.')
post=post.replace('"JG2_V26_FONT"','"JG2_V26_FONT","JG2_V26_PACKET","JG2_V26_QA_DUMP"')
post=post.replace('Write-Host ("Exact source backup: " + $Backup)','Write-Host ("Exact source backup: " + $Backup)\n$PacketCopy = Join-Path $WorkRoot "shared_daily_dates_v26.json"\n[IO.File]::WriteAllBytes($PacketCopy,$PacketBytes)')
post=post.replace('$env:JG2_V26_FONT = $FontPath','$env:JG2_V26_FONT = $FontPath\n    $env:JG2_V26_PACKET = $PacketCopy\n    $env:JG2_V26_QA_DUMP = $null')
post=post.replace('Building the pool/club dialogue, daily menu, and location labels...','Building shared dates and daily narration across 78 text banks...')
post=post.replace('$Preview = Join-Path $BuildDir "club-baseball-palette4-v26.png"\n','')
post=post.replace('$Report.honorific_entries -ne 100 -or $Report.event_banks -ne 25 -or -not $Report.name_selection_and_enrolled_names_preserved','$Report.runtime_images -ne 78 -or $Report.source_patterns -ne 46 -or $Report.source_date_coordinates -ne 4836 -or ($Report.translated_coordinates + $Report.custom_coordinates_preserved) -ne 4836 -or -not $Report.all_other_payloads_and_non_text_records_preserved -or $Report.packet_sha256 -ne $ExpectedPacketHash')
post=post.replace('if ((Hash $FontPath)', 'if ((Hash $PacketCopy) -ne $ExpectedPacketHash) { throw "Candidate translation input changed during build." }\nif ((Hash $FontPath)')
a=post.index('Write-Host "100 honorific');post=post[:a]+'''Write-Host ("Translated date/narration coordinates: " + $Report.translated_coordinates)
Write-Host ("Custom existing payloads retained: " + $Report.custom_coordinates_preserved)
Write-Host "Reviewed source scope: 46 date/narration patterns across 78 School Life text banks."
Write-Host ("Native glyph previews: " + (Join-Path $BuildDir "previews"))
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v25. Boot this new CUE fresh, load your in-game save, and check April 21 daily narration."
Write-Host "Also check one seasonal/exam notice and an earlier translated event. Unique story dialogue remains outside this shared-text batch."
'''
(r/'build_shared_dates_english_v26.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)
print('Public v26 wrapper assembled; private input required, no dialogue packet embedded')
