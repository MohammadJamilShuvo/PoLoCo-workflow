#!/usr/bin/env bash
#SBATCH --job-name=poloco_validation
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/03_validation_%j.out
#SBATCH --error=logs/03_validation_%j.err

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
mkdir -p "${VALIDATION_DIR}" logs

if [[ ! -f "${REF_FASTA}" ]]; then
    echo "[ERROR] Draft reference not found: ${REF_FASTA}"
    echo "[ERROR] Run 02_assembly.sh first, or provide a reference at this path."
    exit 1
fi

echo "[INFO] Running QUAST on draft reference..."
quast.py "${REF_FASTA}" -o "${VALIDATION_DIR}/quast_draft" -t "${THREADS_VALIDATION}"

if [[ -f "${PUBLISHED_REF}" ]]; then
    echo "[INFO] Published/reference genome found: ${PUBLISHED_REF}"
    echo "[INFO] Running comparative QUAST..."
    quast.py "${REF_FASTA}" -r "${PUBLISHED_REF}" -o "${VALIDATION_DIR}/quast_vs_published" -t "${THREADS_VALIDATION}"

    echo "[INFO] Running FastANI..."
    fastANI -q "${REF_FASTA}" -r "${PUBLISHED_REF}" -o "${VALIDATION_DIR}/${PROJECT_PREFIX}_fastani.tsv" -t "${THREADS_VALIDATION}" || \
      echo "[WARN] FastANI did not complete successfully. See validation logs."

    if command -v nucmer >/dev/null 2>&1; then
        echo "[INFO] Running MUMmer/nucmer alignment..."
        nucmer --prefix="${VALIDATION_DIR}/${PROJECT_PREFIX}_nucmer" "${PUBLISHED_REF}" "${REF_FASTA}" || \
          echo "[WARN] nucmer did not complete successfully."
        if command -v mummerplot >/dev/null 2>&1; then
            mummerplot --png --prefix="${VALIDATION_DIR}/${PROJECT_PREFIX}_nucmer_plot" "${VALIDATION_DIR}/${PROJECT_PREFIX}_nucmer.delta" || \
              echo "[WARN] mummerplot did not complete successfully."
        fi
    fi
else
    echo "[WARN] No published/reference genome found at ${PUBLISHED_REF}."
    echo "[WARN] Skipping comparative QUAST, FastANI, and MUMmer alignment."
fi

echo "[OK] Validation finished."
