#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

SITE_CONFIG=""
OVERRIDE_CONFIG=""

usage() {
    echo "Usage: $0 --slurm-config FILE [--config FILE] -- SCRIPT [ARGUMENTS...]" >&2
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --slurm-config)
            SITE_CONFIG="${2:-}"
            shift 2
            ;;
        --config)
            OVERRIDE_CONFIG="${2:-}"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "[ERROR] Unknown wrapper argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${SITE_CONFIG}" || ! -f "${SITE_CONFIG}" ]]; then
    echo "[ERROR] SLURM configuration not found: ${SITE_CONFIG}" >&2
    exit 1
fi

if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] No workflow script was supplied." >&2
    usage
    exit 1
fi

# shellcheck disable=SC1090
source "${SITE_CONFIG}"

if [[ -n "${MODULE_SETUP:-}" ]]; then
    eval "${MODULE_SETUP}"
fi

if [[ -n "${CONDA_ENVS_DIR:-}" ]]; then
    mkdir -p "${CONDA_ENVS_DIR}"
    export CONDA_ENVS_PATH="${CONDA_ENVS_DIR}"
fi

if [[ -n "${CONDA_PKGS_DIR:-}" ]]; then
    mkdir -p "${CONDA_PKGS_DIR}"
    export CONDA_PKGS_DIRS="${CONDA_PKGS_DIR}"
fi

if [[ -n "${CONDA_INIT:-}" ]]; then
    if [[ ! -f "${CONDA_INIT}" ]]; then
        echo "[ERROR] CONDA_INIT does not exist: ${CONDA_INIT}" >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    source "${CONDA_INIT}"
elif command -v conda >/dev/null 2>&1; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
else
    echo "[ERROR] Conda is unavailable inside this compute job." >&2
    echo "[ERROR] Set MODULE_SETUP or CONDA_INIT in configs/slurm_config.sh." >&2
    exit 1
fi

if [[ -n "${OVERRIDE_CONFIG}" ]]; then
    if [[ ! -f "${OVERRIDE_CONFIG}" ]]; then
        echo "[ERROR] Override configuration not found: ${OVERRIDE_CONFIG}" >&2
        exit 1
    fi
    export POLOCO_OVERRIDE_CONFIG="${OVERRIDE_CONFIG}"
else
    unset POLOCO_OVERRIDE_CONFIG
fi

echo "============================================================"
echo "PoLoCo SLURM step"
echo "============================================================"
echo "Job ID: ${SLURM_JOB_ID:-not_set}"
echo "Node: $(hostname)"
echo "Started: $(date -Is)"
echo "Directory: $(pwd)"
echo "Git commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo "Override config: ${POLOCO_OVERRIDE_CONFIG:-default main config}"
echo "Command: bash $*"
echo "============================================================"

bash "$@"

echo "============================================================"
echo "[OK] Step completed: bash $*"
echo "Completed: $(date -Is)"
echo "============================================================"
