#!/usr/bin/env bash
#SBATCH --job-name=poloco_assembly
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=logs/02_assembly_%j.out
#SBATCH --error=logs/02_assembly_%j.err

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

activate_env poloco_assembly
mkdir -p logs "${REF_DIR}"

R1="${ASSEMBLY_TRIM_DIR}/assembly_pool${TRIMMED_READ1_SUFFIX}"
R2="${ASSEMBLY_TRIM_DIR}/assembly_pool${TRIMMED_READ2_SUFFIX}"

if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "[WARN] Trimmed assembly reads not found. Using raw assembly reads from config."
    R1="${ASSEMBLY_R1}"
    R2="${ASSEMBLY_R2}"
fi

if [[ ! -f "$R1" || ! -f "$R2" ]]; then
    echo "[ERROR] Assembly read pair not found."
    echo "[ERROR] R1: $R1"
    echo "[ERROR] R2: $R2"
    exit 1
fi

echo "[INFO] Running MEGAHIT assembly from assembly-only library."
echo "[INFO] R1: $R1"
echo "[INFO] R2: $R2"

if [[ -f "${ASSEMBLY_CONTIGS}" ]]; then
    echo "[SKIP] Existing assembly found: ${ASSEMBLY_CONTIGS}"
else
    if [[ -d "${ASSEMBLY_DIR}" ]]; then
        echo "[ERROR] ${ASSEMBLY_DIR} exists but ${ASSEMBLY_CONTIGS} was not found."
        echo "[ERROR] Remove or rename ${ASSEMBLY_DIR} before re-running assembly."
        exit 1
    fi
    megahit \
      -1 "$R1" \
      -2 "$R2" \
      -o "${ASSEMBLY_DIR}" \
      --min-contig-len 1000 \
      -t "${THREADS_ASSEMBLY}"
fi

if [[ ! -f "${ASSEMBLY_CONTIGS}" ]]; then
    echo "[ERROR] Expected assembly output not found: ${ASSEMBLY_CONTIGS}"
    exit 1
fi

echo "[INFO] Preparing draft reference for downstream mapping..."
mkdir -p "${REF_DIR}"
cp -f "${ASSEMBLY_CONTIGS}" "${REF_FASTA}"
echo "[OK] Draft reference written to: ${REF_FASTA}"

if command -v samtools >/dev/null 2>&1; then
    samtools faidx "${REF_FASTA}"
else
    echo "[WARN] samtools not available in current environment; FASTA indexing will be done later if needed."
fi

if command -v bwa >/dev/null 2>&1; then
    bwa index "${REF_FASTA}"
else
    echo "[WARN] bwa not available in current environment; BWA indexing will be done during mapping."
fi

echo "[INFO] Running BUSCO on draft assembly..."
if [[ -d "${ASSEMBLY_DIR}/busco_results" ]]; then
    echo "[SKIP] Existing BUSCO output found: ${ASSEMBLY_DIR}/busco_results"
else
    busco \
      -i "${REF_FASTA}" \
      -l arthropoda_odb10 \
      -o busco_results \
      -m genome \
      -c "${THREADS_ASSEMBLY}" \
      --out_path "${ASSEMBLY_DIR}"
fi

echo "[OK] Assembly, reference preparation, and BUSCO finished."
