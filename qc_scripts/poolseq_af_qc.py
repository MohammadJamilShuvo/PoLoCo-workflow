#!/usr/bin/env python3
"""
poolseq_af_qc.py
-----------------------------------
Visualize allele-frequency distribution and missingness from the final
PoPoolation2-derived allele-frequency matrix.

Input:
  PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv

Outputs:
  07_plots/poolseq_maf_distribution.png
  07_plots/poolseq_missingness_per_population.png
Conda env: poloco_poolseq
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

IN_FILE = "PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv"
OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

print("[INFO] Loading final Pool-seq allele-frequency matrix...")

if not os.path.exists(IN_FILE):
    print(f"[WARN] File not found: {IN_FILE}")
    raise SystemExit(0)

df = pd.read_csv(IN_FILE, header=None)

# First column is SNP ID, remaining columns are populations
af = df.iloc[:, 1:].replace("NA", pd.NA).apply(pd.to_numeric, errors="coerce")

sns.set(style="whitegrid")

# Flatten AF values for overall distribution
af_values = af.stack().dropna()

plt.figure(figsize=(8, 6))
sns.histplot(af_values, bins=50, color="tab:green")
plt.xlabel("Allele Frequency")
plt.ylabel("Count")
plt.title("Allele-frequency distribution (LD_MAF05)")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "poolseq_maf_distribution.png"))
plt.close()

# Missingness per population
missing_pct = af.isna().mean() * 100
missing_df = pd.DataFrame({
    "Population": [f"Pop_{i+1}" for i in range(len(missing_pct))],
    "Missing_Pct": missing_pct.values
}).sort_values("Missing_Pct", ascending=False)

plt.figure(figsize=(12, 5))
sns.barplot(x="Population", y="Missing_Pct", data=missing_df, color="tab:blue")
plt.xticks(rotation=90)
plt.xlabel("Population")
plt.ylabel("Missing values (%)")
plt.title("Missingness per population (LD_MAF05)")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "poolseq_missingness_per_population.png"))
plt.close()

print("[OK] Pool-seq AF QC plots saved to 07_plots/")
