#!/usr/bin/env python3
"""
final_qc_master.py
-----------------------------------
Integrate QC results from preprocessing, alignment, coverage, and final
Pool-seq outputs into a single Excel workbook.

Inputs:
  07_plots/alignment_summary.tsv
  05_coverage/*_coverage.txt
  07_plots/poolseq_summary.tsv

Output:
  07_plots/poloco_master_qc.xlsx
Conda env: poloco_poolseq
"""

import os
import pandas as pd

OUT_DIR = "07_plots"
COV_DIR = "05_coverage"
os.makedirs(OUT_DIR, exist_ok=True)

print("[INFO] Integrating QC results...")

tables = {}

alignment_file = os.path.join(OUT_DIR, "alignment_summary.tsv")
if os.path.exists(alignment_file):
    tables["alignment"] = pd.read_csv(alignment_file, sep="\t")

poolseq_file = os.path.join(OUT_DIR, "poolseq_summary.tsv")
if os.path.exists(poolseq_file):
    tables["poolseq"] = pd.read_csv(poolseq_file, sep="\t")

cov_files = []
if os.path.exists(COV_DIR):
    cov_files = [f for f in os.listdir(COV_DIR) if f.endswith("_coverage.txt")]

if cov_files:
    dfs = []
    for f in cov_files:
        df = pd.read_csv(
            os.path.join(COV_DIR, f),
            sep="\t",
            header=None,
            names=["Sample", "Mean_Coverage"]
        )
        dfs.append(df)
    tables["coverage"] = pd.concat(dfs, ignore_index=True)

if not tables:
    print("[WARN] No QC tables found. Nothing to write.")
    raise SystemExit(0)

with pd.ExcelWriter(os.path.join(OUT_DIR, "poloco_master_qc.xlsx")) as writer:
    for key, df in tables.items():
        df.to_excel(writer, sheet_name=key, index=False)

print("[OK] Master QC table saved to 07_plots/poloco_master_qc.xlsx")
