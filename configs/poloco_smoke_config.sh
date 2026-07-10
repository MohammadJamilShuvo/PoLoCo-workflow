#!/usr/bin/env bash

# ============================================================
# PoLoCo fixed smoke-test configuration override
# ============================================================
# Use with:
#   POLOCO_OVERRIDE_CONFIG=configs/poloco_smoke_config.sh \
#     bash scripts/run_poloco_pipeline.sh --mode full
#
# This file is sourced after configs/poloco_config.sh and replaces
# only the settings needed for the lightweight fixed smoke test.
# ============================================================

PROJECT_PREFIX="poloco_smoke"

# Fixed smoke-test inputs
RAW_DIR="smoke_test/data"
ASSEMBLY_RAW_DIR="${RAW_DIR}/assembly"
POOL_RAW_DIR="${RAW_DIR}/pools"

ASSEMBLY_R1="${ASSEMBLY_RAW_DIR}/assembly_pool_R1.fastq.gz"
ASSEMBLY_R2="${ASSEMBLY_RAW_DIR}/assembly_pool_R2.fastq.gz"

# Keep all generated smoke-test outputs separate
SMOKE_OUTPUT_DIR="smoke_test/output"

TRIM_DIR="${SMOKE_OUTPUT_DIR}/02_trimmed_reads"
ASSEMBLY_TRIM_DIR="${TRIM_DIR}/assembly"
POOL_TRIM_DIR="${TRIM_DIR}/pools"

QC_DIR="${SMOKE_OUTPUT_DIR}/02_fastqc_reports"
ALIGN_DIR="${SMOKE_OUTPUT_DIR}/03_alignments"
FILTERED_BAM_DIR="${SMOKE_OUTPUT_DIR}/04_bam_filtered"
COVERAGE_DIR="${SMOKE_OUTPUT_DIR}/05_coverage"

POOLSEQ_DIR="${SMOKE_OUTPUT_DIR}/PoPoolation2"
POOLSEQ_METADATA_DIR="${POOLSEQ_DIR}/metadata"
POOLSEQ_RESULTS_DIR="${POOLSEQ_DIR}/results"

PLOTS_DIR="${SMOKE_OUTPUT_DIR}/07_plots"
ASSEMBLY_DIR="${SMOKE_OUTPUT_DIR}/08_assembly"
VALIDATION_DIR="${SMOKE_OUTPUT_DIR}/09_validation"

ASSEMBLY_CONTIGS="${ASSEMBLY_DIR}/final.contigs.fa"

REF_DIR="${SMOKE_OUTPUT_DIR}/ref"
REF_FASTA="${REF_DIR}/poloco_draft.fa"
PUBLISHED_REF="${REF_DIR}/ncbi_reference.fa"

# Lightweight smoke-test thresholds
MINCOV=2
MINPOP_MODE="absolute"
MINPOP_ABS=2
MINPOP_PROP=0.67
MAF=0.01
THIN_DIST=50

# Lightweight assembly settings
MIN_CONTIG_LEN=500
RUN_BUSCO="no"

# WSL-friendly resources
THREADS_QC=2
THREADS_MAPPING=2
THREADS_POOLSEQ=2
THREADS_ASSEMBLY=2
THREADS_VALIDATION=2
