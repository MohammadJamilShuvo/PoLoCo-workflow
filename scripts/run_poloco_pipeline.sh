#!/bin/bash
#SBATCH --job-name=poloco_pipeline
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=logs/run_pipeline_%j.out
#SBATCH --error=logs/run_pipeline_%j.err

# ===============================
# PoLoCo Workflow Launcher
# Author: Mohammad Jamil Shuvo
# Manuscript: PoLoCo workflow for pooled draft genome + Pool-seq analysis
#
# Usage:
#   sbatch scripts/run_poloco_pipeline.sh --step all
#   sbatch scripts/run_poloco_pipeline.sh --step 1
#   sbatch scripts/run_poloco_pipeline.sh --step 3
#
# Steps:
#   1 = Preprocessing & QC
#   2 = Mapping & BAM filtering
#   3 = Coverage estimation
#   4 = ANGSD SNP calling
#   5 = QC visualization
#   6 = Genome assembly
#   7 = Assembly validation
#   8 = Annotation (optional)
#
# Conda environments:
#   poloco_qc_mapping  -> steps 1, 2, 3
#   poloco_angsd       -> steps 4, 5
#   poloco_assembly    -> steps 6, 7
#   poloco_annotation  -> step 8
# ===============================

# Default: run all steps
STEP="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --step)
      STEP="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

run_step() {
    local step=$1
    echo "[INFO] Running step $step ..."
    case $step in
        1) bash scripts/01_preprocessing_qc.sh ;;
        2) bash scripts/02_mapping_dedup_filter.sh ;;
        3) bash scripts/03_coverage_depth.sh ;;
        4) bash scripts/04_angsd_snp_calling.sh ;;
        5) bash scripts/05_qc_visualization.sh ;;
        6) bash scripts/06_assembly.sh ;;
        7) bash scripts/07_validation.sh ;;
        8) bash scripts/08_annotation.sh ;;
        *) echo "[ERROR] Unknown step: $step" ;;
    esac
}

if [[ "$STEP" == "all" ]]; then
    for i in {1..8}; do
        run_step $i
    done
else
    run_step $STEP
fi

echo "[OK] Pipeline finished."

