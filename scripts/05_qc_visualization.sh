#!/bin/bash
#SBATCH --job-name=poloco_qcplots
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/05_qcplots_%j.out
#SBATCH --error=logs/05_qcplots_%j.err

# ===============================
# Step 5: Pool-seq QC & Visualization
# Tools: Python (custom scripts)
# Conda env: poloco_poolseq
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_poolseq

PLOT_DIR="07_plots"
RESULT_DIR="PoPoolation2/results"

mkdir -p "${PLOT_DIR}" logs

echo "[INFO] Running Pool-seq QC visualization scripts..."

if [[ ! -f "${RESULT_DIR}/geno_AF_matrix_LD_MAF05.csv" ]]; then
    echo "[ERROR] Missing final dataset: ${RESULT_DIR}/geno_AF_matrix_LD_MAF05.csv"
    exit 1
fi

python qc_scripts/alignment_qc.py
python qc_scripts/poolseq_af_qc.py
python qc_scripts/poolseq_summary_stats_qc.py

echo "[OK] QC visualization finished."
