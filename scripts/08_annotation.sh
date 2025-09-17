#!/bin/bash
#SBATCH --job-name=poloco_annotation
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=logs/08_annotation_%j.out
#SBATCH --error=logs/08_annotation_%j.err

# ===============================
# Step 8: Genome Annotation (Optional)
# Tools: RepeatModeler, RepeatMasker, BRAKER2, eggNOG-mapper, InterProScan
# Conda env: poloco_annotation
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_annotation

ASSEMBLY="08_assembly/final.contigs.fa"
ANNOT_DIR="10_annotation"

mkdir -p $ANNOT_DIR logs

echo "[INFO] Running RepeatModeler..."

BuildDatabase -name ${ANNOT_DIR}/genome_db $ASSEMBLY
RepeatModeler -database ${ANNOT_DIR}/genome_db -pa 16 -LTRStruct > ${ANNOT_DIR}/repeatmodeler.log

echo "[INFO] Running RepeatMasker..."

RepeatMasker -pa 16 -lib ${ANNOT_DIR}/consensi.fa.classified -dir $ANNOT_DIR $ASSEMBLY

echo "[INFO] Running BRAKER2..."

braker.pl --genome=$ASSEMBLY --species=poloco --softmasking --cores 16 --gff3

echo "[INFO] Running eggNOG-mapper..."

emapper.py -i ${ANNOT_DIR}/braker2/augustus.hints.gff3 -o ${ANNOT_DIR}/eggnog --cpu 16

echo "[INFO] Running InterProScan..."

interproscan.sh -i ${ANNOT_DIR}/braker2/augustus.hints.gff3 -o ${ANNOT_DIR}/interproscan.tsv -dp -f TSV -cpu 16

echo "[OK] Annotation finished."

