#!/usr/bin/env bash
#SBATCH --job-name=poloco_check
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=logs/00_check_inputs_%j.out
#SBATCH --error=logs/00_check_inputs_%j.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

CONFIG_FILE="${PROJECT_ROOT}/configs/poloco_config.sh"
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "[ERROR] Missing config file: ${CONFIG_FILE}"
    exit 1
fi

set -a
source "${CONFIG_FILE}"
set +a

mkdir -p logs

MODE="${1:-full}"

check_dir() {
    local d="$1"
    local label="$2"
    if [[ ! -d "$d" ]]; then
        echo "[ERROR] Missing ${label} directory: $d"
        exit 1
    fi
}

check_file() {
    local f="$1"
    local label="$2"
    if [[ ! -f "$f" ]]; then
        echo "[ERROR] Missing ${label}: $f"
        exit 1
    fi
}

check_paired_reads() {
    local dir="$1"
    local label="$2"
    local n=0
    shopt -s nullglob
    for r1 in "${dir}"/*"${READ1_SUFFIX}"; do
        local base sample r2
        base="$(basename "$r1")"
        sample="${base%${READ1_SUFFIX}}"
        r2="${dir}/${sample}${READ2_SUFFIX}"
        if [[ ! -f "$r2" ]]; then
            echo "[ERROR] Missing R2 pair for $r1"
            echo "[ERROR] Expected: $r2"
            exit 1
        fi
        n=$((n + 1))
    done
    shopt -u nullglob

    if [[ "$n" -eq 0 ]]; then
        echo "[ERROR] No paired-end reads found for ${label} in $dir"
        echo "[ERROR] Expected files ending in ${READ1_SUFFIX} and ${READ2_SUFFIX}"
        exit 1
    fi
    echo "[OK] ${label} paired-end libraries detected: $n"
}

check_tool_path_warn() {
    local f="$1"
    local label="$2"
    if [[ ! -f "$f" ]]; then
        echo "[WARN] ${label} not found at: $f"
        echo "[WARN] Update configs/poloco_config.sh if needed."
    else
        echo "[OK] ${label}: $f"
    fi
}

echo "============================================================"
echo "PoLoCo input and configuration check"
echo "============================================================"
echo "[INFO] Mode: ${MODE}"
echo "[INFO] Project prefix: ${PROJECT_PREFIX}"

check_dir "${RAW_DIR}" "raw-read"

if [[ "${MODE}" == "full" || "${MODE}" == "assembly-only" ]]; then
    check_dir "${ASSEMBLY_RAW_DIR}" "assembly raw-read"
    check_file "${ASSEMBLY_R1}" "assembly R1"
    check_file "${ASSEMBLY_R2}" "assembly R2"
fi

if [[ "${MODE}" == "full" || "${MODE}" == "poolseq-only" ]]; then
    check_dir "${POOL_RAW_DIR}" "Pool-seq raw-read"
    check_paired_reads "${POOL_RAW_DIR}" "Pool-seq"
fi

if [[ "${MODE}" == "poolseq-only" ]]; then
    check_file "${REF_FASTA}" "reference genome"
fi

echo "[INFO] MINCOV=${MINCOV}"
echo "[INFO] MINPOP_MODE=${MINPOP_MODE}"
echo "[INFO] MINPOP_ABS=${MINPOP_ABS}"
echo "[INFO] MINPOP_PROP=${MINPOP_PROP}"
echo "[INFO] MAF=${MAF}"
echo "[INFO] THIN_DIST=${THIN_DIST}"
echo "[INFO] MAPQ=${MAPQ}; BASEQ=${BASEQ}"

if [[ "${MODE}" == "full" || "${MODE}" == "poolseq-only" ]]; then
    check_tool_path_warn "${MPILEUP2SYNC}" "PoPoolation2 mpileup2sync.pl"
fi

echo "[OK] Input and configuration check completed."
