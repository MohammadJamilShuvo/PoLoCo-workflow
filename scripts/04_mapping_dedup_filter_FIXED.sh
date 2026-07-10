#!/usr/bin/env bash
#SBATCH --job-name=poloco_mapping
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output=logs/04_mapping_%j.out
#SBATCH --error=logs/04_mapping_%j.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

set -a
source "configs/poloco_config.sh"
set +a

activate_env() {
    local env_name="$1"
    if command -v conda >/dev/null 2>&1; then
        source "$(conda info --base)/etc/profile.d/conda.sh"
        conda activate "${env_name}"
    else
        echo "[WARN] conda not found. Continuing without activating ${env_name}."
    fi
}

activate_env poloco_qc_mapping
mkdir -p "${ALIGN_DIR}" "${FILTERED_BAM_DIR}" logs

if [[ ! -f "${REF_FASTA}" ]]; then
    echo "[ERROR] Reference genome not found: ${REF_FASTA}"
    echo "[ERROR] Run 02_assembly.sh first or provide a reference at this path."
    exit 1
fi

if [[ ! -f "${REF_FASTA}.bwt" ]]; then
    echo "[INFO] BWA index not found. Running bwa index..."
    bwa index "${REF_FASTA}"
fi
if [[ ! -f "${REF_FASTA}.fai" ]]; then
    echo "[INFO] FASTA index not found. Running samtools faidx..."
    samtools faidx "${REF_FASTA}"
fi

echo "[INFO] Mapping Pool-seq libraries from ${POOL_TRIM_DIR} to ${REF_FASTA}"
shopt -s nullglob
count=0
for r1 in "${POOL_TRIM_DIR}"/*"${TRIMMED_READ1_SUFFIX}"; do
    base="$(basename "$r1")"
    sample="${base%${TRIMMED_READ1_SUFFIX}}"
    r2="${POOL_TRIM_DIR}/${sample}${TRIMMED_READ2_SUFFIX}"
    if [[ ! -f "$r2" ]]; then
        echo "[ERROR] Missing trimmed R2 for sample ${sample}: $r2"
        exit 1
    fi

    sam="${ALIGN_DIR}/${sample}.sam"
    sorted_bam="${ALIGN_DIR}/${sample}.sorted.bam"
    dedup_bam="${ALIGN_DIR}/${sample}.dedup.bam"
    metrics="${ALIGN_DIR}/${sample}.dedup_metrics.txt"
    filtered_bam="${FILTERED_BAM_DIR}/${sample}.filtered.bam"

    echo "[INFO] Mapping sample: ${sample}"
    read_group="@RG\tID:${sample}\tSM:${sample}\tPL:ILLUMINA"
    bwa mem       -t "${THREADS_MAPPING}"       -R "${read_group}"       "${REF_FASTA}" "$r1" "$r2" > "$sam"

    samtools sort -@ "${THREADS_MAPPING}" -o "$sorted_bam" "$sam"
    rm -f "$sam"
    samtools index "$sorted_bam"

    if [[ "${REMOVE_DUPLICATES}" == "yes" ]]; then
        picard MarkDuplicates           I="$sorted_bam"           O="$dedup_bam"           M="$metrics"           REMOVE_DUPLICATES=true           READ_NAME_REGEX=null           VALIDATION_STRINGENCY=SILENT
        samtools index "$dedup_bam"
        samtools view -@ "${THREADS_MAPPING}" -b -f 2 -q "${MAPQ}" "$dedup_bam" > "$filtered_bam"
    else
        samtools view -@ "${THREADS_MAPPING}" -b -f 2 -q "${MAPQ}" "$sorted_bam" > "$filtered_bam"
    fi

    samtools index "$filtered_bam"
    count=$((count + 1))
done
shopt -u nullglob

if [[ "$count" -eq 0 ]]; then
    echo "[ERROR] No trimmed Pool-seq R1 files found in ${POOL_TRIM_DIR}."
    echo "[ERROR] Run 01_preprocessing_qc.sh first."
    exit 1
fi

echo "[OK] Mapping and BAM filtering finished for ${count} Pool-seq libraries."
