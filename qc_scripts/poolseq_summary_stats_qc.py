#!/usr/bin/env python3
"""
Summarize SNP and population-level statistics from the final
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

AF_FILE = POOLSEQ_RESULTS_DIR / f"geno_AF_matrix_LD_MAF{maf_label}.csv"
SNP_FILE = POOLSEQ_RESULTS_DIR / f"{PROJECT_PREFIX}_snps_LD_MAF{maf_label}.txt"

if not AF_FILE.exists():
    AF_FILE = POOLSEQ_RESULTS_DIR / "geno_AF_matrix_LD_MAF05.csv"
if not SNP_FILE.exists():
    SNP_FILE = POOLSEQ_RESULTS_DIR / f"{PROJECT_PREFIX}_snps_LD_MAF05.txt"

PLOTS_DIR.mkdir(parents=True, exist_ok=True)

print("[INFO] Loading Pool-seq final outputs...")

if not AF_FILE.exists():
    print(f"[WARN] Missing allele-frequency file: {AF_FILE}")
    raise SystemExit(0)

df = pd.read_csv(AF_FILE, header=None)
if df.empty or df.shape[1] < 2:
    print(f"[WARN] Allele-frequency matrix is empty or malformed: {AF_FILE}")
    raise SystemExit(0)

af = df.iloc[:, 1:].replace("NA", pd.NA).apply(pd.to_numeric, errors="coerce")

n_snps = df.shape[0]
n_pops = af.shape[1]
global_mean_af = af.stack().mean()
global_missing_pct = af.isna().mean().mean() * 100

n_snp_annotations = pd.NA
if SNP_FILE.exists():
    snp_df = pd.read_csv(SNP_FILE, sep="\t")
    n_snp_annotations = snp_df.shape[0]

summary = pd.DataFrame(
    [
        ["Final_Dataset", AF_FILE.name],
        ["N_SNPs", n_snps],
        ["N_Populations", n_pops],
        ["Mean_Allele_Frequency", global_mean_af],
        ["Mean_Missing_Pct", global_missing_pct],
        ["Annotated_SNP_Rows", n_snp_annotations],
    ],
    columns=["Metric", "Value"],
)

summary.to_csv(PLOTS_DIR / "poolseq_summary.tsv", sep="\t", index=False)

pop_mean_af = af.mean(axis=0, skipna=True)
plot_df = pd.DataFrame(
    {
        "Population": [f"Pop_{i+1}" for i in range(len(pop_mean_af))],
        "Mean_AF": pop_mean_af.values,
    }
).sort_values("Mean_AF", ascending=False)

sns.set(style="whitegrid")
plt.figure(figsize=(max(8, len(plot_df) * 0.18), 5))
sns.barplot(x="Population", y="Mean_AF", data=plot_df, color="tab:orange")
plt.xticks(rotation=90)
plt.xlabel("Population")
plt.ylabel("Mean allele frequency")
plt.title("Mean allele frequency per population")
plt.tight_layout()
plt.savefig(PLOTS_DIR / "poolseq_population_mean_af.png", dpi=300)
plt.close()

print(f"[OK] Pool-seq summary stats saved to {PLOTS_DIR}")
