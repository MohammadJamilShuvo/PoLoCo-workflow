#!/usr/bin/env python3
"""
angsd_sfs_maf_qc.py
-----------------------------------
Visualize site frequency spectrum (SFS) and minor allele frequency (MAF) distributions.
Inputs: ANGSD output files (e.g. *.mafs.gz, *.saf, *.sfs)
Outputs: Plots in 07_plots/
Conda env: poloco_angsd
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

print("[INFO] Loading ANGSD MAF file...")

try:
    df = pd.read_csv("06_angsd/angsd_results.mafs.gz", sep="\t", compression="gzip")
except FileNotFoundError:
    print("[WARN] No MAF file found. Skipping.")
    exit()

sns.set(style="whitegrid")

# Histogram of MAF
plt.figure(figsize=(8, 6))
sns.histplot(df["knownEM"], bins=50, color="tab:green")
plt.xlabel("Minor Allele Frequency")
plt.ylabel("Sites")
plt.title("MAF distribution")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "maf_distribution.png"))
plt.close()

print("[OK] MAF QC plots saved to 07_plots/")

