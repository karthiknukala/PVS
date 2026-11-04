"""Render the second-round PVS benchmark figures from round2-results.json."""
import json
from pathlib import Path
from statistics import median

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator, PercentFormatter


WORKLOADS = {
    "startup": "Raw PVS startup",
    "cheri": "CHERI-PVS · RV64 top64 typecheck",
    "cheri-restore": "CHERI-PVS · RV64 top64 restore",
    "cheri-xref": "CHERI-PVS · cross-reference rebuild",
    "cheri-proof": "CHERI-PVS · register proofs",
    "smt": "SMT · term manager typecheck",
    "inference": "Inference Systems · grs_relations proofs",
    "ints": "NASALib · gcd typecheck",
    "ints-proof": "NASALib · gcd proofs",
    "orders": "NASALib · orders typecheck",
}
INK, MUTED = "#19323b", "#536772"
REDUCTION, INCREASE = "#087a76", "#b45026"


def summarize(data, workloads, field):
    rows = []
    for name in workloads:
        pair = []
        for variant in ("before", "after"):
            trials = data[name][variant]
            if not trials:
                raise ValueError(f"{name} has no {variant} trials")
            values = [row.get(field) for row in trials]
            pair.append(median(values) if None not in values else None)
        before, after = pair
        change = 100 * (after / before - 1) if before and after is not None else None
        rows.append((before, after, change))
    return rows


def format_pair(before, after, field):
    if before is None and after is None:
        return "Not measured"
    largest = max((v for v in (before, after) if v is not None), default=0)
    if field == "seconds":
        unit, scale = ("ms", 0.001) if largest < 1 else ("s", 1)
    else:
        unit, scale = ("GB", 1e9) if largest >= 1e9 else ("MB", 1e6)
    values = [f"{v / scale:.3g}" if v is not None else "—" for v in (before, after)]
    return f"{values[0]} → {values[1]} {unit}"


def render(data, workloads, panels, title, footnote, output):
    # Each chart shares its rows with a table of absolute medians and changes.
    double = len(panels) == 2
    fig = plt.figure(figsize=(14.8 if double else 10.2, 6.6))
    grid = fig.add_gridspec(1, 2 * len(panels), width_ratios=[1.0, 1.12] * len(panels),
                            left=0.245 if double else 0.35, right=0.98,
                            top=0.78, bottom=0.15, wspace=0.12)
    fig.text(0.04, 0.925, title, fontsize=22, weight="bold", color=INK)
    fig.text(0.04, 0.867, "Change in the median from the previous build. Lower is better.",
             fontsize=12, color=MUTED)
    all_rows = [summarize(data, workloads, field) for field, _ in panels]
    changes = [c for rows in all_rows for _, _, c in rows if c is not None]
    bounds = (min([-10, *changes]) * 1.07, max([10, *changes]) * 1.07)
    for i, ((field, heading), rows) in enumerate(zip(panels, all_rows)):
        bars = fig.add_subplot(grid[0, i * 2])
        table = fig.add_subplot(grid[0, i * 2 + 1])
        for ax in (bars, table):
            ax.set_ylim(len(rows) - 0.5, -0.5)
            ax.spines[:].set_visible(False)
        bars.set_title(heading, loc="left", color=INK, fontsize=12, weight="bold", pad=10)
        bars.set_xlim(*bounds)
        bars.axvline(0, color="#75868e", linewidth=1)
        bars.xaxis.set_major_locator(MaxNLocator(nbins=4))
        bars.xaxis.set_major_formatter(PercentFormatter(xmax=100, decimals=0))
        bars.tick_params(axis="x", length=0, labelsize=9, colors=MUTED)
        bars.set_axisbelow(True)
        bars.grid(axis="x", color="#e4e9eb", linewidth=0.8)
        bars.set_yticks(range(len(rows)), [WORKLOADS[name] for name in workloads])
        bars.tick_params(axis="y", length=0, pad=9, labelsize=10, labelleft=i == 0)
        table.set_axis_off()
        table.set_title("Before → after", loc="left", color=MUTED, fontsize=10, pad=10)
        table.set_title("Change", loc="right", color=MUTED, fontsize=10, pad=10)
        for y, (before, after, change) in enumerate(rows):
            color = REDUCTION if change is not None and change < 0 else INCREASE
            if change is not None:
                bars.barh(y, change, height=0.43, color=color)
            table.text(0, y, format_pair(before, after, field), va="center", color=INK, fontsize=10)
            delta = "—" if change is None else f"{change:+.1f}%".replace("-", "−")
            if change is not None and abs(change) < 0.05:
                delta, color = "≈0%", MUTED
            table.text(1, y, delta, ha="right", va="center", fontsize=10,
                       color=color if change is not None else MUTED)
    fig.text(0.04, 0.045, footnote, color=MUTED, fontsize=10)
    fig.savefig(output, dpi=150, facecolor="white")
    plt.close(fig)


def main():
    base = Path(__file__).resolve().parent
    data = json.loads((base / "round2-results.json").read_text())
    for name in WORKLOADS:
        if name != "startup":
            rows = data[name]["before"] + data[name]["after"]
            if len({r["signature"] for r in rows}) != 1:
                raise ValueError(f"{name} has inconsistent benchmark signatures")
    render(data, list(WORKLOADS), [("seconds", "Elapsed time")], "PVS latency",
           "Startup measures time to the ready marker. The other rows time the named operation.",
           base / "round2-latency.png")
    render(data, [name for name in WORKLOADS if name != "startup"],
           [("bytes", "Cumulative Lisp allocation"), ("peak_rss_bytes", "Peak process RSS")],
           "PVS memory use",
           "Peak RSS includes startup and preparation. Memory uses decimal MB and GB. Startup was timed only.",
           base / "round2-memory.png")


if __name__ == "__main__":
    main()
