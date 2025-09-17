#!/bin/bash
#SBATCH --job-name=poloco_coverage
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/03_coverage_%j.out
#SBATCH --error=logs/03_coverage_%j.err

# ===============================
# Step 3: Coverage Estimation
# Tools: samtools
# Conda env: poloco_qc_mapping
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_qc_mapping

FILTER_DIR="04_bam_filtered"
COV_DIR="05_coverage"

mkdir -p $COV_DIR logs

echo "[INFO] Estimating coverage..."

for BAM in ${FILTER_DIR}/*.filtered.bam; do
    SAMPLE=$(basename $BAM .filtered.bam)
    samtools depth -a $BAM | \
        awk '{sum+=$3} END { if (NR>0) print "'$SAMPLE'\t"sum/NR; else print "'$SAMPLE'\t0"}' \
        > ${COV_DIR}/${SAMPLE}_coverage.txt
done

echo "[OK] Coverage estimation finished."

