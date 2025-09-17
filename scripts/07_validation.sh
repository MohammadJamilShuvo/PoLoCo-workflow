#!/bin/bash
#SBATCH --job-name=poloco_validation
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/07_validation_%j.out
#SBATCH --error=logs/07_validation_%j.err

# ===============================
# Step 7: Assembly Validation
# Tools: QUAST, FastANI
# Conda env: poloco_assembly
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_assembly

ASSEMBLY="08_assembly/final.contigs.fa"
REF="ref/ncbi_reference.fa"
VAL_DIR="09_validation"

mkdir -p $VAL_DIR logs

echo "[INFO] Running QUAST..."

quast.py $ASSEMBLY -r $REF -o $VAL_DIR

echo "[INFO] Running FastANI..."

fastANI --query $ASSEMBLY --ref $REF -o ${VAL_DIR}/fastani.out

echo "[OK] Validation finished."

