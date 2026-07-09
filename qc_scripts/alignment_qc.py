#!/usr/bin/env python3
"""
Summarize and visualize alignment statistics from filtered BAM files.
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


BAM_DIR = Path(os.environ.get("FILTERED_BAM_DIR", "04_bam_filtered"))
OUT_DIR = Path(os.environ.get("PLOTS_DIR", "07_plots"))
OUT_DIR.mkdir(parents=True, exist_ok=True)

summary_data = []

def parse_flagstat(text: str):
    total = None
    mapped = None
    properly_paired = None

    for line in text.splitlines():
        if " in total " in line and total is None:
            total = int(line.split()[0])
        elif " mapped (" in line and "primary mapped" not in line and mapped is None:
            mapped = int(line.split()[0])
        elif " properly paired " in line and properly_paired is None:
            properly_paired = int(line.split()[0])

    return total or 0, mapped or 0, properly_paired or 0

print("[INFO] Collecting alignment statistics...")

if not BAM_DIR.exists():
    print(f"[WARN] BAM directory not found: {BAM_DIR}")
    raise SystemExit(0)

for bam_path in sorted(BAM_DIR.glob("*.filtered.bam")):
    sample = bam_path.name.replace(".filtered.bam", "")
    result = subprocess.run(["samtools", "flagstat", str(bam_path)], capture_output=True, text=True, check=False)

    if result.returncode != 0:
        print(f"[WARN] samtools flagstat failed for {bam_path}")
        continue

    total, mapped, properly_paired = parse_flagstat(result.stdout)
    pct_mapped = (mapped / total * 100) if total > 0 else 0
    pct_properly_paired = (properly_paired / total * 100) if total > 0 else 0

    summary_data.append([sample, total, mapped, properly_paired, pct_mapped, pct_properly_paired])

df = pd.DataFrame(
    summary_data,
    columns=["Sample", "Total_Reads", "Mapped_Reads", "Properly_Paired_Reads", "Pct_Mapped", "Pct_Properly_Paired"],
)
df.to_csv(OUT_DIR / "alignment_summary.tsv", sep="\t", index=False)

if not df.empty:
    sns.set(style="whitegrid")
    plt.figure(figsize=(max(8, len(df) * 0.18), 6))
    sns.barplot(x="Sample", y="Pct_Mapped", data=df, color="tab:blue")
    plt.xticks(rotation=90)
    plt.ylabel("% mapped")
    plt.title("Mapping efficiency per sample")
    plt.tight_layout()
    plt.savefig(OUT_DIR / "alignment_pct_mapped.png", dpi=300)
    plt.close()

print(f"[OK] Alignment QC saved to {OUT_DIR}")
