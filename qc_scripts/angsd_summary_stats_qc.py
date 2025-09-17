#!/usr/bin/env python3
"""
angsd_summary_stats_qc.py
-----------------------------------
Summarize SNP statistics from ANGSD.
Inputs: ANGSD output (e.g. .mafs.gz, SNP stats)
Outputs: TSV + plots in 07_plots/
Conda env: poloco_angsd
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

print("[INFO] Loading ANGSD results...")

try:
    df = pd.read_csv("06_angsd/angsd_results.mafs.gz", sep="\t", compression="gzip")
except FileNotFoundError:
    print("[WARN] No ANGSD output found. Skipping.")
    exit()

# Summaries
total_sites = df.shape[0]
mean_maf = df["knownEM"].mean()

summary = pd.DataFrame([["Total_Sites", total_sites], ["Mean_MAF", mean_maf]],
                       columns=["Metric", "Value"])
summary.to_csv(os.path.join(OUT_DIR, "angsd_summary.tsv"), sep="\t", index=False)

# Plot histogram of allele frequency
sns.set(style="whitegrid")
plt.figure(figsize=(8, 6))
sns.histplot(df["knownEM"], bins=40, color="tab:orange")
plt.xlabel("MAF")
plt.ylabel("Sites")
plt.title("ANGSD SNP summary")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "angsd_summary_hist.png"))
plt.close()

print("[OK] ANGSD summary stats saved to 07_plots/")

