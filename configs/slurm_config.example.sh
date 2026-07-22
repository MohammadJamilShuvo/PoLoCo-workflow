#!/usr/bin/env bash

# ============================================================
# Site-specific PoLoCo SLURM configuration
# ============================================================
# Copy before editing:
#
#   cp configs/slurm_config.example.sh configs/slurm_config.sh
#
# The local configs/slurm_config.sh file is ignored by Git.
# ============================================================

SLURM_PARTITION=""
SLURM_ACCOUNT=""
SLURM_QOS=""

# Commands executed inside every compute job before Conda is initialized.
MODULE_SETUP=""

# Optional direct path to conda.sh.
CONDA_INIT=""

# Optional Conda locations in project/workspace storage.
CONDA_ENVS_DIR=""
CONDA_PKGS_DIR=""

# Leave empty when the site does not support this option.
SLURM_THREADS_PER_CORE="1"

# Additional site-specific sbatch arguments.
# Example:
# SBATCH_EXTRA=(--constraint=my_constraint)
SBATCH_EXTRA=()

# Tested bwUniCluster 3 example:
# SLURM_PARTITION="cpu_il"
# MODULE_SETUP='module purge; module load devel/miniforge'

CHECK_CPUS=1
CHECK_MEM="4G"
CHECK_TIME="01:00:00"

PREPROCESS_CPUS=4
PREPROCESS_MEM="32G"
PREPROCESS_TIME="48:00:00"

ASSEMBLY_CPUS=16
ASSEMBLY_MEM="128G"
ASSEMBLY_TIME="72:00:00"

VALIDATION_CPUS=8
VALIDATION_MEM="64G"
VALIDATION_TIME="24:00:00"

MAPPING_CPUS=8
MAPPING_MEM="64G"
MAPPING_TIME="72:00:00"

COVERAGE_CPUS=4
COVERAGE_MEM="16G"
COVERAGE_TIME="72:00:00"

POOLSEQ_CPUS=8
POOLSEQ_MEM="64G"
POOLSEQ_TIME="72:00:00"

QC_CPUS=2
QC_MEM="16G"
QC_TIME="12:00:00"
