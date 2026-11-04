"""Render reproducible stock vs optimized performance figures from results.json."""
import json
from pathlib import Path
from statistics import median

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter

base = Path(__file__).resolve().parent
data = json.loads((base / "results.json").read_text())
labels = {"cheri": "CHERI-PVS\nRV64 top64", "smt": "SMT\nhashcons_term_manager",
          "inference": "Inference Systems\ngrs_relations replay",
          "ints": "NASALib ints\ngcd", "orders": "NASALib orders\ntop"}
for name in labels:
    rows = data[name]["stock"] + data[name]["patched"]
    if len({row["signature"] for row in rows}) != 1:
        raise ValueError(f"Declaration or TCC signature mismatch for {name}")

for field, unit, divisor, title, filename in [
    ("seconds", "s", 1, "Elapsed time", "elapsed"),
    ("bytes", "MB", 1e6, "Cumulative Lisp allocation", "allocation"),
    ("peak_rss_bytes", "MB", 1e6, "Peak process memory", "resident"),
]:
    fig, ax = plt.subplots(figsize=(9.0, 4.8))
    fig.subplots_adjust(left=0.28, right=0.95, top=0.81, bottom=0.17)
    pairs = []
    for name in labels:
        pairs.append([median(row[field] for row in data[name][mode]) / divisor
                      for mode in ("stock", "patched")])
    ratios = [after / before for before, after in pairs]
    end = max(1.0, *ratios)
    for i, ((before, after), ratio) in enumerate(zip(pairs, ratios)):
        ax.barh(i, 1, height=0.46, color="#dce4eb")
        ax.barh(i, ratio, height=0.24, color="#087a76")
        precision = 2 if field == "seconds" else 0 if after >= 10 else 1
        ax.text(end + 0.05, i, f"{before:,.{precision}f} → {after:,.{precision}f} {unit}",
                fontsize=10, va="center")
    ax.set_xlim(0, end + 0.64)
    ax.set_yticks(range(len(labels)), labels.values(), fontsize=10)
    ax.invert_yaxis()
    ax.set_xticks([0, .25, .50, .75, 1.0])
    ax.xaxis.set_major_formatter(PercentFormatter(1))
    ax.spines[:].set_visible(False)
    ax.tick_params(length=0, pad=7)
    ax.set_xlabel("Percentage of the stock measurement", loc="left", fontsize=10)
    fig.text(.045, .92, title, fontsize=20, weight="bold", color="#172c3b")
    fig.text(.045, .856, "Gray = stock PVS     Teal = optimized PVS     Lower is better",
             fontsize=10, color="#435568")
    fig.savefig(base / f"{filename}.png", dpi=150, facecolor="white")
    plt.close(fig)
