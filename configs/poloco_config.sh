#!/usr/bin/env bash

# ============================================================
# PoLoCo central configuration file
# ============================================================
# Default values reproduce the Entomobrya nivalis case study:
# 1 assembly pool, 82 Pool-seq libraries, MINPOP 55/82,
# MAF 0.05, and 200 bp distance thinning.
# For a new project, edit project label, input folders,
# reference paths, thresholds, and PoPoolation2 path if needed.
# ============================================================

set -u

# Project label
PROJECT_PREFIX="envilis"

# Input folders
RAW_DIR="01_raw_reads"
ASSEMBLY_RAW_DIR="${RAW_DIR}/assembly"
POOL_RAW_DIR="${RAW_DIR}/pools"

READ1_SUFFIX="_R1.fastq.gz"
READ2_SUFFIX="_R2.fastq.gz"

# Trimmed-read folders
TRIM_DIR="02_trimmed_reads"
ASSEMBLY_TRIM_DIR="${TRIM_DIR}/assembly"
POOL_TRIM_DIR="${TRIM_DIR}/pools"

TRIMMED_READ1_SUFFIX="_R1_trimmed.fastq.gz"
TRIMMED_READ2_SUFFIX="_R2_trimmed.fastq.gz"

# Output folders
QC_DIR="02_fastqc_reports"
ALIGN_DIR="03_alignments"
FILTERED_BAM_DIR="04_bam_filtered"
COVERAGE_DIR="05_coverage"

POOLSEQ_DIR="PoPoolation2"
POOLSEQ_METADATA_DIR="${POOLSEQ_DIR}/metadata"
POOLSEQ_RESULTS_DIR="${POOLSEQ_DIR}/results"

PLOTS_DIR="07_plots"
ASSEMBLY_DIR="08_assembly"
VALIDATION_DIR="09_validation"

# Assembly input/output
ASSEMBLY_R1="${ASSEMBLY_RAW_DIR}/assembly_pool_R1.fastq.gz"
ASSEMBLY_R2="${ASSEMBLY_RAW_DIR}/assembly_pool_R2.fastq.gz"
ASSEMBLY_CONTIGS="${ASSEMBLY_DIR}/final.contigs.fa"

# Reference genome paths
REF_DIR="ref"
REF_FASTA="${REF_DIR}/poloco_draft.fa"
PUBLISHED_REF="${REF_DIR}/ncbi_reference.fa"

# Read preprocessing
QUAL_THRESHOLD=20
MIN_READ_LENGTH=50

# Mapping and pileup
MAPQ=30
BASEQ=20
REMOVE_DUPLICATES="yes"

# Pool-seq filtering
MINCOV=4

# MINPOP options:
# Case study: MINPOP_MODE="absolute"; MINPOP_ABS=55
# Other datasets: MINPOP_MODE="proportion"; MINPOP_PROP=0.67
MINPOP_MODE="absolute"
MINPOP_ABS=55
MINPOP_PROP=0.67

MAF=0.05
THIN_DIST=200

# Assembly and validation controls
MIN_CONTIG_LEN=1000
RUN_BUSCO="yes"

# Resources
THREADS_QC=4
THREADS_MAPPING=8
THREADS_POOLSEQ=8
THREADS_ASSEMBLY=16
THREADS_VALIDATION=8

# Optional PoPoolation2 override. Leave empty for automatic discovery
# inside the poloco_poolseq conda environment.
MPILEUP2SYNC=""

# Optional dataset-specific override.
# Example smoke-test run:
#   POLOCO_OVERRIDE_CONFIG=configs/poloco_smoke_config.sh \
#     bash scripts/run_poloco_pipeline.sh --mode full
#
# The workflow scripts always source this main configuration file.
# When POLOCO_OVERRIDE_CONFIG is set, the selected override file is
# loaded afterward and replaces only the values needed for that run.
if [[ -n "${POLOCO_OVERRIDE_CONFIG:-}" ]]; then
    if [[ ! -f "${POLOCO_OVERRIDE_CONFIG}" ]]; then
        echo "[ERROR] Configuration override not found: ${POLOCO_OVERRIDE_CONFIG}" >&2
        return 1 2>/dev/null || exit 1
    fi
    source "${POLOCO_OVERRIDE_CONFIG}"
fi

# Helper function for scripts:
#   MINPOP=$(get_minpop "$N_POOLS")
get_minpop() {
    local n_pools="$1"

    if [[ "${MINPOP_MODE}" == "absolute" ]]; then
        echo "${MINPOP_ABS}"
    elif [[ "${MINPOP_MODE}" == "proportion" ]]; then
        python - <<EOF
import math
print(math.ceil(float(${n_pools}) * float(${MINPOP_PROP})))
EOF
    else
        echo "[ERROR] MINPOP_MODE must be 'absolute' or 'proportion'." >&2
        exit 1
    fi
}
