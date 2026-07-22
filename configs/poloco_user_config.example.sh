#!/usr/bin/env bash

# ============================================================
# PoLoCo user-project configuration override
# ============================================================
# Copy before editing:
#
#   cp configs/poloco_user_config.example.sh \
#      configs/my_project_config.sh
#
# Run locally:
#
#   POLOCO_OVERRIDE_CONFIG=configs/my_project_config.sh \
#     bash scripts/run_poloco_pipeline.sh --mode full
#
# Run on SLURM:
#
#   bash hpc/submit_poloco_slurm.sh \
#     --mode full \
#     --config configs/my_project_config.sh
#
# This file is sourced after configs/poloco_config.sh.
# ============================================================

PROJECT_PREFIX="my_project"

# Keep each dataset and parameter set in an independent root.
PROJECT_OUTPUT_ROOT="projects/my_project"

# Input folders
RAW_DIR="${PROJECT_OUTPUT_ROOT}/01_raw_reads"
ASSEMBLY_RAW_DIR="${RAW_DIR}/assembly"
POOL_RAW_DIR="${RAW_DIR}/pools"

READ1_SUFFIX="_R1.fastq.gz"
READ2_SUFFIX="_R2.fastq.gz"

# Assembly read pair
ASSEMBLY_R1="${ASSEMBLY_RAW_DIR}/assembly_pool_R1.fastq.gz"
ASSEMBLY_R2="${ASSEMBLY_RAW_DIR}/assembly_pool_R2.fastq.gz"

# Trimmed reads
TRIM_DIR="${PROJECT_OUTPUT_ROOT}/02_trimmed_reads"
ASSEMBLY_TRIM_DIR="${TRIM_DIR}/assembly"
POOL_TRIM_DIR="${TRIM_DIR}/pools"

# Output folders
QC_DIR="${PROJECT_OUTPUT_ROOT}/02_fastqc_reports"
ALIGN_DIR="${PROJECT_OUTPUT_ROOT}/03_alignments"
FILTERED_BAM_DIR="${PROJECT_OUTPUT_ROOT}/04_bam_filtered"
COVERAGE_DIR="${PROJECT_OUTPUT_ROOT}/05_coverage"

POOLSEQ_DIR="${PROJECT_OUTPUT_ROOT}/PoPoolation2"
POOLSEQ_METADATA_DIR="${POOLSEQ_DIR}/metadata"
POOLSEQ_RESULTS_DIR="${POOLSEQ_DIR}/results"

PLOTS_DIR="${PROJECT_OUTPUT_ROOT}/07_plots"
ASSEMBLY_DIR="${PROJECT_OUTPUT_ROOT}/08_assembly"
VALIDATION_DIR="${PROJECT_OUTPUT_ROOT}/09_validation"

ASSEMBLY_CONTIGS="${ASSEMBLY_DIR}/final.contigs.fa"

# Reference paths
REF_DIR="${PROJECT_OUTPUT_ROOT}/ref"
REF_FASTA="${REF_DIR}/poloco_draft.fa"

# Optional external reference for Step 03.
# It is safe for this file to be absent when no appropriate reference exists.
PUBLISHED_REF="${REF_DIR}/external_reference.fa"

# Read preprocessing
QUAL_THRESHOLD=20
MIN_READ_LENGTH=50

# Mapping
MAPQ=30
BASEQ=20
REMOVE_DUPLICATES="yes"

# Pool-seq filtering
MINCOV=4

# Review this threshold scientifically for the actual number of pools.
MINPOP_MODE="proportion"
MINPOP_PROP=0.67

# Used only when MINPOP_MODE="absolute".
MINPOP_ABS=2

MAF=0.05
THIN_DIST=200

# Assembly and validation
MIN_CONTIG_LEN=1000
RUN_BUSCO="yes"

# Do not set thread values above the allocated CPUs.
THREADS_QC=4
THREADS_MAPPING=8
THREADS_POOLSEQ=8
THREADS_ASSEMBLY=16
THREADS_VALIDATION=8

# Leave empty for automatic discovery in poloco_poolseq.
MPILEUP2SYNC=""
