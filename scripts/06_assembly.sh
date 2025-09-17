#!/bin/bash
#SBATCH --job-name=poloco_assembly
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=logs/06_assembly_%j.out
#SBATCH --error=logs/06_assembly_%j.err

# ===============================
# Step 6: Draft Genome Assembly
# Tools: MEGAHIT, BUSCO
# Conda env: poloco_assembly
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_assembly

RAW_DIR="01_raw_reads"
ASSEMBLY_DIR="08_assembly"

mkdir -p $ASSEMBLY_DIR logs

echo "[INFO] Running MEGAHIT assembly..."

megahit -1 ${RAW_DIR}/*_R1*.fastq.gz \
        -2 ${RAW_DIR}/*_R2*.fastq.gz \
        -o $ASSEMBLY_DIR \
        --min-contig-len 1000 \
        -t 16

echo "[INFO] Assembly complete. Running BUSCO..."

busco -i ${ASSEMBLY_DIR}/final.contigs.fa \
      -l arthropoda_odb10 \
      -o busco_results \
      -m genome \
      -c 16

echo "[OK] Assembly and BUSCO finished."

