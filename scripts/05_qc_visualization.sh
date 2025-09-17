#!/bin/bash
#SBATCH --job-name=poloco_qcplots
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/05_qcplots_%j.out
#SBATCH --error=logs/05_qcplots_%j.err

# ===============================
# Step 5: SNP QC & Visualization
# Tools: Python (custom scripts)
# Conda env: poloco_angsd
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_angsd

PLOT_DIR="07_plots"
mkdir -p $PLOT_DIR logs

echo "[INFO] Running QC visualization scripts..."

python qc_scripts/alignment_qc.py
python qc_scripts/angsd_sfs_maf_qc.py
python qc_scripts/angsd_summary_stats_qc.py
python qc_scripts/final_qc_master.py

echo "[OK] QC visualization finished."

