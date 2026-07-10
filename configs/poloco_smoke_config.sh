#!/usr/bin/env bash

# ============================================================
# PoLoCo fixed lightweight smoke-test configuration
# ============================================================
# Use with:
#   bash scripts/run_poloco_pipeline.sh --mode full \
#     --config configs/poloco_smoke_config.sh
#
# This functional test checks workflow execution only. It does
# not reproduce the manuscript assembly statistics or results.
# ============================================================

set -u

PROJECT_PREFIX="poloco_smoke"

RAW_DIR="smoke_test/data"
ASSEMBLY_RAW_DIR="${RAW_DIR}/assembly"
POOL_RAW_DIR="${RAW_DIR}/pools"

READ1_SUFFIX="_R1.fastq.gz"
READ2_SUFFIX="_R2.fastq.gz"

TRIM_DIR="smoke_test/output/02_trimmed_reads"
ASSEMBLY_TRIM_DIR="${TRIM_DIR}/assembly"
POOL_TRIM_DIR="${TRIM_DIR}/pools"
TRIMMED_READ1_SUFFIX="_R1_trimmed.fastq.gz"
TRIMMED_READ2_SUFFIX="_R2_trimmed.fastq.gz"

QC_DIR="smoke_test/output/02_fastqc_reports"
ALIGN_DIR="smoke_test/output/03_alignments"
FILTERED_BAM_DIR="smoke_test/output/04_bam_filtered"
COVERAGE_DIR="smoke_test/output/05_coverage"
POOLSEQ_DIR="smoke_test/output/PoPoolation2"
POOLSEQ_METADATA_DIR="${POOLSEQ_DIR}/metadata"
POOLSEQ_RESULTS_DIR="${POOLSEQ_DIR}/results"
PLOTS_DIR="smoke_test/output/07_plots"
ASSEMBLY_DIR="smoke_test/output/08_assembly"
VALIDATION_DIR="smoke_test/output/09_validation"

ASSEMBLY_R1="${ASSEMBLY_RAW_DIR}/assembly_pool_R1.fastq.gz"
ASSEMBLY_R2="${ASSEMBLY_RAW_DIR}/assembly_pool_R2.fastq.gz"
ASSEMBLY_CONTIGS="${ASSEMBLY_DIR}/final.contigs.fa"

REF_DIR="smoke_test/output/ref"
REF_FASTA="${REF_DIR}/poloco_draft.fa"
PUBLISHED_REF="${REF_DIR}/ncbi_reference.fa"

QUAL_THRESHOLD=20
MIN_READ_LENGTH=50
MAPQ=20
BASEQ=15
REMOVE_DUPLICATES="yes"

MINCOV=2
MINPOP_MODE="absolute"
MINPOP_ABS=2
MINPOP_PROP=0.67
MAF=0.01
THIN_DIST=50

MIN_CONTIG_LEN=500
RUN_BUSCO="no"

THREADS_QC=2
THREADS_MAPPING=2
THREADS_POOLSEQ=2
THREADS_ASSEMBLY=2
THREADS_VALIDATION=2

MPILEUP2SYNC=""

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
