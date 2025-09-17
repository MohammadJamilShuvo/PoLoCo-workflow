#!/bin/bash
#SBATCH --job-name=poloco_mapping
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/02_mapping_%j.out
#SBATCH --error=logs/02_mapping_%j.err

# ===============================
# Step 2: Read Mapping & BAM Processing
# Tools: BWA, samtools, Picard
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_env

REF="ref/poloco_draft.fa"
TRIM_DIR="02_trimmed_reads"
ALIGN_DIR="03_alignments"
FILTER_DIR="04_bam_filtered"

mkdir -p $ALIGN_DIR $FILTER_DIR logs

echo "[INFO] Indexing reference..."
bwa index $REF
samtools faidx $REF

echo "[INFO] Mapping reads..."
for R1 in ${TRIM_DIR}/*_R1_trimmed.fastq.gz; do
    SAMPLE=$(basename $R1 | sed 's/_R1_trimmed.fastq.gz//')
    R2=${TRIM_DIR}/${SAMPLE}_R2_trimmed.fastq.gz
    
    # Mapping
    bwa mem -t 8 $REF $R1 $R2 | samtools view -Sb - > ${ALIGN_DIR}/${SAMPLE}.bam
    
    # Sort
    samtools sort -@ 8 -o ${ALIGN_DIR}/${SAMPLE}.sorted.bam ${ALIGN_DIR}/${SAMPLE}.bam
    rm ${ALIGN_DIR}/${SAMPLE}.bam
    
    # Mark duplicates
    picard MarkDuplicates I=${ALIGN_DIR}/${SAMPLE}.sorted.bam \
                          O=${ALIGN_DIR}/${SAMPLE}.dedup.bam \
                          M=${ALIGN_DIR}/${SAMPLE}.dup_metrics.txt \
                          REMOVE_DUPLICATES=true
    
    # Index
    samtools index ${ALIGN_DIR}/${SAMPLE}.dedup.bam
    
    # Filtering: keep only properly paired, MQ ≥ 30
    samtools view -b -q 30 -f 2 ${ALIGN_DIR}/${SAMPLE}.dedup.bam > ${FILTER_DIR}/${SAMPLE}.filtered.bam
    samtools index ${FILTER_DIR}/${SAMPLE}.filtered.bam
done

# Run QC plotting (Python script)
python qc_scripts/alignment_qc.py

echo "[OK] Mapping + filtering complete."
