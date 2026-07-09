#!/usr/bin/env python3
"""
Generate QC plots and summary tables from fastp output.
"""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


QC_DIR = Path(os.environ.get("QC_DIR", "02_fastqc_reports"))
OUT_DIR = Path(os.environ.get("PLOTS_DIR", "07_plots"))
IN_CSV = QC_DIR / "fastp_summary.csv"
OUT_DIR.mkdir(parents=True, exist_ok=True)

if not IN_CSV.exists():
    print(f"[WARN] fastp summary not found: {IN_CSV}")
    raise SystemExit(0)

df = pd.read_csv(IN_CSV, sep="\t")
if df.empty:
    print("[WARN] fastp summary is empty.")
    raise SystemExit(0)

if "Retention" not in df.columns:
    df["Retention"] = df["Passed_Reads"] / df["Total_Reads"]

sns.set(style="whitegrid")

if "GC_Content" in df.columns:
    plt.figure(figsize=(6, 4))
    plt.hist(pd.to_numeric(df["GC_Content"], errors="coerce").dropna(), bins=30)
    plt.xlabel("GC content")
    plt.ylabel("Samples")
    plt.title("GC content distribution")
    plt.tight_layout()
    plt.savefig(OUT_DIR / "fastp_gc_hist.png", dpi=300)
    plt.close()

df_sorted = df.sort_values("Retention").reset_index(drop=True)
plt.figure(figsize=(max(8, len(df_sorted) * 0.18), 4.8))
sns.barplot(x="Sample", y="Retention", data=df_sorted, color="tab:blue")
plt.xticks(rotation=90)
plt.ylabel("Retention (passed / total)")
plt.ylim(0, 1)
plt.title("Read retention per sample")
plt.tight_layout()
plt.savefig(OUT_DIR / "fastp_retention_sorted.png", dpi=300)
plt.close()

df.to_csv(OUT_DIR / "fastp_summary_for_plots.tsv", sep="\t", index=False)

print(f"[OK] Saved fastp QC plots to {OUT_DIR}")
