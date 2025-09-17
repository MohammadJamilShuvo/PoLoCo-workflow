#!/usr/bin/env python3
"""
final_qc_master.py
-----------------------------------
Integrate QC results from alignment, coverage, and SNP analysis.
Inputs: alignment_summary.tsv, coverage files, ANGSD summaries
Outputs: Master QC table in 07_plots/
Conda env: poloco_angsd
"""

import os
import pandas as pd

OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

print("[INFO] Integrating QC results...")

tables = {}

# Alignment summary
if os.path.exists(os.path.join(OUT_DIR, "alignment_summary.tsv")):
    tables["alignment"] = pd.read_csv(os.path.join(OUT_DIR, "alignment_summary.tsv"), sep="\t")

# ANGSD summary
if os.path.exists(os.path.join(OUT_DIR, "angsd_summary.tsv")):
    tables["angsd"] = pd.read_csv(os.path.join(OUT_DIR, "angsd_summary.tsv"), sep="\t")

# Coverage (optional, concatenate)
cov_files = [f for f in os.listdir("05_coverage") if f.endswith("_coverage.txt")]
if cov_files:
    dfs = []
    for f in cov_files:
        df = pd.read_csv(os.path.join("05_coverage", f), sep="\t", header=None, names=["Sample", "Mean_Coverage"])
        dfs.append(df)
    tables["coverage"] = pd.concat(dfs, ignore_index=True)

# Merge results
with pd.ExcelWriter(os.path.join(OUT_DIR, "poloco_master_qc.xlsx")) as writer:
    for key, df in tables.items():
        df.to_excel(writer, sheet_name=key, index=False)

print("[OK] Master QC table saved to poloco_master_qc.xlsx")

