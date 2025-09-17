#!/bin/bash
#SBATCH --job-name=poloco_qc
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/01_qc_%j.out
#SBATCH --error=logs/01_qc_%j.err

# ===============================
# Step 1: Read Preprocessing & QC
# Tools: fastp, FastQC, MultiQC
# ===============================

# Activate conda environment
source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_env

# Input directory with raw reads
RAW_DIR="01_raw_reads"
OUT_DIR="02_trimmed_reads"
QC_DIR="02_fastqc_reports"
PLOT_DIR="07_plots"

mkdir -p $OUT_DIR $QC_DIR $PLOT_DIR logs

echo "[INFO] Running fastp trimming + QC..."

for R1 in ${RAW_DIR}/*_R1*.fastq.gz; do
    SAMPLE=$(basename $R1 | sed 's/_R1.*//')
    R2=${RAW_DIR}/${SAMPLE}_R2.fastq.gz
    
    fastp \
      -i $R1 -I $R2 \
      -o ${OUT_DIR}/${SAMPLE}_R1_trimmed.fastq.gz \
      -O ${OUT_DIR}/${SAMPLE}_R2_trimmed.fastq.gz \
      -h ${QC_DIR}/${SAMPLE}_fastp.html \
      -j ${QC_DIR}/${SAMPLE}_fastp.json
done

# Run FastQC + MultiQC
fastqc ${OUT_DIR}/*.fastq.gz -o $QC_DIR
multiqc $QC_DIR -o $QC_DIR

# Summarize + plot (Python QC script)
python qc_scripts/fastp_qc.py

echo "[OK] Preprocessing + QC finished."

