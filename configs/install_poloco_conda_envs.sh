#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# PoLoCo conda environment installer
# ============================================================
# Usage:
#   bash configs/install_poloco_conda_envs.sh
#
# This single script defines and creates all conda environments
# required for the validated PoLoCo core workflow.
# ============================================================

echo "============================================================"
echo "Installing PoLoCo conda environments"
echo "============================================================"

if ! command -v conda >/dev/null 2>&1; then
    echo "[ERROR] conda was not found in your PATH."
    echo "Please install Miniconda or Anaconda before running this script."
    exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"
echo "[INFO] Conda found at: ${CONDA_BASE}"

TMP_ENV_DIR="$(mktemp -d)"
echo "[INFO] Writing temporary environment files to: ${TMP_ENV_DIR}"

cleanup() {
    rm -rf "${TMP_ENV_DIR}"
}
trap cleanup EXIT

cat > "${TMP_ENV_DIR}/poloco_qc_mapping.yml" <<'EOF'
name: poloco_qc_mapping
channels:
  - conda-forge
  - bioconda
  - defaults
dependencies:
  - python=3.10
  - pandas
  - numpy
  - matplotlib
  - seaborn
  - openpyxl
  - fastp
  - fastqc
  - multiqc
  - bwa
  - samtools
  - bcftools
  - bedtools
  - picard
EOF

cat > "${TMP_ENV_DIR}/poloco_poolseq.yml" <<'EOF'
name: poloco_poolseq
channels:
  - conda-forge
  - bioconda
  - defaults
dependencies:
  - python=3.10
  - pandas
  - numpy
  - scipy
  - matplotlib
  - seaborn
  - openpyxl
  - samtools
  - bcftools
  - htslib
  - vcftools
  - openjdk
  - perl
  - popoolation2
EOF

cat > "${TMP_ENV_DIR}/poloco_assembly.yml" <<'EOF'
name: poloco_assembly
channels:
  - conda-forge
  - bioconda
  - defaults
dependencies:
  - python=3.10
  - pandas
  - numpy
  - megahit
  - busco
  - quast
  - fastani
  - mummer4
  - samtools
  - jellyfish
EOF

create_env_if_missing() {
    local env_name="$1"
    local env_file="$2"

    if conda env list | awk '{print $1}' | grep -qx "${env_name}"; then
        echo "[SKIP] Environment ${env_name} already exists."
    else
        echo "[CREATE] Creating ${env_name}..."
        conda env create -f "${env_file}"
    fi
}

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
echo "Annotation tools are not included because annotation is not"
echo "part of the validated PoLoCo core workflow used in the manuscript."
