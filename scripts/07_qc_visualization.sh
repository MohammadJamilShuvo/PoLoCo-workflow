#!/usr/bin/env bash
#SBATCH --job-name=poloco_qcplots
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=logs/07_qc_visualization_%j.out
#SBATCH --error=logs/07_qc_visualization_%j.err

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

activate_env poloco_poolseq
mkdir -p "${PLOTS_DIR}" logs

python qc_scripts/alignment_qc.py
python qc_scripts/poolseq_af_qc.py
python qc_scripts/poolseq_summary_stats_qc.py
python qc_scripts/final_qc_master.py

echo "[OK] QC visualization and master summary finished."
