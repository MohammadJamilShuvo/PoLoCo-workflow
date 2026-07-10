#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"
mkdir -p logs

usage() {
    cat <<USAGE
PoLoCo sequential workflow runner

Run this with bash on a workstation or inside an interactive HPC allocation.
For SLURM batch execution, submit the numbered scripts separately.

Usage:
  bash scripts/run_poloco_pipeline.sh --mode full
  bash scripts/run_poloco_pipeline.sh --mode poolseq-only
  bash scripts/run_poloco_pipeline.sh --mode assembly-only
  bash scripts/run_poloco_pipeline.sh --step 06

Modes:
  full          Run complete case-study workflow: check, preprocess, assembly, validation, mapping, coverage, Pool-seq, QC
  poolseq-only  Run preprocessing, mapping, coverage, Pool-seq, QC using an existing ref/poloco_draft.fa
  assembly-only Run preprocessing, assembly/reference preparation, validation

Steps:
  00 check inputs
  01 preprocessing and QC
  02 assembly and reference preparation
  03 validation
  04 mapping and BAM filtering
  05 coverage estimation
  06 Pool-seq sync and allele-frequency matrix
  07 QC visualization
USAGE
}

run_step() {
    local step="$1"
    case "$step" in
        00) bash scripts/00_check_inputs.sh "${CURRENT_MODE:-full}" ;;
        01) bash scripts/01_preprocessing_qc.sh ;;
        02) bash scripts/02_assembly.sh ;;
        03) bash scripts/03_validation.sh ;;
        04) bash scripts/04_mapping_dedup_filter.sh ;;
        05) bash scripts/05_coverage_depth.sh ;;
        06) bash scripts/06_poolseq_pipeline.sh ;;
        07) bash scripts/07_qc_visualization.sh ;;
        *) echo "[ERROR] Unknown step: $step"; usage; exit 1 ;;
    esac
}

if [[ "$#" -eq 0 ]]; then
    usage
    exit 1
fi

CURRENT_MODE=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --mode)
            CURRENT_MODE="${2:-}"
            shift 2
            ;;
        --step)
            STEP="${2:-}"
            run_step "$STEP"
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

case "${CURRENT_MODE}" in
    full)
        run_step 00
        run_step 01
        run_step 02
        run_step 03
        run_step 04
        run_step 05
        run_step 06
        run_step 07
        ;;
    poolseq-only)
        run_step 00
        run_step 01
        run_step 04
        run_step 05
        run_step 06
        run_step 07
        ;;
    assembly-only)
        run_step 00
        run_step 01
        run_step 02
        run_step 03
        ;;
    *)
        echo "[ERROR] Unknown or missing mode: ${CURRENT_MODE}"
        usage
        exit 1
        ;;
esac

echo "[OK] PoLoCo workflow completed: ${CURRENT_MODE}"
