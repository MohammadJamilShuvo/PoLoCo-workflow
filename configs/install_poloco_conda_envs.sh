#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# PoLoCo conda environment installer
# ============================================================
# This script creates all conda environments required for the
# validated PoLoCo core workflow.
#
# Usage:
#   bash configs/install_poloco_conda_envs.sh
#
# PoLoCo uses modular conda environments internally to avoid
# dependency conflicts among bioinformatics tools. However, all
# environments are defined and installed from this single script
# to simplify setup for users.
# ============================================================

echo "============================================================"
echo "Installing PoLoCo conda environments"
echo "============================================================"

# ------------------------------------------------------------
# Check conda
# ------------------------------------------------------------

if ! command -v conda &> /dev/null; then
    echo "[ERROR] conda was not found in your PATH."
    echo "Please install Miniconda or Anaconda before running this script."
    exit 1
fi

CONDA_BASE=$(conda info --base)
source "${CONDA_BASE}/etc/profile.d/conda.sh"

echo "[INFO] Conda found at: ${CONDA_BASE}"

# ------------------------------------------------------------
# Temporary environment YAML directory
# ------------------------------------------------------------

TMP_ENV_DIR=$(mktemp -d)
echo "[INFO] Writing temporary environment files to: ${TMP_ENV_DIR}"

cleanup() {
    rm -rf "${TMP_ENV_DIR}"
}
trap cleanup EXIT

# ------------------------------------------------------------
# QC and mapping environment
# ------------------------------------------------------------

cat > "${TMP_ENV_DIR}/poloco_qc_mapping.yml" <<'EOF'
name: poloco_qc_mapping
channels:
  - bioconda
  - conda-forge
  - defaults
dependencies:
  - fastp
  - fastqc
  - multiqc
  - bwa
  - samtools
  - picard
  - python>=3.9
  - pandas
  - numpy
  - matplotlib
  - seaborn
  - openpyxl
EOF

# ------------------------------------------------------------
# Pool-seq environment
# ------------------------------------------------------------

cat > "${TMP_ENV_DIR}/poloco_poolseq.yml" <<'EOF'
name: poloco_poolseq
channels:
  - bioconda
  - conda-forge
  - defaults
dependencies:
  - samtools
  - perl
  - python>=3.9
  - pandas
  - numpy
  - matplotlib
  - seaborn
  - scipy
  - openpyxl
EOF

# ------------------------------------------------------------
# Assembly and validation environment
# ------------------------------------------------------------

cat > "${TMP_ENV_DIR}/poloco_assembly.yml" <<'EOF'
name: poloco_assembly
channels:
  - bioconda
  - conda-forge
  - defaults
dependencies:
  - megahit
  - busco
  - quast
  - fastani
  - mummer4
  - samtools
  - python>=3.9
  - pandas
  - numpy
EOF

# ------------------------------------------------------------
# Function to create environment if missing
# ------------------------------------------------------------

create_env_if_missing() {
    local ENV_NAME="$1"
    local ENV_FILE="$2"

    if conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
        echo "[SKIP] Environment ${ENV_NAME} already exists."
    else
        echo "[CREATE] Creating ${ENV_NAME}..."
        conda env create -f "${ENV_FILE}"
    fi
}

# ------------------------------------------------------------
# Create environments
# ------------------------------------------------------------

create_env_if_missing "poloco_qc_mapping" "${TMP_ENV_DIR}/poloco_qc_mapping.yml"
create_env_if_missing "poloco_poolseq" "${TMP_ENV_DIR}/poloco_poolseq.yml"
create_env_if_missing "poloco_assembly" "${TMP_ENV_DIR}/poloco_assembly.yml"

echo "============================================================"
echo "[DONE] PoLoCo conda environments are installed."
echo "============================================================"

echo ""
echo "Created or checked environments:"
echo "  - poloco_qc_mapping"
echo "  - poloco_poolseq"
echo "  - poloco_assembly"
echo ""
echo "To activate manually:"
echo "  conda activate poloco_qc_mapping"
echo "  conda activate poloco_poolseq"
echo "  conda activate poloco_assembly"
echo ""
echo "Annotation tools are not included because annotation is not part"
echo "of the validated PoLoCo core workflow used in the manuscript."
