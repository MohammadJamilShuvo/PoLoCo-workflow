#!/usr/bin/env bash
#SBATCH --job-name=poloco_coverage
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=logs/05_coverage_%j.out
#SBATCH --error=logs/05_coverage_%j.err

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
mkdir -p "${COVERAGE_DIR}" logs

shopt -s nullglob
bams=("${FILTERED_BAM_DIR}"/*.filtered.bam)
shopt -u nullglob

if [[ "${#bams[@]}" -eq 0 ]]; then
    echo "[ERROR] No filtered BAM files found in ${FILTERED_BAM_DIR}."
    exit 1
fi

summary="${COVERAGE_DIR}/${PROJECT_PREFIX}_coverage_summary.tsv"
echo -e "Sample\tMean_Coverage" > "$summary"

for bam in "${bams[@]}"; do
    sample="$(basename "$bam" .filtered.bam)"
    out="${COVERAGE_DIR}/${sample}_coverage.txt"
    echo "[INFO] Estimating coverage for ${sample}"
    mean_cov=$(samtools depth -a "$bam" | awk '{sum+=$3; n++} END {if(n>0) print sum/n; else print 0}')
    echo -e "${sample}\t${mean_cov}" > "$out"
    echo -e "${sample}\t${mean_cov}" >> "$summary"
done

echo "[OK] Coverage estimation finished. Summary: ${summary}"
