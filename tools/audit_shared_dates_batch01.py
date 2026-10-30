"""Validate English draft/source bindings. Optional private scan needs no codebook.

This checks source identity and coverage, not translation quality or live layout.
"""
import argparse
import json
from pathlib import Path


def audit(packet_path, private=None):
    packet = json.loads(packet_path.read_text())
    entries = packet["entries"]
    assert len(entries) == packet["source_pattern_count"] == 46
    assert len({e["id"] for e in entries}) == len(entries)
    assert len({e["fingerprint"] for e in entries}) == len(entries)
    assert sum(e["coordinate_count"] for e in entries) == packet["source_coordinate_count"] == 4836
    for e in entries:
        assert isinstance(e["english_prose_draft"], str)
        assert e["english_prose_draft"].isascii()
        assert e["date_template"] == "{MONTH}/{DAY}"
        assert e["fit_status"] == "pending" and e["build_status"] == "not built"
        assert [c for c, _ in e["protected_controls"]] == [0x3003, 0x200a, 0x200b, 0x3003]
    if private:
        groups = json.loads((private / "date-groups.json").read_text())
        assert set(groups) == {e["fingerprint"] for e in entries}
        assert len({path for coords in groups.values() for path, _, _ in coords}) == 78
        for e in entries:
            assert len(groups[e["fingerprint"]]) == e["coordinate_count"]
            r = e["representative"]
            coords = json.loads((private / (Path(r["path"]).stem + ".coordinates.json")).read_text())
            source = next(v for v in coords if v["selector"] == r["selector"] and v["entry"] == r["entry"])
            assert source["fingerprint"] == e["fingerprint"]
            assert [v for v in source["controls"] if v[0] not in (0x3000, 0x3001)] == e["protected_controls"]
        for selector in (3, 4):
            ordinary = next(e for e in entries if e["id"] == ("DATE-000" if selector == 3 else "DATE-024"))
            for index in range(3):
                assert ["DAT2/MGK04.BIZ", selector, index] in groups[ordinary["fingerprint"]]
    return {"patterns": len(entries), "original_coordinates": packet["source_coordinate_count"], "private_source_binding_passed": private is not None, "layout_or_build_pass_claimed": False}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("packet", type=Path)
    p.add_argument("--private-source", type=Path)
    a = p.parse_args()
    print(json.dumps(audit(a.packet, a.private_source), indent=2))
