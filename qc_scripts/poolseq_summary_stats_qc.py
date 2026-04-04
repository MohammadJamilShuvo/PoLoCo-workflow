#!/usr/bin/env python3
"""
poolseq_summary_stats_qc.py
-----------------------------------
Summarize SNP and population-level statistics from the final
PoPoolation2-derived allele-frequency matrix.

Input:
  PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv
  PoPoolation2/results/envilis_snps_LD_MAF05.txt

Outputs:
  07_plots/poolseq_summary.tsv
  07_plots/poolseq_population_mean_af.png
Conda env: poloco_poolseq
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

AF_FILE = "PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv"
SNP_FILE = "PoPoolation2/results/envilis_snps_LD_MAF05.txt"
OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

print("[INFO] Loading Pool-seq final outputs...")

if not os.path.exists(AF_FILE):
    print(f"[WARN] Missing allele-frequency file: {AF_FILE}")
    raise SystemExit(0)

df = pd.read_csv(AF_FILE, header=None)
af = df.iloc[:, 1:].replace("NA", pd.NA).apply(pd.to_numeric, errors="coerce")

n_snps = df.shape[0]
n_pops = af.shape[1]
global_mean_af = af.stack().mean()
global_missing_pct = af.isna().mean().mean() * 100

n_snp_annotations = pd.NA
if os.path.exists(SNP_FILE):
    snp_df = pd.read_csv(SNP_FILE, header=None)
    n_snp_annotations = snp_df.shape[0]

summary = pd.DataFrame([
    ["Final_Dataset", "geno_AF_matrix_LD_MAF05.csv"],
    ["N_SNPs", n_snps],
    ["N_Populations", n_pops],
    ["Mean_Allele_Frequency", global_mean_af],
    ["Mean_Missing_Pct", global_missing_pct],
    ["Annotated_SNP_Rows", n_snp_annotations]
], columns=["Metric", "Value"])

summary.to_csv(os.path.join(OUT_DIR, "poolseq_summary.tsv"), sep="\t", index=False)

# Mean AF per population
pop_mean_af = af.mean(axis=0, skipna=True)
plot_df = pd.DataFrame({
    "Population": [f"Pop_{i+1}" for i in range(len(pop_mean_af))],
    "Mean_AF": pop_mean_af.values
}).sort_values("Mean_AF", ascending=False)

sns.set(style="whitegrid")
plt.figure(figsize=(12, 5))
sns.barplot(x="Population", y="Mean_AF", data=plot_df, color="tab:orange")
plt.xticks(rotation=90)
plt.xlabel("Population")
plt.ylabel("Mean allele frequency")
plt.title("Mean allele frequency per population (LD_MAF05)")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "poolseq_population_mean_af.png"))
plt.close()

print("[OK] Pool-seq summary stats saved to 07_plots/")
