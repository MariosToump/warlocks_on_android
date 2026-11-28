"""Sim sandbox analysis: loadout win rates (Wilson 95% CI) and pair synergy.

    python -I tools/sim/analyze.py tools/sim/out/<mode>

Reads every *.jsonl in the folder, writes report.md + synergy.svg + winrate.svg.
synergy(a, b) = p(a+b) - p(a) - p(b) + p(none): does the pair beat its two
spells apart? CI from the four rates' variances (normal approximation).
"""
import glob, json, math, os, sys
from itertools import combinations

Z = 1.96
NAMES = {"homing": "Homing Orb", "mirror": "Dark Mirror", "boomerang": "Boomerang", "swap": "Swap",
         "meteor": "Meteor", "well": "Gravity Well", "timestop": "Time Stop"}


def key(loadout):
    return "+".join(sorted(loadout)) if loadout else "none"


def label(k):
    return "No shop spell" if k == "none" else " + ".join(NAMES.get(x, x) for x in k.split("+"))


def wilson(wins, n):
    if n == 0:
        return (0.0, 0.0, 0.0)
    p = wins / n
    d = 1 + Z * Z / n
    c = (p + Z * Z / (2 * n)) / d
    h = Z * math.sqrt(p * (1 - p) / n + Z * Z / (4 * n * n)) / d
    return (p, c - h, c + h)


def rates(records):
    out = {}
    for r in records:
        for w in r["wizards"]:
            k = key(w["loadout"])
            wins, n = out.get(k, (0, 0))
            out[k] = (wins + (1 if w["won"] else 0), n + 1)
    return out


def _pv(rates_, k):
    wins, n = rates_.get(k, (0, 0))
    if n == 0:
        return 0.0, float("inf")
    p = wins / n
    return p, p * (1 - p) / n


def synergy(rates_, a, b):
    pab, vab = _pv(rates_, key([a, b]))
    pa, va = _pv(rates_, a)
    pb, vb = _pv(rates_, b)
    p0, v0 = _pv(rates_, "none")
    s = pab - pa - pb + p0
    h = Z * math.sqrt(vab + va + vb + v0)
    return (s, s - h, s + h)


# --- charts (static SVG; a <title> per bar is the hover tooltip) ------------------
INK, INK2, GRID, POS, NEG, MUTED = "#191919", "#666666", "#e5e5e5", "#257de0", "#ec4647", "#b5b5b5"


def bar_svg(rows, title, fmt, zero=0.0, ref=None):
    """rows: [(label, value, lo, hi, color)] -> horizontal bars from `zero` with CI whiskers."""
    lw, w, rh, top = 230, 420, 22, 44
    h = top + rh * len(rows) + 30
    lo = min([r[2] for r in rows] + [zero])
    hi = max([r[3] for r in rows] + [zero])
    pad = (hi - lo) * 0.05 or 0.05
    lo, hi = lo - pad, hi + pad
    x = lambda v: lw + (v - lo) / (hi - lo) * w
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{lw + w + 70}" height="{h}" font-family="sans-serif" font-size="12">',
         '<rect width="100%" height="100%" fill="#ffffff"/>',
         f'<text x="8" y="20" font-size="14" font-weight="bold" fill="{INK}">{title}</text>']
    step = 0.05 if hi - lo < 0.6 else 0.1
    t = math.ceil(lo / step) * step
    while t <= hi:
        s.append(f'<line x1="{x(t):.1f}" y1="{top - 6}" x2="{x(t):.1f}" y2="{h - 26}" stroke="{GRID}"/>')
        s.append(f'<text x="{x(t):.1f}" y="{h - 10}" fill="{INK2}" text-anchor="middle">{fmt(t)}</text>')
        t += step
    s.append(f'<line x1="{x(zero):.1f}" y1="{top - 6}" x2="{x(zero):.1f}" y2="{h - 26}" stroke="{INK2}" stroke-width="1.5"/>')
    if ref is not None:
        s.append(f'<line x1="{x(ref):.1f}" y1="{top - 6}" x2="{x(ref):.1f}" y2="{h - 26}" stroke="{INK2}" stroke-dasharray="4 3"/>')
    for i, (lab, v, a, b, col) in enumerate(rows):
        y = top + i * rh
        x0, x1 = sorted((x(zero), x(v)))
        s.append(f'<g><title>{lab}: {fmt(v)} (95% CI {fmt(a)} to {fmt(b)})</title>')
        s.append(f'<text x="{lw - 8}" y="{y + 14}" fill="{INK}" text-anchor="end">{lab}</text>')
        s.append(f'<rect x="{x0:.1f}" y="{y + 4}" width="{max(x1 - x0, 1):.1f}" height="{rh - 8}" rx="4" fill="{col}"/>')
        s.append(f'<line x1="{x(a):.1f}" y1="{y + rh / 2}" x2="{x(b):.1f}" y2="{y + rh / 2}" stroke="{INK}" stroke-width="1.5"/>')
        for e in (a, b):
            s.append(f'<line x1="{x(e):.1f}" y1="{y + 6}" x2="{x(e):.1f}" y2="{y + rh - 6}" stroke="{INK}" stroke-width="1.5"/>')
        s.append(f'<text x="{x(max(b, v)) + 6:.1f}" y="{y + 14}" fill="{INK2}">{fmt(v)}</text></g>')
    s.append("</svg>")
    return "\n".join(s)


def pct(v):
    return f"{v * 100:.0f}%"


def pp(v):
    return f"{v * 100:+.0f} pp"


def load(folder):
    records = []
    for f in sorted(glob.glob(os.path.join(folder, "*.jsonl"))):
        with open(f, encoding="utf-8") as fh:
            records += [json.loads(l) for l in fh if l.strip()]
    return records


def main(folder):
    records = load(folder)
    if not records:
        sys.exit(f"no records in {folder}")
    r = rates(records)
    n_w = len(records[0]["wizards"])
    spells = sorted({x for k in r if k != "none" for x in k.split("+")})
    deaths = sum(w["died"] for rec in records for w in rec["wizards"])
    lava = sum(w["lava_death"] for rec in records for w in rec["wizards"])
    secs = sum(rec["secs"] for rec in records) / len(records)
    timeouts = sum(rec["timeout"] for rec in records)
    fair = 1.0 / n_w

    syn = []
    for a, b in combinations(spells, 2):
        s, lo, hi = synergy(r, a, b)
        syn.append((label(key([a, b])), s, lo, hi, POS if lo > 0 else NEG if hi < 0 else MUTED, key([a, b])))
    syn.sort(key=lambda t: -t[1])
    wr = []
    for k, (wins, n) in r.items():
        p, lo, hi = wilson(wins, n)
        wr.append((label(k), p, lo, hi, POS if lo > fair else NEG if hi < fair else MUTED, k, n))
    wr.sort(key=lambda t: -t[1])

    with open(os.path.join(folder, "synergy.svg"), "w", encoding="utf-8") as fh:
        fh.write(bar_svg([t[:5] for t in syn if math.isfinite(t[3])], "Pair synergy: win rate beyond the two spells apart", pp))
    with open(os.path.join(folder, "winrate.svg"), "w", encoding="utf-8") as fh:
        fh.write(bar_svg([t[:5] for t in wr], f"Round win rate per loadout (fair share {fair:.0%}, dashed)", pct, 0.0, fair))

    L = [f"# Spell pair sim: {records[0].get('mode', '?')} ({n_w} wizards)", "",
         f"{len(records)} rounds, avg fight {secs:.0f} s, {timeouts} timeouts, deaths in lava {lava / max(deaths, 1):.0%}.",
         "Every wizard is a neutral bot, all spells level 0, no items. Each round every wizard gets a random loadout",
         "(no shop spell, one, or a pair) on top of the starters (Fireball, Blink, Lightning, Shield, Staff).", "",
         "**Bias:** the bots pick each spell on its own merits and never plan combos, so this is the synergy that",
         "happens naturally with these bots; planned combos (pull, then meteor) are under-counted.", "",
         "Colours: blue = clearly above (CI above 0 / above fair share), red = clearly below, gray = can't tell from noise.", "",
         "![synergy](synergy.svg)", "", "## Synergy (pairs)", "",
         "| Pair | Synergy | 95% CI | Pair win rate | n | Verdict |", "|---|---|---|---|---|---|"]
    for lab, s, lo, hi, col, k in syn:
        wins, n = r.get(k, (0, 0))
        verdict = "real combo" if lo > 0 else "anti-combo" if hi < 0 else "noise"
        L.append(f"| {lab} | {s * 100:+.1f} pp | {lo * 100:+.1f} to {hi * 100:+.1f} | {wins / max(n, 1):.0%} | {n} | {verdict} |")
    L += ["", "![win rate](winrate.svg)", "", "## Win rate per loadout", "",
          "| Loadout | Win rate | 95% CI | n |", "|---|---|---|---|"]
    for lab, p, lo, hi, col, k, n in wr:
        L.append(f"| {lab} | {p:.1%} | {lo:.1%} to {hi:.1%} | {n} |")
    with open(os.path.join(folder, "report.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")
    print("\n".join(L[:3]))
    print(f"wrote {folder}/report.md")


if __name__ == "__main__":
    main(sys.argv[1])
