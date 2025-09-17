#!/bin/bash
#SBATCH --job-name=poloco_angsd
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/04_angsd_%j.out
#SBATCH --error=logs/04_angsd_%j.err

# ===============================
# Step 4: SNP Discovery (ANGSD)
# Tools: ANGSD, bcftools, vcftools
# Conda env: poloco_angsd
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_angsd

BAMLIST="bamlist.txt"
REF="ref/poloco_draft.fa"
ANGSD_OUT="06_angsd"

mkdir -p $ANGSD_OUT logs

echo "[INFO] Running ANGSD SNP calling..."

angsd -b $BAMLIST \
    -ref $REF \
    -out ${ANGSD_OUT}/angsd_results \
    -uniqueOnly 1 -remove_bads 1 -only_proper_pairs 1 \
    -baq 1 -C 50 \
    -minMapQ 30 -minQ 20 \
    -doCounts 1 \
    -GL 1 \
    -doSaf 1 \
    -doMajorMinor 1 -doMaf 1 \
    -doSnpStat 1 \
    -doHWE 1 \
    -SNP_pval 1e-6 \
    -minInd 10 \
    -setMinDepth 20 -setMaxDepth 100 \
    -P 8

echo "[OK] ANGSD SNP calling complete."

