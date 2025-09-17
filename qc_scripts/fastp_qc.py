#!/usr/bin/env python3
"""
fastp_qc.py
-----------------------------------
Generate QC plots and summary tables from fastp output.
Inputs: fastp_summary.csv
Outputs: PNG plots + TSV summaries in 07_plots/
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

IN_CSV = "02_fastqc_reports/fastp_summary.csv"
OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

df = pd.read_csv(IN_CSV, sep="\t")

# Derived metrics
df["Retention"] = df["Passed_Reads"] / df["Total_Reads"]

sns.set(style="whitegrid")

# GC distribution
plt.figure(figsize=(6,4))
plt.hist(df["GC_Content"].dropna(), bins=30)
plt.xlabel("GC content")
plt.ylabel("Samples")
plt.title("GC content distribution")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "fastp_gc_hist.png"))
plt.close()

# Retention plot
df_sorted = df.sort_values("Retention").reset_index(drop=True)
plt.figure(figsize=(12,4.8))
sns.barplot(x="Sample", y="Retention", data=df_sorted, color="tab:blue")
plt.xticks(rotation=90)
plt.ylabel("Retention (Passed/Total)")
plt.ylim(0, 1)
plt.title("Retention per sample (sorted)")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "fastp_retention_sorted.png"))
plt.close()

print(f"[OK] Saved fastp QC plots to {OUT_DIR}")
