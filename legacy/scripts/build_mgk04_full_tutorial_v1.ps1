param(
    [string]$RomFolder = "C:\Users\Fluent\Downloads\Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)",
    [string]$WorkspacePackage = "",
    [string]$FontPath = ""
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail ("{0} failed with exit code {1}" -f $Command, $LASTEXITCODE)
    }
}

function Read-Utf8Text([string]$Path) {
    return [System.IO.File]::ReadAllText(
        $Path,
        (New-Object System.Text.UTF8Encoding($false, $true))
    )
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $Parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Replace-RegexOnce(
    [string]$Text,
    [string]$Pattern,
    [string]$Replacement,
    [string]$Description
) {
    $Regex = New-Object System.Text.RegularExpressions.Regex(
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $Matches = $Regex.Matches($Text)
    if ($Matches.Count -ne 1) {
        Fail ("{0}: expected exactly one match, found {1}" -f $Description, $Matches.Count)
    }
    return $Regex.Replace($Text, $Replacement, 1)
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$TargetRecord = "DAT2/MGK04.BIZ"

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder beside this script."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Fail "Cargo is not on PATH."
}

# ---------------------------------------------------------------------------
# Locate the validated Batsu workspace package produced by bootstrap v4.
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($WorkspacePackage)) {
    $Candidates = @(
        (Join-Path $Upstream "work\english-batsu-workspace-bootstrap-v4.zip"),
        (Join-Path $Here "english-batsu-workspace-bootstrap-v4.zip"),
        (Join-Path $env:USERPROFILE "Downloads\english-batsu-workspace-bootstrap-v4.zip")
    )
    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) {
            $WorkspacePackage = $Candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($WorkspacePackage) -or -not (Test-Path $WorkspacePackage)) {
    Fail "Could not find english-batsu-workspace-bootstrap-v4.zip. Pass -WorkspacePackage if you moved it."
}

# ---------------------------------------------------------------------------
# Validate exact source BIN and restore the standard upstream ROM path.
# ---------------------------------------------------------------------------
$Bins = @(Get-ChildItem -Path $RomFolder -Filter *.bin -File)
if ($Bins.Count -ne 1) {
    Fail ("Expected exactly one .bin in {0}; found {1}" -f $RomFolder, $Bins.Count)
}

$SourceBin = $Bins[0].FullName
$SourceHash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
Write-Host ("Source BIN SHA-256: {0}" -f $SourceHash)
if ($SourceHash -ne $ExpectedBinHash) {
    Fail "This is not the exact BIN we audited."
}

$Roms = Join-Path $Upstream "roms"
New-Item -ItemType Directory -Force -Path $Roms | Out-Null
$TargetBin = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
$TargetCue = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"

if (-not (Test-Path $TargetBin) -or
    (Get-FileHash -Algorithm SHA256 $TargetBin).Hash.ToLower() -ne $ExpectedBinHash) {
    Copy-Item $SourceBin $TargetBin -Force
}

$SourceCueText = @'
FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@
[System.IO.File]::WriteAllText($TargetCue, $SourceCueText, [System.Text.Encoding]::ASCII)

# ---------------------------------------------------------------------------
# Compose this MGK04 patch on top of the already-verified English menu/title
# build so we preserve Mode Select, PLAY/LOAD, and the earlier Batsu MGT00 patch.
# ---------------------------------------------------------------------------
$BaseBin = Join-Path $Upstream "work\english-road-to-batsu-dynamic-date-pretty-v2\build\justice-gakuen2-road-to-batsu-dynamic-date-pretty-v2.bin"
$ExpectedBaseHash = "6479176dc1788f64deb933d1a08569c87e677f5d1ba0f3e001567158dc80c91d"
if (-not (Test-Path $BaseBin)) {
    Fail "Missing the verified 6479176d... master build with pretty dynamic date and SCHOOL GATE."
}
$BaseHash = (Get-FileHash -Algorithm SHA256 $BaseBin).Hash.ToLower()
Write-Host ("Master base BIN SHA-256: {0}" -f $BaseHash)
if ($BaseHash -ne $ExpectedBaseHash) {
    Fail "Base is not the exact verified 6479176d... master build."
}

# ---------------------------------------------------------------------------
# Font: prototype accepts an installed Windows font, but never distributes it.
# ---------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($FontPath)) {
    foreach ($Candidate in @(
        "C:\Windows\Fonts\arial.ttf",
        "C:\Windows\Fonts\segoeui.ttf",
        "C:\Windows\Fonts\calibri.ttf",
        "C:\Windows\Fonts\consola.ttf"
    )) {
        if (Test-Path $Candidate) {
            $FontPath = $Candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($FontPath) -or -not (Test-Path $FontPath)) {
    Fail "Could not locate a prototype font. Re-run with -FontPath pointing to an installed .ttf."
}
Write-Host ("Prototype font: {0}" -f $FontPath)

# ---------------------------------------------------------------------------
# Work tree.
# ---------------------------------------------------------------------------
$WorkRoot = Join-Path $Upstream "work\english-mgk04-full-tutorial-v1"
$PackageRoot = Join-Path $WorkRoot "workspace-package"
$PrimaryWorkspace = Join-Path $PackageRoot "translation-workspace"
$Codebook = Join-Path $PackageRoot "batsu-codebook.json"
$SelectorWorkspace = Join-Path $WorkRoot "selector-workspace"
$KeyboardDir = Join-Path $WorkRoot "name-entry"
$Keyboard = Join-Path $KeyboardDir "keyboard.json"
$PrimaryAudit = Join-Path $WorkRoot "primary-mgk04-full-tutorial-audit.json"
$SelectorAudit = Join-Path $WorkRoot "selector-audit.json"
$BuildOutput = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildOutput "justice-gakuen2-mgk04-full-tutorial-v1.bin"
$OutputCue = Join-Path $BuildOutput "justice-gakuen2-mgk04-full-tutorial-v1.cue"
$OutputReport = Join-Path $BuildOutput "prototype-report.json"

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PackageRoot | Out-Null
Expand-Archive -Path $WorkspacePackage -DestinationPath $PackageRoot -Force

if (-not (Test-Path $PrimaryWorkspace)) {
    Fail "Workspace package does not contain translation-workspace."
}
if (-not (Test-Path $Codebook)) {
    Fail "Workspace package does not contain batsu-codebook.json."
}

# ---------------------------------------------------------------------------
# First playable test deliberately uses ONLY scene 1 and text that fits the
# confirmed native renderer: <=20 cells per line, <=4 lines per message.
# ---------------------------------------------------------------------------
$FitJson = @'
{
  "DAT2/MGK04.BIZ#bank-0-entry-0000": [
    "",
    "SCHOOL LIFE 2",
    "WELCOME",
    "HAVE A GREAT YEAR!",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0001": [
    "UNTIL THE EXAM,",
    "I'LL GUIDE YOU.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0002": [
    "ME?",
    "I'M CLASS PRESIDENT.",
    "CALL ME PRESIDENT.",
    "DON'T YOU KNOW ME?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0003": [
    "ANYWAY.",
    "IF YOU NEED HELP",
    "WITH THIS GAME,",
    "JUST ASK ME.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0004": [
    "GOAL",
    "",
    "",
    "",
    "CONTROLS",
    "SETUP",
    "",
    "",
    "",
    "FLOW",
    "GROWTH",
    "",
    "",
    "",
    "ABOUT",
    "SKIP",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0005": [
    "YOU CAME HERE",
    "WITHOUT KNOWING?",
    "FINE. I'LL EXPLAIN.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0006": [
    "YOUR GOAL IS TO",
    "SPEND A SCHOOL YEAR",
    "FROM ENROLLMENT TO",
    "",
    "EDIT CHARACTER",
    "AND MAKE IT YOURS.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0007": [
    "YOUR CREATED FIGHTER",
    "",
    "\"EDIT CHAR\"",
    " REGISTER",
    "FOR",
    " OTHER MODES.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0008": [
    "YOU CAN REGISTER",
    "A SAVE IN PROGRESS.",
    "NO NEED TO FINISH.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0009": [
    "SOME PEOPLE JUST",
    "ENJOY SCHOOL LIFE",
    "MORE THAN BUILDING",
    "A FIGHTER. THAT'S OK",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0010": [
    "THAT'S THE GOAL.",
    "ANYTHING ELSE?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0011": [
    "BASIC CONTROLS:",
    "D-PAD: SELECT",
    "",
    "\ue296",
    "/",
    "\ue28a",
    "/",
    "\ue243",
    "/",
    "\ue276",
    "= OK",
    "",
    "X",
    "/",
    "\ue315",
    "= CANCEL",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0012": [
    "ADVANCE TEXT WITH",
    "",
    "\ue296",
    "/",
    "\ue28a",
    "/",
    "\ue243",
    "/",
    "\ue276",
    ".",
    "USE ",
    "\ue243",
    "=SKIP",
    " TO CHOICE",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0013": [
    "FOR MINI-GAMES,",
    "",
    "\"HELP\"",
    " HAS DETAILS.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0014": [
    "THAT'S CONTROLS.",
    "ANYTHING ELSE?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0015": [
    "ABOUT YOUR SETUP:",
    "YOU'LL FILL OUT AN",
    "APPLICATION NEXT.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0016": [
    "NAME AND SCHOOL OK?",
    "GENERAL ADMISSION TO",
    "JUSTICE IS OPEN NOW.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0017": [
    "OTHER FIELDS RATE",
    "BIRTHDAY, BEST CLASS",
    "FAVORITE WORD...",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0018": [
    "YOUR FAVORITE WORD",
    "STRONGLY AFFECTS",
    "CPU BEHAVIOR,",
    "SO CHOOSE CAREFULLY.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0019": [
    "AFTER YOUR FORM,",
    "REGISTER YOUR PHOTO.",
    "PICK PARTS YOU LIKE",
    "TO MAKE YOUR FACE.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0020": [
    "DON'T LIKE THE HAIR?",
    "",
    "SELECT",
    " CHANGES IT.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0021": [
    "THAT'S CHARACTER",
    "SETUP.",
    "ANYTHING ELSE?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0022": [
    "ABOUT GAME FLOW:",
    "IT LASTS ONE YEAR.",
    "SCHOOL EVENTS HAPPEN",
    "WITH THE SEASONS.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0023": [
    "EXAMS, CAMP, FEST",
    "CHRISTMAS, NEW YEAR,",
    "VALENTINE'S DAY AND",
    "WHITE DAY, TOO.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0024": [
    "EACH MONTH STARTS",
    "WITH SPECIAL CLUB",
    "PRACTICE. MORE ON",
    "THAT LATER.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0025": [
    "MID-MONTH, THERE'S",
    "A DAY TO ROAM",
    "AROUND THE SCHOOL.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0026": [
    "PLACES:",
    "CLASS",
    ",",
    "FIELD",
    ",",
    "",
    "ROOF",
    ",",
    "GYM",
    ",",
    "NURSE",
    " PLUS",
    "",
    "CLUBS",
    ". SIX TOTAL.",
    "SOME MAY BE CLOSED.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0027": [
    "AND THOSE SCHOOL",
    "EVENTS I MENTIONED.",
    "THAT'S THE FLOW.",
    "ANYTHING ELSE?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0028": [
    "ABOUT GROWTH:",
    "YOUR MAIN WAY TO",
    "MAINLY VIA ",
    "CLUBS",
    ".",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0029": [
    "JOIN A CLUB AND",
    "YOUR STATS WILL",
    "GROW OVER TIME.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0030": [
    "AT MONTH'S START",
    "EACH CLUB:",
    "BOOST",
    " DAY",
    "IT CAN RAISE",
    "CERTAIN STATS A LOT.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0031": [
    "CLUB ORIENTATION",
    "WILL EXPLAIN MORE.",
    "IT'S AFTER THE",
    "ENTRANCE CEREMONY.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0032": [
    "SCHOOL EVENTS LIKE",
    "SPORTS FESTIVAL AND",
    "EXAMS CAN BOOST YOU",
    "IF YOU DO WELL.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0033": [
    "THAT'S CHARACTER",
    "GROWTH.",
    "ANYTHING ELSE?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0034": [
    "ME?",
    "I'M CLASS PRESIDENT.",
    "I'M HINATA'S FRIEND.",
    "YOU KNOW HINATA, YES",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0035": [
    "ENOUGH ABOUT ME.",
    "ANYTHING ELSE?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0036": [
    "RIGHT. THE ENTRANCE",
    "EXAM STARTS SOON.",
    "SUBMIT YOUR FORM AND",
    "GO TO THE EXAM SITE",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0037": [
    "THIS YEAR'S EXAM IS",
    "WRITTEN. PRACTICALS",
    "ARE ONLY FOR FINALS.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0038": [
    "SEE YOU.",
    "AT THE CEREMONY!",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0039": [
    "ALL RIGHT.",
    "TO ENROLL HERE,",
    "YOU'LL TAKE A SHORT",
    "ENTRANCE EXAM.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0040": [
    "IT'S A WRITTEN TEST.",
    "TEN QUESTIONS FOLLOW",
    "PRESS THE SYMBOL",
    "OF THE RIGHT ANSWER.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0041": [
    "CORRECT ANSWERS GET",
    "POINTS + TIME BONUS.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0042": [
    "ANSWER QUICKLY:",
    "THE BIGGER THE",
    "TIME BONUS.",
    "ANSWER QUICKLY!",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0043": [
    "IF YOU'VE STUDIED,",
    "THEY SHOULD BE EASY.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0044": [
    "LET'S BEGIN.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0045": [
    "NICE WORK, ",
    "",
    "",
    "!",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0046": [
    "YOUR KNOWLEDGE",
    "SOLID. IMPRESSIVE.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0047": [
    "DECENT KNOWLEDGE.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0048": [
    "YOU BARELY GOT ANY",
    "RIGHT! DID YOU STUDY",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0049": [
    "AND YOU JUDGED",
    "FAST AND ACCURATE.",
    "EXCELLENT WORK.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0050": [
    "QUICK JUDGMENT.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0051": [
    "ANSWER A BIT FASTER.",
    "I KNOW YOU CAN.",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0052": [
    "I CAN PROUDLY ADMIT",
    "YOU. GOOD LUCK!",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0053": [
    "YOU'RE ADMITTED.",
    "HOW FAR YOU GO IS",
    "UP TO YOU. WORK HARD",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0054": [
    "YOU'RE ADMITTED, BUT",
    "YOUR SCORES WORRY ME",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0055": [
    "WORK HARD OR YOU'LL",
    "FALL BEHIND!",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-0-entry-0056": [
    "I DON'T WANT THAT.",
    "SO STUDY HARD, OK?",
    ""
  ],
  "DAT2/MGK04.BIZ#bank-1-entry-0045": [
    "NICE WORK, ",
    "",
    "",
    "!",
    ""
  ]
}
'@

$FitObj = $FitJson | ConvertFrom-Json
$FitByCoordinate = @{}
foreach ($Property in $FitObj.PSObject.Properties) {
    $FitByCoordinate[[string]$Property.Name] = @($Property.Value)
}
if ($FitByCoordinate.Count -ne 58) {
    Fail ("Expected 58 MGK04 tutorial coordinates; got {0}." -f $FitByCoordinate.Count)
}

# Context shards are the canonical coordinate -> current semantic hash binding.
$SemanticByCoordinate = @{}
$SceneSegmentsBySemantic = @{}
$ContextFiles = @(Get-ChildItem (Join-Path $PrimaryWorkspace "context\mgk04") -Recurse -Filter *.json -File)

foreach ($File in $ContextFiles) {
    $Obj = (Read-Utf8Text $File.FullName) | ConvertFrom-Json
    if ([string]$Obj.kind -ne "Justice Gakuen 2 route dialogue context shard") {
        continue
    }

    foreach ($Entry in @($Obj.entries)) {
        $Coordinate = [string]$Entry.coordinate_id
        if (-not $FitByCoordinate.ContainsKey($Coordinate)) {
            continue
        }

        $Semantic = [string]$Entry.semantic_source_sha256
        if ([string]::IsNullOrWhiteSpace($Semantic)) {
            Fail ("Opening-scene coordinate has no semantic hash: {0}" -f $Coordinate)
        }

        $Segments = @($FitByCoordinate[$Coordinate])
        $SegmentsKey = ($Segments | ConvertTo-Json -Compress)

        if ($SceneSegmentsBySemantic.ContainsKey($Semantic)) {
            $ExistingKey = (@($SceneSegmentsBySemantic[$Semantic]) | ConvertTo-Json -Compress)
            if ($ExistingKey -ne $SegmentsKey) {
                Fail ("Shared semantic group has conflicting fitted English: {0}" -f $Semantic)
            }
        } else {
            $SceneSegmentsBySemantic[$Semantic] = $Segments
        }
        $SemanticByCoordinate[$Coordinate] = $Semantic
    }
}

if ($SemanticByCoordinate.Count -ne 58) {
    Fail ("Only {0}/58 MGK04 tutorial coordinates were found in current route contexts." -f $SemanticByCoordinate.Count)
}
if ($SceneSegmentsBySemantic.Count -ne 58) {
    Fail ("Expected 58 MGK04 tutorial semantic groups; got {0}." -f $SceneSegmentsBySemantic.Count)
}

# First demote every previous Batsu draft back to untranslated, then author only
# the 5 fitted MGK04 opening groups.
# Clear authored decisions across the ENTIRE primary workspace first.
# The Batsu bootstrap contains 116 MGT00 drafts plus one shared draft owned by MGE03.
# Restricting this scan to MGT00 leaves that MGE03 decision authored and makes the
# audit report 20 drafts instead of the intended 19-scene prototype.
$TranslationFiles = @(Get-ChildItem (Join-Path $PrimaryWorkspace "translations\in-progress") -Recurse -Filter *.json -File)
$AuthoredCount = 0
$SceneSemanticSeen = New-Object System.Collections.Generic.HashSet[string]

foreach ($File in $TranslationFiles) {
    $Obj = (Read-Utf8Text $File.FullName) | ConvertFrom-Json
    if ($null -eq $Obj.entries) {
        continue
    }

    $Changed = $false
    foreach ($Decision in @($Obj.entries)) {
        $Semantic = [string]$Decision.semantic_source_sha256

        if ($SceneSegmentsBySemantic.ContainsKey($Semantic)) {
            $Segments = @($SceneSegmentsBySemantic[$Semantic])
            if (@($Decision.korean_segments).Count -ne $Segments.Count) {
                Fail (
                    "Segment/control shape changed for opening-scene group {0}: workspace={1}, fitted={2}" -f
                    $Semantic, @($Decision.korean_segments).Count, $Segments.Count
                )
            }
            $Decision.korean_segments = @($Segments)
            $Decision.status = "draft"
            $Decision.translator = "Justice Gakuen English Project"
            $Decision.notes = "Full English MGK04 tutorial/admissions translation; korean_segments is temporarily used as generic target-language storage."
            [void]$SceneSemanticSeen.Add($Semantic)
            $AuthoredCount += 1
            $Changed = $true
        }
        elseif ([string]$Decision.status -ne "untranslated") {
            $NullSegments = @()
            foreach ($Unused in @($Decision.korean_segments)) {
                $NullSegments += $null
            }
            $Decision.korean_segments = $NullSegments
            $Decision.status = "untranslated"
            $Decision.translator = $null
            $Decision.notes = ""
            $Changed = $true
        }
    }

    if ($Changed) {
        Write-Utf8NoBom $File.FullName (($Obj | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
    }
}

if ($SceneSemanticSeen.Count -ne 58 -or $AuthoredCount -ne 58) {
    Fail ("Expected to author exactly 58 MGK04 tutorial groups; seen={0}, authored={1}." -f $SceneSemanticSeen.Count, $AuthoredCount)
}

# Local JSON-level sanity check before invoking the Rust audit.
$RemainingDrafts = 0
$RemainingDraftOwners = New-Object System.Collections.Generic.List[string]
foreach ($File in $TranslationFiles) {
    $Obj = (Read-Utf8Text $File.FullName) | ConvertFrom-Json
    foreach ($Decision in @($Obj.entries)) {
        if ([string]$Decision.status -eq "draft") {
            $RemainingDrafts += 1
            if ($RemainingDraftOwners.Count -lt 10) {
                $RemainingDraftOwners.Add($File.FullName)
            }
        }
    }
}
if ($RemainingDrafts -ne 58) {
    Fail (
        "Primary workspace cleanup expected 58 drafts before Rust audit; found {0}. First owners: {1}" -f
        $RemainingDrafts, ($RemainingDraftOwners -join "; ")
    )
}

Write-Host ""
Write-Host "Full MGK04 tutorial/admissions text prepared:" -ForegroundColor Cyan
Write-Host "  Coordinates: 58"
Write-Host "  Semantic groups: 58"
Write-Host "  Includes help menu, controls, setup, flow, growth, admissions, exam instructions, and result reactions"
Write-Host "  Native line bound: <=20 cells"
Write-Host "  Native message bound: <=4 lines"
Write-Host "  Entry 0 combined palette line: SCHOOL LIFE 2 + WELCOME = 20 cells"
Write-Host "  Force-materializes printable ASCII glyphs in MGK04 (fixes I/F/M/V/!)"

# ---------------------------------------------------------------------------
# Minimal keyboard spec needed only so upstream code allocation can reserve the
# original shared-name code domain. The prototype font builder below DOES NOT
# overwrite those name cells or install a Hangul pack.
# JSON is ASCII-only via \u escapes so Windows PowerShell 5.1 cannot mojibake it.
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $KeyboardDir | Out-Null
$KeyboardJson = @'
{
  "kind": "Justice Gakuen 2 Korean name-input keyboard",
  "source_overlay_sha256": "eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a",
  "pages": [
    {
      "source_page": "hiragana",
      "role": "hangul",
      "label": "Hangul",
      "groups": [
        {
          "id": "consonants",
          "input": "consonant",
          "characters": "\u3131\u3132\u3134\u3137\u3138\u3139\u3141\u3142\u3143\u3145\u3146\u3147\u3148\u3149\u314a\u314b\u314c\u314d\u314e"
        },
        {
          "id": "vowels",
          "input": "vowel",
          "characters": "\u314f\u3150\u3151\u3152\u3153\u3154\u3155\u3156\u3157\u3158\u3159\u315a\u315b\u315c\u315d\u315e\u315f\u3160\u3161\u3162\u3163"
        }
      ]
    },
    {
      "source_page": "katakana",
      "role": "latin",
      "label": "Latin",
      "groups": [
        {
          "id": "latin",
          "input": "direct",
          "characters": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        }
      ]
    },
    {
      "source_page": "alphanumeric",
      "role": "digits_and_symbols",
      "label": "Digits/Symbols",
      "groups": [
        {
          "id": "digits",
          "input": "direct",
          "characters": "0123456789"
        },
        {
          "id": "symbols",
          "input": "direct",
          "characters": " .-_!?@#%&+/:'\""
        }
      ]
    }
  ]
}
'@
Write-Utf8NoBom $Keyboard $KeyboardJson

# ---------------------------------------------------------------------------
# Verify the earlier development-PUA patches are present.
# ---------------------------------------------------------------------------
$CorpusRs = Join-Path $Upstream "src\dialogue_audit\corpus.rs"
$WorkspaceSourceRs = Join-Path $Upstream "src\dialogue_audit\translation_workspace_source.rs"

if (-not (Test-Path $CorpusRs) -or
    -not (Read-Utf8Text $CorpusRs).Contains("ENGLISH_PROJECT_DEVELOPMENT_PUA_SEMANTICS")) {
    Fail "Development PUA corpus patch is missing. The successful v4 bootstrap should have installed it."
}
if (-not (Test-Path $WorkspaceSourceRs) -or
    -not (Read-Utf8Text $WorkspaceSourceRs).Contains("ENGLISH_PROJECT_DEVELOPMENT_PUA_WORKSPACE_DENOMINATOR")) {
    Fail "Development PUA workspace patch is missing. The successful v4 bootstrap should have installed it."
}

# ---------------------------------------------------------------------------
# Patch selector semantic denominators for the PUA development corpus while
# keeping structural counts strict.
# ---------------------------------------------------------------------------
$SelectorSourceRs = Join-Path $Upstream "src\dialogue_audit\selector_translation_source.rs"
$SelectorSourceText = Read-Utf8Text $SelectorSourceRs
$SelectorSourceMarker = "ENGLISH_PROJECT_DEVELOPMENT_PUA_SELECTOR_SOURCE"

if (-not $SelectorSourceText.Contains($SelectorSourceMarker)) {
    $Pattern = 'let\s+\(group_count,\s*coordinate_count,\s*direct_selector_count\)\s*=\s*match\s+scope\s*\{.*?\n\s*ensure!\(.*?\n\s*\);\s*\n\s*Ok\(\(\)\)'
    $Replacement = @'
// ENGLISH_PROJECT_DEVELOPMENT_PUA_SELECTOR_SOURCE:
// Source pixel identity is still exact; only semantic collapsing remains
// provisional while PUA placeholders exist. Keep selector population,
// coordinates, uniqueness, and adopted runtime consumers strict.
    let coordinate_count = match scope {
        DialogueSelectorTranslationScope::MgkDevelopment => 3_070,
        DialogueSelectorTranslationScope::AllRuntimeImages => 22_500,
    };
    ensure!(
        groups_by_selector.keys().copied().collect::<Vec<_>>() == vec![2, 3, 4, 5, 6]
            && semantic_hashes.len() == groups.len()
            && contexts.len() == coordinate_count
            && coordinate_ids.len() == contexts.len()
            && count(DialogueSelectorConsumerEvidence::RuntimeInsertionRewrite) == 4
            && count(DialogueSelectorConsumerEvidence::DirectEntryLoad) == 1,
        "selector translation structural denominator changed for {}: groups={}, coordinates={}, runtime={}, direct_entry={}, direct_selector={}, pending={}",
        scope.target_scope(),
        groups.len(),
        contexts.len(),
        count(DialogueSelectorConsumerEvidence::RuntimeInsertionRewrite),
        count(DialogueSelectorConsumerEvidence::DirectEntryLoad),
        count(DialogueSelectorConsumerEvidence::DirectSelectorLoad),
        count(DialogueSelectorConsumerEvidence::ConsumerPending),
    );
    Ok(())
'@
    $SelectorSourceText = Replace-RegexOnce `
        $SelectorSourceText `
        $Pattern `
        $Replacement `
        "Selector-source development denominator gate"
    Write-Utf8NoBom $SelectorSourceRs $SelectorSourceText
    Write-Host "Installed development-PUA selector-source patch." -ForegroundColor Cyan
}

$SelectorWorkspaceRs = Join-Path $Upstream "src\dialogue_audit\selector_translation_workspace.rs"
$SelectorWorkspaceText = Read-Utf8Text $SelectorWorkspaceRs
$SelectorWorkspaceMarker = "ENGLISH_PROJECT_DEVELOPMENT_PUA_SELECTOR_WORKSPACE"

if (-not $SelectorWorkspaceText.Contains($SelectorWorkspaceMarker)) {
    $Pattern = 'let\s+expected\s*=\s*match\s+config\.scope\s*\{.*?\n\s*ensure!\(.*?\n\s*\);\s*\n\s*write_bounded_json'
    $Replacement = @'
// ENGLISH_PROJECT_DEVELOPMENT_PUA_SELECTOR_WORKSPACE:
// Semantic group collapsing is provisional; structural selector evidence is not.
    let expected_coordinate_count = match config.scope {
        super::selector_translation_model::DialogueSelectorTranslationScope::MgkDevelopment => 3_070,
        super::selector_translation_model::DialogueSelectorTranslationScope::AllRuntimeImages => 22_500,
    };
    ensure!(
        manifest.source_asset_count == config.scope.source_asset_count()
            && manifest.coordinate_count == expected_coordinate_count
            && manifest.selector_count == 5
            && manifest.runtime_insertion_rewrite_group_count == 4
            && manifest.direct_entry_load_group_count == 1,
        "selector translation workspace structural denominator changed for {}",
        config.scope.target_scope(),
    );
    write_bounded_json
'@
    $SelectorWorkspaceText = Replace-RegexOnce `
        $SelectorWorkspaceText `
        $Pattern `
        $Replacement `
        "Selector-workspace development denominator gate"
    Write-Utf8NoBom $SelectorWorkspaceRs $SelectorWorkspaceText
    Write-Host "Installed development-PUA selector-workspace patch." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# English prototype: Japanese honorific runtime insertions become empty suffixes.
# This affects only the four known selector-2 runtime insertion records.
# ---------------------------------------------------------------------------
$RuntimeInsertionRs = Join-Path $Upstream "src\dialogue_audit\runtime_insertion_messages.rs"
$RuntimeInsertionText = Read-Utf8Text $RuntimeInsertionRs
$RuntimeMarker = "ENGLISH_PROJECT_EMPTY_HONORIFIC_RUNTIME_INSERTIONS"

if (-not $RuntimeInsertionText.Contains($RuntimeMarker)) {
    $RuntimeInsertionText = $RuntimeInsertionText.Replace(
        "const RUNTIME_INSERTION_MESSAGE_SPECS: &[RuntimeInsertionMessageSpec] = &[",
        "// ENGLISH_PROJECT_EMPTY_HONORIFIC_RUNTIME_INSERTIONS:`nconst RUNTIME_INSERTION_MESSAGE_SPECS: &[RuntimeInsertionMessageSpec] = &["
    )
    $HonorificRegex = New-Object System.Text.RegularExpressions.Regex(
        'korean_text:\s*"[^"]*",'
    )
    $HonorificMatches = $HonorificRegex.Matches($RuntimeInsertionText)
    if ($HonorificMatches.Count -ne 4) {
        Fail ("Expected exactly four runtime honorific text literals; found {0}." -f $HonorificMatches.Count)
    }
    $RuntimeInsertionText = $HonorificRegex.Replace(
        $RuntimeInsertionText,
        'korean_text: "",'
    )
    Write-Utf8NoBom $RuntimeInsertionRs $RuntimeInsertionText
    Write-Host "Patched runtime honorific insertions to empty English suffixes." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Admit the user's local font ONLY in this non-release fork.
# We do not copy or distribute the font.
# ---------------------------------------------------------------------------
$RasterRs = Join-Path $Upstream "src\font\raster.rs"
$RasterText = Read-Utf8Text $RasterRs
$FontMarker = "ENGLISH_PROJECT_LOCAL_PROTOTYPE_FONT"

if (-not $RasterText.Contains($FontMarker)) {
    $Start = $RasterText.IndexOf("pub(super) fn supported_font_identity")
    $End = $RasterText.IndexOf("/// Preserve the admitted", $Start)
    if ($Start -lt 0 -or $End -lt 0) {
        Fail "Could not locate supported_font_identity in raster.rs."
    }

    $Segment = $RasterText.Substring($Start, $End - $Start)
    $Needle = "        _ => None,"
    $NeedleCount = ([regex]::Matches($Segment, [regex]::Escape($Needle))).Count
    if ($NeedleCount -ne 1) {
        Fail ("Expected one font fallback in supported_font_identity; found {0}." -f $NeedleCount)
    }

    $Segment = $Segment.Replace(
        $Needle,
        @'
        // ENGLISH_PROJECT_LOCAL_PROTOTYPE_FONT:
        // Non-release English development builds may use a local user-installed
        // font. The font bytes are never shipped by this project.
        _ => Some(SupportedFontIdentity {
            name: "Local English Prototype Font",
            slug: "local-english-prototype-font",
        }),
'@
    )
    $RasterText = $RasterText.Substring(0, $Start) + $Segment + $RasterText.Substring($End)
    Write-Utf8NoBom $RasterRs $RasterText
    Write-Host "Enabled local prototype font identity." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Add a direct preparation entry point that does NOT require the private Korean
# assets/build/development.json.
# ---------------------------------------------------------------------------
$PreparedRs = Join-Path $Upstream "src\dialogue_audit\prepared_dialogue.rs"
$PreparedText = Read-Utf8Text $PreparedRs
$DirectPrepareMarker = "ENGLISH_PROJECT_DIRECT_DIALOGUE_PREPARE"

if (-not $PreparedText.Contains($DirectPrepareMarker)) {
    $InsertAt = $PreparedText.IndexOf("#[cfg(test)]")
    if ($InsertAt -lt 0) {
        Fail "Could not locate prepared_dialogue.rs test module insertion point."
    }

    $DirectPrepareRust = @'

// ENGLISH_PROJECT_DIRECT_DIALOGUE_PREPARE:
// Prepare dialogue from explicit public inputs instead of the private Korean
// development.json. This preserves the upstream plan/allocation validators.
pub fn prepare_dialogue_inputs_direct(config: &DialogueMessageBuildConfig) -> Result<()> {
    let _lock = crate::output_lock::OutputLock::writer(&config.output_dir)?;
    ensure!(
        config.force || !config.output_dir.join(MANIFEST).exists(),
        "prepared dialogue exists; use force to replace it"
    );

    let bindings = input_bindings(
        &config.codebook,
        &config.translation,
        &config.selector_translation,
        &config.name_input_keyboard,
    )?;

    std::fs::create_dir_all(&config.output_dir)?;
    let source = SupportedSourceDisc::open(&config.cue)?;
    let (message_plan, allocation) = plan_dialogue_messages(config, &source)?;

    ensure!(
        bindings
            == input_bindings(
                &config.codebook,
                &config.translation,
                &config.selector_translation,
                &config.name_input_keyboard,
            )?,
        "dialogue inputs changed during direct preparation"
    );

    validate_source_population(
        message_plan
            .assets
            .iter()
            .map(|asset| asset.source_path.as_str()),
    )?;

    for asset in &message_plan.assets {
        write_message_member(
            &config.output_dir,
            &asset.rebuilt_decoded_sha256,
            &asset.rebuilt_decoded,
        )?;
    }

    let prepared = PreparedDialogue {
        kind: KIND.into(),
        input_bindings: bindings,
        message_plan,
        allocation: PreparedGlyphAllocation {
            static_allocation_complete: allocation.static_allocation_complete,
            fixed_code_consumer_ownership_complete: allocation
                .fixed_code_consumer_ownership_complete,
            name_glyph_layout: allocation.name_glyph_layout,
            fixed_code_consumers: allocation.fixed_code_consumers.assets,
            assets: allocation.assets,
        },
    };

    publish_manifest(
        &config.output_dir,
        &serde_json::to_vec(&prepared)?,
    )
}

'@
    $PreparedText = $PreparedText.Substring(0, $InsertAt) + $DirectPrepareRust + $PreparedText.Substring($InsertAt)
    Write-Utf8NoBom $PreparedRs $PreparedText
    Write-Host "Installed direct dialogue preparation entry point." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Add a text-only target font build. It installs ONLY asset-local translated
# glyphs. Original dynamic name glyphs/cache/pack remain untouched.
# ---------------------------------------------------------------------------
$FontBuildRs = Join-Path $Upstream "src\dialogue_audit\dialogue_font_build.rs"
$FontBuildText = Read-Utf8Text $FontBuildRs
$TextOnlyMarker = "ENGLISH_PROJECT_TEXT_ONLY_PROTOTYPE_RECORD"

if (-not $FontBuildText.Contains($TextOnlyMarker)) {
    $InsertAt = $FontBuildText.IndexOf("pub(super) fn classify_font_build_assets")
    if ($InsertAt -lt 0) {
        Fail "Could not locate dialogue font classification insertion point."
    }

    $TextOnlyRust = @'

// ENGLISH_PROJECT_TEXT_ONLY_PROTOTYPE_RECORD:
// Build one standalone dialogue BIZ using authored message bytes plus only the
// target asset's translated glyph installs. Shared dynamic-name cells and the
// Korean name-glyph pack are intentionally left exactly as source for this
// first English runtime proof.
pub fn build_dialogue_text_only_prototype_record(
    config: &DialogueFontBuildConfig,
    target_path: &str,
) -> Result<DialogueFontRecordBuild> {
    let source = SupportedSourceDisc::open(&config.cue)?;
    let (message_plan, allocation, _) =
        super::prepared_dialogue::load_prepared_dialogue(config, &source)?;

    ensure!(
        !config.input_policy.requires_complete_scope(),
        "text-only prototype requires authored-subset input policy"
    );
    ensure!(
        message_plan.development_build_input_available
            && message_plan
                .assets
                .iter()
                .all(|asset| asset.parse_back_verified),
        "text-only prototype requires parse-verified development messages"
    );

    prepare_output_directory(&config.output_dir, config.force)?;

    let message_asset = message_plan
        .assets
        .iter()
        .find(|asset| asset.source_path == target_path)
        .with_context(|| format!("{target_path} disappeared from prepared dialogue"))?;

    let allocation_asset = allocation
        .assets
        .iter()
        .find(|asset| asset.source_path == target_path)
        .with_context(|| format!("{target_path} disappeared from code allocation"))?;

    let (installable_assets, skipped_assets) =
        classify_font_build_assets(&allocation.fixed_code_consumers);
    if !installable_assets.contains(target_path) {
        let reason = skipped_assets
            .iter()
            .find(|asset| asset.source_path == target_path)
            .map(|asset| asset.reason.as_str())
            .unwrap_or("target asset is not source-safe for translated glyph installs");
        bail!("{target_path} is not installable in authored-subset mode: {reason}");
    }

    // English prototype rule: materialize every printable ASCII assignment
    // in this source-safe target asset, even when the upstream Korean-era
    // allocator says the source glyph can be reused. MGK04 proved that a few
    // such "reused" Latin semantics point at visually unsuitable/blank source
    // cells (I/F/M/V/! in the opening message).
    let mut raster_character_set = collect_raster_characters(
        std::slice::from_ref(allocation_asset)
    )?
    .chars()
    .collect::<BTreeSet<_>>();
    for assignment in &allocation_asset.assignments {
        let mut chars = assignment.character.chars();
        if let Some(character) = chars.next() {
            if chars.next().is_none() && character.is_ascii_graphic() {
                raster_character_set.insert(character);
            }
        }
    }
    let raster_characters = raster_character_set.into_iter().collect::<String>();

    let rasterized = rasterize_menu_glyphs(
        &config.font,
        &raster_characters,
        config.font_px,
        OUTLINE_PALETTE_INDEX,
        FILL_PALETTE_INDEX,
    )?;
    let glyph_pixels = rasterized
        .glyphs
        .into_iter()
        .map(|glyph| (glyph.character, glyph.pixels))
        .collect::<BTreeMap<_, _>>();
    ensure!(
        glyph_pixels.len() == raster_characters.chars().count(),
        "prototype rasterized character population changed"
    );

    let source_atlas = parse_dialogue_atlas(&message_asset.original_decoded)?;
    let mut font_decoded = message_asset.rebuilt_decoded.clone();
    let mut installed_codes = BTreeSet::new();

    for assignment in allocation_asset
        .assignments
        .iter()
        .filter(|assignment| {
            if render_dialogue_assignment(assignment) {
                return true;
            }
            let mut chars = assignment.character.chars();
            matches!(
                chars.next(),
                Some(character)
                    if chars.next().is_none() && character.is_ascii_graphic()
            )
        })
    {
        install_assignment(
            &mut font_decoded,
            &source_atlas,
            assignment,
            "english_prototype_asset_local",
            &glyph_pixels,
            &mut installed_codes,
        )?;
    }

    ensure!(
        !installed_codes.is_empty(),
        "prototype target has no translated glyph installs"
    );
    eprintln!(
        "prototype: materialized {} printable/required glyph codes into {}",
        installed_codes.len(),
        target_path
    );

    let compressed =
        compress_page_safe_image(&font_decoded, message_asset.source_compression_profile)
            .with_context(|| format!("failed to compress prototype {target_path}"))?;
    let _rebuilt_profile = profile_paged_compression(&compressed)?;

    ensure!(
        decompress(&compressed, false)? == font_decoded,
        "{target_path} prototype compression roundtrip changed decoded bytes"
    );
    ensure!(
        compressed.len() <= message_asset.original_stored_byte_count,
        "{target_path} prototype exceeds original stored extent"
    );
    ensure!(
        compressed.get(..4) == Some(message_asset.source_catalog_prefix.as_slice()),
        "{target_path} prototype changed its catalog prefix"
    );

    let mut padded = compressed;
    padded.resize(message_asset.original_stored_byte_count, 0);

    let stem = asset_stem(target_path)?;
    std::fs::write(
        config.output_dir.join(format!("{stem}.decoded.bin")),
        &font_decoded,
    )?;
    std::fs::write(
        config.output_dir.join(format!("{stem}.rebuilt.biz")),
        &padded,
    )?;

    Ok(DialogueFontRecordBuild {
        source_path: target_path.to_string(),
        stored: padded,
    })
}

'@
    $FontBuildText = $FontBuildText.Substring(0, $InsertAt) + $TextOnlyRust + $FontBuildText.Substring($InsertAt)
    Write-Utf8NoBom $FontBuildRs $FontBuildText
    Write-Host "Installed text-only prototype record builder." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Export the two prototype helpers through dialogue_audit.
# ---------------------------------------------------------------------------
$DialogueAuditRs = Join-Path $Upstream "src\dialogue_audit.rs"
$DialogueAuditText = Read-Utf8Text $DialogueAuditRs

if (-not $DialogueAuditText.Contains("prepare_dialogue_inputs_direct")) {
    $Old = "pub use prepared_dialogue::prepare_dialogue_inputs;"
    $New = "pub use prepared_dialogue::{prepare_dialogue_inputs, prepare_dialogue_inputs_direct};"
    if (-not $DialogueAuditText.Contains($Old)) {
        Fail "Could not export prepare_dialogue_inputs_direct."
    }
    $DialogueAuditText = $DialogueAuditText.Replace($Old, $New)
}
if (-not $DialogueAuditText.Contains("build_dialogue_text_only_prototype_record")) {
    $Old = "pub use dialogue_font_build::build_dialogue_font_images;"
    $New = "pub use dialogue_font_build::{build_dialogue_font_images, build_dialogue_text_only_prototype_record};"
    if (-not $DialogueAuditText.Contains($Old)) {
        Fail "Could not export text-only dialogue prototype builder."
    }
    $DialogueAuditText = $DialogueAuditText.Replace($Old, $New)
}
Write-Utf8NoBom $DialogueAuditRs $DialogueAuditText

# ---------------------------------------------------------------------------
# English selector validation.
#
# The four source-bound relationship honorific rewrites intentionally encode an
# empty suffix in English. Upstream's generic Draft validator requires authored
# selector text to contain at least one nonempty segment. Keep that rule for all
# ordinary authored selector translations, but exempt ONLY RuntimeInsertionRewrite.
#
# This patch deliberately targets the one nonempty-segment predicate instead of
# replacing the surrounding Rust block, so it is resilient to harmless formatting
# or wording changes left by earlier prototype runs.
# ---------------------------------------------------------------------------
$SelectorValidationRs = Join-Path $Upstream "src\dialogue_audit\selector_translation_validation.rs"
$SelectorValidationText = Read-Utf8Text $SelectorValidationRs
$SelectorValidationMarker = "ENGLISH_PROJECT_EMPTY_RUNTIME_REWRITE_VALIDATION_V2"

if (-not $SelectorValidationText.Contains($SelectorValidationMarker)) {
    $NonemptyPattern = 'decision\s*\.korean_segments\s*\.iter\(\)\s*\.flatten\(\)\s*\.any\(\|segment\|\s*!segment\.trim\(\)\.is_empty\(\)\)'

    $Regex = New-Object System.Text.RegularExpressions.Regex(
        $NonemptyPattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $Matches = $Regex.Matches($SelectorValidationText)
    if ($Matches.Count -ne 1) {
        Fail (
            "Selector validator nonempty-text predicate: expected exactly one match, found {0}." -f
            $Matches.Count
        )
    }

    $Replacement = @'
(source_group.development_resolution
                            == DialogueSelectorDevelopmentResolution::RuntimeInsertionRewrite
                            || decision
                                .korean_segments
                                .iter()
                                .flatten()
                                .any(|segment| !segment.trim().is_empty()))
'@

    $SelectorValidationText = $Regex.Replace(
        $SelectorValidationText,
        $Replacement,
        1
    )

    # Prefix a harmless Rust comment as the idempotence marker.
    $SelectorValidationText = "// ENGLISH_PROJECT_EMPTY_RUNTIME_REWRITE_VALIDATION_V2" +
        [Environment]::NewLine + $SelectorValidationText

    Write-Utf8NoBom $SelectorValidationRs $SelectorValidationText
    Write-Host "Patched selector validator for empty English runtime suffixes." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Embed the two small dialogue-layout assets that the public Rust source expects
# from the omitted private product-assets root.
#
# Choice columns: admit the earlier Batsu choice plus the MGK04 tutorial selector.
# Stat results: none of the 5 MGK04 groups are stat-result text, so preserve
# the nine native arrow offsets with unreachable placeholder semantic hashes.
# ---------------------------------------------------------------------------
$ChoiceColumnsRs = Join-Path $Upstream "src\dialogue_audit\choice_columns.rs"
$ChoiceColumnsText = Read-Utf8Text $ChoiceColumnsRs
$ChoiceColumnsMarker = "ENGLISH_PROJECT_EMBEDDED_CHOICE_COLUMNS_ASSET"

if (-not $ChoiceColumnsText.Contains($ChoiceColumnsMarker)) {
    $ChoicePattern = 'fn\s+asset\(\)\s*->\s*Result<&''static\s+\[u8\]>\s*\{\s*crate::product_assets::read\("dialogue/choice-columns\.json"\)\s*\}'
    $ChoiceRegex = New-Object System.Text.RegularExpressions.Regex(
        $ChoicePattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if ($ChoiceRegex.Matches($ChoiceColumnsText).Count -ne 1) {
        Fail "Could not locate choice-columns private asset loader."
    }

    $ChoiceReplacement = @'
fn asset() -> Result<&'static [u8]> {
    // ENGLISH_PROJECT_EMBEDDED_CHOICE_COLUMNS_ASSET:
    // Minimal source-bound layout metadata for the English prototype choices.
    Ok(br#"{
  "right_column": 10,
  "semantic_source_sha256": [
    "29522700f6feb927deb0582b7dfe71275df8f1780431b6057c9082a7d3e74608",
    "add3aac193294dbd56448bad4acb0bde55f6645735b4781e3775081ee1780257"
  ]
}"#)
}
'@
    $ChoiceColumnsText = $ChoiceRegex.Replace(
        $ChoiceColumnsText,
        $ChoiceReplacement,
        1
    )
    Write-Utf8NoBom $ChoiceColumnsRs $ChoiceColumnsText
    Write-Host "Embedded English prototype choice-column metadata." -ForegroundColor Cyan
}

# The user's upstream tree may already contain the earlier Batsu-only embedded
# choice-column asset. Ensure the MGK04 tutorial selector is admitted too.
$ChoiceColumnsText = Read-Utf8Text $ChoiceColumnsRs
$Mgk04ChoiceSemantic = "add3aac193294dbd56448bad4acb0bde55f6645735b4781e3775081ee1780257"
if (-not $ChoiceColumnsText.Contains($Mgk04ChoiceSemantic)) {
    $BatsuChoiceSemantic = "29522700f6feb927deb0582b7dfe71275df8f1780431b6057c9082a7d3e74608"
    if (-not $ChoiceColumnsText.Contains($BatsuChoiceSemantic)) {
        Fail "Embedded choice-column asset is present but the known Batsu semantic anchor is missing."
    }
    $ChoiceColumnsText = $ChoiceColumnsText.Replace(
        '"' + $BatsuChoiceSemantic + '"',
        '"' + $BatsuChoiceSemantic + '",' + [Environment]::NewLine +
        '    "' + $Mgk04ChoiceSemantic + '"'
    )
    Write-Utf8NoBom $ChoiceColumnsRs $ChoiceColumnsText
    Write-Host "Added MGK04 tutorial selector to embedded choice-column metadata." -ForegroundColor Cyan
}

$StatLayoutRs = Join-Path $Upstream "src\dialogue_audit\stat_result_layout.rs"
$StatLayoutText = Read-Utf8Text $StatLayoutRs
$StatLayoutMarker = "ENGLISH_PROJECT_EMBEDDED_NATIVE_STAT_LAYOUT_ASSET"

if (-not $StatLayoutText.Contains($StatLayoutMarker)) {
    $StatPattern = 'fn\s+asset\(\)\s*->\s*Result<&''static\s+\[u8\]>\s*\{\s*crate::product_assets::read\("dialogue/stat-result-layout\.json"\)\s*\}'
    $StatRegex = New-Object System.Text.RegularExpressions.Regex(
        $StatPattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if ($StatRegex.Matches($StatLayoutText).Count -ne 1) {
        Fail "Could not locate stat-result private asset loader."
    }

    $StatReplacement = @'
fn asset() -> Result<&'static [u8]> {
    // ENGLISH_PROJECT_EMBEDDED_NATIVE_STAT_LAYOUT_ASSET:
    // Scene 1 does not author any stat-result strings. These unreachable hashes
    // preserve the source nine-row arrow geometry while retaining upstream checks.
    Ok(br#"{
  "arrow_alignment": "center_between_text_runs",
  "stats": [
    {"source_stat":"prototype-0","source_arrow_offset":88,"up":"unused-up-0","down":"unused-down-0"},
    {"source_stat":"prototype-1","source_arrow_offset":88,"up":"unused-up-1","down":"unused-down-1"},
    {"source_stat":"prototype-2","source_arrow_offset":68,"up":"unused-up-2","down":"unused-down-2"},
    {"source_stat":"prototype-3","source_arrow_offset":68,"up":"unused-up-3","down":"unused-down-3"},
    {"source_stat":"prototype-4","source_arrow_offset":108,"up":"unused-up-4","down":"unused-down-4"},
    {"source_stat":"prototype-5","source_arrow_offset":108,"up":"unused-up-5","down":"unused-down-5"},
    {"source_stat":"prototype-6","source_arrow_offset":88,"up":"unused-up-6","down":"unused-down-6"},
    {"source_stat":"prototype-7","source_arrow_offset":88,"up":"unused-up-7","down":"unused-down-7"},
    {"source_stat":"prototype-8","source_arrow_offset":68,"up":"unused-up-8","down":"unused-down-8"}
  ]
}"#)
}
'@
    $StatLayoutText = $StatRegex.Replace(
        $StatLayoutText,
        $StatReplacement,
        1
    )
    Write-Utf8NoBom $StatLayoutRs $StatLayoutText
    Write-Host "Embedded native stat-result layout metadata." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# English runtime-character demand.
#
# Upstream Korean development policy seeds EVERY translated asset with the
# Hangul honorific glyphs 군/씨/짱, then adds them again for relationship honorific
# controls. English source-bound runtime rewrites intentionally render those
# suffixes as empty, so allocating/rasterizing those Hangul glyphs is incorrect.
#
# Preserve all dynamic-name unresolved-source tracking and date/digit demand.
# Remove ONLY the Korean honorific character demand.
# ---------------------------------------------------------------------------
$DevelopmentInputRs = Join-Path $Upstream "src\dialogue_audit\dialogue_development_input.rs"
$DevelopmentInputText = Read-Utf8Text $DevelopmentInputRs
$RuntimeDemandMarker = "ENGLISH_PROJECT_EMPTY_HONORIFIC_CHARACTER_DEMAND"

if (-not $DevelopmentInputText.Contains($RuntimeDemandMarker)) {
    # Replace the Korean-specific nonempty seed with an empty/default demand.
    $SeedPattern = 'let\s+mut\s+result\s*=\s*RuntimeCharacterDemand\s*\{\s*characters:\s*"[^"]*"\.chars\(\)\.collect\(\),\s*\.\.RuntimeCharacterDemand::default\(\)\s*\};'
    $SeedRegex = New-Object System.Text.RegularExpressions.Regex(
        $SeedPattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $SeedMatches = $SeedRegex.Matches($DevelopmentInputText)
    if ($SeedMatches.Count -ne 1) {
        Fail (
            "Runtime character-demand seed: expected exactly one Korean-specific initializer, found {0}." -f
            $SeedMatches.Count
        )
    }

    $DevelopmentInputText = $SeedRegex.Replace(
        $DevelopmentInputText,
        @'
    // ENGLISH_PROJECT_EMPTY_HONORIFIC_CHARACTER_DEMAND:
    // English removes the source-bound relationship honorific suffixes.
    let mut result = RuntimeCharacterDemand::default();
'@,
        1
    )

    # Remove only Hangul honorific additions inside relationship-name branches.
    # Keep the surrounding unresolved player-name buffer tracking unchanged.
    $HonorificExtendPattern = 'result\.characters\.extend\("[^"]*"\.chars\(\)\);\s*'
    $HonorificRegex = New-Object System.Text.RegularExpressions.Regex(
        $HonorificExtendPattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    $FunctionStart = $DevelopmentInputText.IndexOf(
        "pub(super) fn classify_runtime_character_demand"
    )
    if ($FunctionStart -lt 0) {
        Fail "Could not locate classify_runtime_character_demand."
    }

    # Limit edits to the classifier function, ending before its final result.
    $FunctionTail = $DevelopmentInputText.Substring($FunctionStart)
    $FunctionEndNeedle = "    result`n}"
    $FunctionEnd = $FunctionTail.IndexOf($FunctionEndNeedle)
    if ($FunctionEnd -lt 0) {
        $FunctionEndNeedle = "    result`r`n}"
        $FunctionEnd = $FunctionTail.IndexOf($FunctionEndNeedle)
    }
    if ($FunctionEnd -lt 0) {
        Fail "Could not locate end of classify_runtime_character_demand."
    }
    $FunctionLength = $FunctionEnd + $FunctionEndNeedle.Length
    $FunctionText = $FunctionTail.Substring(0, $FunctionLength)

    # We expect four .extend(...) calls in this function:
    # three honorific branches and one digits branch. Remove only the three
    # whose literals are non-ASCII; keep "0123456789".
    $AllExtends = $HonorificRegex.Matches($FunctionText)
    $Removed = 0
    for ($i = $AllExtends.Count - 1; $i -ge 0; $i--) {
        $Match = $AllExtends[$i]
        if ($Match.Value.Contains('"0123456789"')) {
            continue
        }
        $FunctionText = $FunctionText.Remove($Match.Index, $Match.Length)
        $Removed += 1
    }
    if ($Removed -ne 3) {
        Fail ("Expected to remove exactly 3 Korean honorific demand extensions; removed {0}." -f $Removed)
    }

    $DevelopmentInputText = $DevelopmentInputText.Substring(0, $FunctionStart) +
        $FunctionText +
        $DevelopmentInputText.Substring($FunctionStart + $FunctionLength)

    Write-Utf8NoBom $DevelopmentInputRs $DevelopmentInputText
    Write-Host "Removed Korean-only honorific glyph demand from English prototype." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# v4 repair: earlier runs already installed the text-only helper in the local
# Rust source, so merely changing the embedded helper body does not update it.
# Patch that live helper in-place and verify the old source-reuse filter is gone.
# ---------------------------------------------------------------------------
$FontBuildRs = Join-Path $Upstream "src\dialogue_audit\dialogue_font_build.rs"
$LiveFontBuild = Read-Utf8Text $FontBuildRs
$AsciiRepairMarker = "ENGLISH_PROJECT_FORCE_ASCII_MATERIALIZATION_V4"

if (-not $LiveFontBuild.Contains($AsciiRepairMarker)) {
    $OldRasterBlock = @'
    let raster_characters =
        collect_raster_characters(std::slice::from_ref(allocation_asset))?;
    let rasterized = rasterize_menu_glyphs(
        &config.font,
        &raster_characters,
        config.font_px,
        OUTLINE_PALETTE_INDEX,
        FILL_PALETTE_INDEX,
    )?;
'@

    $NewRasterBlock = @'
    // ENGLISH_PROJECT_FORCE_ASCII_MATERIALIZATION_V4:
    // For the English prototype, force every printable ASCII assignment in
    // this source-safe target asset to be rasterized even when the upstream
    // allocator marks the source glyph as reusable.
    let mut raster_character_set = collect_raster_characters(
        std::slice::from_ref(allocation_asset)
    )?
    .chars()
    .collect::<BTreeSet<_>>();
    for assignment in &allocation_asset.assignments {
        let mut chars = assignment.character.chars();
        if let Some(character) = chars.next() {
            if chars.next().is_none() && character.is_ascii_graphic() {
                raster_character_set.insert(character);
            }
        }
    }
    let raster_characters = raster_character_set.into_iter().collect::<String>();

    let rasterized = rasterize_menu_glyphs(
        &config.font,
        &raster_characters,
        config.font_px,
        OUTLINE_PALETTE_INDEX,
        FILL_PALETTE_INDEX,
    )?;
'@

    $OldRasterCount = ([regex]::Matches(
        $LiveFontBuild,
        [regex]::Escape($OldRasterBlock)
    )).Count
    if ($OldRasterCount -ne 1) {
        Fail ("Expected exactly one old prototype raster block; found {0}." -f $OldRasterCount)
    }
    $LiveFontBuild = $LiveFontBuild.Replace($OldRasterBlock, $NewRasterBlock)

    $OldFilter = @'
    for assignment in allocation_asset
        .assignments
        .iter()
        .filter(|assignment| render_dialogue_assignment(assignment))
    {
'@

    $NewFilter = @'
    for assignment in allocation_asset
        .assignments
        .iter()
        .filter(|assignment| {
            if render_dialogue_assignment(assignment) {
                return true;
            }
            let mut chars = assignment.character.chars();
            matches!(
                chars.next(),
                Some(character)
                    if chars.next().is_none() && character.is_ascii_graphic()
            )
        })
    {
'@

    $OldFilterCount = ([regex]::Matches(
        $LiveFontBuild,
        [regex]::Escape($OldFilter)
    )).Count
    if ($OldFilterCount -ne 1) {
        Fail ("Expected exactly one old prototype install filter; found {0}." -f $OldFilterCount)
    }
    $LiveFontBuild = $LiveFontBuild.Replace($OldFilter, $NewFilter)

    $OldAssert = @'
    ensure!(
        !installed_codes.is_empty(),
        "prototype target has no translated glyph installs"
    );
'@
    $NewAssert = @'
    ensure!(
        !installed_codes.is_empty(),
        "prototype target has no translated glyph installs"
    );
    eprintln!(
        "prototype: materialized {} printable/required glyph codes into {}",
        installed_codes.len(),
        target_path
    );
'@
    $AssertCount = ([regex]::Matches(
        $LiveFontBuild,
        [regex]::Escape($OldAssert)
    )).Count
    if ($AssertCount -ne 1) {
        Fail ("Expected exactly one prototype installed-code assertion; found {0}." -f $AssertCount)
    }
    $LiveFontBuild = $LiveFontBuild.Replace($OldAssert, $NewAssert)

    Write-Utf8NoBom $FontBuildRs $LiveFontBuild
    Write-Host "Repaired live MGK04 font helper to force printable ASCII materialization." -ForegroundColor Cyan
}
else {
    Write-Host "Live MGK04 ASCII materialization repair already present." -ForegroundColor Cyan
}

$VerifyFontBuild = Read-Utf8Text $FontBuildRs
if (-not $VerifyFontBuild.Contains($AsciiRepairMarker)) {
    Fail "Live font helper repair marker is missing after patch."
}

# Verify ONLY the prototype helper. The normal upstream builder legitimately
# still uses the source-reuse-only filter elsewhere in this file.
$PrototypeFnStart = $VerifyFontBuild.IndexOf(
    "pub fn build_dialogue_text_only_prototype_record"
)
if ($PrototypeFnStart -lt 0) {
    Fail "Could not locate build_dialogue_text_only_prototype_record for scoped verification."
}

$PrototypeFnEnd = $VerifyFontBuild.IndexOf(
    "pub(super) fn classify_font_build_assets",
    $PrototypeFnStart
)
if ($PrototypeFnEnd -lt 0) {
    Fail "Could not locate the end of the text-only prototype helper."
}

$PrototypeFnText = $VerifyFontBuild.Substring(
    $PrototypeFnStart,
    $PrototypeFnEnd - $PrototypeFnStart
)

if (-not $PrototypeFnText.Contains($AsciiRepairMarker)) {
    Fail "Prototype helper does not contain the ASCII materialization repair marker."
}
if ($PrototypeFnText.Contains('.filter(|assignment| render_dialogue_assignment(assignment))')) {
    Fail "Prototype helper still contains the old source-reuse-only install filter."
}
if (-not $PrototypeFnText.Contains('character.is_ascii_graphic()')) {
    Fail "Prototype helper is missing printable-ASCII forced installation."
}
if (-not $PrototypeFnText.Contains('prototype: materialized {} printable/required glyph codes into {}')) {
    Fail "Prototype helper is missing the materialization diagnostic."
}

Write-Host "Verified repaired ASCII materialization inside the live text-only helper." -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Custom one-record prototype binary.
# ---------------------------------------------------------------------------
$PrototypeRust = @'
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, ensure};
use serde::Serialize;

use justice_gakuen2_kr::dialogue_audit::{
    DialogueDevelopmentInputPolicy, DialogueFontBuildConfig, DialogueMessageBuildConfig,
    build_dialogue_text_only_prototype_record, prepare_dialogue_inputs_direct,
};
use justice_gakuen2_kr::disc::rebuild;

const TARGET_PATH: &str = "DAT2/MGK04.BIZ";

#[derive(Serialize)]
struct PrototypeReport {
    kind: String,
    target_path: String,
    source_bin: String,
    output_bin: String,
    output_bin_sha256: String,
    replacement_byte_count: usize,
    changed_sector_count: usize,
    changed_lba_ranges: Vec<[u32; 2]>,
    readback_verified: bool,
    source_image_length_preserved: bool,
}

fn ranges(values: &[u32]) -> Vec<[u32; 2]> {
    let mut result = Vec::new();
    let Some((&first, rest)) = values.split_first() else {
        return result;
    };
    let mut start = first;
    let mut previous = first;
    for &value in rest {
        if value == previous + 1 {
            previous = value;
            continue;
        }
        result.push([start, previous]);
        start = value;
        previous = value;
    }
    result.push([start, previous]);
    result
}

fn app_main() -> Result<()> {
    let args = std::env::args().collect::<Vec<_>>();
    ensure!(
        args.len() == 9,
        "usage: english_mgk04_prototype <cue> <source-bin> <codebook> <primary-workspace> <selector-workspace> <keyboard.json> <font.ttf> <output-dir>"
    );

    let cue = PathBuf::from(&args[1]);
    let source_bin = PathBuf::from(&args[2]);
    let codebook = PathBuf::from(&args[3]);
    let primary = PathBuf::from(&args[4]);
    let selector = PathBuf::from(&args[5]);
    let keyboard = PathBuf::from(&args[6]);
    let font = PathBuf::from(&args[7]);
    let output_dir = PathBuf::from(&args[8]);

    std::fs::create_dir_all(&output_dir)?;
    let prepared = output_dir.join("prepared");
    let font_output = output_dir.join("font-record");

    let message_config = DialogueMessageBuildConfig {
        cue: cue.clone(),
        codebook: codebook.clone(),
        translation: primary.clone(),
        selector_translation: selector.clone(),
        name_input_keyboard: keyboard.clone(),
        translation_audit_output: prepared.join("dialogue-translation-audit.json"),
        selector_translation_audit_output: prepared.join("dialogue-selector-translation-audit.json"),
        code_allocation_output: prepared.join("dialogue-code-allocation.json"),
        output_dir: prepared.clone(),
        force: true,
        input_policy: DialogueDevelopmentInputPolicy::AuthoredSubset,
    };

    eprintln!("prototype: preparing authored-subset dialogue");
    prepare_dialogue_inputs_direct(&message_config)?;

    let font_config = DialogueFontBuildConfig {
        prepared_dialogue: prepared,
        cue: cue.clone(),
        codebook,
        translation: primary,
        selector_translation: selector,
        name_input_keyboard: keyboard,
        name_glyph_font: font.clone(),
        name_glyph_font_px: 13.0,
        font,
        font_px: 13.0,
        input_policy: DialogueDevelopmentInputPolicy::AuthoredSubset,
        output_dir: font_output,
        force: true,
    };

    eprintln!("prototype: building text-only MGK04 record");
    let record = build_dialogue_text_only_prototype_record(&font_config, TARGET_PATH)?;

    let output_bin = output_dir.join("justice-gakuen2-mgk04-full-tutorial-v1.bin");
    eprintln!("prototype: replacing only {TARGET_PATH}");
    rebuild::copy_and_replace_record(
        &source_bin,
        &output_bin,
        TARGET_PATH,
        &record.stored,
    )?;

    let (_, readback) = rebuild::read_record(&output_bin, TARGET_PATH)?;
    ensure!(
        readback == record.stored,
        "prototype MGK04 disc readback differs from replacement"
    );

    let source_len = std::fs::metadata(&source_bin)?.len();
    let output_len = std::fs::metadata(&output_bin)?.len();
    ensure!(source_len == output_len, "prototype image length changed");

    let (changed_lbas, output_sha256) =
        rebuild::compare_and_hash_images(&source_bin, &output_bin)?;
    ensure!(!changed_lbas.is_empty(), "prototype disc has no changed sectors");

    let report = PrototypeReport {
        kind: "Justice Gakuen 2 full English MGK04 tutorial/admissions one-record build".into(),
        target_path: TARGET_PATH.into(),
        source_bin: source_bin.display().to_string(),
        output_bin: output_bin.display().to_string(),
        output_bin_sha256: output_sha256,
        replacement_byte_count: record.stored.len(),
        changed_sector_count: changed_lbas.len(),
        changed_lba_ranges: ranges(&changed_lbas),
        readback_verified: true,
        source_image_length_preserved: true,
    };

    let mut bytes = serde_json::to_vec_pretty(&report)?;
    bytes.push(b'\n');
    std::fs::write(output_dir.join("prototype-report.json"), bytes)
        .context("failed to write prototype report")?;

    eprintln!("prototype: one-record readback verified");
    Ok(())
}

fn main() -> Result<()> {
    let worker = std::thread::Builder::new()
        .name("justice-gakuen2-english-prototype-large-stack".to_string())
        .stack_size(64 * 1024 * 1024)
        .spawn(app_main)?;

    match worker.join() {
        Ok(result) => result,
        Err(payload) => std::panic::resume_unwind(payload),
    }
}
'@

$BinDir = Join-Path $Upstream "src\bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$PrototypeRs = Join-Path $BinDir "english_mgk04_prototype.rs"
Write-Utf8NoBom $PrototypeRs $PrototypeRust

# ---------------------------------------------------------------------------
# Build patched tools.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Justice Gakuen English Project - FULL MGK04 TUTORIAL + ADMISSIONS v1" -ForegroundColor Cyan
Write-Host ""

Push-Location $Upstream
try {
    Write-Host "[1/6] Building English prototype tools..."
    Run-Native "cargo" @("build", "--release", "--bin", "justice-gakuen2-kr", "--bin", "english_mgk04_prototype")
}
finally {
    Pop-Location
}

$MainExe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
$PrototypeExe = Join-Path $Upstream "target\release\english_mgk04_prototype.exe"
if (-not (Test-Path $MainExe) -or -not (Test-Path $PrototypeExe)) {
    Fail "Prototype executables were not produced."
}

# ---------------------------------------------------------------------------
# Audit scene-only primary workspace: exactly 19 drafts.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Auditing 58 translated MGK04 tutorial/admissions groups..."
Run-Native $MainExe @(
    "audit-dialogue-translation",
    "--cue", $TargetCue,
    "--codebook", $Codebook,
    "--translation", $PrimaryWorkspace,
    "--output", $PrimaryAudit
)

$PrimaryAuditObj = (Read-Utf8Text $PrimaryAudit) | ConvertFrom-Json
Write-Host ("  Draft groups: {0}" -f $PrimaryAuditObj.draft_group_count)
Write-Host ("  Untranslated groups: {0}" -f $PrimaryAuditObj.untranslated_group_count)
if ($PrimaryAuditObj.draft_group_count -ne 58) {
    Fail ("Expected exactly 58 tutorial draft groups; audit reports {0}." -f $PrimaryAuditObj.draft_group_count)
}

# ---------------------------------------------------------------------------
# Generate the all-runtime selector workspace. English prototype runtime suffixes
# are empty, so no Korean glyphs are introduced.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/6] Building source-bound selector workspace..."
Run-Native $MainExe @(
    "init-dialogue-selector-translation",
    "--cue", $TargetCue,
    "--codebook", $Codebook,
    "--output", $SelectorWorkspace,
    "--scope", "all-runtime-images",
    "--force"
)

Run-Native $MainExe @(
    "audit-dialogue-selector-translation",
    "--cue", $TargetCue,
    "--codebook", $Codebook,
    "--translation", $SelectorWorkspace,
    "--output", $SelectorAudit
)

$SelectorAuditObj = (Read-Utf8Text $SelectorAudit) | ConvertFrom-Json
Write-Host ("  Selector semantic groups: {0}" -f $SelectorAuditObj.semantic_group_count)
Write-Host ("  Runtime insertion rewrites: {0}" -f $SelectorAuditObj.runtime_insertion_rewrite_group_count)

# ---------------------------------------------------------------------------
# Prepare messages, install only English body glyphs into MGK04, replace exactly
# one disc record, and verify raw-disc readback.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Preparing authored-subset message plan..."
Write-Host "[5/6] Installing English glyphs into MGK04 only..."
Write-Host "[6/6] Building and readback-verifying one-record BIN..."

Run-Native $PrototypeExe @(
    $TargetCue,
    $BaseBin,
    $Codebook,
    $PrimaryWorkspace,
    $SelectorWorkspace,
    $Keyboard,
    $FontPath,
    $BuildOutput
)

if (-not (Test-Path $OutputBin) -or -not (Test-Path $OutputReport)) {
    Fail "Prototype BIN/report was not produced."
}

# Write matching single-track CUE.
$OutputCueText = @'
FILE "justice-gakuen2-mgk04-full-tutorial-v1.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@
[System.IO.File]::WriteAllText($OutputCue, $OutputCueText, [System.Text.Encoding]::ASCII)

$ReportObj = (Read-Utf8Text $OutputReport) | ConvertFrom-Json
Write-Host ""
Write-Host "Prototype disc results:" -ForegroundColor Cyan
Write-Host ("  Output SHA-256: {0}" -f $ReportObj.output_bin_sha256)
Write-Host ("  Changed sectors: {0}" -f $ReportObj.changed_sector_count)
Write-Host ("  Changed LBA ranges: {0}" -f (($ReportObj.changed_lba_ranges | ForEach-Object { "[{0}..{1}]" -f $_[0], $_[1] }) -join ", "))
Write-Host ("  MGK04 readback verified: {0}" -f $ReportObj.readback_verified)
Write-Host ("  Disc length preserved: {0}" -f $ReportObj.source_image_length_preserved)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "FULL MGK04 TUTORIAL + ADMISSIONS ENGLISH BUILD COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
Write-Host $OutputCue -ForegroundColor Yellow
Write-Host ""
Write-Host "Scope: all 58 unique MGK04 tutorial/admissions semantic groups." -ForegroundColor Yellow
Write-Host "Play the tutorial, entrance exam, and result sequence straight through and report the first Japanese text you see." -ForegroundColor Yellow
