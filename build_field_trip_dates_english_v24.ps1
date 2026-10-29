[CmdletBinding()]
param(
    [string]$RecoveryRoot = "",
    [string]$MasterBin = "",
    [string]$SourceBin = "",
    [string]$UpstreamRoot = "",
    [string]$WorkRoot = "",
    [string]$FontPath = "",
    [switch]$CheckOnly
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function FullPath([string]$Path) { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert-FreeSpace([string]$OutputPath, [long]$DiscBytes, [string]$TargetPath) {
    $Budgets = @{}
    foreach ($Need in @(@{Path=$OutputPath;Bytes=$DiscBytes+32MB},@{Path=$TargetPath;Bytes=4GB})) {
        $Root = [IO.Path]::GetPathRoot((FullPath $Need.Path))
        if (-not $Budgets.ContainsKey($Root)) { $Budgets[$Root] = [long]0 }
        $Budgets[$Root] += [long]$Need.Bytes
    }
    foreach ($Root in $Budgets.Keys) {
        $Drive = [IO.DriveInfo]::new($Root)
        $Available = [long]$Drive.AvailableFreeSpace
        Write-Host ("Drive {0}: {1:N2} GiB free; {2:N2} GiB required." -f $Root, ($Available/1GB), ($Budgets[$Root]/1GB))
        if ($Available -lt $Budgets[$Root]) { throw "Not enough free space. Choose -WorkRoot / CARGO_TARGET_DIR on a roomier drive. No game or source file has been changed." }
    }
}
if (-not $RecoveryRoot) { $RecoveryRoot = Join-Path $env:USERPROFILE "JG2-Recovery-v1" }
$RecoveryRoot = FullPath $RecoveryRoot
if (-not $UpstreamRoot) { $UpstreamRoot = Join-Path $RecoveryRoot "project/upstream" }
$UpstreamRoot = FullPath $UpstreamRoot
if (-not $SourceBin) { $SourceBin = Join-Path $UpstreamRoot "roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" }
if (-not $MasterBin) {
    $CandidateRoot = Join-Path $RecoveryRoot "candidates"
    if (Test-Path -LiteralPath $CandidateRoot -PathType Container) {
        $Folders = @(Get-ChildItem -LiteralPath $CandidateRoot -Directory -Filter "club-join-v23-*" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Folder in $Folders) {
            $Candidate = Join-Path $Folder.FullName "build/justice-gakuen2-club-join-v23.bin"
            if ((Test-Path -LiteralPath $Candidate -PathType Leaf) -and (Hash $Candidate) -eq "9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1") {
                $MasterBin = $Candidate
                break
            }
        }
    }
    if (-not $MasterBin) { throw "No verified v23 candidate found. Pass -MasterBin with the v23 BIN from your successful build." }
}
if (-not $FontPath) { $FontPath = "C:\Windows\Fonts\arial.ttf" }
$FontPath = FullPath $FontPath
if (-not $WorkRoot) { $WorkRoot = Join-Path $RecoveryRoot ("candidates/field-trip-dates-v24-" + [Guid]::NewGuid().ToString("N")) }
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$WorkRoot = FullPath $WorkRoot
$RustPath = Join-Path $UpstreamRoot "src/dialogue_audit/name_entry_input_tests.rs"
$ExpectedMasterHash = "9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedDiscBytes = [long]663216960
$BuildDir = Join-Path $WorkRoot "build"
$Backup = Join-Path $WorkRoot "name_entry_input_tests.pre-v24.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v24.log"
Write-Host "Justice Gakuen English Project - FIELD TRIP AND DATES ENGLISH v24" -ForegroundColor Cyan
foreach ($Path in @($RustPath,$SourceBin,$MasterBin,$FontPath,(Join-Path $UpstreamRoot "Cargo.toml"))) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
}
if ((Hash $MasterBin) -ne $ExpectedMasterHash) { throw "v23 master hash mismatch. No files changed." }
if ((Hash $SourceBin) -ne $ExpectedSourceHash) { throw "Original source hash mismatch. No files changed." }
foreach ($Path in @($MasterBin,$SourceBin)) {
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedDiscBytes) { throw "Disc length mismatch: $Path" }
}
if (Test-Path -LiteralPath $WorkRoot) { throw "Output already exists: $WorkRoot. Use a new -WorkRoot; existing work is never replaced." }
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not on PATH. Use the terminal where recovery succeeded." }
$OriginalFontHash = Hash $FontPath
$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_FIELD_TRIP_V24")) {
    throw "A previous v24 source injection remains. Restore name_entry_input_tests.pre-v24.rs.bak from that run's candidate folder before retrying."
}
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host ("v23 input: " + $MasterBin)
Write-Host "Verified original and v23 images, font, source availability, output ownership, and free space." -ForegroundColor Green
if ($CheckOnly) { Write-Host "Preflight passed. No files changed." -ForegroundColor Green; return }
$Rust = @'
// ENGLISH_PROJECT_CLUB_JOIN_V24
mod english_field_trip_v24 {
 use anyhow::{Context,Result,ensure};
 use std::{fs,path::{Path,PathBuf},collections::{BTreeMap,BTreeSet},io::BufWriter};
 use serde_json::{json,Value};
 use super::super::{atlas,tokens};
 use crate::{pipeline::{sha256_bytes,sha256_file},compression::decompress,disc::rebuild,tim::{Cell,read_indexed_cell_in_prefix,write_indexed_cell_in_prefix,read_4bpp_palette_words_in_prefix,read_8bpp_palette_words_in_prefix,write_8bpp_indexed_cell_in_prefix}};
 const MASTER_HASH:&str="9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1";
 const SOURCE_HASH:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 const TEXT_HASH:&str="6cda90f63dce4639ab489d5ac69b9448e095f5fc0ceb6b4443bcb7c52ee3276e";
 const PACKET:&str=r###"{
  "record": "DAT2/MGG04T.BIZ",
  "selectors": [
    0,
    1
  ],
  "entries": [
    {
      "index": 348,
      "text": "THE FIELD TRIP IS TO\nAN AMUSEMENT PARK!\nIT'S BEEN AGES. I'LL\nENJOY EVERY BIT!"
    },
    {
      "index": 349,
      "text": "HEY, {0}!\nGLAD THE WEATHER\nCLEARED UP."
    },
    {
      "index": 350,
      "text": "MORNING, BATSU.\nWHERE'S EVERYONE?"
    },
    {
      "index": 351,
      "text": "HM? OH, SOMEWHERE\nAROUND HERE, I\nGUESS."
    },
    {
      "index": 352,
      "text": "MORNING, {0}!\nI'M EXCITED ABOUT\nTODAY'S TRIP!"
    },
    {
      "index": 353,
      "text": "MORNING, HINATA.\nYOU'RE EVEN LIVELIER\nTHAN USUAL."
    },
    {
      "index": 354,
      "text": "OF COURSE! IT'S AN\nAMUSEMENT PARK! I'M\nRIDING EVERY RIDE!"
    },
    {
      "index": 355,
      "text": "HINATA, DON'T GET\nCARRIED AWAY AND\nCAUSE TROUBLE, ALL\nRIGHT?"
    },
    {
      "index": 356,
      "text": "HAHA. SOUNDS LIKE\nYOU HAVE YOUR HANDS\nFULL, KYOSUKE."
    },
    {
      "index": 357,
      "text": "WELL, SUCH IS THE\nFATE OF A CLASS\nREPRESENTATIVE."
    },
    {
      "index": 358,
      "text": "HEY! DON'T JUST\nASSUME I'LL CAUSE\nTROUBLE!"
    },
    {
      "index": 359,
      "text": "HINATA'S READY TO\nGO! WHICH ATTRACTION\nFIRST?"
    },
    {
      "index": 360,
      "text": "UM, I WANT TO SEE\nTHE BIGGEST FERRIS\nWHEEL IN JAPAN."
    },
    {
      "index": 361,
      "text": "FERRIS WHEEL? SURE.\nWHAT ABOUT YOU,\n{0}?"
    },
    {
      "index": 362,
      "text": "HMM... WHAT SHOULD I\nDO?"
    },
    {
      "index": 363,
      "text": "NOT SURE? WE'LL BE\nAT THE FERRIS WHEEL.\nCOME ALONG LATER!"
    },
    {
      "index": 364,
      "text": "GOOD IDEA. I WILL."
    },
    {
      "index": 365,
      "text": "{0},\nSEE YOU LATER!"
    },
    {
      "index": 366,
      "text": "OH, {0}!\nWHAT ARE YOU DOING\nHERE?"
    },
    {
      "index": 367,
      "text": "HEY, RAN. HUNTING\nFOR A SCOOP EVEN WAY\nOUT HERE?"
    },
    {
      "index": 368,
      "text": "WHAT DO YOU MEAN?\nPLACES LIKE THIS ARE\nPERFECT FOR FINDING\nSCOOPS!"
    },
    {
      "index": 369,
      "text": "YOU LOOK BORED. IF\nYOU'RE FREE, WILL\nYOU HELP WITH MY\nREPORTING?"
    },
    {
      "index": 370,
      "text": "HMM. HELPING RAN\nWITH HER REPORTING\nCOULD BE FUN..."
    },
    {
      "index": 371,
      "text": "HELP RAN\nDECLINE"
    },
    {
      "index": 372,
      "text": "I'VE NO PLANS. SURE,\nI'LL HELP."
    },
    {
      "index": 373,
      "text": "REALLY? GREAT! COME\nALONG, THEN!"
    },
    {
      "index": 374,
      "text": "SORRY, RAN. THERE'S\nSOMEWHERE I WANT TO\nGO. MAYBE ANOTHER\nTIME."
    },
    {
      "index": 375,
      "text": "WHAT?! HONESTLY,\nYOU'RE NO FUN!"
    },
    {
      "index": 376,
      "text": "SORRY! IF I FIND A\nGOOD STORY, YOU'LL\nBE THE FIRST TO\nKNOW."
    },
    {
      "index": 377,
      "text": "REALLY? OK, I'LL LET\nYOU OFF. SEE YOU!"
    },
    {
      "index": 378,
      "text": "PHEW, THAT WAS\nCLOSE. I DON'T WANT\nTO GET ON RAN'S BAD\nSIDE."
    },
    {
      "index": 379,
      "text": "WHERE TO NOW? WE'RE\nAT AN AMUSEMENT\nPARK. BETTER ENJOY\nIT!"
    },
    {
      "index": 380,
      "text": "WHEEL     COASTER\nHAUNTED   ARCADE\nWALK"
    },
    {
      "index": 381,
      "text": "I HEARD THIS FERRIS\nWHEEL IS ONE OF THE\nWORLD'S BIGGEST.\nI'LL TAKE A LOOK!"
    },
    {
      "index": 382,
      "text": "AN AMUSEMENT PARK\nMEANS ROLLER\nCOASTERS! LET'S GO!"
    },
    {
      "index": 383,
      "text": "A HAUNTED HOUSE\nALONE SOUNDS LONELY.\nANYONE AROUND...?"
    },
    {
      "index": 384,
      "text": "COMING ALL THIS WAY\nJUST TO PLAY ARCADE\nGAMES... OH WELL."
    },
    {
      "index": 385,
      "text": "I'LL START WITH A\nLITTLE WALK AROUND."
    },
    {
      "index": 386,
      "text": "FIRST, WE NEED A\nDESTINATION. WHERE\nCOULD WE FIND A GOOD\nSTORY?"
    },
    {
      "index": 387,
      "text": "LET'S SEE..."
    },
    {
      "index": 388,
      "text": "FERRIS WHEEL?\nROLLER COASTER?\nHOW ABOUT THE POND?"
    },
    {
      "index": 389,
      "text": "HOW ABOUT THE FERRIS\nWHEEL? I HEAR IT'S\nONE OF THE WORLD'S\nBIGGEST."
    },
    {
      "index": 390,
      "text": "THE FERRIS WHEEL? A\nBIT TAME, BUT BEING\nONE OF THE WORLD'S\nBIGGEST IS A PLUS."
    },
    {
      "index": 391,
      "text": "OK! LET'S START\nTHERE!"
    },
    {
      "index": 392,
      "text": "THIS IS THAT\nSUPPOSEDLY\nWORLD-CLASS FERRIS\nWHEEL."
    },
    {
      "index": 393,
      "text": "BUT I'M NOT SURE IT\nREALLY IS ONE OF THE\nWORLD'S BIGGEST."
    },
    {
      "index": 394,
      "text": "WHY NOT RIDE IT?\nTHEN YOU CAN GET A\nPROPER FEEL FOR ITS\nSIZE."
    },
    {
      "index": 395,
      "text": "GOOD POINT.\n{0}, LET'S GO!"
    },
    {
      "index": 396,
      "text": "{0}..................{1}"
    },
    {
      "index": 397,
      "text": "HOW WAS IT, RAN?"
    },
    {
      "index": 398,
      "text": "YES, THAT WAS QUITE\nA VIEW. AS A STORY,\nIT WAS ALL RIGHT, I\nSUPPOSE."
    },
    {
      "index": 399,
      "text": "A TOUGH CRITIC!\nSTILL, I'M GLAD I\nCOULD HELP."
    },
    {
      "index": 400,
      "text": "LET'S TAKE A FEW\nPHOTOS, THEN HEAD\nBACK!"
    },
    {
      "index": 401,
      "text": "(WE CHATTED HAPPILY\nWHILE I HELPED RAN\nTAKE HER\nPHOTOGRAPHS.)"
    },
    {
      "index": 402,
      "text": "IT HAS TO BE THE\nROLLER COASTER.\nNOTHING BEATS IT FOR\nTHRILLS AND A STORY."
    },
    {
      "index": 403,
      "text": "THAT'S IT!\n{0}, COME ALONG!"
    },
    {
      "index": 404,
      "text": "NICE! VERY NICE!\nTHIS LOOKS GREAT!"
    },
    {
      "index": 405,
      "text": "RAN, THIS SIGN\nEXPLAINS THE\nCOASTER."
    },
    {
      "index": 406,
      "text": "LET'S SEE... WHAT'S\nIT SAY?"
    },
    {
      "index": 407,
      "text": "ROLLER COASTER:\nBEAGLE. THIS PARK'S\nFIRST COASTER WITH A\nSIDEWAYS LOOP."
    },
    {
      "index": 408,
      "text": "EVEN THE TOUGHEST\nRIDER WILL FORGET TO\nSCREAM AT ITS\nINCREDIBLE SPEED."
    },
    {
      "index": 409,
      "text": "...IT SAYS. SOUNDS\nPRETTY WILD."
    },
    {
      "index": 410,
      "text": "SOUNDS ALMOST TOO\nGOOD. IS ANY OF THAT\nREALLY TRUE?"
    },
    {
      "index": 411,
      "text": "WE NEED A SPECIAL\nCORRESPONDENT TO\nRIDE IT AND GIVE US\nA REPORT!"
    },
    {
      "index": 412,
      "text": "...WHO WOULD THAT\nBE?"
    },
    {
      "index": 413,
      "text": "WHAT DO YOU MEAN?\nYOU'RE THE ONE FOR\nTHE JOB!"
    },
    {
      "index": 414,
      "text": "W-WHY ME?!"
    },
    {
      "index": 415,
      "text": "{0}..................{1}"
    },
    {
      "index": 416,
      "text": "LOOKS LIKE TRUTH IN\nADVERTISING! GIVE ME\nALL THE DETAILS.\nWHAT A GREAT STORY!"
    },
    {
      "index": 417,
      "text": "(RAN LOOKS PLEASED.\nWELL, GOOD FOR\nHER... THAT WAS A\nROUGH RIDE!)"
    },
    {
      "index": 418,
      "text": "I THINK WE COULD TRY\nA MORE UNEXPECTED\nSPOT..."
    },
    {
      "index": 419,
      "text": "HMM. AND WHERE WOULD\nTHAT BE?"
    },
    {
      "index": 420,
      "text": "THE POND! BIG THINGS\nCAN HAPPEN IN\nORDINARY PLACES.\nTRUST ME, RAN!"
    },
    {
      "index": 421,
      "text": "WHAT ARE YOU TALKING\nABOUT? BUT YOU SOUND\nAWFULLY CONFIDENT.\nLET'S GO!"
    },
    {
      "index": 422,
      "text": "{0}..................{1}"
    },
    {
      "index": 423,
      "text": "SO WHERE'S THIS\nINCIDENT OF YOURS?"
    },
    {
      "index": 424,
      "text": "{0}..................{1}"
    },
    {
      "index": 425,
      "text": "A COUPLE, A FAMILY\nPICNIC... SO\nPEACEFUL. WHERE'S\nTHIS INCIDENT?"
    },
    {
      "index": 426,
      "text": "UM... THAT'S\nSTRANGE..."
    },
    {
      "index": 427,
      "text": "YOU WASTED MY\nPRECIOUS REPORTING\nTIME! HOW WILL YOU\nMAKE IT UP TO ME?!"
    },
    {
      "index": 428,
      "text": "(I SPENT THE REST OF\nTHE DAY BEING\nDRAGGED AROUND BY\nRAN...)"
    },
    {
      "index": 429,
      "text": "HEY, IT'S BATSU AND\nTHE OTHERS. HEY!"
    },
    {
      "index": 430,
      "text": "HEY, {0}!\nLOOK AT THIS LINE."
    },
    {
      "index": 431,
      "text": "I NEVER THOUGHT I'D\nHAVE TO WAIT THIS\nLONG FOR A FERRIS\nWHEEL."
    },
    {
      "index": 432,
      "text": "IT LOOKS NEW. NO\nWONDER IT'S POPULAR."
    },
    {
      "index": 433,
      "text": "PLUS, CALLING IT ONE\nOF THE WORLD'S\nBIGGEST DRAWS MORE\nPEOPLE, I SUPPOSE."
    },
    {
      "index": 434,
      "text": "EVEN SO, THIS IS\nRIDICULOUS..."
    },
    {
      "index": 435,
      "text": "DAMN IT! THAT GUY\nJUST CUT INTO THE\nLINE!"
    },
    {
      "index": 436,
      "text": "H-HEY, BATSU!"
    },
    {
      "index": 437,
      "text": "STOP BATSU\nBACK BATSU UP"
    },
    {
      "index": 438,
      "text": "BATSU, CALM DOWN! A\nFIGHT HERE WOULD BE\nTROUBLE!"
    },
    {
      "index": 439,
      "text": "HE BROKE THE RULES,\nBUT A FIGHT WOULD\nBOTHER EVERYONE.\nDON'T HIT HIM."
    },
    {
      "index": 440,
      "text": "EXACTLY. BESIDES,\nIT'S ALMOST OUR\nTURN. LET'S BE\nPATIENT."
    },
    {
      "index": 441,
      "text": "...TCH. ALL RIGHT."
    },
    {
      "index": 442,
      "text": "THE VIEW FROM THE\nFERRIS WHEEL WAS\nAMAZING!"
    },
    {
      "index": 443,
      "text": "YES, IT DESERVES TO\nBE CALLED ONE OF THE\nWORLD'S BIGGEST."
    },
    {
      "index": 444,
      "text": "YAWN... GREAT VIEW,\nBUT THAT THING MOVES\nSO SLOWLY IT PUT ME\nTO SLEEP."
    },
    {
      "index": 445,
      "text": "IT'S A FERRIS WHEEL,\nNOT A SCREAMING\nTHRILL RIDE. WHAT\nDID YOU EXPECT?"
    },
    {
      "index": 446,
      "text": "(WE HEADED HOME,\nCHATTING HAPPILY\nTOGETHER.)"
    },
    {
      "index": 447,
      "text": "I'LL BACK YOU UP! I\nWAS GETTING FED UP,\nTOO!"
    },
    {
      "index": 448,
      "text": "HEY, YOU! CAN'T YOU\nACT YOUR AGE AND\nWAIT YOUR TURN?"
    },
    {
      "index": 449,
      "text": "I KNEW IT WOULD TURN\nOUT THIS WAY, BUT\nSTILL..."
    },
    {
      "index": 450,
      "text": "{0}, WE NEVER GOT\nTO RIDE THE WHEEL!\nWE WAITED SO LONG.\nI WAS SO EXCITED!"
    },
    {
      "index": 451,
      "text": "SORRY. I JUST..."
    },
    {
      "index": 452,
      "text": "COME ON, HINATA. AT\nLEAST WE GOT THAT\nOUT OF OUR SYSTEMS!"
    },
    {
      "index": 453,
      "text": "IT WASN'T GOOD AT\nALL! YOU HAVEN'T\nREFLECTED ON IT ONE\nBIT!"
    },
    {
      "index": 454,
      "text": "HINATA, HOW ABOUT\n{0} AND I BUY YOU\nCAKE TO MAKE UP?"
    },
    {
      "index": 455,
      "text": "{0}YES. YOU OWE US AT\nLEAST THAT MUCH!{1}"
    },
    {
      "index": 456,
      "text": "(BATSU AND I ENDED\nUP BEING THOROUGHLY\nSCOLDED BY HINATA\nAND KYOSUKE...)"
    },
    {
      "index": 457,
      "text": "OH? AREN'T THOSE\nTHREE IN THE QUEUE\nAKIRA AND HER RATHER\nNOISY FRIENDS?"
    },
    {
      "index": 458,
      "text": "NOISY? SO WHAT IF\nWE'RE NOISY?"
    },
    {
      "index": 459,
      "text": "EDGE, DON'T THREATEN\nPEOPLE YOU KNOW!"
    },
    {
      "index": 460,
      "text": "{0}, OUR TURN!\nYOU CAME TO RIDE,\nRIGHT? LET'S GO!"
    },
    {
      "index": 461,
      "text": "WAIT, AKIRA. ARE YOU\nREALLY KEEPING YOUR\nHELMET ON?"
    },
    {
      "index": 462,
      "text": "OF COURSE. WHY WOULD\nI TAKE IT OFF?"
    },
    {
      "index": 463,
      "text": "BECAUSE THE\nATTENDANT IS\nDEFINITELY GOING TO\nSTOP YOU!"
    },
    {
      "index": 464,
      "text": "REMOVE HER HELMET\nLEAVE IT ON"
    },
    {
      "index": 465,
      "text": "(DESPITE AKIRA'S\nPROTESTS, I MADE HER\nTAKE HER HELMET\nOFF.)"
    },
    {
      "index": 466,
      "text": "W-WHAT ARE YOU\nDOING?! S-STOP!"
    },
    {
      "index": 467,
      "text": "THERE. I'LL LOOK\nAFTER YOUR HELMET\nFOR NOW."
    },
    {
      "index": 468,
      "text": "PLEASE, {0}!\nGIVE MY HELMET BACK!"
    },
    {
      "index": 469,
      "text": "WOW! WHAT A COASTER!\nEVEN I WAS YELLING A\nLITTLE!"
    },
    {
      "index": 470,
      "text": "...HM? WHAT'S WRONG,\nAKIRA?"
    },
    {
      "index": 471,
      "text": "{0}, HOW AWFUL.\nI'M SCARED OF\nCOASTERS. THAT'S WHY\nI WANTED MY HELMET."
    },
    {
      "index": 472,
      "text": "HONESTLY! THAT WAS A\nTERRIBLE THING TO DO\nTO HER."
    },
    {
      "index": 473,
      "text": "S-SORRY! BUT THE\nTHRILLS WERE LIKE\nRIDING A MOTORCYCLE.\nFUN, RIGHT?"
    },
    {
      "index": 474,
      "text": "{0}..................{1}"
    },
    {
      "index": 475,
      "text": "(IT TOOK QUITE A\nWHILE TO SOOTHE\nAKIRA, WHO LOOKED\nCLOSE TO TEARS...)"
    },
    {
      "index": 476,
      "text": "WELL, IF AKIRA\nREALLY DOESN'T WANT\nTO TAKE IT OFF, WE\nCAN'T FORCE HER."
    },
    {
      "index": 477,
      "text": "SORRY. I ABSOLUTELY\nCAN'T TAKE IT OFF\nHERE."
    },
    {
      "index": 478,
      "text": "NO GOOD, HUH... TCH.\nWHAT AN INFLEXIBLE\nATTENDANT."
    },
    {
      "index": 479,
      "text": "SORRY, EVERYONE. I'M\nSCARED OF COASTERS.\nI CAN'T RIDE WITHOUT\nMY HELMET."
    },
    {
      "index": 480,
      "text": "WELL, IT CAN'T BE\nHELPED. THERE'S MORE\nTO AN AMUSEMENT PARK\nTHAN COASTERS!"
    },
    {
      "index": 481,
      "text": "THEN GET RIDES I CAN\nFIT ON! I CAN'T RIDE\nMOST OF THESE. IT'S\nBORING!"
    },
    {
      "index": 482,
      "text": "HMM... THAT MIGHT BE\nTHE TOUGHEST REQUEST\nOF ALL..."
    },
    {
      "index": 483,
      "text": "HEH! YOU SAID IT."
    },
    {
      "index": 484,
      "text": "{0}HEEHEE! YOU'RE ALL\nSO SELFISH!{1}"
    },
    {
      "index": 485,
      "text": "(WE NEVER RODE THE\nCOASTER, BUT WE\nSTILL HAD A GOOD\nTIME TOGETHER.)"
    },
    {
      "index": 486,
      "text": "(MAYBE IT WORKED OUT\nBETTER THIS WAY.)"
    },
    {
      "index": 487,
      "text": "HERE I AM AT THE\nHAUNTED HOUSE. GOING\nIN ALONE SEEMS DULL.\nWHAT SHOULD I DO?"
    },
    {
      "index": 488,
      "text": "OH? ISN'T THAT\n{0}?"
    },
    {
      "index": 489,
      "text": "{0}! WHAT ARE\nYOU DOING HERE?"
    },
    {
      "index": 490,
      "text": "DECIDING WHETHER TO\nGO IN. THESE PLACES\nAREN'T MUCH FUN\nALONE, ARE THEY?"
    },
    {
      "index": 491,
      "text": "YOU SAY THAT, BUT\nYOU'RE REALLY\nFRIGHTENED, AREN'T\nYOU?"
    },
    {
      "index": 492,
      "text": "N-NO! THAT'S NOT IT!"
    },
    {
      "index": 493,
      "text": "HAHA! JUST A JOKE.\nWE WERE ABOUT TO GO\nIN. CARE TO JOIN US?"
    },
    {
      "index": 494,
      "text": "JOIN ROY AND FRIENDS\nGIVE IT A MISS"
    },
    {
      "index": 495,
      "text": "SURE! WITH BOMAN\nALONG, AT LEAST THE\nGHOSTS WON'T SCARE\nME."
    },
    {
      "index": 496,
      "text": "IT'S TOO DARK TO SEE\nANYTHING."
    },
    {
      "index": 497,
      "text": "OH, GREAT. I CAN'T\nEVEN TELL WHICH WAY\nTHE EXIT IS."
    },
    {
      "index": 498,
      "text": "EEK! WHO TOUCHED MY\nBOTTOM?!"
    },
    {
      "index": 499,
      "text": "IT WASN'T ME! OW!\nSTOP HITTING ME!"
    },
    {
      "index": 500,
      "text": "{0}..................{1}"
    },
    {
      "index": 501,
      "text": "UGH... THAT WAS\nAWFUL."
    },
    {
      "index": 502,
      "text": "STRANGE. WHAT\nHAPPENED INSIDE WAS\nMORE FUN THAN THE\nHAUNTED HOUSE."
    },
    {
      "index": 503,
      "text": "WE ENJOYED OURSELVES\nIN THE END. THAT'S\nWHAT MATTERS, ISN'T\nIT?"
    },
    {
      "index": 504,
      "text": "JUST AS BOMAN SAYS!"
    },
    {
      "index": 505,
      "text": "(TIFFANY'S HURRICANE\nBATTERED ME INSIDE,\nBUT EVERYONE SEEMED\nHAPPY.)"
    },
    {
      "index": 506,
      "text": "...MAYBE I'LL PASS.\nIT LOOKS A LITTLE\nSCARY."
    },
    {
      "index": 507,
      "text": "{0}, NO GUT!"
    },
    {
      "index": 508,
      "text": "{0}, YOU MEAN\nGUTS. ARE YOU REALLY\nNOT COMING?"
    },
    {
      "index": 509,
      "text": "SORRY, BUT I'LL PASS\nTHIS TIME."
    },
    {
      "index": 510,
      "text": "I SEE... WE'LL SEE\nYOU LATER, THEN."
    },
    {
      "index": 511,
      "text": "(I'D LOOK PATHETIC\nIF I SCREAMED IN\nFRONT OF EVERYONE.\nBETTER SKIP IT.)"
    },
    {
      "index": 512,
      "text": "HEY, {0}!\nYOU CAME HERE, TOO?"
    },
    {
      "index": 513,
      "text": "HI, EVERYONE. HAVING\nFUN?"
    },
    {
      "index": 514,
      "text": "MORE OR LESS. I\nTHINK ROBERTO IS\nENJOYING HIMSELF\nMOST."
    },
    {
      "index": 515,
      "text": "YEAH. SORRY FOR\nDRAGGING YOU ALONG."
    },
    {
      "index": 516,
      "text": "SINCE WE'RE ALL\nHERE, WHY DON'T WE\nPLAY A GAME\nTOGETHER?"
    },
    {
      "index": 517,
      "text": "GOOD IDEA..."
    },
    {
      "index": 518,
      "text": "LET'S PLAY HERE!\nGO SOMEWHERE ELSE"
    },
    {
      "index": 519,
      "text": "SOUNDS GOOD! WHICH\nGAME SHALL WE\nCOMPETE AT?"
    },
    {
      "index": 520,
      "text": "FOR A GROUP, A BIG\nMACHINE IS BEST. HOW\nABOUT THIS ONE?"
    },
    {
      "index": 521,
      "text": "HEY, THAT LOOKS FUN!\nI DON'T KNOW WHAT IT\nIS, THOUGH."
    },
    {
      "index": 522,
      "text": "I DON'T KNOW MUCH\nABOUT GAMES, SO I'LL\nLEAVE IT TO YOU."
    },
    {
      "index": 523,
      "text": "WOW, THAT WAS FUN!\nROBERTO, YOU'RE\nREALLY GOOD AT\nTHESE!"
    },
    {
      "index": 524,
      "text": "YES. HOW DO YOU\nMANAGE TO BE SO\nGOOD? IT'S A\nMYSTERY."
    },
    {
      "index": 525,
      "text": "HAHA! PRACTICE.\nRIGHT, {0}?"
    },
    {
      "index": 526,
      "text": "THAT'S TRUE. IT DOES\nGET EXPENSIVE,\nTHOUGH."
    },
    {
      "index": 527,
      "text": "(WE CARRIED ON\nENJOYING THE ARCADE\nTOGETHER.)"
    },
    {
      "index": 528,
      "text": "WE CAME TO THE PARK.\nSHOULD WE TRY\nSOMETHING WE CAN\nONLY DO HERE?"
    },
    {
      "index": 529,
      "text": "TRUE, BUT... WHAT\nWOULD EVERYONE LIKE\nTO DO?"
    },
    {
      "index": 530,
      "text": "HMM. I'D LIKE TO\nRIDE THE FERRIS\nWHEEL."
    },
    {
      "index": 531,
      "text": "WHAT? AT AN\nAMUSEMENT PARK, IT\nHAS TO BE THE ROLLER\nCOASTER!"
    },
    {
      "index": 532,
      "text": "{0}..................{1}"
    },
    {
      "index": 533,
      "text": "(NOBODY WANTS TO GO\nTO THE SAME\nPLACE...)"
    },
    {
      "index": 534,
      "text": "(AT THIS RATE, IT'LL\nBE TIME TO GO HOME\nBEFORE WE DECIDE.)"
    },
    {
      "index": 535,
      "text": "(THAT'S HYO, THE\nSTUDENT COUNCIL\nPRESIDENT... I'LL\nTRY TALKING TO HIM.)"
    },
    {
      "index": 536,
      "text": "HYO, ARE YOU HERE\nALONE?"
    },
    {
      "index": 537,
      "text": "...{0}?\nAS YOU CAN SEE."
    },
    {
      "index": 538,
      "text": "IF YOU DON'T MIND...\nWOULD YOU LIKE TO\nLOOK AROUND WITH ME?"
    },
    {
      "index": 539,
      "text": "VERY WELL. I HAVE\nNOTHING IN\nPARTICULAR TO DO\nANYWAY."
    },
    {
      "index": 540,
      "text": "WELL, THEN..."
    },
    {
      "index": 541,
      "text": "TRY AN ATTRACTION\nRELAX BY THE POND"
    },
    {
      "index": 542,
      "text": "SHALL WE TRY A RIDE?"
    },
    {
      "index": 543,
      "text": "AN ATTRACTION?"
    },
    {
      "index": 544,
      "text": "Y-YES. THE FERRIS\nWHEEL OR THE ROLLER\nCOASTER. THEY'RE\nQUITE FUN."
    },
    {
      "index": 545,
      "text": "...WELL, ALL RIGHT.\nI SHALL ACCOMPANY\nYOU."
    },
    {
      "index": 546,
      "text": "I HEARD THE ROLLER\nCOASTER IS A GOOD\nCHOICE..."
    },
    {
      "index": 547,
      "text": "{0}..................{1}"
    },
    {
      "index": 548,
      "text": "N-NO, ACTUALLY...\nHOW ABOUT THE FERRIS\nWHEEL?"
    },
    {
      "index": 549,
      "text": "HOW TIRESOME! DID\nYOU BRING ME ALL\nTHIS WAY TO WASTE MY\nTIME?"
    },
    {
      "index": 550,
      "text": "HYO, PLEASE CALM\nDOWN."
    },
    {
      "index": 551,
      "text": "SILENCE! I HAVE NO\nWISH TO HEAR\nANYTHING MORE FROM\nYOU!"
    },
    {
      "index": 552,
      "text": "(...HE'S GONE.\nPERHAPS INVITING HIM\nALONG WAS A\nMISTAKE.)"
    },
    {
      "index": 553,
      "text": "SHALL WE GO\nSOMEWHERE QUIET? I\nHEAR THERE'S A POND\nA SHORT WALK AWAY."
    },
    {
      "index": 554,
      "text": "VERY WELL. I WAS\nGROWING RATHER TIRED\nOF THE CROWDS\nMYSELF."
    },
    {
      "index": 555,
      "text": "WHAT DO YOU THINK?\nIT'S NICE AND QUIET\nHERE."
    },
    {
      "index": 556,
      "text": "HM. NOT BAD. HERE,\nAT LEAST, I NEEDN'T\nENDURE THAT\nBOTHERSOME NOISE."
    },
    {
      "index": 557,
      "text": "{0}...\nNATURE IS A FINE\nTHING."
    },
    {
      "index": 558,
      "text": "OPEN YOUR HEART AND\nTOUCH NATURE, AND\nYOUR PETTY TROUBLES\nSEEM TO DISAPPEAR."
    },
    {
      "index": 559,
      "text": "...NO. THE TROUBLES\nREMAIN. A WEAK HEART\nJUST FORGETS AND IS\nSOOTHED."
    },
    {
      "index": 560,
      "text": "{0}..................{1}"
    },
    {
      "index": 561,
      "text": "(HYO HAS WORRIES OF\nHIS OWN, TOO...)"
    },
    {
      "index": 562,
      "text": "(AFTER THAT, WE SAID\nNOTHING. WE SIMPLY\nSHARED A QUIET,\nPEACEFUL TIME.)"
    }
  ],
  "overrides": {
    "1:498": "EEK! SOMETHING COLD\nTOUCHED MY NECK!",
    "1:499": "I-IT WASN'T ME! OW!\nTIFFANY, PLEASE STOP\nFLAILING AROUND!",
    "1:513": "I JUST GOT HERE.\nARE YOU ALL HAVING\nFUN?"
  },
  "review": {
    "male_source_messages": 215,
    "variant_payload_differences_reviewed": 96,
    "protected_control_coordinates": 64,
    "source_control_order_preserved": true,
    "maximum_name_cells": 6,
    "choice_geometry_requires_native_test": true
  }
}
"###;
 const DIALOGUE:&str="DAT2/MGG04T.BIZ";
 const BUNDLE:&str="DAT2/MGG04.BZZ";
 const GRAPHICS:&str="DAT2/MGBGG04.BZZ";
 const HEADER:&str="DAT2/MGCOCK.TIZ";
 const MGAME:&str="DAT1/MGAME.BIN";
 const ARENA:usize=0x31000;
 const LIMIT:usize=0x4a000;
 type Banks=Vec<(usize,Vec<Vec<u8>>)>;
 fn words(b:&[u8])->Vec<u16>{b.chunks_exact(2).map(|p|u16::from_le_bytes([p[0],p[1]])).collect()}
 fn bytes(mut w:Vec<u16>)->Vec<u8>{if w.len()%2!=0{w.push(0);}w.into_iter().flat_map(u16::to_le_bytes).collect()}
 fn u32_at(b:&[u8],at:usize)->Result<u32>{Ok(u32::from_le_bytes(b.get(at..at+4).context("truncated u32")?.try_into()?))}
 fn controls(b:&[u8],fixed:usize,slots:usize)->Result<Vec<(u16,Vec<u16>)>>{
  Ok(tokens::tokenize_dialogue_message(&words(b),fixed,slots)?.tokens.into_iter().filter(|t|!matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph|tokens::DialogueTokenKind::LineBreak|tokens::DialogueTokenKind::SkippedCode)).map(|t|(t.code,t.arguments)).collect())
 }
 // Native messages are pointer-indexed, end-terminated streams. This reader
 // accepts shared payloads while retaining exact 4-byte storage alignment.
 fn pointer_banks(d:&[u8])->Result<Banks>{
  ensure!(d.len()==0x51800,"decoded extent changed");let mut result=Vec::new();
  for sel in 0..8{let table=u32_at(d,ARENA+sel*4)?;if table==0{continue;}let table=table.checked_sub(0x800d0000).context("bad table pointer")? as usize;ensure!((ARENA+32..LIMIT).contains(&table)&&table%4==0,"table outside arena");let mut messages=Vec::new();let mut at=table;
   loop{ensure!(at+4<=LIMIT,"unterminated table");let p=u32_at(d,at)?;at+=4;if p==u32::MAX{break;}let p=p.checked_sub(0x800d0000).context("bad message pointer")? as usize;ensure!((ARENA+32..LIMIT).contains(&p)&&p%4==0,"message outside arena");let mut end=p;
    loop{ensure!(end+2<=LIMIT,"unterminated message");let code=u16::from_le_bytes(d[end..end+2].try_into()?);end+=2;if code==0x3001{break;}if code==0x3002||code==0x3003||(0x2003..=0x2009).contains(&code){ensure!(end+2<=LIMIT,"missing argument");end+=2;}}
    let aligned=(end+3)&!3;ensure!(aligned<=LIMIT&&d[end..aligned].iter().all(|b|*b==0),"invalid alignment padding");messages.push(d[p..aligned].to_vec());
   }result.push((sel,messages));
  }Ok(result)
 }
 fn compact(d:&mut[u8],banks:&Banks)->Result<(usize,usize)>{
  d[ARENA..LIMIT].fill(0);let mut cursor=ARENA+32;let mut pool=BTreeMap::<Vec<u8>,usize>::new();let mut aliases=0;
  for(sel,messages)in banks{let mut ptrs=Vec::new();for m in messages{ensure!(!m.is_empty()&&m.len()%4==0,"unaligned message");let p=if let Some(p)=pool.get(m){aliases+=1;*p}else{ensure!(cursor+m.len()<=LIMIT,"message arena overflow");let p=cursor;d[p..p+m.len()].copy_from_slice(m);cursor+=m.len();pool.insert(m.clone(),p);p};ptrs.push(p);}
   let table=cursor;for p in ptrs{ensure!(cursor+4<=LIMIT,"pointer arena overflow");d[cursor..cursor+4].copy_from_slice(&(0x800d0000+p as u32).to_le_bytes());cursor+=4;}ensure!(cursor+4<=LIMIT,"table terminator overflow");d[cursor..cursor+4].copy_from_slice(&u32::MAX.to_le_bytes());cursor+=4;d[ARENA+sel*4..ARENA+sel*4+4].copy_from_slice(&(0x800d0000+table as u32).to_le_bytes());
  }
  ensure!(pointer_banks(d)?==*banks,"shared message readback differs");Ok((cursor-(ARENA+32),aliases))
 }
 fn assert_pointer_consumer(mgame:&[u8],source:&[u8])->Result<()>{
  super::super::script_message_contract::validate_compact_message_opcode_contract(mgame)?;
  for(off,expected)in [(0xd630,0x96460000u32),(0xd634,0x24023001),(0xd638,0x30c3ffff),(0xd63c,0x106200d2),(0xd640,0x26520002),(0xd974,0x96460000),(0xd978,0x24023001),(0xd97c,0x30c3ffff),(0xd980,0x1462ff35),(0xd984,0x26520002)]{ensure!(u32_at(mgame,off)?==expected&&u32_at(source,off)?==expected,"native end-terminated reader changed");}
  ensure!(mgame[0xd5d0..0xda00]==source[0xd5d0..0xda00],"native message traversal differs");Ok(())
 }
 fn ink(font:&fontdue::Font,text:&str,size:f32)->Result<(usize,usize,Vec<(usize,usize)>)>{
  let mut pts=Vec::new();let mut cursor=0f32;
  for c in text.chars(){let(m,p)=font.rasterize(c,size);if c!=' '{ensure!(p.iter().any(|v|*v>=96),"font lacks {c}");}
   for y in 0..m.height {for x in 0..m.width {if p[y*m.width+x]>=96{pts.push((cursor.round() as i32+m.xmin+x as i32,-m.ymin-m.height as i32+y as i32));}}}cursor+=m.advance_width;
  }
  if pts.is_empty(){return Ok((0,0,vec![]));}
  let minx=pts.iter().map(|p|p.0).min().unwrap();let miny=pts.iter().map(|p|p.1).min().unwrap();
  let w=(pts.iter().map(|p|p.0).max().unwrap()-minx+1) as usize;let h=(pts.iter().map(|p|p.1).max().unwrap()-miny+1) as usize;
  Ok((w,h,pts.into_iter().map(|(x,y)|((x-minx) as usize,(y-miny) as usize)).collect()))
 }
 fn encode_target(text:&str,source:&[u8],codes:&BTreeMap<char,u16>,at:&atlas::ParsedDialogueAtlas)->Result<Vec<u8>>{
  let mut protected=controls(source,at.fixed_cell_count,at.addressable_slot_count)?;ensure!(protected.pop()==Some((0x3001,vec![])),"source terminator changed");let mut w=Vec::new();let mut rest=text;let mut next=0;let mut lines=1;let mut columns=0;
  while !rest.is_empty(){if rest.starts_with('{'){let end=rest.find('}').context("unclosed control placeholder")?;let id=rest[1..end].parse::<usize>()?;ensure!(id==next&&id<protected.len(),"control placeholder order/count");let(code,args)=&protected[id];w.push(*code);w.extend(args);if (0x2000..=0x2009).contains(code){columns+=6;}next+=1;rest=&rest[end+1..];
   }else{let c=rest.chars().next().unwrap();rest=&rest[c.len_utf8()..];if c=='\n'{ensure!(columns<=20,"line wider than 20 cells");lines+=1;columns=0;w.push(0x3000);}else{ensure!(c.is_ascii(),"non-ASCII translation");w.push(*codes.get(&c).with_context(||format!("missing ASCII glyph {c}"))?);columns+=1;}}
  }
  ensure!(next==protected.len(),"missing protected control placeholder");ensure!(columns<=20&&lines<=4,"translation exceeds native window");w.push(0x3001);let result=bytes(w);ensure!(controls(&result,at.fixed_cell_count,at.addressable_slot_count)?==controls(source,at.fixed_cell_count,at.addressable_slot_count)?,"protected controls changed");Ok(result)
 }
 fn chars_of(text:&str,set:&mut BTreeSet<char>)->Result<()>{let mut rest=text;while !rest.is_empty(){if rest.starts_with('{'){let end=rest.find('}').context("unclosed placeholder")?;rest=&rest[end+1..];}else{let c=rest.chars().next().unwrap();rest=&rest[c.len_utf8()..];if c!='\n'{ensure!(c.is_ascii(),"non-ASCII");set.insert(c);}}}Ok(())}
 fn patch_text(current:&[u8],font:&fontdue::Font)->Result<(Vec<u8>,Vec<u8>,Value)>{
  ensure!(sha256_bytes(current)==TEXT_HASH,"v22 Taiyo text identity changed");let before=decompress(current,true)?;let at=atlas::parse_dialogue_atlas(&before)?;let banks=pointer_banks(&before)?;let mut wanted=banks.clone();
  let packet:Value=serde_json::from_str(PACKET)?;let entries=packet["entries"].as_array().context("entries")?;ensure!(entries.len()==215,"translation population");let mut translations=BTreeMap::new();for sel in [0usize,1]{for e in entries{let i=e["index"].as_u64().context("index")? as usize;ensure!((348..=562).contains(&i),"entry outside scope");let key=format!("{sel}:{i}");let text=packet["overrides"][&key].as_str().or_else(||e["text"].as_str()).context("text")?.to_owned();ensure!(translations.insert((sel,i),text).is_none(),"duplicate coordinate");}}
  ensure!(translations.len()==430,"target count");
  let mut codes=" !'(),-./?ABCDEFGHIJKLMNOPQRSTUVWYZ".chars().enumerate().map(|(i,c)|(c,892+i as u16)).collect::<BTreeMap<_,_>>();codes.extend([(':',927),('>',928),('X',929)]);ensure!(codes.len()==38&&codes[&'X']==929,"v22 glyph mapping");
  for(&c,&code)in &codes{let p=at.pixel_data_offset+code as usize*200;ensure!(p+200<=ARENA,"existing glyph outside atlas");ensure!(before[p..p+200].iter().any(|b|*b!=0)||c==' ',"v21 ASCII glyph missing");}
  let mut chars=BTreeSet::new();for text in translations.values(){chars_of(text,&mut chars)?;}let mut first=at.fixed_cell_count;let mut used=BTreeSet::new();for(_,ms)in &banks{for m in ms{for t in tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens{if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){used.insert(t.code as usize);}}}}
  for i in 0..at.addressable_slot_count{if used.contains(&i)||before[at.pixel_data_offset+i*200..at.pixel_data_offset+(i+1)*200].iter().any(|b|*b!=0){first=first.max(i+1);}}
  let mut after=before.clone();let mut next=first;for c in chars{if codes.contains_key(&c){continue;}ensure!(next<at.addressable_slot_count,"new glyph capacity");let(w,h,pts)=ink(font,&c.to_string(),14.0)?;ensure!(w<=18&&h<=18,"glyph bounds");let mut pix=vec![0u8;400];let dx=(20-w)/2;let dy=(20-h)/2;for &(x,y)in &pts{for yy in (y+dy).saturating_sub(1)..=(y+dy+1).min(19){for xx in (x+dx).saturating_sub(1)..=(x+dx+1).min(19){pix[yy*20+xx]=4;}}}for(x,y)in pts{pix[(y+dy)*20+x+dx]=14;}let p=at.pixel_data_offset+next*200;ensure!(after[p..p+200].iter().all(|b|*b==0),"glyph slot used");for(i,pair)in pix.chunks_exact(2).enumerate(){after[p+i]=pair[0]|pair[1]<<4;}codes.insert(c,next as u16);next+=1;}
  for(&(sel,i),text)in &translations{let ms=&mut wanted.iter_mut().find(|(s,_)|*s==sel).context("selector")?.1;let old=ms.get(i).context("message")?;
   ms[i]=encode_target(text,old,&codes,&at).with_context(||format!("selector {sel} entry {i}"))?;
  }
  let naive=wanted.iter().map(|(_,ms)|ms.iter().map(Vec::len).sum::<usize>()+(ms.len()+1)*4).sum::<usize>();let(used_bytes,aliases)=compact(&mut after,&wanted)?;ensure!(aliases>0,"no shared payloads");
  let parsed=pointer_banks(&after)?;ensure!(parsed==wanted,"compacted readback");for((sel,ms),(_,original))in parsed.iter().zip(&banks){for(i,m)in ms.iter().enumerate(){tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?;if !translations.contains_key(&(*sel,i)){ensure!(m==&original[i],"earlier or unrelated message changed");}}}
  let lo=at.pixel_data_offset+first*200;let hi=at.pixel_data_offset+next*200;ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||(lo..hi).contains(&i)||(ARENA..LIMIT).contains(&i)),"text change outside ownership");
  let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len())?;let length=stored.len();ensure!(decompress(&stored,false)?==after,"text compression roundtrip");stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"padded text roundtrip");
  let report=json!({"translated_story_entries":430,"new_glyph_start":first,"new_glyph_count":next-first,"glyph_codes":codes,"arena_used_bytes":used_bytes,"arena_capacity_bytes":LIMIT-ARENA-32,"unshared_arena_bytes":naive,"shared_message_references":aliases,"deduplicated_bytes":naive-used_bytes,"compressed_bytes":length,"fixed_slot":current.len(),"input_sha256":TEXT_HASH,"patched_sha256":sha256_bytes(&stored),"earlier_and_untargeted_payloads_preserved":true,"scripts_preserved":true,"protected_controls_preserved":true,"native_pointer_readback_verified":true});Ok((stored,after,report))
 }
 fn canvas(font:&fontdue::Font,text:&str,width:usize,height:usize,fill:u8,outline:u8)->Result<Vec<u8>>{
  for size in [16.0f32,15.0,14.0,13.0,12.0,11.0,10.0,9.0]{let(w,h,pts)=ink(font,text,size)?;if w+2>width||h+2>height{continue;}let dx=(width-w)/2;let dy=(height-h)/2;let mut pix=vec![0u8;width*height];for &(x,y)in &pts{for yy in y+dy-1..=y+dy+1{for xx in x+dx-1..=x+dx+1{pix[yy*width+xx]=outline;}}}for(x,y)in pts{pix[(y+dy)*width+x+dx]=fill;}return Ok(pix);}anyhow::bail!("{text} does not fit")
 }
 fn rgba_png(path:&Path,pix:&[u8],w:usize,h:usize,pal:&[u16])->Result<()>{let mut rgba=Vec::new();for &i in pix{let p=pal[i as usize];for s in [0,5,10]{rgba.push((((p>>s)&31)*255/31)as u8);}rgba.push(if i==0{0}else{255});}let mut e=png::Encoder::new(BufWriter::new(fs::File::create(path)?),w as u32,h as u32);e.set_color(png::ColorType::Rgba);e.set_depth(png::BitDepth::Eight);e.write_header()?.write_image_data(&rgba)?;Ok(())}
 fn nearest(pal:&[u16],rgb:[i32;3])->u8{(0..pal.len()).min_by_key(|&i|[0,5,10].iter().enumerate().map(|(c,s)|(((pal[i]>>s)&31)as i32*255/31-rgb[c]).pow(2)).sum::<i32>()).unwrap()as u8}

 const TITLES:&str=r###"{"kind": "Candidate 256x220 8bpp title TIM inventory; visual classification required", "source_sha256": "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e", "unique_candidates": 22, "references": [{"record": "DAT2/MGBGC00.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "582fa11fa1751a1772e82f5805a3dbe7f07e3399d04960191f67f98cd234643a"}, {"record": "DAT2/MGBGC00.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "18af508d9ba153c6fd91c8b70e217243655984ce0b161154b04cf88359e8ddb2"}, {"record": "DAT2/MGBGC00.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d028a63ed6eaaaa9d12e61bfc738f7bf5d5aa4f1a4f60c3db3bd015ba3af998a"}, {"record": "DAT2/MGBGC00.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "526510d283187a1a62a54071f78ebb82359c605ec63199c7cf4040ad812f72ec"}, {"record": "DAT2/MGBGC00.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "288b6f087283de656e05e947b8391ebf6d28600269695eed3ad645d3d3917c3a"}, {"record": "DAT2/MGBGC00.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d1f371a3d7b02efef82b47f2547fbb5ec30d3ed91b1b1eb4ba8933868b2b9f14"}, {"record": "DAT2/MGBGC00.BZZ", "member": 6, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "1ff2d11ebe49279dcc998e027121bdd6db61673eb2256c05c3d1b8ffb76910dd"}, {"record": "DAT2/MGBGC00.BZZ", "member": 7, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "af2a74105575850c487f6f36f0a028a795bf374e74366e00bc552235519ad62c"}, {"record": "DAT2/MGBGC00.BZZ", "member": 8, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "7766468a8540908440d7821043d352b7e40c725c512fdee151b4515c616ae026"}, {"record": "DAT2/MGBGE03.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "5603ea58af19a72ef69d4c37377bcfd4769c462418d43cb69a452ed1bf934b84", "member_stored_sha256": "fd27060f823d0c2e55d68273a0a6f4fb64f6225620157a0954c4ff5162214d29"}, {"record": "DAT2/MGBGE03.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "fd27060f823d0c2e55d68273a0a6f4fb64f6225620157a0954c4ff5162214d29"}, {"record": "DAT2/MGBGE03.BZZ", "member": 23, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "68192ef02d2b2f332c9ff0b8ae93a3d57af62aaa108eba223d1ca161cc81ccca"}, {"record": "DAT2/MGBGF02.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "111dea04b358d02da8ab8ced8bf7670fc9f6995f7bfb36efbc61ef22f4872ac6"}, {"record": "DAT2/MGBGF02.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "92f0004b50b3364d4440e9e4503c78f8e7930fd6a45bea675ec7d595bce2cfc8"}, {"record": "DAT2/MGBGF02.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "236718ebefa024df19c5aeeff1b8351bbafc9bb261e4a18fb374cf1b472022f0"}, {"record": "DAT2/MGBGF02.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d9fb25863908eccb67f9276f38bfbe4a79c49b77b66b328f8c7b936da1332c9f"}, {"record": "DAT2/MGBGF02.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "4df12026050067244cf243164ac55c2ee478d490739af0710e9950a46a7df407"}, {"record": "DAT2/MGBGF02.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "668c5813f0009ba1d7b4cafe31bbcca7a41c7d00d18e20b5dffba87fcf8a5778"}, {"record": "DAT2/MGBGF02.BZZ", "member": 6, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "42c23a932bbef4e4660a57051ebe4235183bc9c1cf07fc5f607f7589f8937f18"}, {"record": "DAT2/MGBGF02.BZZ", "member": 7, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "f712d2f20e5b2f7de0ccf8296c52ebc14110a496eebf37e192b542e0c019efd2"}, {"record": "DAT2/MGBGF02.BZZ", "member": 8, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3feb7ff1c200072c7c096b16688129d77c6273a4c849c17d86729e2aa2f0d18a"}, {"record": "DAT2/MGBGG04.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29", "member_stored_sha256": "51ecb5253e608acf9e7cb895647e6b8ae910b0cf2d3a92799bc22c031d2db45a"}, {"record": "DAT2/MGBGG04.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "51ecb5253e608acf9e7cb895647e6b8ae910b0cf2d3a92799bc22c031d2db45a"}, {"record": "DAT2/MGBGG04.BZZ", "member": 14, "tim_offset": 0, "tim_sha256": "bd3135f549895e54cda5925b2637c2562ce5ceb7754abb146aba488a4859bcbf", "member_stored_sha256": "da3b817a11746eff27cf697d3faad78138a75291f0a164bcff2e4aa95e0f4d19"}, {"record": "DAT2/MGBGG04.BZZ", "member": 14, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "da3b817a11746eff27cf697d3faad78138a75291f0a164bcff2e4aa95e0f4d19"}, {"record": "DAT2/MGBGG04.BZZ", "member": 22, "tim_offset": 0, "tim_sha256": "0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29", "member_stored_sha256": "cc8df44c34b312ca7e4c03fb45d20c0d9123e2cf7be36846afc90a073e79744a"}, {"record": "DAT2/MGBGG04.BZZ", "member": 22, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "cc8df44c34b312ca7e4c03fb45d20c0d9123e2cf7be36846afc90a073e79744a"}, {"record": "DAT2/MGBGG04.BZZ", "member": 25, "tim_offset": 0, "tim_sha256": "bd3135f549895e54cda5925b2637c2562ce5ceb7754abb146aba488a4859bcbf", "member_stored_sha256": "34dbd3a4f27c59b7887d63f39e307b87d66eebce7ff14cdbe05428f3fb08dd3d"}, {"record": "DAT2/MGBGG04.BZZ", "member": 25, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "34dbd3a4f27c59b7887d63f39e307b87d66eebce7ff14cdbe05428f3fb08dd3d"}, {"record": "DAT2/MGBGG04.BZZ", "member": 26, "tim_offset": 0, "tim_sha256": "0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29", "member_stored_sha256": "c69d669c11b81a277971cca7a520adced5b8c747be306f6a2a692280ee8dd3b2"}, {"record": "DAT2/MGBGG04.BZZ", "member": 26, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "c69d669c11b81a277971cca7a520adced5b8c747be306f6a2a692280ee8dd3b2"}, {"record": "DAT2/MGBGG04.BZZ", "member": 29, "tim_offset": 0, "tim_sha256": "bd3135f549895e54cda5925b2637c2562ce5ceb7754abb146aba488a4859bcbf", "member_stored_sha256": "68f914f8bfe64d86fb38eadbbf0869e80bbb4c4f16f2a2cd88f0a1441b7dcbe5"}, {"record": "DAT2/MGBGG04.BZZ", "member": 29, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "68f914f8bfe64d86fb38eadbbf0869e80bbb4c4f16f2a2cd88f0a1441b7dcbe5"}, {"record": "DAT2/MGBGG04.BZZ", "member": 30, "tim_offset": 0, "tim_sha256": "0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29", "member_stored_sha256": "4819ddfea77f5432a88ef01ce6223b585d4ab6ed7bb056db93abb57d2c4ea43d"}, {"record": "DAT2/MGBGG04.BZZ", "member": 30, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "4819ddfea77f5432a88ef01ce6223b585d4ab6ed7bb056db93abb57d2c4ea43d"}, {"record": "DAT2/MGBGG04.BZZ", "member": 33, "tim_offset": 0, "tim_sha256": "bd3135f549895e54cda5925b2637c2562ce5ceb7754abb146aba488a4859bcbf", "member_stored_sha256": "856b605e8b13f306c656b9076e33cfa42124a00fea16b540b476eeb7b58363a7"}, {"record": "DAT2/MGBGG04.BZZ", "member": 33, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "856b605e8b13f306c656b9076e33cfa42124a00fea16b540b476eeb7b58363a7"}, {"record": "DAT2/MGBGG04.BZZ", "member": 34, "tim_offset": 0, "tim_sha256": "0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29", "member_stored_sha256": "a99462798d251f1e90464ca03321f906b6e58dd88e34810872c259f190a47783"}, {"record": "DAT2/MGBGG04.BZZ", "member": 34, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "a99462798d251f1e90464ca03321f906b6e58dd88e34810872c259f190a47783"}, {"record": "DAT2/MGBGG04.BZZ", "member": 37, "tim_offset": 0, "tim_sha256": "bd3135f549895e54cda5925b2637c2562ce5ceb7754abb146aba488a4859bcbf", "member_stored_sha256": "5d2e931069a6f521468977a128b7843e58ad7f53f481378073f7aae0641078ab"}, {"record": "DAT2/MGBGG04.BZZ", "member": 37, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "5d2e931069a6f521468977a128b7843e58ad7f53f481378073f7aae0641078ab"}, {"record": "DAT2/MGBGG06.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "eee4a0673d869e94261310cc4129ef92baf150abbb84aed936f70aca4387abdc", "member_stored_sha256": "8f2e45f10fbf48bba9090625ec984685d5af11e6f2ac56e5b6dc1cdb917439c3"}, {"record": "DAT2/MGBGG06.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "8f2e45f10fbf48bba9090625ec984685d5af11e6f2ac56e5b6dc1cdb917439c3"}, {"record": "DAT2/MGBGG06.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "eee4a0673d869e94261310cc4129ef92baf150abbb84aed936f70aca4387abdc", "member_stored_sha256": "26d2c86aad6fa2cad03391667a4add8b0e4f7e65a1dd8743253c980fb5df7bec"}, {"record": "DAT2/MGBGG06.BZZ", "member": 4, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "26d2c86aad6fa2cad03391667a4add8b0e4f7e65a1dd8743253c980fb5df7bec"}, {"record": "DAT2/MGBGG06.BZZ", "member": 9, "tim_offset": 0, "tim_sha256": "eee4a0673d869e94261310cc4129ef92baf150abbb84aed936f70aca4387abdc", "member_stored_sha256": "460064d352798e4ab682cbede6927bc13dff7d523cdd9ae2afc1b21286b40cf8"}, {"record": "DAT2/MGBGG06.BZZ", "member": 9, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "460064d352798e4ab682cbede6927bc13dff7d523cdd9ae2afc1b21286b40cf8"}, {"record": "DAT2/MGBGG06.BZZ", "member": 13, "tim_offset": 0, "tim_sha256": "eee4a0673d869e94261310cc4129ef92baf150abbb84aed936f70aca4387abdc", "member_stored_sha256": "655c1b97c2bc8ff099b947269525ba5bc15c180acbe494c5c14c11bd3ff70fa5"}, {"record": "DAT2/MGBGG06.BZZ", "member": 13, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "655c1b97c2bc8ff099b947269525ba5bc15c180acbe494c5c14c11bd3ff70fa5"}, {"record": "DAT2/MGBGG06.BZZ", "member": 20, "tim_offset": 0, "tim_sha256": "eee4a0673d869e94261310cc4129ef92baf150abbb84aed936f70aca4387abdc", "member_stored_sha256": "b17009390f24dc04d1fd9ba9de18be05bcbbca13aa0bcfbea373e6ee1e7db92f"}, {"record": "DAT2/MGBGG06.BZZ", "member": 20, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b17009390f24dc04d1fd9ba9de18be05bcbbca13aa0bcfbea373e6ee1e7db92f"}, {"record": "DAT2/MGBGG08.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "57ba907e1e07a2d5ef733400124f78c2fbe0aa416924d9adb272acd4db2d223d", "member_stored_sha256": "d8b6ddd818da01a373e3af86222b28c02625c19d3d2163bdd214fc1f8f47d2f7"}, {"record": "DAT2/MGBGG08.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d8b6ddd818da01a373e3af86222b28c02625c19d3d2163bdd214fc1f8f47d2f7"}, {"record": "DAT2/MGBGG08.BZZ", "member": 16, "tim_offset": 0, "tim_sha256": "57ba907e1e07a2d5ef733400124f78c2fbe0aa416924d9adb272acd4db2d223d", "member_stored_sha256": "740eaaefe0c23929e6dd7bb4166e0dcae9ef0f5ec37cfef0703da312d9f39e88"}, {"record": "DAT2/MGBGG08.BZZ", "member": 16, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "740eaaefe0c23929e6dd7bb4166e0dcae9ef0f5ec37cfef0703da312d9f39e88"}, {"record": "DAT2/MGBGG08.BZZ", "member": 17, "tim_offset": 0, "tim_sha256": "57ba907e1e07a2d5ef733400124f78c2fbe0aa416924d9adb272acd4db2d223d", "member_stored_sha256": "5a636a623cf8e4b92b5876026e980d211d774a73801243f76f13a1ce4efec161"}, {"record": "DAT2/MGBGG08.BZZ", "member": 17, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "5a636a623cf8e4b92b5876026e980d211d774a73801243f76f13a1ce4efec161"}, {"record": "DAT2/MGBGG08.BZZ", "member": 18, "tim_offset": 0, "tim_sha256": "57ba907e1e07a2d5ef733400124f78c2fbe0aa416924d9adb272acd4db2d223d", "member_stored_sha256": "1556f95d4751b642c7d4ce022e4a1ae18aa85834dea4271752bc86f5e3cb1330"}, {"record": "DAT2/MGBGG08.BZZ", "member": 18, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "1556f95d4751b642c7d4ce022e4a1ae18aa85834dea4271752bc86f5e3cb1330"}, {"record": "DAT2/MGBGG08.BZZ", "member": 19, "tim_offset": 0, "tim_sha256": "57ba907e1e07a2d5ef733400124f78c2fbe0aa416924d9adb272acd4db2d223d", "member_stored_sha256": "d332709fbf99149df16b652740ef880b9bbc0d0f31880f05f93fe790f70a0d12"}, {"record": "DAT2/MGBGG08.BZZ", "member": 19, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d332709fbf99149df16b652740ef880b9bbc0d0f31880f05f93fe790f70a0d12"}, {"record": "DAT2/MGBGG09.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "2877eb4038ebbad7e7b4eaaf316fd1a115119c2d72877a988cdee2e96e064407", "member_stored_sha256": "f53d65705be798021e5bac2c1c50db5e767ce49cece65f54755416b45eac7828"}, {"record": "DAT2/MGBGG09.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "f53d65705be798021e5bac2c1c50db5e767ce49cece65f54755416b45eac7828"}, {"record": "DAT2/MGBGG09.BZZ", "member": 29, "tim_offset": 0, "tim_sha256": "2877eb4038ebbad7e7b4eaaf316fd1a115119c2d72877a988cdee2e96e064407", "member_stored_sha256": "dfaf1808a9dfd8c4155d262ed97f6308f22bafd1da88ce3b3bcb350aabc7e6e3"}, {"record": "DAT2/MGBGG09.BZZ", "member": 29, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "dfaf1808a9dfd8c4155d262ed97f6308f22bafd1da88ce3b3bcb350aabc7e6e3"}, {"record": "DAT2/MGBGG09.BZZ", "member": 30, "tim_offset": 0, "tim_sha256": "2877eb4038ebbad7e7b4eaaf316fd1a115119c2d72877a988cdee2e96e064407", "member_stored_sha256": "ac9cd2955e5c9157926994e941e5b87319df8cfb23ce28d743f489e7271ed4bf"}, {"record": "DAT2/MGBGG09.BZZ", "member": 30, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ac9cd2955e5c9157926994e941e5b87319df8cfb23ce28d743f489e7271ed4bf"}, {"record": "DAT2/MGBGG09.BZZ", "member": 31, "tim_offset": 0, "tim_sha256": "2877eb4038ebbad7e7b4eaaf316fd1a115119c2d72877a988cdee2e96e064407", "member_stored_sha256": "01c21df951aed0ca919f9904f87dd6a4ef14dd94ca5118fa56df4686e9127877"}, {"record": "DAT2/MGBGG09.BZZ", "member": 31, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "01c21df951aed0ca919f9904f87dd6a4ef14dd94ca5118fa56df4686e9127877"}, {"record": "DAT2/MGBGG09.BZZ", "member": 32, "tim_offset": 0, "tim_sha256": "2877eb4038ebbad7e7b4eaaf316fd1a115119c2d72877a988cdee2e96e064407", "member_stored_sha256": "35df430020a6ba1615212b410bfce056575d9ecde08b66d3c188f8c9479fca5a"}, {"record": "DAT2/MGBGG09.BZZ", "member": 32, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "35df430020a6ba1615212b410bfce056575d9ecde08b66d3c188f8c9479fca5a"}, {"record": "DAT2/MGBGG11.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "48f4a5096174db627701cb74483004aa80043969c38a85bdea5b1fa1656315d5", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 8, "tim_offset": 0, "tim_sha256": "48f4a5096174db627701cb74483004aa80043969c38a85bdea5b1fa1656315d5", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 8, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 16, "tim_offset": 0, "tim_sha256": "48f4a5096174db627701cb74483004aa80043969c38a85bdea5b1fa1656315d5", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 16, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 24, "tim_offset": 0, "tim_sha256": "48f4a5096174db627701cb74483004aa80043969c38a85bdea5b1fa1656315d5", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 24, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 32, "tim_offset": 0, "tim_sha256": "48f4a5096174db627701cb74483004aa80043969c38a85bdea5b1fa1656315d5", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGG11.BZZ", "member": 32, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d82a86174182506febb5bda517e39be659af66d9a14ddbcfa6c2c03350996fb8"}, {"record": "DAT2/MGBGK01.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "25324e38c5ca15439a87a648cb17c1713370ed5c13a6bc0f7efee87ff47731ee", "member_stored_sha256": "ea2c7d15be7f52b20f6d3dc32de2c3e65c6168a51946b1460e324c5b0eeccb8d"}, {"record": "DAT2/MGBGK01.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ea2c7d15be7f52b20f6d3dc32de2c3e65c6168a51946b1460e324c5b0eeccb8d"}, {"record": "DAT2/MGBGK01.BZZ", "member": 21, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "872f08468ad7deebc568e11388e6156a85e5a9bc393e8cba4262c85e5e27cb2c"}, {"record": "DAT2/MGBGK01.BZZ", "member": 30, "tim_offset": 0, "tim_sha256": "25324e38c5ca15439a87a648cb17c1713370ed5c13a6bc0f7efee87ff47731ee", "member_stored_sha256": "cef9fba774f9550eb0512d1c50ca419bba6c58ae3fb0612acfbf4345c755ad0d"}, {"record": "DAT2/MGBGK01.BZZ", "member": 30, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "cef9fba774f9550eb0512d1c50ca419bba6c58ae3fb0612acfbf4345c755ad0d"}, {"record": "DAT2/MGBGK02.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "2b746290dd8f44e202f83deb38e89c5213f8de4abe156e55016fcd6b1d1e4d41", "member_stored_sha256": "7db56260dcb4d5cfe4730902dd56eb5910b712ed16b76cf4938668d48e25e772"}, {"record": "DAT2/MGBGK02.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "7db56260dcb4d5cfe4730902dd56eb5910b712ed16b76cf4938668d48e25e772"}, {"record": "DAT2/MGBGK02.BZZ", "member": 27, "tim_offset": 0, "tim_sha256": "2b746290dd8f44e202f83deb38e89c5213f8de4abe156e55016fcd6b1d1e4d41", "member_stored_sha256": "ecf26db7c8b6e3e5912762964de36c38f4791f2e203ba2a874b596f760f0cba8"}, {"record": "DAT2/MGBGK02.BZZ", "member": 27, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ecf26db7c8b6e3e5912762964de36c38f4791f2e203ba2a874b596f760f0cba8"}, {"record": "DAT2/MGBGK03.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "7d13612e23d39288997b3b7b10c97e6907b2aa37bfe86d4c8a0aa1303cfbbd1f", "member_stored_sha256": "f9935ec865905bf4060f2cc2f8b947ef91b84e447cfea854f3af9c1ff5bb16d9"}, {"record": "DAT2/MGBGK03.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "f9935ec865905bf4060f2cc2f8b947ef91b84e447cfea854f3af9c1ff5bb16d9"}, {"record": "DAT2/MGBGK03.BZZ", "member": 26, "tim_offset": 0, "tim_sha256": "5b04a0f2c805fc0b196ea4192ffd97c087b8b5ddb081a3ce2165433d189e3932", "member_stored_sha256": "76709839a9a7c2725191d5c55adfd7bf53f3601f16e7afea9959dc9db9ac997f"}, {"record": "DAT2/MGBGK03.BZZ", "member": 26, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "76709839a9a7c2725191d5c55adfd7bf53f3601f16e7afea9959dc9db9ac997f"}, {"record": "DAT2/MGBGK03.BZZ", "member": 29, "tim_offset": 0, "tim_sha256": "c5cedd79fa6eb0f4dfa70bdeb10c924c7edf0ed634b524ddd387242c1a0d9f90", "member_stored_sha256": "b55c03b74c0e8cdc3c51354231ecb5b0153f4c967f6b69f0b41f70f677f9d582"}, {"record": "DAT2/MGBGK03.BZZ", "member": 29, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b55c03b74c0e8cdc3c51354231ecb5b0153f4c967f6b69f0b41f70f677f9d582"}, {"record": "DAT2/MGBGK03.BZZ", "member": 32, "tim_offset": 0, "tim_sha256": "7d13612e23d39288997b3b7b10c97e6907b2aa37bfe86d4c8a0aa1303cfbbd1f", "member_stored_sha256": "2f25fb405cb613b7a0790821f7167db8446a6e624521aaeea65f5f9191133626"}, {"record": "DAT2/MGBGK03.BZZ", "member": 32, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2f25fb405cb613b7a0790821f7167db8446a6e624521aaeea65f5f9191133626"}, {"record": "DAT2/MGBGK04.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "c66a8cf99138b9d2304f55d4623dfdabef3834bb997ad2ccc8712ad3f43eacb2", "member_stored_sha256": "a11eb95d2a3de960a7f2841e6b2d5028b213edff28841b1b3e2d9d30778d2064"}, {"record": "DAT2/MGBGK05.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "7d70c98184f842b51fe7700b75510d7ac2a0803e7b6fafb7d0bfa3c784f85de6", "member_stored_sha256": "eb830e360c7d57d2255fea5cf86a71d43089e0a4a4b61dc52119487dc2b28dfe"}, {"record": "DAT2/MGBGK05.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "eb830e360c7d57d2255fea5cf86a71d43089e0a4a4b61dc52119487dc2b28dfe"}, {"record": "DAT2/MGBGK05.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "c66a8cf99138b9d2304f55d4623dfdabef3834bb997ad2ccc8712ad3f43eacb2", "member_stored_sha256": "a11eb95d2a3de960a7f2841e6b2d5028b213edff28841b1b3e2d9d30778d2064"}, {"record": "DAT2/MGBGK07.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "8c91b78d29bf8daa1264624187bea98ad9b9c35c4eba97edbd6fc96381d4a2dd", "member_stored_sha256": "73acd140a678c8b480bc32a7612a825a62d5e08ffc828257f3833b1a6373e07b"}, {"record": "DAT2/MGBGK07.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "73acd140a678c8b480bc32a7612a825a62d5e08ffc828257f3833b1a6373e07b"}, {"record": "DAT2/MGBGK07.BZZ", "member": 6, "tim_offset": 0, "tim_sha256": "1123074b2bd674dfb1e57f3110504fb3587062491de804f64045696f9fb8143d", "member_stored_sha256": "1f3b868d9079621bf4b672dff93b41a7feb6aa7d78bdcbbd47a81e37843bcd6d"}, {"record": "DAT2/MGBGK07.BZZ", "member": 6, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "1f3b868d9079621bf4b672dff93b41a7feb6aa7d78bdcbbd47a81e37843bcd6d"}, {"record": "DAT2/MGBGK07.BZZ", "member": 7, "tim_offset": 0, "tim_sha256": "1123074b2bd674dfb1e57f3110504fb3587062491de804f64045696f9fb8143d", "member_stored_sha256": "efb98adc6b0afd401ecb2a94b4430669213e6636ddf79333a3943ab0cd6aa635"}, {"record": "DAT2/MGBGK07.BZZ", "member": 7, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "efb98adc6b0afd401ecb2a94b4430669213e6636ddf79333a3943ab0cd6aa635"}, {"record": "DAT2/MGBGK08.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "ecc7a7625c02ae9112d5e9a56affeef54e568e4dd44039ccb4c5fcd679a9e41f", "member_stored_sha256": "fdaef7c05f70ddbfa1ea024d8ba6622c703adfaf6e74e7b35a2fca298a9ab493"}, {"record": "DAT2/MGBGK08.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "fdaef7c05f70ddbfa1ea024d8ba6622c703adfaf6e74e7b35a2fca298a9ab493"}, {"record": "DAT2/MGBGK08.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "ecc7a7625c02ae9112d5e9a56affeef54e568e4dd44039ccb4c5fcd679a9e41f", "member_stored_sha256": "7af82c708819ee6847d0cd00f6d335b074b79ce0125a97bd1b4b30595239aad1"}, {"record": "DAT2/MGBGK08.BZZ", "member": 1, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "7af82c708819ee6847d0cd00f6d335b074b79ce0125a97bd1b4b30595239aad1"}, {"record": "DAT2/MGBGK09.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "872f08468ad7deebc568e11388e6156a85e5a9bc393e8cba4262c85e5e27cb2c"}, {"record": "DAT2/MGBGK10.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "9b734643a162cee5149a27b4038bdf7454c144faf39e3171fa3db82fd0de6f12", "member_stored_sha256": "93936defff33b2eabc425dbd9c27aad1f4b80158996d3ca81f92c4779e9c6c19"}, {"record": "DAT2/MGBGK10.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "93936defff33b2eabc425dbd9c27aad1f4b80158996d3ca81f92c4779e9c6c19"}, {"record": "DAT2/MGBGK10.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "c66a8cf99138b9d2304f55d4623dfdabef3834bb997ad2ccc8712ad3f43eacb2", "member_stored_sha256": "a11eb95d2a3de960a7f2841e6b2d5028b213edff28841b1b3e2d9d30778d2064"}, {"record": "DAT2/MGBGK12.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "c015047ebd2ac5e82e33e761e6557c09d48dccb695e4954ea09bb8f4f65eea0d", "member_stored_sha256": "8308b7fde1d431cafd1d7b4a1ca3899c9595ce5b947529e7c51d97494838c045"}, {"record": "DAT2/MGBGK12.BZZ", "member": 0, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "8308b7fde1d431cafd1d7b4a1ca3899c9595ce5b947529e7c51d97494838c045"}, {"record": "DAT2/MGBGK12.BZZ", "member": 6, "tim_offset": 0, "tim_sha256": "4131308a6faf48394cd8b7e114dcd8c63a556ba4239c357726e01ba0a1cc447f", "member_stored_sha256": "fed994e5613e8974424cad091c2ab3fa852fd531ea4e64535102fe32164fec3c"}, {"record": "DAT2/MGBGK12.BZZ", "member": 6, "tim_offset": 57344, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "fed994e5613e8974424cad091c2ab3fa852fd531ea4e64535102fe32164fec3c"}, {"record": "DAT2/MGBGM01.BZZ", "member": 18, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM01.BZZ", "member": 18, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM02.BZZ", "member": 18, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM02.BZZ", "member": 18, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM04.BZZ", "member": 6, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM04.BZZ", "member": 6, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM05.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM05.BZZ", "member": 5, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM06.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM06.BZZ", "member": 5, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM07.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM07.BZZ", "member": 5, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM08.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM08.BZZ", "member": 5, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM09.BZZ", "member": 11, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM09.BZZ", "member": 11, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM10.BZZ", "member": 10, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM10.BZZ", "member": 10, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM11.BZZ", "member": 10, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM11.BZZ", "member": 10, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM12.BZZ", "member": 15, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGM12.BZZ", "member": 15, "tim_offset": 120832, "tim_sha256": "00ea8196bc9b7cfc6ac7ce96d073276d9a9efb11c76c7fdf3dda8c8822e1dfd0", "member_stored_sha256": "2277b52d601ca50254a34400b7c607c3bfba8f638d90ef59c3c44d723416e244"}, {"record": "DAT2/MGBGT00.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3f0b98c1a67ca3d2fb338c79ce820de22e744de940536b6673313567e985a640"}, {"record": "DAT2/MGBGT00.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "a0e6d70c9d93297e8d99e53ef529359cc8289e9e6c460416f6e4cce19af3ca5f"}, {"record": "DAT2/MGBGT00.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "e06a0a1b1b5d132bff5504819470c68461c071d77a9edc273cde1c105ea2e807"}, {"record": "DAT2/MGBGT00.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "70df05dfbd1c38f6a4a8d381a15a09519b11b311eeacae91ebd0a117e62b743e"}, {"record": "DAT2/MGBGT00.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "6071d295aad40e9aa788349837ce5514eb19901a90127a8d5224b9154587c4de"}, {"record": "DAT2/MGBGT01.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d92bdf04ace4d2767153f57736b54117df7afe382808429c1169f0367145d786"}, {"record": "DAT2/MGBGT01.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "a11f71706436570b409c64f2a4ba48bf2f6458682eafd3047c7f69ae4870e2e8"}, {"record": "DAT2/MGBGT01.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "7f015a90260f4ea1eb393526e2f29383e96597513e6c82054f43c2ca3ff45dee"}, {"record": "DAT2/MGBGT01.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "22c983ca54db2fc92a2071adfb6f8c15ea3cf3cd3c74f809427e24f498e76e6a"}, {"record": "DAT2/MGBGT01.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "406d50923580ade74f23b32e3f680a919b6fd5efb3f78116c359923aa7ddbf94"}, {"record": "DAT2/MGBGT02.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "a2fbbe76c0bcd6238c1dd3ee497e23a86243d464213ab4d7f6eed584b031179b"}, {"record": "DAT2/MGBGT02.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ef6f637297e76c5d2601dd80827ad81cdf867cb5c47a390c72a8815514e715b2"}, {"record": "DAT2/MGBGT02.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "53a1b4368cd773168258598f39c7dc46465d7a9beec401a41f7444c380c35237"}, {"record": "DAT2/MGBGT02.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "bf27c7cff8a6047f14c349670a7fbb281d6c9932762286c18e8eb8bcb03f57fd"}, {"record": "DAT2/MGBGT02.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "00ec87195f278629854522101aff9cd3133498973a877bc01450182a6da7b0e7"}, {"record": "DAT2/MGBGT02.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "493d32b9b17811f2755e5648b8b3b53a5e58446b13c3933a70370c7229266944"}, {"record": "DAT2/MGBGT03.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "16b2efce064b18513e7a6a336a368540e0876111036c996b90117df594bf55fe"}, {"record": "DAT2/MGBGT03.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ec00f0a00587d96b0383b85c5e52fc6c72eb7823b6f91c7f873e62940aae1bb0"}, {"record": "DAT2/MGBGT03.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d7a60e700585d726a610e41ee358d85a7fe7d0f227e306f1db00eb1fd0e68daf"}, {"record": "DAT2/MGBGT03.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "73b72b090378be8d0f69ad0aecbbba85223a47391c59bd0da232c4e5099e4f79"}, {"record": "DAT2/MGBGT03.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "cbaace4e7da36c39ca74da50591e9d562385a838d1dcf6a493eab26bcc1f939c"}, {"record": "DAT2/MGBGT04.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "20807ed62fc322bb4a84d50a578bb050cb8903d99aca969a2e04ded7cc375ec9"}, {"record": "DAT2/MGBGT04.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "30d19479929b282725afe117b8d328ea4c4632f391693adbce1fff07cd52e44f"}, {"record": "DAT2/MGBGT04.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "061a91a393d4b415be2da400be135d3a4ac829d56412c7f3a26c8f4380e885e3"}, {"record": "DAT2/MGBGT04.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "42b8adcb88e4edd8255fec78397917fbc69620dcb77e66f3808d162361784d46"}, {"record": "DAT2/MGBGT04.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "5f2987752af0b308c0ce8d8c9b9251a3b5bf691f9eaeba9ddae6aee942aca438"}, {"record": "DAT2/MGBGT04.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "91204f8e163342cdfeedc374c6e22e61a02d4f436c8246c9f1431ce1baa525fb"}, {"record": "DAT2/MGBGT05.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b813f4825650c14f4f265067d92e8a51e7ace5b203c3b04a57e54079766bd378"}, {"record": "DAT2/MGBGT05.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "160efd6df6e05587d9fabeccf2114f5cbc5f401e66806be91a8f4bae0edd29ac"}, {"record": "DAT2/MGBGT05.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "0323ff9cbab0fbf235648eeb4f021ba976a873ac8953159d19e4d6e9d03b5c6c"}, {"record": "DAT2/MGBGT05.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "9ad1c8c50ec8ddd32c219c85bcd2467effc167c9af41cc1f4208dacc8c754d25"}, {"record": "DAT2/MGBGT05.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "446986f2af181252f4f8270ff79bac79b83324bb5305e33a9ad23bc7d92f018e"}, {"record": "DAT2/MGBGT06.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d60579108c003f875b69df271f4b3ac40daa1f8294e01a8837a2df0b7d3c9ad7"}, {"record": "DAT2/MGBGT06.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "fb95ed5e11b1b98bc7d23725a6e7dbda1afddfbbebacbe5f16d368fe1bce783c"}, {"record": "DAT2/MGBGT06.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "4c59d336103da6ee8fd7a5265e98d3743c9bc7fddbf754b246130a1fae0ae19c"}, {"record": "DAT2/MGBGT06.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "293d1d80b69e0bf733060979e688c404dffb1406c684074f45b2e1c937bb4dfe"}, {"record": "DAT2/MGBGT06.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3f396c775c8c0303d421c6510915bccce54db8a0b3dd55aca2655b00f366401a"}, {"record": "DAT2/MGBGT07.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "8253b5eb4b13b5f2acd22fa3472e7227d0dda14f8ba3fcec5824fbf5dba265b2"}, {"record": "DAT2/MGBGT07.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "de01302d588e651ecc9533c42f11497fd115025b3bb24408fe1b2eecfda0f710"}, {"record": "DAT2/MGBGT07.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "45901442563905a8b3b5a6f80b00579c4ebe43730ce4c537564ec4d4901473b0"}, {"record": "DAT2/MGBGT07.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "c65254b899a9265ce2e92cccc47d802475b6242871b0358cbfaf529155abe35a"}, {"record": "DAT2/MGBGT07.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "304afb06766a28c4f7821f6d890c2a9c1098f79a497fcaff9c6e9abab1427a89"}, {"record": "DAT2/MGBGT08.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "a44c3c48a193c4ad4abb122fffb6aeb0ad3e4450a95c5053bdff151e6437156f"}, {"record": "DAT2/MGBGT08.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3c69967dfe31114f7e638aebd9ead2cade35466f56a330a84aa93d9de7de51e4"}, {"record": "DAT2/MGBGT08.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b21f1ae98d40880d5dfa3a83a49477cb2febb7a3e4e453726e8d129e56ff19fd"}, {"record": "DAT2/MGBGT08.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "f95cd0cfa64e20898379758b127912c1f6caf254ecbb617b60e1f9278e2070fc"}, {"record": "DAT2/MGBGT08.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "63fe52f354e9e9f2caf0252bae958357438d64f94e84eec93a16e0235c7f0086"}, {"record": "DAT2/MGBGT09.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ba2003f595f987ce24f263dae343f009bf705b1b3833e217c6316e161f55b0ee"}, {"record": "DAT2/MGBGT09.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b4abfe0a11f72e6cdf335657fde1fb407ec30016ebf06b4c4a4d3f1e1120076b"}, {"record": "DAT2/MGBGT09.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "793dcb81e3ee6478b5620a2b7ece4a1854136cf038756452a27b6eb21ed2a126"}, {"record": "DAT2/MGBGT09.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "ba68e3b64ff94a2c610d19630ad6f900673e521b43436f19e96571670caee744"}, {"record": "DAT2/MGBGT09.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "877da98ee3aadc027f3e24e8b20aa0d2e0641b207320e4d70d0abf8d27675434"}, {"record": "DAT2/MGBGT0A.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "d11dc44971b4763cbaa1d842f59996790d9347a14fb4a1960778b5d0f007d17b"}, {"record": "DAT2/MGBGT0A.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "553f8258f6d97f45f5e46d3dae36c4e1a06598af0990e6660b9139a0a8f8b1fb"}, {"record": "DAT2/MGBGT0A.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "62ee8f02f7bfa4dc68cd0b7f72d5b340e9070a70d54b5e01f66cac5b0aeec3ce"}, {"record": "DAT2/MGBGT0A.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "8524a18a8ac1c31b6097c71cb61d52a1ab9f9379969332815c0ee6fe1393d1fa"}, {"record": "DAT2/MGBGT0A.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "bfaf20cbf3910883dbaaef4f52f77305d02589ee902aa34a319b4338e1e73a46"}, {"record": "DAT2/MGBGT0A.BZZ", "member": 5, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "73bbc269d526f160e2aec340415bbc6dc94f7b7b4e45582434289a61684da889"}, {"record": "DAT2/MGBGT0B.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "2c5953aa7aa6fbe425b2e86c661b519c3ad671e4bdb78bdd04a1779dc858b4bb"}, {"record": "DAT2/MGBGT0B.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3552f969874848de4615235af3e0a7fc86d4c81fc0829535a1101c8822a3ae5f"}, {"record": "DAT2/MGBGT0B.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "747bdfcdcffe049c0c0e471f508fa785439ceb9b32ab7e21efce9ebcfc9a4969"}, {"record": "DAT2/MGBGT0B.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "a82fbb8f5b8c48a8ae7654d41cee9f6e2e09d317c30e7f049963a5ff79377cb8"}, {"record": "DAT2/MGBGT0B.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "cd2fca2975a77b661fbbf8a649ea433ba23bab2e1101e493cae5c177d5d5bd25"}, {"record": "DAT2/MGBGT0C.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "212483dbfb9e0deb6887593d6c47168fa0130799864e49cf08e6f3770cc11bc3"}, {"record": "DAT2/MGBGT0C.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "87f02168c8e140925a27cf4e796a1635026b820d8241e49299b7da17825ac7ab"}, {"record": "DAT2/MGBGT0C.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b0c8e2970dc11a372db1a51a20a3e28904af8012c13e9c74a462d2e80e284669"}, {"record": "DAT2/MGBGT0C.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "bd742f299e74479165523bc818a485d897c1493ceb2cf5124d0a99c1c6c369e6"}, {"record": "DAT2/MGBGT0C.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "50d48b4eac597e1add86a578c4d4867edeb578efa72048dfda2a8d750d85638e"}, {"record": "DAT2/MGBGT0D.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "9f8eaf7560b28287bd99aac40cdb8184ebdc8ffe112de644cb055eb82e7e0c12"}, {"record": "DAT2/MGBGT0D.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "98f097497fa3adf466c9fdf5503303f5a528afa3fe22882a0a7ec629778e173f"}, {"record": "DAT2/MGBGT0D.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "73d980d5c19bfe28df659602afb6302bbdfaae1840968c42d6089590cb97d054"}, {"record": "DAT2/MGBGT0D.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "80337c5f8789b3bcbf0a75e45bf37b79789535f2227ce70418786e316c761751"}, {"record": "DAT2/MGBGT0D.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "6628ea09ffabc3686ca9769bf92661d2e1cca5ecdb2112dd0e50bb28fcccc13d"}, {"record": "DAT2/MGBGT0F.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "80e03c4cbf69eace218480c19ffacb4ed9d664998881341aca8c0764c5b106b0"}, {"record": "DAT2/MGBGT0F.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "97f17af2f624199655224c7837d33d5dbfc700ca4bfec95f311d396d64f37236"}, {"record": "DAT2/MGBGT0F.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "eda754e742e1158a72e1bbcd951a2ac893c5cd45bd53630ae1deca53cd046583"}, {"record": "DAT2/MGBGT0F.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3fce8f60b012d3e2b006e3f6526307229d992a167bda5cf0211e54a09ebc25ed"}, {"record": "DAT2/MGBGT0F.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "842dae16e2d98309d2ef483c082333f9c53bd00e155bcd855fb5964d9c89fd70"}, {"record": "DAT2/MGBGT10.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b394a731975f300fcd6ab34ff21b097950bb4feb922a3039443afebdc5a04d4f"}, {"record": "DAT2/MGBGT10.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "f1e4f0018f367312bc123ba26a44024a078d5ad9af5557000522c493eed3e877"}, {"record": "DAT2/MGBGT10.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "0a2597f587fdc54aa00c9c7f097033a22c46ec7bc6014b6a090e3bfe01384f32"}, {"record": "DAT2/MGBGT10.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "398c04d7ae1568f2e50247ff23ac14bc5e145f345bce021e8a51685d7bdcdabd"}, {"record": "DAT2/MGBGT10.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "271d33ef5a7a3d9ad3d8fd99b5e70ebe30ec8dd965eda26a4c42f7a3dae35daf"}, {"record": "DAT2/MGBGT11.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "e4ec6e4165700df3eae5b82ff36b9f88f400a6751c70ed5f96ca8f411429f3e6"}, {"record": "DAT2/MGBGT11.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "eab2e2cb8fa69002c6bf155b15cc60bc5682d5809a1ef68c8bedc9ef111be321"}, {"record": "DAT2/MGBGT11.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "28be00a7021b7a5bec5255e2ab78acae9c602a1771f3f0d7574188b0c2b45ecc"}, {"record": "DAT2/MGBGT11.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3bec3460ef144dd422b7ddfbefcfe14265b3f17ea46f3e1cc0cbd3b0c3e1a396"}, {"record": "DAT2/MGBGT12.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "843d1a1a4af559b72f933877907096bb072255a874f1dde46df63ead04f984f4"}, {"record": "DAT2/MGBGT12.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "010203611a78085b43385e245f77f7a8b59f374a0c839ebbf8d9266318d28e43"}, {"record": "DAT2/MGBGT12.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3fd4372407be5b046eb655f9bc20b8a4c6566c08a4bd7a6994efecc1770a60da"}, {"record": "DAT2/MGBGT12.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "c38ccb1481e06a2aaebca933bed6e14e1eb4683dd003f0c94e8e7a8e3068e992"}, {"record": "DAT2/MGBGT13.BZZ", "member": 0, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "9cc3bab8bb08db1405d01ce4750ce45285fcdc8ac635b9995fe87c49280fd77e"}, {"record": "DAT2/MGBGT13.BZZ", "member": 1, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "b93bbc81904293691fb11fe438b50038aa57a6d1a67f98738a6789e6b53b4b0d"}, {"record": "DAT2/MGBGT13.BZZ", "member": 2, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "9fde1572c0a176e56c21016747602ff3fbd857a7231fcb47ae49109bc7f25b2f"}, {"record": "DAT2/MGBGT13.BZZ", "member": 3, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "3264ee6c9e054777448213c01da785571bbfe45d97573b1518c823ce69b509d1"}, {"record": "DAT2/MGBGT13.BZZ", "member": 4, "tim_offset": 0, "tim_sha256": "3d901be6c1bdf486681330f988ef90d2388f86b41dad64e37da7bbfce6dfe2e0", "member_stored_sha256": "db427041dbe30d207975e2e650ba824a51d153241cc41776d0456c811340c80f"}], "classification": [{"candidate_index": 1, "tim_sha256": "5603ea58af19a72ef69d4c37377bcfd4769c462418d43cb69a452ed1bf934b84", "date_english": "MARCH 24", "title_english": "CLOSING CEREMONY", "title_translation_verified": true, "references": 1}, {"candidate_index": 2, "tim_sha256": "0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29", "date_english": "APRIL 8", "title_english": "ENTRANCE CEREMONY", "title_translation_verified": true, "references": 5}, {"candidate_index": 3, "tim_sha256": "bd3135f549895e54cda5925b2637c2562ce5ceb7754abb146aba488a4859bcbf", "date_english": "APRIL 16", "title_english": "FIELD TRIP", "title_translation_verified": true, "references": 5}, {"candidate_index": 4, "tim_sha256": "eee4a0673d869e94261310cc4129ef92baf150abbb84aed936f70aca4387abdc", "date_english": "JUNE 12", "title_english": "TAIYO VS PACIFIC", "title_translation_verified": true, "references": 5}, {"candidate_index": 5, "tim_sha256": "57ba907e1e07a2d5ef733400124f78c2fbe0aa416924d9adb272acd4db2d223d", "date_english": "AUGUST 13-14", "title_english": "SEASIDE TRAINING", "title_translation_verified": true, "references": 5}, {"candidate_index": 6, "tim_sha256": "2877eb4038ebbad7e7b4eaaf316fd1a115119c2d72877a988cdee2e96e064407", "date_english": "SEPTEMBER 25", "title_english": "SCHOOL FESTIVAL", "title_translation_verified": true, "references": 5}, {"candidate_index": 7, "tim_sha256": "48f4a5096174db627701cb74483004aa80043969c38a85bdea5b1fa1656315d5", "date_english": "NOVEMBER 27", "title_english": "SPORTS FESTIVAL", "title_translation_verified": true, "references": 5}, {"candidate_index": 8, "tim_sha256": "25324e38c5ca15439a87a648cb17c1713370ed5c13a6bc0f7efee87ff47731ee", "date_english": "JANUARY 1", "title_english": "NEW YEAR SHRINE VISIT", "title_translation_verified": true, "references": 2}, {"candidate_index": 9, "tim_sha256": "2b746290dd8f44e202f83deb38e89c5213f8de4abe156e55016fcd6b1d1e4d41", "date_english": "FEBRUARY 14", "title_english": "VALENTINE'S DAY", "title_translation_verified": true, "references": 2}, {"candidate_index": 10, "tim_sha256": "7d13612e23d39288997b3b7b10c97e6907b2aa37bfe86d4c8a0aa1303cfbbd1f", "date_english": "MARCH 14", "title_english": "WHITE DAY", "title_translation_verified": true, "references": 2}, {"candidate_index": 11, "tim_sha256": "5b04a0f2c805fc0b196ea4192ffd97c087b8b5ddb081a3ce2165433d189e3932", "date_english": "", "title_english": "YEAR-END EXAMS", "title_translation_verified": true, "references": 1}, {"candidate_index": 12, "tim_sha256": "c5cedd79fa6eb0f4dfa70bdeb10c924c7edf0ed634b524ddd387242c1a0d9f90", "date_english": "", "title_english": "PROMOTION EXAM", "title_translation_verified": true, "references": 1}, {"candidate_index": 14, "tim_sha256": "7d70c98184f842b51fe7700b75510d7ac2a0803e7b6fafb7d0bfa3c784f85de6", "date_english": "", "title_english": "TERM 1 MIDTERMS", "title_translation_verified": true, "references": 1}, {"candidate_index": 15, "tim_sha256": "8c91b78d29bf8daa1264624187bea98ad9b9c35c4eba97edbd6fc96381d4a2dd", "date_english": "", "title_english": "TERM 1 FINALS", "title_translation_verified": true, "references": 1}, {"candidate_index": 16, "tim_sha256": "1123074b2bd674dfb1e57f3110504fb3587062491de804f64045696f9fb8143d", "date_english": "JULY 31", "title_english": "POOL", "title_translation_verified": true, "references": 2}, {"candidate_index": 17, "tim_sha256": "ecc7a7625c02ae9112d5e9a56affeef54e568e4dd44039ccb4c5fcd679a9e41f", "date_english": "AUGUST 28", "title_english": "SUMMER FESTIVAL", "title_translation_verified": true, "references": 2}, {"candidate_index": 18, "tim_sha256": "9b734643a162cee5149a27b4038bdf7454c144faf39e3171fa3db82fd0de6f12", "date_english": "", "title_english": "TERM 2 MIDTERMS", "title_translation_verified": true, "references": 1}, {"candidate_index": 19, "tim_sha256": "c015047ebd2ac5e82e33e761e6557c09d48dccb695e4954ea09bb8f4f65eea0d", "date_english": "", "title_english": "TERM 2 FINALS", "title_translation_verified": true, "references": 1}, {"candidate_index": 20, "tim_sha256": "4131308a6faf48394cd8b7e114dcd8c63a556ba4239c357726e01ba0a1cc447f", "date_english": "DECEMBER 24", "title_english": "CHRISTMAS", "title_translation_verified": true, "references": 1}], "excluded_non_title_candidates": [0, 13, 21], "classified_title_count": 19, "unresolved_event_name_candidate": 4}"###;

 fn patch_dates(input:&[u8],font:&fontdue::Font,taiyo:bool)->Result<(Vec<u8>,Value)>{
 let before=decompress(input,true)?;let at=atlas::parse_dialogue_atlas(&before)?;let mut bs=pointer_banks(&before)?;let mut after=before.clone();let slash=if taiyo{900}else{let mut first=at.fixed_cell_count;for i in 0..at.addressable_slot_count{if before[at.pixel_data_offset+i*200..at.pixel_data_offset+(i+1)*200].iter().any(|b|*b!=0){first=first.max(i+1);}}for(_,ms)in &bs{for m in ms{for t in tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens{if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){first=first.max(t.code as usize+1);}}}}ensure!(first<at.addressable_slot_count,"slash glyph capacity");let(w,h,pts)=ink(font,"/",14.0)?;let mut pix=vec![0u8;400];let dx=(20-w)/2;let dy=(20-h)/2;for &(x,y)in &pts{for yy in (y+dy).saturating_sub(1)..=(y+dy+1).min(19){for xx in (x+dx).saturating_sub(1)..=(x+dx+1).min(19){pix[yy*20+xx]=4;}}}for(x,y)in pts{pix[(y+dy)*20+x+dx]=14;}let p=at.pixel_data_offset+first*200;for(i,pair)in pix.chunks_exact(2).enumerate(){after[p+i]=pair[0]|pair[1]<<4;}first as u16};let mut count=0;
 for(sel,ms)in &mut bs{for(i,m)in ms.iter_mut().enumerate(){let old=m.clone();let w=words(&old);let mut new=Vec::new();let mut j=0;let mut changed=false;while j<w.len(){if j+3<w.len()&&w[j]==0x200a&&w[j+2]==0x200b{new.extend([0x200a,slash,0x200b]);j+=if w[j+3]<0x1000{4}else{3};changed=true;}else{let c=w[j];new.push(c);j+=1;if c==0x3001{break;}if c==0x3002||c==0x3003||(0x2003..=0x2009).contains(&c){new.push(w[j]);j+=1;}}}if changed{*m=bytes(new);count+=1;}if taiyo&&[3,4].contains(sel)&&i==34{let codes=" !'(),-./?ABCDEFGHIJKLMNOPQRSTUVWYZ".chars().enumerate().map(|(i,c)|(c,892+i as u16)).collect::<BTreeMap<_,_>>();*m=encode_target("{0}{1}/{2}{3}\nTODAY IS THE SPRING\nFIELD TRIP.",&old,&codes,&at)?;}}
 }ensure!(count==62,"date template population changed: {count}");for(_,ms)in &bs{for m in ms{tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?;}}let(used,aliases)=compact(&mut after,&bs)?;let profile=crate::paged_compression::source_paged_compression_profile(input)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,input.len())?;let length=stored.len();stored.resize(input.len(),0);ensure!(decompress(&stored,true)?==after,"date compression readback");Ok((stored,json!({"date_messages":count,"slash_glyph":slash,"compressed_bytes":length,"fixed_slot":input.len(),"arena_used":used,"aliases":aliases})))
 }
 fn patch_title_tim(source:&[u8],date:&str,title:&str,font:&fontdue::Font)->Result<Vec<u8>>{
 let mut target=source.to_vec();let pal=read_8bpp_palette_words_in_prefix(source,0,0)?;let mut p=vec![0u8;512*110];for y in 0..110{for x in 0..512{p[y*512+x]=source[544+(y+(x/256)*110)*256+x%256];}}
 let regions=if date.is_empty(){vec![(Cell{x:35,y:30,width:442,height:60},title)]}else{vec![(Cell{x:100,y:12,width:320,height:36},date),(Cell{x:45,y:50,width:422,height:53},title)]};
 for(c,text)in regions{let mut counts=[0usize;256];for y in c.y..c.y+c.height{for x in 0..512{if x<c.x||x>=c.x+c.width{counts[p[y*512+x]as usize]+=1;}}}let bg=(0..256).max_by_key(|i|counts[*i]).unwrap()as u8;for y in c.y..c.y+c.height{for x in c.x..c.x+c.width{p[y*512+x]=bg;}}
 let mut rendered=false;for size in [26.0,24.0,22.0,20.0,18.0,16.0]{let(w,h,pts)=ink(font,text,size)?;if w+2>c.width||h+2>c.height{continue;}let dx=c.x+(c.width-w)/2;let dy=c.y+(c.height-h)/2;let outline=nearest(&pal,[255,255,255]);for &(x,y)in &pts{for yy in y+dy-1..=y+dy+1{for xx in x+dx-1..=x+dx+1{p[yy*512+xx]=outline;}}}for(x,y)in pts{let rgb=match x*4/w.max(1){0=>[230,80,255],1=>[40,170,255],2=>[80,255,70],_=>[255,200,40]};p[(y+dy)*512+x+dx]=nearest(&pal,rgb);}rendered=true;break;}ensure!(rendered,"title text does not fit");}
 let mut native=vec![0u8;256*220];for y in 0..110{for x in 0..512{native[(y+(x/256)*110)*256+x%256]=p[y*512+x];}}crate::tim::write_8bpp_indexed_cell_in_prefix(&mut target,0,Cell{x:0,y:0,width:256,height:220},&native)?;ensure!(target[..544]==source[..544],"title palette changed");Ok(target)
 }
 fn run()->Result<()>{
 let master=PathBuf::from(std::env::var("JG2_V24_MASTER")?);let source=PathBuf::from(std::env::var("JG2_V24_SOURCE")?);let out=PathBuf::from(std::env::var("JG2_V24_OUTPUT")?);ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"disc identity");ensure!(!out.exists(),"output exists");fs::create_dir_all(&out)?;let fontbytes=fs::read(std::env::var("JG2_V24_FONT")?)?;let font=fontdue::Font::from_bytes(fontbytes.clone(),fontdue::FontSettings::default()).unwrap();let mut data=BTreeMap::<String,Vec<u8>>::new();let mut reports=Vec::new();
 for month in ["04","06","08","09","11"]{let bundlepath=format!("DAT2/MGG{month}.BZZ");let mut bundle=rebuild::read_record(&master,&bundlepath)?.1;let slots=crate::tzz::parse_tzz(&bundle)?;ensure!(slots.len()==5,"school bundle population");for(school,slot)in ["T","O","P","G","J"].into_iter().zip(slots){let path=format!("DAT2/MGG{month}{school}.BIZ");eprintln!("Patching dates: {path}");let original=rebuild::read_record(&master,&path)?.1;ensure!(bundle[slot.compressed_range()]==original,"school bundle binding {path}");let taiyo=month=="04"&&school=="T";let input=if taiyo{patch_text(&original,&font)?.0}else{original};let(patched,report)=patch_dates(&input,&font,taiyo)?;bundle[slot.compressed_range()].copy_from_slice(&patched);data.insert(path.clone(),patched);reports.push(json!({"path":path,"dates":report}));}data.insert(bundlepath,bundle);}
 let inv:Value=serde_json::from_str(TITLES)?;let classes=inv["classification"].as_array().unwrap();let mut grouped=BTreeMap::<String,Vec<&Value>>::new();for e in inv["references"].as_array().unwrap(){if classes.iter().any(|c|c["tim_sha256"]==e["tim_sha256"]){grouped.entry(e["record"].as_str().unwrap().into()).or_default().push(e);}}
 let mut title_count=0;for(path,refs)in grouped{let current=rebuild::read_record(&master,&path)?.1;let original=rebuild::read_record(&source,&path)?.1;let slots=crate::tzz::parse_tzz(&current)?;ensure!(slots==crate::tzz::parse_tzz(&original)?,"graphics table");let mut archive=current.clone();let mut groups=BTreeMap::<usize,Vec<&Value>>::new();for e in refs{groups.entry(e["member"].as_u64().unwrap()as usize).or_default().push(e);}for(member,refs)in groups{let slot=slots[member];let stored=&current[slot.compressed_range()];let before=decompress(stored,true)?;let mut after=before.clone();for e in refs{let c=classes.iter().find(|c|c["tim_sha256"]==e["tim_sha256"]).unwrap();let off=e["tim_offset"].as_u64().unwrap()as usize;let tim=crate::embedded_tim::parse_embedded_tim_at(&before,off)?;let end=off+tim.total_size;if sha256_bytes(&before[off..end])!=e["tim_sha256"].as_str().unwrap(){ensure!(c["candidate_index"]==2,"unexpected premodified title");continue;}let target=patch_title_tim(&before[off..end],c["date_english"].as_str().unwrap(),c["title_english"].as_str().context("title translation missing")?,&font)?;after[off..end].copy_from_slice(&target);title_count+=1;}if after==before{continue;}let profile=crate::paged_compression::source_paged_compression_profile(stored)?;let prefix=before.iter().zip(&after).take_while(|(a,b)|a==b).count()&!1;let(encoded,_)=crate::paged_compression::compress_on_source_final_page_with_preserved_prefix(&after,stored,profile,prefix)?;ensure!(encoded.len()<=slot.compressed_size,"title slot overflow {path} member {member}");let mut padded=encoded;padded.resize(slot.compressed_size,0);ensure!(decompress(&padded,true)?==after,"title readback");archive[slot.compressed_range()].copy_from_slice(&padded);}data.insert(path,archive);}
 let bin=out.join("justice-gakuen2-field-trip-dates-v24.bin");let repl=data.iter().map(|(p,d)|rebuild::FixedRecordReplacement{path:p,data:d}).collect::<Vec<_>>();let replaced=rebuild::copy_and_replace_records(&master,&bin,&repl)?;for r in &repl{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback");}let allowed=replaced.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(&master,&bin)?;ensure!(changed.iter().all(|l|allowed.contains(l)),"sector scope");let mut track=crate::disc::RawTrack::open(&bin)?;for l in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*l)?),"sector checksum");}let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-field-trip-dates-v24.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;fs::write(out.join("field-trip-dates-v24-report.json"),serde_json::to_vec_pretty(&json!({"font_sha256":sha256_bytes(&fontbytes),"output_sha256":hash,"cue":cue,"changed_sector_count":changed.len(),"story_messages":430,"date_messages":1550,"title_copies_patched":title_count,"records":reports}))?)?;Ok(())
 }
 #[test] fn english_project_field_trip_dates_v24()->Result<()>{std::thread::Builder::new().stack_size(64*1024*1024).spawn(run)?.join().unwrap()}
}

'@
$SavedEnvironment = @{}
foreach ($Name in @("CARGO_HOME","CARGO_TARGET_DIR","RUSTUP_TOOLCHAIN","JG2_V24_MASTER","JG2_V24_SOURCE","JG2_V24_OUTPUT","JG2_V24_FONT")) {
    $SavedEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name,"Process")
}
[IO.Directory]::CreateDirectory($WorkRoot) | Out-Null
$BackupStream = [IO.File]::Open($Backup,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $BackupStream.Write($OriginalRust,0,$OriginalRust.Length) } finally { $BackupStream.Dispose() }
if ((Hash $Backup) -ne $OriginalRustHash) { throw "Source backup verification failed; source was not edited." }
Write-Host ("Exact source backup: " + $Backup)
$Utf8 = [Text.UTF8Encoding]::new($false)
$Append = $Utf8.GetBytes("`n" + $Rust + "`n")
$Injected = New-Object byte[] ($OriginalRust.Length + $Append.Length)
[Array]::Copy($OriginalRust,0,$Injected,0,$OriginalRust.Length)
[Array]::Copy($Append,0,$Injected,$OriginalRust.Length,$Append.Length)
try {
    if (-not $env:CARGO_HOME -and (Test-Path -LiteralPath (Join-Path $RecoveryRoot "cargo-cache") -PathType Container)) {
        $env:CARGO_HOME = Join-Path $RecoveryRoot "cargo-cache"
    }
    $env:CARGO_TARGET_DIR = $TargetPath
    $env:RUSTUP_TOOLCHAIN = "1.98.0"
    $env:JG2_V24_MASTER = $MasterBin
    $env:JG2_V24_SOURCE = $SourceBin
    $env:JG2_V24_OUTPUT = $BuildDir
    $env:JG2_V24_FONT = $FontPath
    [IO.File]::WriteAllBytes($RustPath,$Injected)
    Write-Host "Building the pool/club dialogue, daily menu, and location labels..." -ForegroundColor Cyan
    Push-Location $UpstreamRoot
    try {
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_field_trip_dates_v24 -- --nocapture 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $SavedPreference }
        if ($CargoExit -ne 0) { throw "v24 build failed with exit code $CargoExit. Keep $LogPath for diagnosis." }
    } finally { Pop-Location }
} finally {
    try {
        [IO.File]::WriteAllBytes($RustPath,$OriginalRust)
        if ((Hash $RustPath) -ne $OriginalRustHash) { throw "Source restoration failed. The exact backup is $Backup" }
    } finally {
        foreach ($Name in $SavedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process") }
    }
}
$ReportPath = Join-Path $BuildDir "field-trip-dates-v24-report.json"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-field-trip-dates-v24.bin"
$OutputCue = [IO.Path]::ChangeExtension($OutputBin,".cue")
$Preview = Join-Path $BuildDir "club-baseball-palette4-v24.png"
foreach ($Path in @($ReportPath,$OutputBin,$OutputCue)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Build did not produce required output: $Path" }
}
$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
if ($Report.story_messages -ne 430 -or $Report.date_messages -ne 1550) { throw "Final report scope verification failed." }
if ((Get-Item -LiteralPath $OutputBin).Length -ne $ExpectedDiscBytes -or (Hash $OutputBin) -ne $Report.output_sha256) { throw "Final output length/hash differs from the build report." }
if ((Hash $FontPath) -ne $OriginalFontHash -or $Report.font_sha256 -ne $OriginalFontHash) { throw "Font identity changed during the build." }
if ((Hash $MasterBin) -ne $ExpectedMasterHash -or (Hash $SourceBin) -ne $ExpectedSourceHash) { throw "An input image changed during the build." }
Write-Host ""
Write-Host "FIELD TRIP AND DATES ENGLISH v24 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host ("Changed raw sectors: " + $Report.changed_sector_count)
Write-Host "430 field-trip messages across both player variants; 1550 event-bank date formats."
Write-Host ("Event title copies patched: " + $Report.title_copies_patched)
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v23. Boot this new CUE fresh and test April 16, its opening date, and all field-trip choices."
Write-Host "Other schools' story dialogue and later story events remain untranslated."
