from pathlib import Path
r=Path(__file__).resolve().parents[1];old=(r/'build_status_diary_english_v28.ps1').read_text();pre=old.split('$ExpectedPacketHash =',1)[0]
pre=pre.replace('    [string]$FontPath = "",\n','').replace('    [string]$PacketPath = "",\n','')
pre=pre.replace('if (-not $FontPath) { $FontPath = "C:\\Windows\\Fonts\\arial.ttf" }\n$FontPath = FullPath $FontPath\n','').replace('$MasterBin,$FontPath,','$MasterBin,')
pre=pre.replace('v28','v29').replace('V28','V29').replace('v27','v28').replace('status-diary-v29','boot-notice-v29').replace('daily-map-v28','status-diary-v28').replace('STATUS AND DIARY','BOOT NOTICE').replace('3f5b7630fd3115804c892e75c37213fbfff148b28ed657d0424ecba0614dc34e','47ed14e1936a0072be400dcdd41296be264ab8bdc1ddcff0e4e7be3bfdc4902b')
pre+='''$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_BOOT_NOTICE_V29")) { throw "Previous v29 injection remains. Restore its exact source backup before retrying." }
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host ("v28 input: " + $MasterBin)
Write-Host "Verified original and v28 images, source availability, output ownership and free space."
if ($CheckOnly) { Write-Host "Preflight passed. No files changed."; return }
'''
post=old.split("\n'@",1)[1]
post=post.replace(',"JG2_V28_FONT","JG2_V28_PACKET","JG2_V28_QA_DUMP"','')
post=post.replace('$PacketCopy = Join-Path $WorkRoot "status_diary_v28.json"\n[IO.File]::WriteAllBytes($PacketCopy,$PacketBytes)\n','')
for line in ['    $env:JG2_V28_FONT = $FontPath\n','    $env:JG2_V28_PACKET = $PacketCopy\n','    $env:JG2_V28_QA_DUMP = $null\n'] :post=post.replace(line,'')
post=post.replace('v28','v29').replace('V28','V29').replace('status_diary_v29','boot_notice_v29').replace('status-diary-v29','boot-notice-v29').replace('Building status labels, 57 item descriptions and diary choices...','Building the startup notice and its shared Records copies...')
a=post.index('if ($Report.runtime_images');b=post.index('if ((Get-Item',a)
post=post[:a]+'''if ($Report.messages -ne 2 -or $Report.record_copies -ne 4 -or -not $Report.code_fonts_pointers_and_other_bytes_preserved) { throw "Report scope verification failed." }
'''+post[b:]
post='\n'.join(l for l in post.split('\n') if '$PacketCopy' not in l and '$OriginalFontHash' not in l)
a=post.index('Write-Host ""');post=post[:a]+'''Write-Host ""
Write-Host "BOOT NOTICE ENGLISH v29 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host "Startup: NO FILE / LOAD SKIPPED. Shared Records copies updated."
Write-Host "Code, fonts, pointers, save behavior and earlier English preserved."
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v28. Fresh-boot the new CUE and check the startup notice."
Write-Host "Exam instruction graphics and other save/load prompts remain outside this build."
'''
rust=(r/'patches/boot_notice_v29.rs').read_text();(r/'build_boot_notice_english_v29.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)
