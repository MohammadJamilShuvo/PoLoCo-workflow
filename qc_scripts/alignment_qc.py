#!/usr/bin/env python3
"""
alignment_qc.py
-----------------------------------
Summarize and visualize alignment statistics.
Inputs: BAM files in 04_bam_filtered/
Outputs: Plots + TSV summaries in 07_plots/
Conda env: poloco_qc_mapping
"""

import os
import subprocess
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

BAM_DIR = "04_bam_filtered"
OUT_DIR = "07_plots"
os.makedirs(OUT_DIR, exist_ok=True)

summary_data = []

print("[INFO] Collecting alignment statistics...")
for bam in os.listdir(BAM_DIR):
    if bam.endswith(".filtered.bam"):
        sample = bam.replace(".filtered.bam", "")
        bam_path = os.path.join(BAM_DIR, bam)
        
        # run samtools flagstat
        result = subprocess.run(["samtools", "flagstat", bam_path], capture_output=True, text=True)
        lines = result.stdout.splitlines()
        
        total = int(lines[0].split()[0])
        mapped = int(lines[4].split()[0])
        pct_mapped = (mapped / total * 100) if total > 0 else 0
        
        summary_data.append([sample, total, mapped, pct_mapped])

# Save summary
df = pd.DataFrame(summary_data, columns=["Sample", "Total_Reads", "Mapped_Reads", "Pct_Mapped"])
df.to_csv(os.path.join(OUT_DIR, "alignment_summary.tsv"), sep="\t", index=False)

# Plot
sns.set(style="whitegrid")
plt.figure(figsize=(10, 6))
sns.barplot(x="Sample", y="Pct_Mapped", data=df, color="tab:blue")
plt.xticks(rotation=90)
plt.ylabel("% Mapped")
plt.title("Mapping Efficiency per Sample")
plt.tight_layout()
plt.savefig(os.path.join(OUT_DIR, "alignment_pct_mapped.png"))
plt.close()

print("[OK] Alignment QC plots saved to 07_plots/")

