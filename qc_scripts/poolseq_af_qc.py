#!/usr/bin/env python3
"""
Visualize allele-frequency distribution and missingness from the final
PoLoCo allele-frequency matrix.
"""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns


PROJECT_PREFIX = os.environ.get("PROJECT_PREFIX", "envilis")
POOLSEQ_RESULTS_DIR = Path(os.environ.get("POOLSEQ_RESULTS_DIR", "PoPoolation2/results"))
PLOTS_DIR = Path(os.environ.get("PLOTS_DIR", "07_plots"))
MAF = os.environ.get("MAF", "0.05")
maf_label = str(MAF).replace(".", "")

IN_FILE = POOLSEQ_RESULTS_DIR / f"geno_AF_matrix_LD_MAF{maf_label}.csv"
if not IN_FILE.exists():
    # fallback historical file
    IN_FILE = POOLSEQ_RESULTS_DIR / "geno_AF_matrix_LD_MAF05.csv"

PLOTS_DIR.mkdir(parents=True, exist_ok=True)

print("[INFO] Loading final Pool-seq allele-frequency matrix...")

if not IN_FILE.exists():
    print(f"[WARN] File not found: {IN_FILE}")
    raise SystemExit(0)

df = pd.read_csv(IN_FILE, header=None)
if df.empty or df.shape[1] < 2:
    print(f"[WARN] Allele-frequency matrix is empty or malformed: {IN_FILE}")
    raise SystemExit(0)

af = df.iloc[:, 1:].replace("NA", pd.NA).apply(pd.to_numeric, errors="coerce")

sns.set(style="whitegrid")

af_values = af.stack().dropna()

if not af_values.empty:
    plt.figure(figsize=(8, 6))
    sns.histplot(af_values, bins=50, color="tab:green")
    plt.xlabel("Minor allele frequency")
    plt.ylabel("Count")
    plt.title("Allele-frequency distribution")
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "poolseq_maf_distribution.png", dpi=300)
    plt.close()

missing_pct = af.isna().mean() * 100
missing_df = pd.DataFrame(
    {
        "Population": [f"Pop_{i+1}" for i in range(len(missing_pct))],
        "Missing_Pct": missing_pct.values,
    }
).sort_values("Missing_Pct", ascending=False)

plt.figure(figsize=(max(8, len(missing_df) * 0.18), 5))
sns.barplot(x="Population", y="Missing_Pct", data=missing_df, color="tab:blue")
plt.xticks(rotation=90)
plt.xlabel("Population")
plt.ylabel("Missing values (%)")
plt.title("Missingness per population")
plt.tight_layout()
plt.savefig(PLOTS_DIR / "poolseq_missingness_per_population.png", dpi=300)
plt.close()

missing_df.to_csv(PLOTS_DIR / "poolseq_missingness_per_population.tsv", sep="\t", index=False)

print(f"[OK] Pool-seq AF QC saved to {PLOTS_DIR}")
