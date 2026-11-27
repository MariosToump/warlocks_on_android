"""Tests for the sim sandbox analysis.  python -I tools/sim/test_analyze.py"""
import os, sys, unittest
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze


def rec(*wizards):
    return {"secs": 40.0, "timeout": False, "wizards": [
        {"name": n, "loadout": l, "won": w, "kills": 0, "died": not w, "lava_death": False, "mood": "", "casts": {}}
        for n, l, w in wizards]}


class T(unittest.TestCase):
    def test_wilson(self):
        p, lo, hi = analyze.wilson(25, 100)
        self.assertAlmostEqual(p, 0.25, 3)
        self.assertAlmostEqual(lo, 0.175, 2)
        self.assertAlmostEqual(hi, 0.343, 2)

    def test_wilson_empty(self):
        self.assertEqual(analyze.wilson(0, 0), (0.0, 0.0, 0.0))

    def test_synergy(self):
        rates = {"a+b": (50, 100), "a": (30, 100), "b": (30, 100), "none": (20, 100)}
        s, lo, hi = analyze.synergy(rates, "a", "b")
        self.assertAlmostEqual(s, 0.1, 6)
        self.assertLess(lo, s)
        self.assertGreater(hi, s)

    def test_rates(self):
        recs = [rec(("P", ["meteor", "well"], True), ("B", [], False)),
                rec(("P", ["well", "meteor"], False), ("B", ["swap"], True)),
                rec(("P", [], False), ("B", ["swap"], False))]
        r = analyze.rates(recs)
        self.assertEqual(r["meteor+well"], (1, 2))
        self.assertEqual(r["swap"], (1, 2))
        self.assertEqual(r["none"], (0, 2))


if __name__ == "__main__":
    unittest.main()
