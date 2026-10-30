"""Regression checks for shared pointers, control arguments and deduplication."""
import struct
import unittest

from inspect_pool_club_v22 import banks
from inventory_disc_translation import tokens, ranges


class InventoryTests(unittest.TestCase):
    def test_argument_which_looks_like_terminator_is_retained(self):
        result, controls = tokens([0x2003, 0x3001, 0, 0x3001, 0], ["glyph-A"])
        self.assertEqual(result[0], ["control", 0x2003, [0x3001]])
        self.assertEqual(result[1], ["glyph", "glyph-A"])
        self.assertEqual(controls[-1], [0x3001, []])

    def test_aliases_remain_separate_coordinates(self):
        d = bytearray(0x51800)
        struct.pack_into("<I", d, 0x31000, 0x800d0000 + 0x31028)
        struct.pack_into("<4H", d, 0x31020, 0x2003, 0x3001, 0x3001, 0)
        struct.pack_into("<3I", d, 0x31028, 0x800d0000 + 0x31020, 0x800d0000 + 0x31020, 0xffffffff)
        rows = banks(d)
        self.assertEqual([(s, i) for s, i, _ in rows], [(0, 0), (0, 1)])
        self.assertEqual(rows[0][2], rows[1][2])
        self.assertEqual(rows[0][2], (0x2003, 0x3001, 0x3001, 0))

    def test_glyph_identity_is_cross_font_code_independent(self):
        a, _ = tokens([0, 1, 0x3001], ["A", "B"])
        b, _ = tokens([1, 0, 0x3001], ["B", "A"])
        self.assertEqual(a, b)

    def test_reject_bad_tokens_and_padding(self):
        for words in ([0], [0x2003], [0xffff, 0x3001], [0x3001, 7]):
            with self.assertRaises((AssertionError, ValueError)):
                tokens(words, ["A"])

    def test_ranges_preserve_sparse_membership(self):
        self.assertEqual(ranges([5, 1, 2, 5, 9]), [[1, 2], [5, 5], [9, 9]])


if __name__ == "__main__":
    unittest.main()
