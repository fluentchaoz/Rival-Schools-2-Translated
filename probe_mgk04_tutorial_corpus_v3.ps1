param(
    [string]$WorkspacePackage = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText(
        $Path,
        (New-Object System.Text.UTF8Encoding($false, $true))
    )
}

function Has-Prop($Object, [string]$Name) {
    if ($null -eq $Object) { return $false }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-Prop($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $Default }
    return $Property.Value
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$TargetPath = "DAT2/MGK04.BIZ"
$WorkRoot = Join-Path $Upstream "work\english-mgk04-tutorial-corpus-v3"
$ExtractRoot = Join-Path $WorkRoot "workspace-package"
$ReportPath = Join-Path $WorkRoot "mgk04-tutorial-corpus-v3.txt"
$JsonPath = Join-Path $WorkRoot "mgk04-tutorial-corpus-v3.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - MGK04 Tutorial Corpus Probe v3" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder beside this script."
}

# Find the canonical Batsu translation workspace package.
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

$Workspace = $null

if (-not [string]::IsNullOrWhiteSpace($WorkspacePackage) -and (Test-Path $WorkspacePackage)) {
    if (Test-Path $WorkRoot) {
        Remove-Item $WorkRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $ExtractRoot | Out-Null
    Expand-Archive -Path $WorkspacePackage -DestinationPath $ExtractRoot -Force

    $Workspace = Join-Path $ExtractRoot "translation-workspace"
    if (-not (Test-Path $Workspace)) {
        Fail "Workspace ZIP did not contain translation-workspace."
    }

    Write-Host ("Workspace package: {0}" -f $WorkspacePackage)
}
else {
    # Fallback: use the already-expanded workspace from the earlier MGK04 run.
    $Fallback = Join-Path $Upstream "work\english-road-to-batsu-mgk04\workspace-package\translation-workspace"
    if (Test-Path $Fallback) {
        $Workspace = $Fallback
        if (Test-Path $WorkRoot) {
            Remove-Item $WorkRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
        Write-Host ("Using existing expanded workspace: {0}" -f $Fallback)
    }
    else {
        Fail "Could not find english-batsu-workspace-bootstrap-v4.zip or an existing expanded MGK04 workspace."
    }
}

Write-Host ("Target dialogue record: {0}" -f $TargetPath)

$JsonFiles = @(Get-ChildItem $Workspace -Recurse -Filter *.json -File)

# semantic hash -> source entry
$SourceBySemantic = @{}
$ContextEntries = New-Object System.Collections.Generic.List[object]
$TranslationBySemantic = @{}
$Owners = @{}

foreach ($File in $JsonFiles) {
    $Obj = $null
    try {
        $Obj = (Read-Utf8 $File.FullName) | ConvertFrom-Json
    }
    catch {
        continue
    }

    if ($null -eq $Obj) { continue }

    $Owner = Get-Prop $Obj "owner"
    $Entries = Get-Prop $Obj "entries"

    # Source/context shards have an owner. Many other workspace JSON files do not.
    if ($null -ne $Owner -and $null -ne $Entries) {
        $OwnerSourcePath = [string](Get-Prop $Owner "source_path" "")
        if ($OwnerSourcePath -eq $TargetPath) {
            $OwnerBank = [int](Get-Prop $Owner "bank_selector" 0)
            $OwnerVariant = [int](Get-Prop $Owner "variant_selector" 0)
            $OwnerRoute = [string](Get-Prop $Owner "route_table_offset" "")

            $OwnerKey = "{0}|bank={1}|variant={2}|route={3}" -f
                $OwnerSourcePath,
                $OwnerBank,
                $OwnerVariant,
                $OwnerRoute
            $Owners[$OwnerKey] = $true

            foreach ($Entry in @($Entries)) {
                if ($null -eq $Entry) { continue }

                # Source shards.
                if ((Has-Prop $Entry "source_segments") -and
                    (Has-Prop $Entry "semantic_source_sha256")) {

                    $Semantic = [string](Get-Prop $Entry "semantic_source_sha256" "")
                    if (-not [string]::IsNullOrWhiteSpace($Semantic)) {
                        $SourceBySemantic[$Semantic] = [pscustomobject]@{
                            semantic = $Semantic
                            source_segments = @(Get-Prop $Entry "source_segments" @())
                            controls = @(Get-Prop $Entry "controls" @())
                            referenced_coordinate_ids = @(Get-Prop $Entry "referenced_coordinate_ids" @())
                            owner = $OwnerKey
                            source_file = $File.FullName
                        }
                    }
                }

                # Route-context shards.
                if ((Has-Prop $Entry "coordinate_id") -and
                    (Has-Prop $Entry "message_order") -and
                    (Has-Prop $Entry "speaker_identity") -and
                    (Has-Prop $Entry "semantic_source_sha256")) {

                    $ContextEntries.Add([pscustomobject]@{
                        coordinate_id = [string](Get-Prop $Entry "coordinate_id" "")
                        semantic = [string](Get-Prop $Entry "semantic_source_sha256" "")
                        message_order = [int](Get-Prop $Entry "message_order" 0)
                        segment_index = [int](Get-Prop $Entry "segment_index" 0)
                        entry_index = [int](Get-Prop $Entry "entry_index" 0)
                        scene_identity = [string](Get-Prop $Entry "scene_identity" "")
                        speaker_identity = [string](Get-Prop $Entry "speaker_identity" "")
                        listener_identity = [string](Get-Prop $Entry "listener_identity" "")
                        entrypoint = [string](Get-Prop $Entry "entrypoint" "")
                        command_offset = [string](Get-Prop $Entry "command_offset" "")
                        opcode = [string](Get-Prop $Entry "opcode" "")
                        semantic_evidence = [string](Get-Prop $Entry "semantic_evidence" "")
                        owner_bank = $OwnerBank
                        owner_variant = $OwnerVariant
                        owner_route = $OwnerRoute
                        context_file = $File.FullName
                    })
                }
            }
        }
    }

    # Translation decisions can live in owner-less JSON files.
    if ($null -ne $Entries) {
        foreach ($Entry in @($Entries)) {
            if ($null -eq $Entry) { continue }

            if ((Has-Prop $Entry "korean_segments") -and
                (Has-Prop $Entry "status") -and
                (Has-Prop $Entry "semantic_source_sha256")) {

                $Semantic = [string](Get-Prop $Entry "semantic_source_sha256" "")
                if ((-not [string]::IsNullOrWhiteSpace($Semantic)) -and
                    ($SourceBySemantic.ContainsKey($Semantic) -or
                     $TranslationBySemantic.ContainsKey($Semantic))) {

                    $TranslationBySemantic[$Semantic] = [pscustomobject]@{
                        status = [string](Get-Prop $Entry "status" "")
                        target_segments = @(Get-Prop $Entry "korean_segments" @())
                        translator = [string](Get-Prop $Entry "translator" "")
                        notes = [string](Get-Prop $Entry "notes" "")
                        translation_file = $File.FullName
                    }
                }
            }
        }
    }
}

if ($SourceBySemantic.Count -eq 0) {
    Fail "No MGK04 source groups were found in the workspace."
}
if ($ContextEntries.Count -eq 0) {
    Fail "No MGK04 route-context entries were found in the workspace."
}

# Second translation pass: now that all MGK04 source semantics are known,
# pick up translation decisions regardless of traversal order.
foreach ($File in $JsonFiles) {
    $Obj = $null
    try {
        $Obj = (Read-Utf8 $File.FullName) | ConvertFrom-Json
    }
    catch {
        continue
    }

    if ($null -eq $Obj) { continue }
    $Entries = Get-Prop $Obj "entries"
    if ($null -eq $Entries) { continue }

    foreach ($Entry in @($Entries)) {
        if ($null -eq $Entry) { continue }

        if ((Has-Prop $Entry "korean_segments") -and
            (Has-Prop $Entry "status") -and
            (Has-Prop $Entry "semantic_source_sha256")) {

            $Semantic = [string](Get-Prop $Entry "semantic_source_sha256" "")
            if ((-not [string]::IsNullOrWhiteSpace($Semantic)) -and
                $SourceBySemantic.ContainsKey($Semantic)) {

                $TranslationBySemantic[$Semantic] = [pscustomobject]@{
                    status = [string](Get-Prop $Entry "status" "")
                    target_segments = @(Get-Prop $Entry "korean_segments" @())
                    translator = [string](Get-Prop $Entry "translator" "")
                    notes = [string](Get-Prop $Entry "notes" "")
                    translation_file = $File.FullName
                }
            }
        }
    }
}

# Deduplicate coordinate/message occurrences. Some context shards can contain
# multiple segment-level entries for one message.
$Occurrences = @{}
foreach ($Ctx in $ContextEntries) {
    $Key = "{0}|{1}|{2}|{3}|{4}" -f
        $Ctx.owner_bank,
        $Ctx.owner_variant,
        $Ctx.message_order,
        $Ctx.coordinate_id,
        $Ctx.semantic

    if (-not $Occurrences.ContainsKey($Key)) {
        $Occurrences[$Key] = $Ctx
    }
}

$Ordered = @(
    $Occurrences.Values |
    Sort-Object `
        @{ Expression = { $_.owner_bank } }, `
        @{ Expression = { $_.owner_variant } }, `
        @{ Expression = { $_.message_order } }, `
        @{ Expression = { $_.entry_index } }, `
        @{ Expression = { $_.coordinate_id } }
)

$SpeakerSet = @{}
$SceneSet = @{}
$Rows = New-Object System.Collections.Generic.List[object]

foreach ($Ctx in $Ordered) {
    $SpeakerSet[[string]$Ctx.speaker_identity] = $true
    $SceneSet[[string]$Ctx.scene_identity] = $true

    if (-not $SourceBySemantic.ContainsKey($Ctx.semantic)) {
        Fail ("Context coordinate {0} points to missing source semantic {1}" -f $Ctx.coordinate_id, $Ctx.semantic)
    }

    $Source = $SourceBySemantic[$Ctx.semantic]
    $Translation = $null
    if ($TranslationBySemantic.ContainsKey($Ctx.semantic)) {
        $Translation = $TranslationBySemantic[$Ctx.semantic]
    }

    $Rows.Add([pscustomobject]@{
        bank = $Ctx.owner_bank
        variant = $Ctx.owner_variant
        message_order = $Ctx.message_order
        entry_index = $Ctx.entry_index
        coordinate_id = $Ctx.coordinate_id
        semantic_source_sha256 = $Ctx.semantic
        scene_identity = $Ctx.scene_identity
        speaker_identity = $Ctx.speaker_identity
        listener_identity = $Ctx.listener_identity
        source_segments = @($Source.source_segments)
        controls = @($Source.controls)
        translation_status = if ($null -eq $Translation) { "missing" } else { $Translation.status }
        target_segments = if ($null -eq $Translation) { @() } else { @($Translation.target_segments) }
        entrypoint = $Ctx.entrypoint
        command_offset = $Ctx.command_offset
        opcode = $Ctx.opcode
    })
}

# Produce a human-readable report.
$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add("Justice Gakuen 2 - Full DAT2/MGK04.BIZ tutorial/dialogue corpus")
$Lines.Add("")
$Lines.Add(("Workspace: {0}" -f $Workspace))
$Lines.Add(("Source semantic groups: {0}" -f $SourceBySemantic.Count))
$Lines.Add(("Execution-referenced message occurrences: {0}" -f $Rows.Count))
$Lines.Add(("Route owners: {0}" -f $Owners.Count))
$Lines.Add(("Distinct scene identities: {0}" -f $SceneSet.Count))
$Lines.Add(("Distinct speaker identities: {0}" -f $SpeakerSet.Count))
$Lines.Add("")
$Lines.Add("SCENES:")
foreach ($Scene in ($SceneSet.Keys | Sort-Object)) {
    $Lines.Add(("  {0}" -f $Scene))
}
$Lines.Add("")
$Lines.Add("SPEAKERS:")
foreach ($Speaker in ($SpeakerSet.Keys | Sort-Object)) {
    $Lines.Add(("  {0}" -f $Speaker))
}
$Lines.Add("")
$Lines.Add("OWNERS:")
foreach ($Owner in ($Owners.Keys | Sort-Object)) {
    $Lines.Add(("  {0}" -f $Owner))
}
$Lines.Add("")
$Lines.Add("=== EXECUTION ORDER ===")

$N = 0
foreach ($Row in $Rows) {
    $N += 1
    $Lines.Add("")
    $Lines.Add((
        "[{0:D3}] bank={1} variant={2} order={3} entry={4}" -f
        $N, $Row.bank, $Row.variant, $Row.message_order, $Row.entry_index
    ))
    $Lines.Add(("coordinate: {0}" -f $Row.coordinate_id))
    $Lines.Add(("scene:      {0}" -f $Row.scene_identity))
    $Lines.Add(("speaker:    {0}" -f $Row.speaker_identity))
    $Lines.Add(("listener:   {0}" -f $Row.listener_identity))
    $Lines.Add(("semantic:   {0}" -f $Row.semantic_source_sha256))
    $Lines.Add(("status:     {0}" -f $Row.translation_status))

    $Lines.Add("source_segments:")
    $SegIndex = 0
    foreach ($Segment in @($Row.source_segments)) {
        $Lines.Add(('  [{0}] "{1}"' -f $SegIndex, ([string]$Segment).Replace('"','\"')))
        $SegIndex += 1
    }

    if (@($Row.controls).Count -gt 0) {
        $Lines.Add("controls:")
        foreach ($Control in @($Row.controls)) {
            $Name = [string]$Control.semantic_name
            $Args = @($Control.arguments) -join ", "
            $Lines.Add(("  {0}({1})" -f $Name, $Args))
        }
    }

    if (@($Row.target_segments).Count -gt 0) {
        $HasTarget = $false
        foreach ($Segment in @($Row.target_segments)) {
            if ($null -ne $Segment) { $HasTarget = $true; break }
        }
        if ($HasTarget) {
            $Lines.Add("current_target_segments:")
            $SegIndex = 0
            foreach ($Segment in @($Row.target_segments)) {
                if ($null -eq $Segment) {
                    $Lines.Add(("  [{0}] <null>" -f $SegIndex))
                }
                else {
                    $Lines.Add(('  [{0}] "{1}"' -f $SegIndex, ([string]$Segment).Replace('"','\"')))
                }
                $SegIndex += 1
            }
        }
    }
}

[System.IO.File]::WriteAllLines(
    $ReportPath,
    $Lines,
    (New-Object System.Text.UTF8Encoding($false))
)

$SortedScenes = @(
    @($SceneSet.Keys) |
    ForEach-Object { [string]$_ } |
    Sort-Object
)

$SortedSpeakers = @(
    @($SpeakerSet.Keys) |
    ForEach-Object { [string]$_ } |
    Sort-Object
)

$JsonObj = [pscustomobject]@{
    kind = "Justice Gakuen 2 MGK04 tutorial corpus probe v3"
    target_path = $TargetPath
    workspace = $Workspace
    source_semantic_group_count = $SourceBySemantic.Count
    execution_message_occurrence_count = $Rows.Count
    route_owner_count = $Owners.Count
    scene_identities = $SortedScenes
    speaker_identities = $SortedSpeakers
    rows = @($Rows)
}
[System.IO.File]::WriteAllText(
    $JsonPath,
    (($JsonObj | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "MGK04 TUTORIAL CORPUS PROBE V3 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Semantic groups: {0}" -f $SourceBySemantic.Count)
Write-Host ("Message occurrences: {0}" -f $Rows.Count)
Write-Host ("Distinct scenes: {0}" -f $SceneSet.Count)
Write-Host ("Distinct speakers: {0}" -f $SpeakerSet.Count)
Write-Host ""
Write-Host "SCENES:" -ForegroundColor Cyan
foreach ($Scene in $SortedScenes) {
    Write-Host ("  {0}" -f $Scene)
}
Write-Host ""
Write-Host "SPEAKERS:" -ForegroundColor Cyan
foreach ($Speaker in $SortedSpeakers) {
    Write-Host ("  {0}" -f $Speaker)
}
Write-Host ""
Write-Host "FULL EXECUTION-ORDER CORPUS:" -ForegroundColor Cyan
Get-Content $ReportPath
Write-Host ""
Write-Host "JSON COPY:" -ForegroundColor Cyan
Write-Host $JsonPath
Write-Host ""
Write-Host "Nothing in the ROM was modified." -ForegroundColor Green
