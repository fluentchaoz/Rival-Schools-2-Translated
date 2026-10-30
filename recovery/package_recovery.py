"""Assemble a private recovery kit from tracked builders and supplied workspaces.

Never commit the resulting ZIP or the supplied source-bound translation JSON.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

REPO = Path(__file__).resolve().parents[1]
UPSTREAM = "98ca12ddf082d6e2367b2963f76edf5a09242deb"
SOURCE_HASH = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
STAGES = [
    ("run_batsu_playable_scene1_prototype_v7.ps1", "english-batsu-playable-scene1", "justice-gakuen2-batsu-english-scene1", "d9b1a57313e3714980f4c618aeffb975bb00286bdcdcab1a4a9a0fb24ab850f2", "workspace"),
    ("run_quick_translate_mode_select_v4.ps1", "english-batsu-playable-scene1", "justice-gakuen2-batsu-english-scene1-menus", "a8f2c7d4ebc025376a36ba84930dee75e6044632e04677ba1eff8cf6d70f0564", ""),
    ("run_translate_school_life_start_menu_v3.ps1", "english-batsu-playable-scene1", "justice-gakuen2-batsu-english-scene1-menus-title", "fb47236ead2e2052f22c92148613f3de942ed32818ff98236391e742aa85133a", ""),
    ("run_road_to_batsu_mgk04_opening_v5.ps1", "english-road-to-batsu-mgk04", "justice-gakuen2-road-to-batsu-mgk04", "09165121e7141830c8c3027ca2de8c08e82cd624627092d4efde2b8d5fcd453b", "workspace"),
    ("run_road_to_batsu_status_hud.ps1", "english-road-to-batsu-mgk04", "justice-gakuen2-road-to-batsu-hud", "167524792e2b3abbb497335637ed3efb75df3e035a173b8cbf0de450c5c22365", ""),
    ("run_road_to_batsu_welcome_reflow_v2.ps1", "english-road-to-batsu-polish", "justice-gakuen2-road-to-batsu-welcome-reflow", "75fce33f40e105d7e58026830d92ec1758230996f8a46dbe79b8ba76f166436d", "workspace"),
    ("run_road_to_batsu_blue_title.ps1", "english-road-to-batsu-blue-title", "justice-gakuen2-road-to-batsu-blue-title", "ad068a54820b62bd246538e49776291512b88cab6447127fdd93ee6d4392dec4", "workspace"),
    ("build_opening_school_gate_v4_fit.ps1", "english-road-to-batsu-opening-school-gate-fit", "justice-gakuen2-road-to-batsu-opening-school-gate-fit", "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1", "font"),
    ("build_dynamic_english_date_pretty_v2.ps1", "english-road-to-batsu-dynamic-date-pretty-v2", "justice-gakuen2-road-to-batsu-dynamic-date-pretty-v2", "6479176dc1788f64deb933d1a08569c87e677f5d1ba0f3e001567158dc80c91d", ""),
    ("build_mgk04_full_tutorial_v3.ps1", "english-mgk04-full-tutorial-v3", "justice-gakuen2-mgk04-full-tutorial-v3", "30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4", "workspace"),
    ("build_name_entry_ui_english_v5.ps1", "english-name-entry-ui-v5", "justice-gakuen2-name-entry-ui-v5", "2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977", ""),
    ("build_name_entry_default_az_v6.ps1", "english-name-entry-default-az-v6", "justice-gakuen2-name-entry-default-az-v6", "e3808a7bef6c6529e45b29963895a6e45a26dd7c30b031be928fcdb4fa98a09f", ""),
    ("build_name_entry_nickname_default_az_v7.ps1", "english-name-entry-nickname-default-az-v7", "justice-gakuen2-name-entry-nickname-default-az-v7", "c9eb6cc1c15eb3b65f1aa9e02cee102fbb1bc502483e88950175139720ca48f5", ""),
    ("build_name_entry_school_choices_english_v8.ps1", "english-name-entry-school-choices-v8", "justice-gakuen2-name-entry-school-choices-v8", "07b4dda156ab0eac7f149f66f7bcb9727a8e74fad4faa2d19d77cee362504d84", ""),
    ("build_mgk04_welcome_hybrid_palette_v9b.ps1", "english-mgk04-welcome-hybrid-v9b", "justice-gakuen2-mgk04-welcome-hybrid-v9b", "403fe83463e714d2621fd404d1556a31021ff2332c5bb9ea5b3d6a59af330371", ""),
    ("build_name_entry_sex_choices_english_v10.ps1", "english-name-entry-sex-choices-v10", "justice-gakuen2-name-entry-sex-choices-v10", "16667311e8d4561cc0d5600c59717539d4c07ccd569700c5d2ed6966a557d2d2", ""),
    ("build_name_entry_best_subject_english_v11.ps1", "english-name-entry-best-subject-v11", "justice-gakuen2-name-entry-best-subject-v11", "c282ecaf026a2c09aac8c63307853cd811f313a581904d4ac932828c86071ca0", ""),
    ("build_name_entry_favorite_words_english_v12.ps1", "english-name-entry-favorite-words-v12", "justice-gakuen2-name-entry-favorite-words-v12", "bcc411d59f5f6a45f6aa8e0c20869ef1d4c4e3f22705f17fc66630b45a7da74b", ""),
    ("build_enrollment_completion_sweep_v13.ps1", "english-enrollment-completion-sweep-v13", "justice-gakuen2-enrollment-completion-sweep-v13", "5010cd27250d4a78651f4e481cb8cb648806fbc3e174f83e219e0c48ecb959f2", ""),
    ("build_face_customization_sweep_v14.ps1", "english-face-customization-sweep-v14", "justice-gakuen2-face-customization-sweep-v14", "e88b4bdc6faf4aaebb35709efbe5324bb875a2272ec9a3d40b8285ac25041d67", ""),
    ("build_mgk10_quiz_english_v15b.ps1", "english-mgk10-quiz-v15b", "justice-gakuen2-mgk10-quiz-v15b", "4c43c6a02e15bd5d470a649ab17b9ff4905c0c8b63ad77e91ea57afcb38e42c5", ""),
    ("build_live_mgk04_quiz_english_v16.ps1", "english-live-mgk04-quiz-v16", "justice-gakuen2-live-mgk04-quiz-v16", "67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51", ""),
]


def read(name):
    return (REPO / name).read_text(encoding="utf-8-sig")


def extract(text, variable):
    matches = re.findall(r"(?m)^\s*\$" + variable + r" = @'\n(.*?)^'@", text, re.S)
    assert len(matches) == 1, (variable, len(matches))
    return matches[0].rstrip("\n")


def replace_once(text, old, new):
    assert text.count(old) == 1, (old[:100], text.count(old))
    return text.replace(old, new)


def source_preparation():
    bootstrap = read("run_batsu_workspace_bootstrap_v4.ps1")
    functions = bootstrap[bootstrap.index("function Fail"):bootstrap.index("$Here =")]
    phase = read("continue_phase1_fixed.ps1")
    exact = phase[phase.index("function Replace-Exact"):phase.index("$Here =")]
    profile = '''
Replace-Exact (Join-Path $Upstream "src/source_disc/profile.rs") "62dbc6ca47ec8d9dfbb5797f35d4e720d63e00b5a8e0edd080b149c3ff4f1823" "''' + SOURCE_HASH + '''"
Replace-Exact (Join-Path $Upstream "src/source_disc/profile.rs") "2130913aba89a8dd19555bad5e2b21d0f666a9e684fd7f35f2e703a2df4d5b62" "71d01319369b97258d962528aeaa274bce6d1b29d194aa530b6e3e0d589356b3"
Replace-Exact (Join-Path $Upstream "src/source_disc/profile.rs") "859515ec9f58a2326708dbbf46516e8601cb59d158c0da3f2e214311762a07d1" "fe36b68795859f907aed70eb13517e853f3fd779df43b7c992191c47c5341cf5"
Replace-Exact (Join-Path $Upstream "src/menu_audit/known_consumers/mgtit.rs") "859515ec9f58a2326708dbbf46516e8601cb59d158c0da3f2e214311762a07d1" "fe36b68795859f907aed70eb13517e853f3fd779df43b7c992191c47c5341cf5"
Replace-Exact (Join-Path $Upstream "src/ending_subtitles.rs") "62dbc6ca47ec8d9dfbb5797f35d4e720d63e00b5a8e0edd080b149c3ff4f1823" "''' + SOURCE_HASH + '''"
Replace-Exact (Join-Path $Upstream "src/dialogue_audit/codebook_tests.rs") "62dbc6ca47ec8d9dfbb5797f35d4e720d63e00b5a8e0edd080b149c3ff4f1823" "''' + SOURCE_HASH + '''"
'''
    patches = bootstrap[bootstrap.index("# Preserve/install"):bootstrap.index("# Prepare owned work paths.")]
    mode = extract(read("run_quick_translate_mode_select_v3.ps1"), "Probe")
    mode = mode.replace('(width - text_width) / 2', 'width.saturating_sub(text_width) / 2')
    mode = mode.replace('(height - text_height) / 2', 'height.saturating_sub(text_height) / 2')
    mode = mode.replace('("CREATE A STUDENT", 39usize, 2usize)', '("CREATE A STUDENT", 39usize, 1usize)')
    mode = mode.replace('MAKE FRIENDS & TRAIN', 'MAKE FRIENDS AND TRAIN')
    title = extract(read("run_translate_school_life_start_menu.ps1"), "Rust")
    pair = extract(read("run_translate_school_life_start_menu_v2.ps1"), "Replacement")
    title, count = re.subn(r'fn find_pair\(all: &\[Placement\]\) -> Result<\(Placement, Placement\)> \{.*?Ok\(pairs\.remove\(0\)\)\s*\}', lambda _: pair, title, flags=re.S)
    assert count == 1
    labels = extract(read("run_translate_school_life_start_menu_v3.ps1"), "Replacement")
    title, count = re.subn(r'let mut first_target = "NEW GAME"\.to_string\(\);.*?let continue_size = safe_owned_size\(\s*&source_overlay_decoded,\s*&all_offsets,\s*&cont,\s*&continue_target,\s*\)\?;', lambda _: labels, title, flags=re.S)
    assert count == 1
    # All scripts use CRLF here-strings; make source line endings consistent first.
    normalize = '''
Get-ChildItem (Join-Path $Upstream "src") -Filter *.rs -File -Recurse | ForEach-Object {
    $Text = [IO.File]::ReadAllText($_.FullName).Replace("`r`n", "`n").Replace("`n", "`r`n")
    Write-Utf8NoBom $_.FullName $Text
}
'''
    return ('param([Parameter(Mandatory=$true)][string]$Upstream)\n$ErrorActionPreference = "Stop"\n'
            + functions + exact + normalize + profile + patches
            + "$Menus = @'\n" + mode + "\n" + title + "\n'@\n"
            + '[IO.File]::AppendAllText((Join-Path $Upstream "src/source_disc.rs"), "`r`n" + $Menus, (New-Object Text.UTF8Encoding($false)))\n')


def ps_bytes(text):
    return b"\xef\xbb\xbf" + text.replace("\r\n", "\n").replace("\n", "\r\n").encode()


def assemble(inputs, folder):
    folder.mkdir(parents=True, exist_ok=False)
    files = {}
    changes = {}
    for name, *_ in STAGES:
        text = read(name)
        changed = []
        text = replace_once(text, '    & $Command @Arguments', '''    if ($Command -eq "cargo" -and $Arguments.Count -gt 1 -and $Arguments[0] -in @("build", "test")) {
        $Arguments = @($Arguments[0], "--locked") + $Arguments[1..($Arguments.Count - 1)]
    }
    & $Command @Arguments''')
        changed.append("Cargo builds and tests retain the pinned lockfile with --locked.")
        # Relocate only the isolated copies, without weakening identity checks.
        if name in {"build_mgk10_quiz_english_v15b.ps1", "build_live_mgk04_quiz_english_v16.ps1"}:
            text, count = re.subn(r'(?m)^\$SourceBin = "C:.*\.bin"$', '$SourceBin = $env:JUSTICE_RECOVERY_SOURCE_BIN', text)
            assert count == 1
            changed.append("Source BIN comes from the verified recovery environment.")
        if name == "build_mgk04_full_tutorial_v3.ps1":
            text, count = re.subn(r'(?m)^(    \[string\]\$RomFolder = )"C:.*",$', r'\1$env:JUSTICE_RECOVERY_ROM_FOLDER,', text)
            assert count == 1
            changed.append("Default ROM folder comes from the recovery environment, including v9b's nested invocation.")
        files[name] = ps_bytes(text)
        if changed:
            changes[name] = changed
    files["build_quiz_fixed_ui_english_v17h.ps1"] = ps_bytes(read("build_quiz_fixed_ui_english_v17h.ps1"))
    files["prepare_recovery_source.ps1"] = ps_bytes(source_preparation())
    files["rebuild_quiz_from_original.ps1"] = ps_bytes(read("recovery/rebuild_quiz_from_original.ps1"))
    files["RECOVERY_README.txt"] = read("recovery/RECOVERY_README.txt").encode()
    inputs_expected = {
        "english-batsu-workspace-bootstrap-v4.zip": "9f832e352868ee3de1d523f10a71a013a33e9295adf98c436fa86a05cb343630",
        "mgk10-bank6-english-v1.json": "224b31cb8eed91d5e9f9368d65f09d68c47aced96953e5f8224e3eb2386338c7",
        "mgk04-selector6-english-v1.json": "aeae238d3b6c7a768950c922ee964db70468ac11f5c00475f3f4d857dca046d0",
    }
    for name, expected in inputs_expected.items():
        content = (inputs / name).read_bytes()
        if expected:
            assert hashlib.sha256(content).hexdigest() == expected, name
        files[name] = content
    plan = dict(schema=1, upstream_commit=UPSTREAM, rust_toolchain="1.98.0", source_sha256=SOURCE_HASH,
                source_bytes=663216960, stages=[dict(script=n, output=f"work/{d}/build/{b}.bin", sha256=h, arguments=a) for n,d,b,h,a in STAGES],
                transformations=changes, files={n:hashlib.sha256(b).hexdigest() for n,b in files.items()})
    for name, content in files.items():
        (folder / name).write_bytes(content)
    (folder / "recovery-plan.json").write_text(json.dumps(plan,indent=2)+"\n")
    with zipfile.ZipFile(folder.with_suffix('.zip'), 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for path in sorted(folder.iterdir()):
            z.write(path, path.name)
    print(json.dumps(dict(folder=str(folder), zip=str(folder.with_suffix('.zip')), stages=len(STAGES), files=len(files)+1)))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", type=Path)
    ap.add_argument("output_folder", type=Path)
    a = ap.parse_args()
    assemble(a.inputs, a.output_folder)
