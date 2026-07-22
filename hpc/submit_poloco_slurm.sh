#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

MODE=""
OVERRIDE_CONFIG=""
SITE_CONFIG="configs/slurm_config.sh"

usage() {
    cat <<'USAGE'
PoLoCo SLURM workflow launcher

Usage:
  bash hpc/submit_poloco_slurm.sh --mode full
  bash hpc/submit_poloco_slurm.sh --mode full --config configs/poloco_smoke_config.sh
  bash hpc/submit_poloco_slurm.sh --mode full --config configs/my_project_config.sh
  bash hpc/submit_poloco_slurm.sh --mode assembly-only --config configs/my_project_config.sh
  bash hpc/submit_poloco_slurm.sh --mode poolseq-only --config configs/my_project_config.sh

Options:
  --mode          full, assembly-only, or poolseq-only
  --config        optional dataset-specific override
  --slurm-config  site config; default: configs/slurm_config.sh
  -h, --help      show help

Omit --config to use the permanent configs/poloco_config.sh defaults.
USAGE
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        --config)
            OVERRIDE_CONFIG="${2:-}"
            shift 2
            ;;
        --slurm-config)
            SITE_CONFIG="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

case "${MODE}" in
    full|assembly-only|poolseq-only) ;;
    *)
        echo "[ERROR] --mode must be full, assembly-only, or poolseq-only." >&2
        usage
        exit 1
        ;;
esac

if ! command -v sbatch >/dev/null 2>&1; then
    echo "[ERROR] sbatch was not found." >&2
    exit 1
fi

if [[ ! -f "${SITE_CONFIG}" ]]; then
    echo "[ERROR] SLURM configuration not found: ${SITE_CONFIG}" >&2
    echo "Create it with:" >&2
    echo "  cp configs/slurm_config.example.sh configs/slurm_config.sh" >&2
    exit 1
fi

SITE_CONFIG="$(realpath "${SITE_CONFIG}")"

if [[ -n "${OVERRIDE_CONFIG}" ]]; then
    if [[ ! -f "${OVERRIDE_CONFIG}" ]]; then
        echo "[ERROR] Override configuration not found: ${OVERRIDE_CONFIG}" >&2
        exit 1
    fi
    OVERRIDE_CONFIG="$(realpath "${OVERRIDE_CONFIG}")"
    if [[ "${OVERRIDE_CONFIG}" == "$(realpath configs/poloco_config.sh)" ]]; then
        echo "[ERROR] Omit --config to use configs/poloco_config.sh." >&2
        exit 1
    fi
    export POLOCO_OVERRIDE_CONFIG="${OVERRIDE_CONFIG}"
else
    unset POLOCO_OVERRIDE_CONFIG
fi

# Load and validate workflow thread settings before submission.
set -a
source configs/poloco_config.sh
set +a

# Default site settings, then local overrides.
SLURM_PARTITION=""
SLURM_ACCOUNT=""
SLURM_QOS=""
SLURM_THREADS_PER_CORE="1"
SBATCH_EXTRA=()

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

# shellcheck disable=SC1090
source "${SITE_CONFIG}"

check_threads() {
    local configured="$1"
    local allocated="$2"
    local label="$3"
    if (( configured > allocated )); then
        echo "[ERROR] ${label} threads (${configured}) exceed allocated CPUs (${allocated})." >&2
        echo "[ERROR] Adjust the project override or configs/slurm_config.sh." >&2
        exit 1
    fi
}

check_threads "${THREADS_QC}" "${PREPROCESS_CPUS}" "THREADS_QC"
check_threads "${THREADS_ASSEMBLY}" "${ASSEMBLY_CPUS}" "THREADS_ASSEMBLY"
check_threads "${THREADS_VALIDATION}" "${VALIDATION_CPUS}" "THREADS_VALIDATION"
check_threads "${THREADS_MAPPING}" "${MAPPING_CPUS}" "THREADS_MAPPING"
check_threads "${THREADS_POOLSEQ}" "${POOLSEQ_CPUS}" "THREADS_POOLSEQ"

mkdir -p logs reproducibility_records

timestamp="$(date +%Y%m%d_%H%M%S)"
JOB_FILE="reproducibility_records/poloco_slurm_jobs_${timestamp}.tsv"
printf "Step\tJobID\tDescription\n" > "${JOB_FILE}"

git rev-parse HEAD \
  > "reproducibility_records/poloco_git_commit_${timestamp}.txt"

cp configs/poloco_config.sh \
  "reproducibility_records/poloco_main_config_${timestamp}.sh"

if [[ -n "${OVERRIDE_CONFIG}" ]]; then
    cp "${OVERRIDE_CONFIG}" \
      "reproducibility_records/poloco_override_config_${timestamp}.sh"
fi

COMMON_ARGS=(
    --parsable
    --nodes=1
    --ntasks=1
    --chdir="${PROJECT_ROOT}"
)

if [[ -n "${SLURM_PARTITION}" ]]; then
    COMMON_ARGS+=(--partition="${SLURM_PARTITION}")
fi
if [[ -n "${SLURM_ACCOUNT}" ]]; then
    COMMON_ARGS+=(--account="${SLURM_ACCOUNT}")
fi
if [[ -n "${SLURM_QOS}" ]]; then
    COMMON_ARGS+=(--qos="${SLURM_QOS}")
fi
if [[ -n "${SLURM_THREADS_PER_CORE}" ]]; then
    COMMON_ARGS+=(--threads-per-core="${SLURM_THREADS_PER_CORE}")
fi
if [[ "${#SBATCH_EXTRA[@]}" -gt 0 ]]; then
    COMMON_ARGS+=("${SBATCH_EXTRA[@]}")
fi

case "${MODE}" in
    full)
        STEPS=(00 01 02 03 04 05 06 07)
        ;;
    assembly-only)
        STEPS=(00 01 02 03)
        ;;
    poolseq-only)
        STEPS=(00 01 04 05 06 07)
        ;;
esac

previous_job=""

for step in "${STEPS[@]}"; do
    case "${step}" in
        00)
            job_name="poloco_00_check"
            script="scripts/00_check_inputs.sh"
            description="Input check"
            cpus="${CHECK_CPUS}"
            mem="${CHECK_MEM}"
            time_limit="${CHECK_TIME}"
            log_prefix="00_check_inputs"
            script_args=("${MODE}")
            ;;
        01)
            job_name="poloco_01_preprocess"
            script="scripts/01_preprocessing_qc.sh"
            description="Preprocessing and QC"
            cpus="${PREPROCESS_CPUS}"
            mem="${PREPROCESS_MEM}"
            time_limit="${PREPROCESS_TIME}"
            log_prefix="01_preprocessing"
            script_args=()
            ;;
        02)
            job_name="poloco_02_assembly"
            script="scripts/02_assembly.sh"
            description="Assembly and BUSCO"
            cpus="${ASSEMBLY_CPUS}"
            mem="${ASSEMBLY_MEM}"
            time_limit="${ASSEMBLY_TIME}"
            log_prefix="02_assembly"
            script_args=()
            ;;
        03)
            job_name="poloco_03_validation"
            script="scripts/03_validation.sh"
            description="Assembly validation"
            cpus="${VALIDATION_CPUS}"
            mem="${VALIDATION_MEM}"
            time_limit="${VALIDATION_TIME}"
            log_prefix="03_validation"
            script_args=()
            ;;
        04)
            job_name="poloco_04_mapping"
            script="scripts/04_mapping_dedup_filter.sh"
            description="Mapping and BAM filtering"
            cpus="${MAPPING_CPUS}"
            mem="${MAPPING_MEM}"
            time_limit="${MAPPING_TIME}"
            log_prefix="04_mapping"
            script_args=()
            ;;
        05)
            job_name="poloco_05_coverage"
            script="scripts/05_coverage_depth.sh"
            description="Coverage calculation"
            cpus="${COVERAGE_CPUS}"
            mem="${COVERAGE_MEM}"
            time_limit="${COVERAGE_TIME}"
            log_prefix="05_coverage"
            script_args=()
            ;;
        06)
            job_name="poloco_06_poolseq"
            script="scripts/06_poolseq_pipeline.sh"
            description="Pool-seq analysis"
            cpus="${POOLSEQ_CPUS}"
            mem="${POOLSEQ_MEM}"
            time_limit="${POOLSEQ_TIME}"
            log_prefix="06_poolseq"
            script_args=()
            ;;
        07)
            job_name="poloco_07_qc"
            script="scripts/07_qc_visualization.sh"
            description="Final QC reports"
            cpus="${QC_CPUS}"
            mem="${QC_MEM}"
            time_limit="${QC_TIME}"
            log_prefix="07_qc_visualization"
            script_args=()
            ;;
    esac

    sbatch_args=(
        "${COMMON_ARGS[@]}"
        --job-name="${job_name}"
        --cpus-per-task="${cpus}"
        --mem="${mem}"
        --time="${time_limit}"
        --output="logs/${log_prefix}_%j.out"
        --error="logs/${log_prefix}_%j.err"
    )

    if [[ -n "${previous_job}" ]]; then
        sbatch_args+=(--dependency="afterok:${previous_job}")
    fi

    wrapper_args=(
        --slurm-config "${SITE_CONFIG}"
    )

    if [[ -n "${OVERRIDE_CONFIG}" ]]; then
        wrapper_args+=(--config "${OVERRIDE_CONFIG}")
    fi

    wrapper_args+=(
        --
        "${script}"
        "${script_args[@]}"
    )

    job_id="$(
        sbatch "${sbatch_args[@]}" \
          hpc/run_poloco_slurm_step.sh \
          "${wrapper_args[@]}"
    )"

    printf "%s\t%s\t%s\n" \
      "${step}" "${job_id}" "${description}" \
      | tee -a "${JOB_FILE}"

    previous_job="${job_id}"
done

echo
echo "Workflow submitted successfully."
echo "Job record: ${JOB_FILE}"
echo "First job: $(awk 'NR==2 {print $2}' "${JOB_FILE}")"
echo "Final job: ${previous_job}"
echo
echo "Monitor with:"
echo "  JOBS=\$(tail -n +2 '${JOB_FILE}' | cut -f2 | paste -sd, -)"
echo "  squeue -j \"\$JOBS\" -o '%.18i %.12P %.25j %.2t %.10M %.30R'"
