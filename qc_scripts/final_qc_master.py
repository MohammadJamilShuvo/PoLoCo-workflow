#!/usr/bin/env python3
"""
Integrate QC results from preprocessing, alignment, coverage, and final
Pool-seq outputs into master QC files.
"""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd


PLOTS_DIR = Path(os.environ.get("PLOTS_DIR", "07_plots"))
COVERAGE_DIR = Path(os.environ.get("COVERAGE_DIR", "05_coverage"))
QC_DIR = Path(os.environ.get("QC_DIR", "02_fastqc_reports"))

PLOTS_DIR.mkdir(parents=True, exist_ok=True)

print("[INFO] Integrating QC results...")

tables = {}

fastp_file = QC_DIR / "fastp_summary.tsv"
if fastp_file.exists():
    tables["fastp"] = pd.read_csv(fastp_file, sep="\t")

alignment_file = PLOTS_DIR / "alignment_summary.tsv"
if alignment_file.exists():
    tables["alignment"] = pd.read_csv(alignment_file, sep="\t")

poolseq_file = PLOTS_DIR / "poolseq_summary.tsv"
if poolseq_file.exists():
    tables["poolseq"] = pd.read_csv(poolseq_file, sep="\t")

if COVERAGE_DIR.exists():
    dfs = []
    for f in sorted(COVERAGE_DIR.glob("*_coverage.txt")):
        df = pd.read_csv(f, sep="\t", header=None, names=["Sample", "Mean_Coverage"])
        dfs.append(df)
    if dfs:
        tables["coverage"] = pd.concat(dfs, ignore_index=True)

if not tables:
    print("[WARN] No QC tables found. Nothing to write.")
    raise SystemExit(0)

# Write Excel workbook
xlsx_file = PLOTS_DIR / "poloco_master_qc.xlsx"
with pd.ExcelWriter(xlsx_file) as writer:
    for key, df in tables.items():
        df.to_excel(writer, sheet_name=key[:31], index=False)

# Also write a simple combined TSV folder output for environments without Excel viewers.
for key, df in tables.items():
    df.to_csv(PLOTS_DIR / f"poloco_master_qc_{key}.tsv", sep="\t", index=False)

print(f"[OK] Master QC workbook saved to {xlsx_file}")
