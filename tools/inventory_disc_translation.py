"""Read-only source inventory; public output contains counts/hashes, never game text.

Private decoded records and message-coordinate manifests are optional. Never publish
that directory. Glyph fingerprints are visual identity, not reviewed semantics.
"""
import argparse
import collections
import hashlib
import json
import re
import struct
from pathlib import Path

from inspect_pool_club_v22 import banks, decompress

SOURCE = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
EXPECTED_PATHS = "65f36ae2f0b3aed0d99bde1aa974f1d29fef0cf67e6bf0f7972f087a532b8968"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def ranges(values):
    result = []
    for v in sorted(set(values)):
        if result and result[-1][1] + 1 == v:
            result[-1][1] = v
        else:
            result.append([v, v])
    return result


class Disc:
    def __init__(self, path):
        with path.open("rb") as f:
            assert hashlib.file_digest(f, "sha256").hexdigest() == SOURCE, "source identity"
        self.f = path.open("rb")

    def read(self, lba, size):
        out = bytearray()
        for offset in range(0, size, 2048):
            self.f.seek((lba + offset // 2048) * 2352 + 24)
            part = self.f.read(min(2048, size - offset))
            assert len(part) == min(2048, size - offset), "truncated record"
            out.extend(part)
        return bytes(out)

    def index(self):
        def walk(lba, size, prefix=""):
            data = self.read(lba, size)
            i = 0
            while i < len(data):
                n = data[i]
                if not n:
                    i = (i // 2048 + 1) * 2048
                    continue
                row = data[i:i+n]
                assert len(row) == n and n >= 34
                i += n
                name = row[33:33+row[32]]
                if name in (b"\0", b"\1"):
                    continue
                path = prefix + name.decode("ascii").split(";")[0]
                extent, length = struct.unpack_from("<I", row, 2)[0], struct.unpack_from("<I", row, 10)[0]
                if row[25] & 2:
                    yield from walk(extent, length, path + "/")
                else:
                    yield {"path": path, "lba": extent, "size": length}
        root = self.read(16, 2048)[156:190]
        return sorted(walk(struct.unpack_from("<I", root, 2)[0], struct.unpack_from("<I", root, 10)[0]), key=lambda x: x["path"])


def tokens(words, glyphs):
    """Return exact glyph/control fingerprint tokens and preserve arguments."""
    result, controls = [], []
    j = 0
    while j < len(words):
        code = words[j]
        j += 1
        if code < len(glyphs):
            result.append(["glyph", glyphs[code]])
        else:
            args = []
            if code in (0x3002, 0x3003) or 0x2003 <= code <= 0x2009:
                assert j < len(words), "missing control argument"
                args = [words[j]]
                j += 1
            assert code in (0x61e, 0x3000, 0x3001, 0x3002, 0x3003) or 0x2000 <= code <= 0x200d, hex(code)
            result.append(["control", code, args])
            controls.append([code, args])
        if code == 0x3001:
            assert all(w == 0 for w in words[j:]), "trailing message data"
            return result, controls
    raise ValueError("unterminated message")


def run(source, output, private=None):
    disc = Disc(source)
    try:
        rows = disc.index()
        runtime = [r for r in rows if r["path"].startswith("DAT2/MG") and r["path"].endswith(".BIZ") and r["path"] != "DAT2/MGSTAFF1.BIZ"]
        assert len(runtime) == 78 and digest(("\n".join(r["path"] for r in runtime)+"\n").encode()) == EXPECTED_PATHS, "runtime population"
        all_groups = collections.defaultdict(list)
        raw_groups = set()
        records = []
        if private:
            private.mkdir(parents=True, exist_ok=True)
            (private / "index.json").write_text(json.dumps(rows, indent=2)+"\n")
        for r in runtime:
            data = disc.read(r["lba"], r["size"])
            decoded = decompress(data)
            assert len(decoded) == 0x51800, r["path"]
            glyphs = [digest(decoded[384+i*200:384+(i+1)*200]) for i in range((0x31000-384)//200)]
            selectors = collections.Counter()
            dates, local_groups, entries = [], set(), []
            for sel, entry, words in banks(decoded):
                fp_tokens, controls = tokens(words, glyphs)
                fp = digest(json.dumps(fp_tokens, separators=(",", ":")).encode())
                raw = digest(struct.pack("<"+"H"*len(words), *words))
                coord = f'{r["path"]}:{sel}:{entry}'
                all_groups[fp].append(coord)
                raw_groups.add(raw)
                local_groups.add(fp)
                selectors[sel] += 1
                row = {"selector": sel, "entry": entry, "fingerprint": fp, "payload_sha256": raw, "controls": controls}
                if any(c in (0x200a, 0x200b) for c, _ in controls):
                    dates.append({"selector": sel, "entry": entry, "month": any(c == 0x200a for c, _ in controls), "day": any(c == 0x200b for c, _ in controls)})
                entries.append(row)
            date_ranges = [{"selector": sel, "entry_ranges": ranges(e["entry"] for e in dates if e["selector"] == sel)} for sel in sorted({e["selector"] for e in dates})]
            rec = {**r, "stored_sha256": digest(data), "decoded_sha256": digest(decoded), "message_coordinates": sum(selectors.values()), "selectors": dict(sorted(selectors.items())), "visual_control_groups": len(local_groups), "dynamic_date_coordinate_count": len(dates), "dynamic_date_coordinate_ranges": date_ranges, "translation_status": "not measured against current English build"}
            records.append(rec)
            if private:
                (private / (Path(r["path"]).stem+".decoded")).write_bytes(decoded)
                (private / (Path(r["path"]).stem+".coordinates.json")).write_text(json.dumps(entries, indent=2)+"\n")
            print(r["path"], rec["message_coordinates"], flush=True)
        assert sum(r["message_coordinates"] for r in records) == 62639, "coordinate denominator"
        families = collections.Counter(re.sub(r"[0-9].*", "", Path(r["path"]).stem) for r in records)
        report = {"kind": "Source-bound whole-disc translation structural inventory", "source_sha256": SOURCE, "limitations": ["Structural source counts are not translation completion percentages.", "Visual/control fingerprints match exact source glyph pixels and controls; they are not reviewed semantic translation groups.", "Runtime coordinates include repeated, variant and possibly unreferenced entries; script reachability not measured here.", "Non-dialogue files are catalogued by path/size only; embedded text and graphics still need consumer and surface mapping.", "No current v25 disc was scanned; existing English coverage is not inferred from original data."], "iso_file_count": len(rows), "files": rows, "file_extensions": dict(collections.Counter(Path(r["path"]).suffix for r in rows)), "runtime_image_count": len(records), "runtime_family_counts": dict(families), "message_coordinate_count": sum(r["message_coordinates"] for r in records), "raw_unique_payloads": len(raw_groups), "exact_visual_control_groups": len(all_groups), "repeated_visual_control_coordinates": sum(len(v)-1 for v in all_groups.values()), "dynamic_date_coordinate_count": sum(r["dynamic_date_coordinate_count"] for r in records), "records": records}
        if private:
            (private / "visual-groups.json").write_text(json.dumps(all_groups, indent=2)+"\n")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2)+"\n")
        print(json.dumps({k: v for k, v in report.items() if k not in ("files", "records", "limitations")}, indent=2))
    finally:
        disc.f.close()


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("disc", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--private-output", type=Path)
    a = p.parse_args()
    run(a.disc, a.output, a.private_output)
