# Read-only export for the first untranslated post-quiz stat-result screen.
# Windows PowerShell 5.1 or PowerShell 7; no Rust, Python, or network required.
[CmdletBinding()]
param(
    [string]$RecoveryRoot = "",
    [string]$SourceBin = "",
    [string]$MasterBin = "",
    [string]$OutputZip = "",
    [switch]$CheckOnly
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedMasterHash = "2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a"
$ExpectedDiscBytes = [long]663216960
$RecordPaths = @("DAT1/MGAME.BIN", "DAT2/MGK04.BIZ", "DAT2/MGCOCK.TIZ", "SLPS_021.20")

function FullPath([string]$Path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}
if (-not $RecoveryRoot) { $RecoveryRoot = Join-Path $env:USERPROFILE "JG2-Recovery-v1" }
$RecoveryRoot = FullPath $RecoveryRoot
if (-not $SourceBin) {
    $SourceBin = Join-Path $RecoveryRoot "project/upstream/roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
}
if (-not $MasterBin) {
    $StatePath = Join-Path $RecoveryRoot "recovery-state.json"
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
        throw "Recovery state not found. Pass -RecoveryRoot or -MasterBin with the working v17h BIN."
    }
    $State = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if (-not $State.v17h_bin) { throw "Recovery state does not contain a completed v17h BIN. Pass -MasterBin explicitly." }
    $MasterBin = [string]$State.v17h_bin
}
if (-not $OutputZip) {
    $OutputZip = Join-Path (Join-Path $env:USERPROFILE "Downloads") ("JG2-Stat-Probe-v18-" + [Guid]::NewGuid().ToString("N") + ".zip")
}
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$OutputZip = FullPath $OutputZip
$PartialZip = $OutputZip + ".partial"
if ([IO.Path]::GetExtension($OutputZip) -ine ".zip") { throw "-OutputZip must end in .zip." }
foreach ($Path in @($OutputZip, $PartialZip)) {
    if (Test-Path -LiteralPath $Path) { throw "Output already exists: $Path. Choose a new -OutputZip; existing files are never replaced." }
}
$OutputParent = Split-Path -Parent $OutputZip
if (-not (Test-Path -LiteralPath $OutputParent -PathType Container)) { throw "Output folder does not exist: $OutputParent" }
$Drive = [IO.DriveInfo]::new([IO.Path]::GetPathRoot($OutputZip))
if ($Drive.AvailableFreeSpace -lt 256MB) { throw "The output drive needs 256 MiB free for this small export." }

# This intentionally supports only contiguous Mode 1 / Mode 2 Form 1 ISO files.
# Like the pinned upstream reader it checks sync, duplicate XA subheaders,
# dual-endian directory fields, and the 2048-byte logical block size.
if (-not ("JG2StatProbeV18.ReadOnlyDisc" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace JG2StatProbeV18 {
    public sealed class Record {
        public string Name;
        public uint Lba;
        public uint Size;
        public byte Flags;
        public byte[] Data;
    }
    public sealed class ReadOnlyDisc : IDisposable {
        private FileStream input;
        private Record root;
        public string Identity { get; private set; }
        public long Length { get { return input.Length; } }

        public ReadOnlyDisc(string path, string expected, long length) {
            try {
                input = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
                Need(input.Length == length && length % 2352 == 0, "Disc length mismatch.");
                Identity = HashInput();
                Need(Identity == expected, "Disc SHA-256 mismatch: " + Path.GetFileName(path));
                byte[] pvd = Sector(16, true);
                Need(pvd[0] == 1 && Encoding.ASCII.GetString(pvd, 1, 5) == "CD001" && pvd[6] == 1,
                    "ISO primary volume descriptor not found.");
                Need(U16(pvd, 128) == 2048, "Unsupported ISO block size.");
                root = Parse(pvd, 156);
                Need((root.Flags & 2) != 0, "ISO root is not a directory.");
            } catch { Dispose(); throw; }
        }
        private static void Need(bool ok, string reason) {
            if (!ok) throw new InvalidDataException(reason);
        }
        public static string Digest(byte[] data) {
            using (SHA256 hash = SHA256.Create()) { return Hex(hash.ComputeHash(data)); }
        }
        private static string Hex(byte[] data) {
            return BitConverter.ToString(data).Replace("-", "").ToLowerInvariant();
        }
        private string HashInput() {
            input.Position = 0;
            using (SHA256 hash = SHA256.Create()) { return Hex(hash.ComputeHash(input)); }
        }
        public void VerifyUnchanged() {
            Need(HashInput() == Identity, "Disc changed during export.");
        }
        private byte[] Sector(uint lba, bool pvd) {
            Need(((long)lba + 1) * 2352 <= input.Length, "ISO extent is outside the disc.");
            input.Position = (long)lba * 2352;
            byte[] raw = new byte[2352];
            int done = 0;
            while (done < raw.Length) {
                int n = input.Read(raw, done, raw.Length - done);
                Need(n > 0, "Truncated raw sector.");
                done += n;
            }
            Need(raw[0] == 0 && raw[11] == 0, "Invalid raw-sector sync.");
            for (int i = 1; i < 11; i++) Need(raw[i] == 255, "Invalid raw-sector sync.");
            int offset;
            if (raw[15] == 2) {
                for (int i = 0; i < 4; i++) Need(raw[16+i] == raw[20+i], "XA subheaders differ.");
                Need((raw[18] & 32) == 0, "Mode 2 Form 2 is not a supported data extent.");
                offset = 24;
            } else {
                Need(raw[15] == 1 && !pvd, "Unsupported sector mode (PVD must be Mode 2 Form 1).");
                offset = 16;
            }
            byte[] result = new byte[2048];
            Buffer.BlockCopy(raw, offset, result, 0, result.Length);
            return result;
        }
        private static uint U32(byte[] b, int at) {
            uint le = (uint)b[at] | ((uint)b[at+1] << 8) | ((uint)b[at+2] << 16) | ((uint)b[at+3] << 24);
            uint be = ((uint)b[at+4] << 24) | ((uint)b[at+5] << 16) | ((uint)b[at+6] << 8) | b[at+7];
            Need(le == be, "ISO dual-endian u32 mismatch.");
            return le;
        }
        private static ushort U16(byte[] b, int at) {
            ushort le = (ushort)(b[at] | (b[at+1] << 8));
            ushort be = (ushort)((b[at+2] << 8) | b[at+3]);
            Need(le == be, "ISO dual-endian u16 mismatch.");
            return le;
        }
        private static Record Parse(byte[] b, int at) {
            int n = b[at];
            Need(n >= 34 && at + n <= b.Length && at % 2048 + n <= 2048, "Invalid ISO directory record.");
            int count = b[at+32];
            Need(count > 0 && 33 + count <= n, "Invalid ISO file name.");
            Need(b[at+1] == 0 && b[at+26] == 0 && b[at+27] == 0 && (b[at+25] & 128) == 0,
                "Extended, interleaved, or multi-extent ISO records are unsupported.");
            string name = Encoding.ASCII.GetString(b, at+33, count).Split(';')[0];
            if (count == 1 && b[at+33] == 0) name = ".";
            if (count == 1 && b[at+33] == 1) name = "..";
            return new Record { Name = name, Lba = U32(b, at+2), Size = U32(b, at+10), Flags = b[at+25] };
        }
        private byte[] Extent(Record r) {
            Need(r.Size <= 16 * 1024 * 1024, "Probe record exceeds the 16 MiB limit.");
            Need(((long)r.Lba + ((long)r.Size + 2047) / 2048) * 2352 <= input.Length, "ISO extent is outside the disc.");
            byte[] data = new byte[(int)r.Size];
            for (int offset = 0; offset < data.Length; offset += 2048) {
                byte[] sector = Sector(r.Lba + (uint)(offset / 2048), false);
                Buffer.BlockCopy(sector, 0, data, offset, Math.Min(2048, data.Length - offset));
            }
            return data;
        }
        public Record ReadFile(string path) {
            Record current = root;
            foreach (string part in path.Split('/')) {
                Need((current.Flags & 2) != 0, "Expected an ISO directory.");
                byte[] directory = Extent(current);
                Record found = null;
                for (int at = 0; at < directory.Length;) {
                    if (directory[at] == 0) { at = (at / 2048 + 1) * 2048; continue; }
                    Record candidate = Parse(directory, at);
                    if (String.Equals(candidate.Name, part, StringComparison.OrdinalIgnoreCase)) {
                        Need(found == null, "Duplicate ISO path: " + path);
                        found = candidate;
                    }
                    at += directory[at];
                }
                Need(found != null, "ISO file not found: " + path);
                current = found;
            }
            Need((current.Flags & 2) == 0, "Expected an ISO file: " + path);
            current.Data = Extent(current);
            return current;
        }
        public void Dispose() { if (input != null) { input.Dispose(); input = null; } }
    }
}
'@
}

$Discs = @()
try {
    Write-Host "Checking the original and working v17h disc identities..." -ForegroundColor Cyan
    $Discs += [JG2StatProbeV18.ReadOnlyDisc]::new($SourceBin, $ExpectedSourceHash, $ExpectedDiscBytes)
    $Discs += [JG2StatProbeV18.ReadOnlyDisc]::new($MasterBin, $ExpectedMasterHash, $ExpectedDiscBytes)
    $Roles = @("original", "v17h")
    $Files = @()
    $ReportRecords = @()
    for ($i = 0; $i -lt $Discs.Count; $i++) {
        foreach ($Path in $RecordPaths) {
            $Record = $Discs[$i].ReadFile($Path)
            $EntryName = $Roles[$i] + "/" + $Path
            $Files += @{ Name = $EntryName; Data = $Record.Data }
            $ReportRecords += [ordered]@{
                image = $Roles[$i]; path = $Path; zip_entry = $EntryName
                extent_lba = $Record.Lba; bytes = $Record.Size
                sha256 = [JG2StatProbeV18.ReadOnlyDisc]::Digest($Record.Data)
            }
            Write-Host ("  {0}: {1} ({2:N0} bytes)" -f $Roles[$i], $Path, $Record.Size)
        }
    }
    foreach ($Disc in $Discs) { $Disc.VerifyUnchanged() }
    if ($CheckOnly) {
        Write-Host "Preflight passed. Both discs and all eight records verified; no export or game/project changes made." -ForegroundColor Green
        return
    }
    $Report = [ordered]@{
        schema = 1; probe = "JG2 stat results v18"; created_utc = [DateTime]::UtcNow.ToString("o")
        original_sha256 = $Discs[0].Identity; v17h_sha256 = $Discs[1].Identity
        disc_bytes = $ExpectedDiscBytes; inputs_unchanged = $true; records = $ReportRecords
        purpose = "Inspect shared stat increase/decrease messages and native arrow spacing. This export is not a patch."
    }
    $Utf8 = [Text.UTF8Encoding]::new($false)
    $Files += @{ Name = "manifest.json"; Data = $Utf8.GetBytes(($Report | ConvertTo-Json -Depth 8)) }
    Add-Type -AssemblyName System.IO.Compression
    $ZipStream = [IO.File]::Open($PartialZip, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $Archive = [IO.Compression.ZipArchive]::new($ZipStream, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($File in $Files) {
                $Entry = $Archive.CreateEntry($File.Name, [IO.Compression.CompressionLevel]::Optimal)
                $EntryStream = $Entry.Open()
                try { $EntryStream.Write($File.Data, 0, $File.Data.Length) } finally { $EntryStream.Dispose() }
            }
        } finally { $Archive.Dispose() }
    } finally { $ZipStream.Dispose() }
    # Validate the actual saved archive before giving it its final name.
    $ZipStream = [IO.File]::OpenRead($PartialZip)
    try {
        $Archive = [IO.Compression.ZipArchive]::new($ZipStream, [IO.Compression.ZipArchiveMode]::Read, $true)
        try {
            if ($Archive.Entries.Count -ne $Files.Count) { throw "ZIP entry count mismatch." }
            foreach ($File in $Files) {
                $Entry = $Archive.GetEntry($File.Name)
                if ($null -eq $Entry -or $Entry.Length -ne $File.Data.Length) { throw "ZIP record missing or truncated: $($File.Name)" }
                $EntryStream = $Entry.Open()
                $Memory = [IO.MemoryStream]::new()
                try {
                    $EntryStream.CopyTo($Memory)
                    if ([JG2StatProbeV18.ReadOnlyDisc]::Digest($Memory.ToArray()) -ne [JG2StatProbeV18.ReadOnlyDisc]::Digest($File.Data)) {
                        throw "ZIP record hash mismatch: $($File.Name)"
                    }
                } finally { $EntryStream.Dispose(); $Memory.Dispose() }
            }
        } finally { $Archive.Dispose() }
    } finally { $ZipStream.Dispose() }
    [IO.File]::Move($PartialZip, $OutputZip)
    Write-Host ""
    Write-Host "STAT-RESULT EXPORT COMPLETE" -ForegroundColor Green
    Write-Host "Original, v16, v17h, recovery state, and project source were not modified."
    Write-Host ("ZIP TO ATTACH HERE: " + $OutputZip) -ForegroundColor Yellow
    Write-Host ("ZIP SIZE: {0:N2} MiB" -f ((Get-Item -LiteralPath $OutputZip).Length / 1MB))
    Write-Host "This ZIP contains private game records. Attach it in the translation conversation; keep it out of public GitHub."
} finally {
    foreach ($Disc in $Discs) { $Disc.Dispose() }
}
