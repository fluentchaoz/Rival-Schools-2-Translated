param(
    [Parameter(Mandatory=$true)]
    [string]$RomFolder,

    [Parameter(Mandatory=$false)]
    [string]$WorkspacePackage = "",

    [Parameter(Mandatory=$false)]
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
$TargetRecord = "DAT2/MGT00.BIZ"

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
$WorkRoot = Join-Path $Upstream "work\english-batsu-playable-scene1"
$PackageRoot = Join-Path $WorkRoot "workspace-package"
$PrimaryWorkspace = Join-Path $PackageRoot "translation-workspace"
$Codebook = Join-Path $PackageRoot "batsu-codebook.json"
$SelectorWorkspace = Join-Path $WorkRoot "selector-workspace"
$KeyboardDir = Join-Path $WorkRoot "name-entry"
$Keyboard = Join-Path $KeyboardDir "keyboard.json"
$PrimaryAudit = Join-Path $WorkRoot "primary-scene1-audit.json"
$SelectorAudit = Join-Path $WorkRoot "selector-audit.json"
$BuildOutput = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildOutput "justice-gakuen2-batsu-english-scene1.bin"
$OutputCue = Join-Path $BuildOutput "justice-gakuen2-batsu-english-scene1.cue"
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
  "DAT2/MGT00.BIZ#bank-0-entry-0000": ["Hey, Batsu!", "Why the long face?", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0001": ["Oh, ", "...", "That meeting got me", "thinking.", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0002": ["Teacher say much?", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0003": ["I don't care what", "teachers say to me.", "But Mom bowed down", "and apologized...", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0004": ["She raised me alone,", "I've only done", "what I wanted...", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0005": ["Try studying harder.", "Buy Mom a gift?", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0006": ["Start with studying.", "Raise your grades,", "then no more worry.", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0007": ["Easy for you to say.", "If only I could...", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0008": ["(Batsu headed down,", "", "still feeling low.", "", "Could I help more?)", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0009": ["Hmm...", "Then get her", "a birthday gift.", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0010": ["A present...", "That's it!", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0011": ["When's her birthday?", ""],
  "DAT2/MGT00.BIZ#bank-0-entry-0012": ["No problem!", "We've got time.", "Okay! Starting now,", "I'll work extra!", ""],

  "DAT2/MGT00.BIZ#bank-1-entry-0000": ["Hey, Batsu.", "Why the long face?", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0001": ["Oh, ", "...", "That meeting got me", "thinking.", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0002": ["Teacher say much?", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0003": ["I don't care what", "teachers say to me.", "But Mom bowed down", "and apologized...", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0004": ["She raised me alone,", "I've only done", "what I wanted...", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0005": ["Try studying harder.", "Buy Mom a gift?", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0006": ["Start with studying.", "", "Raise your grades,", "then no more worry.", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0007": ["Easy for you to say.", "If only I could...", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0008": ["(Batsu headed down,", "", "still feeling low.", "", "Could I help more?)", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0009": ["Hmm...", "Then get her", "a birthday gift.", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0010": ["A present...", "That's it!", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0011": ["When's her birthday?", ""],
  "DAT2/MGT00.BIZ#bank-1-entry-0012": ["No problem!", "We've got time.", "Okay! Starting now,", "I'll work extra!", ""]
}
'@

$FitObj = $FitJson | ConvertFrom-Json
$FitByCoordinate = @{}
foreach ($Property in $FitObj.PSObject.Properties) {
    $FitByCoordinate[[string]$Property.Name] = @($Property.Value)
}
if ($FitByCoordinate.Count -ne 26) {
    Fail ("Expected 26 opening-scene coordinates; got {0}." -f $FitByCoordinate.Count)
}

# Context shards are the canonical coordinate -> current semantic hash binding.
$SemanticByCoordinate = @{}
$SceneSegmentsBySemantic = @{}
$ContextFiles = @(Get-ChildItem (Join-Path $PrimaryWorkspace "context\mgt00") -Recurse -Filter *.json -File)

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

if ($SemanticByCoordinate.Count -ne 26) {
    Fail ("Only {0}/26 opening-scene coordinates were found in current route contexts." -f $SemanticByCoordinate.Count)
}
if ($SceneSegmentsBySemantic.Count -ne 19) {
    Fail ("Expected 19 opening-scene semantic groups; got {0}." -f $SceneSegmentsBySemantic.Count)
}

# First demote every previous Batsu draft back to untranslated, then author only
# the 19 fitted scene-1 groups.
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
            $Decision.notes = "English scene-1 PS1-fit prototype; korean_segments is temporarily used as generic target-language storage."
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

if ($SceneSemanticSeen.Count -ne 19 -or $AuthoredCount -ne 19) {
    Fail ("Expected to author exactly 19 scene groups; seen={0}, authored={1}." -f $SceneSemanticSeen.Count, $AuthoredCount)
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
if ($RemainingDrafts -ne 19) {
    Fail (
        "Primary workspace cleanup expected 19 drafts before Rust audit; found {0}. First owners: {1}" -f
        $RemainingDrafts, ($RemainingDraftOwners -join "; ")
    )
}

Write-Host ""
Write-Host "Batsu scene-1 prototype text prepared:" -ForegroundColor Cyan
Write-Host "  Coordinates: 26"
Write-Host "  Semantic groups: 19"
Write-Host "  Native line bound: <=20 cells"
Write-Host "  Native message bound: <=4 lines"

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
# Add a text-only MGT00 font build. It installs ONLY asset-local translated
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

    let raster_characters =
        collect_raster_characters(std::slice::from_ref(allocation_asset))?;
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
        .filter(|assignment| render_dialogue_assignment(assignment))
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
# English selector validation: source-bound honorific rewrites are intentionally
# empty. Upstream's generic Draft rule requires at least one nonempty Korean
# segment, which is correct for authored translations but wrong for an English
# "remove the suffix" rewrite. Keep the source binding and translator strict.
# ---------------------------------------------------------------------------
$SelectorValidationRs = Join-Path $Upstream "src\dialogue_audit\selector_translation_validation.rs"
$SelectorValidationText = Read-Utf8Text $SelectorValidationRs
$SelectorValidationMarker = "ENGLISH_PROJECT_EMPTY_RUNTIME_REWRITE_VALIDATION"

if (-not $SelectorValidationText.Contains($SelectorValidationMarker)) {
    $OldBlock = @'
        if source_group.development_resolution
            == DialogueSelectorDevelopmentResolution::RuntimeInsertionRewrite
        {
            let expected_segments = source_group
                .development_korean_segments
                .as_ref()
                .context("runtime insertion source lacks Korean development bytes")?;
            ensure!(
                decision.status != DialogueTranslationDecisionStatus::Untranslated
                    && decision.korean_segments
                        == expected_segments
                            .iter()
                            .cloned()
                            .map(Some)
                            .collect::<Vec<_>>()
                    && decision.translator.as_deref() == Some("source-bound-runtime-insertion"),
                "runtime insertion development rewrite changed"
            );
        }
'@

    $NewBlock = @'
        if source_group.development_resolution
            == DialogueSelectorDevelopmentResolution::RuntimeInsertionRewrite
        {
            // ENGLISH_PROJECT_EMPTY_RUNTIME_REWRITE_VALIDATION:
            // English intentionally removes these Japanese relationship
            // honorific suffixes. The rewrite is still source-bound and must
            // exactly equal the expected development bytes, but an all-empty
            // target is valid and must not be rejected by the generic
            // "authored translation must contain nonempty text" rule below.
            let expected_segments = source_group
                .development_korean_segments
                .as_ref()
                .context("runtime insertion source lacks English development bytes")?;
            ensure!(
                decision.status == DialogueTranslationDecisionStatus::Draft
                    && decision.korean_segments
                        == expected_segments
                            .iter()
                            .cloned()
                            .map(Some)
                            .collect::<Vec<_>>()
                    && decision.translator.as_deref() == Some("source-bound-runtime-insertion"),
                "runtime insertion development rewrite changed"
            );
            counts.draft_group_count += 1;
            continue;
        }
'@

    if (-not $SelectorValidationText.Contains($OldBlock)) {
        Fail "Could not locate the upstream runtime-insertion validation block."
    }

    $SelectorValidationText = $SelectorValidationText.Replace($OldBlock, $NewBlock)
    Write-Utf8NoBom $SelectorValidationRs $SelectorValidationText
    Write-Host "Patched selector validation for intentionally empty English suffix rewrites." -ForegroundColor Cyan
}

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

const TARGET_PATH: &str = "DAT2/MGT00.BIZ";

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

fn main() -> Result<()> {
    let args = std::env::args().collect::<Vec<_>>();
    ensure!(
        args.len() == 9,
        "usage: english_batsu_prototype <cue> <source-bin> <codebook> <primary-workspace> <selector-workspace> <keyboard.json> <font.ttf> <output-dir>"
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

    eprintln!("prototype: building text-only MGT00 record");
    let record = build_dialogue_text_only_prototype_record(&font_config, TARGET_PATH)?;

    let output_bin = output_dir.join("justice-gakuen2-batsu-english-scene1.bin");
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
        "prototype MGT00 disc readback differs from replacement"
    );

    let source_len = std::fs::metadata(&source_bin)?.len();
    let output_len = std::fs::metadata(&output_bin)?.len();
    ensure!(source_len == output_len, "prototype image length changed");

    let (changed_lbas, output_sha256) =
        rebuild::compare_and_hash_images(&source_bin, &output_bin)?;
    ensure!(!changed_lbas.is_empty(), "prototype disc has no changed sectors");

    let report = PrototypeReport {
        kind: "Justice Gakuen 2 English Batsu scene-1 one-record prototype".into(),
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
'@

$BinDir = Join-Path $Upstream "src\bin"
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$PrototypeRs = Join-Path $BinDir "english_batsu_prototype.rs"
Write-Utf8NoBom $PrototypeRs $PrototypeRust

# ---------------------------------------------------------------------------
# Build patched tools.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Justice Gakuen English Project - First Playable Batsu Prototype v3" -ForegroundColor Cyan
Write-Host ""

Push-Location $Upstream
try {
    Write-Host "[1/6] Building English prototype tools..."
    Run-Native "cargo" @("build", "--release", "--bin", "justice-gakuen2-kr", "--bin", "english_batsu_prototype")
}
finally {
    Pop-Location
}

$MainExe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
$PrototypeExe = Join-Path $Upstream "target\release\english_batsu_prototype.exe"
if (-not (Test-Path $MainExe) -or -not (Test-Path $PrototypeExe)) {
    Fail "Prototype executables were not produced."
}

# ---------------------------------------------------------------------------
# Audit scene-only primary workspace: exactly 19 drafts.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/6] Auditing 19 fitted Batsu scene groups..."
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
if ($PrimaryAuditObj.draft_group_count -ne 19) {
    Fail ("Expected exactly 19 prototype draft groups; audit reports {0}." -f $PrimaryAuditObj.draft_group_count)
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
# Prepare messages, install only English body glyphs into MGT00, replace exactly
# one disc record, and verify raw-disc readback.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/6] Preparing authored-subset message plan..."
Write-Host "[5/6] Installing English glyphs into MGT00 only..."
Write-Host "[6/6] Building and readback-verifying one-record BIN..."

Run-Native $PrototypeExe @(
    $TargetCue,
    $TargetBin,
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
FILE "justice-gakuen2-batsu-english-scene1.bin" BINARY
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
Write-Host ("  MGT00 readback verified: {0}" -f $ReportObj.readback_verified)
Write-Host ("  Disc length preserved: {0}" -f $ReportObj.source_image_length_preserved)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "BATSU ENGLISH SCENE-1 PLAYABLE PROTOTYPE V3 BUILT" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
Write-Host $OutputCue -ForegroundColor Yellow
Write-Host ""
Write-Host "Prototype scope: only Batsu's opening parent-teacher-conference scene." -ForegroundColor Yellow
Write-Host "Everything else is intentionally left Japanese for this first runtime proof." -ForegroundColor Yellow
