#!/usr/bin/env bash
#SBATCH --job-name=poloco_preprocess
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/01_preprocessing_%j.out
#SBATCH --error=logs/01_preprocessing_%j.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

set -a
source "configs/poloco_config.sh"
set +a

activate_env() {
    local env_name="$1"
    if command -v conda >/dev/null 2>&1; then
        source "$(conda info --base)/etc/profile.d/conda.sh"
        conda activate "${env_name}"
    else
        echo "[WARN] conda not found. Continuing without activating ${env_name}."
    fi
}

activate_env poloco_qc_mapping

mkdir -p "${ASSEMBLY_TRIM_DIR}" "${POOL_TRIM_DIR}" "${QC_DIR}" "${PLOTS_DIR}" logs

trim_pair() {
    local r1="$1"
    local r2="$2"
    local outdir="$3"
    local role="$4"
    local base sample
    base="$(basename "$r1")"
    sample="${base%${READ1_SUFFIX}}"

    echo "[INFO] fastp ${role}: ${sample}"
    fastp \
      -i "$r1" \
      -I "$r2" \
      -o "${outdir}/${sample}${TRIMMED_READ1_SUFFIX}" \
      -O "${outdir}/${sample}${TRIMMED_READ2_SUFFIX}" \
      --qualified_quality_phred "${QUAL_THRESHOLD}" \
      --length_required "${MIN_READ_LENGTH}" \
      --thread "${THREADS_QC}" \
      -h "${QC_DIR}/${role}_${sample}_fastp.html" \
      -j "${QC_DIR}/${role}_${sample}_fastp.json"
}

echo "[INFO] Trimming assembly reads..."
if [[ -f "${ASSEMBLY_R1}" && -f "${ASSEMBLY_R2}" ]]; then
    trim_pair "${ASSEMBLY_R1}" "${ASSEMBLY_R2}" "${ASSEMBLY_TRIM_DIR}" "assembly"
else
    echo "[WARN] Assembly reads not found at configured paths. Skipping assembly trimming."
fi

echo "[INFO] Trimming Pool-seq reads..."
shopt -s nullglob
pool_count=0
for r1 in "${POOL_RAW_DIR}"/*"${READ1_SUFFIX}"; do
    sample="$(basename "$r1")"
    sample="${sample%${READ1_SUFFIX}}"
    r2="${POOL_RAW_DIR}/${sample}${READ2_SUFFIX}"
    if [[ ! -f "$r2" ]]; then
        echo "[ERROR] Missing R2 pair for $r1"
        exit 1
    fi
    trim_pair "$r1" "$r2" "${POOL_TRIM_DIR}" "poolseq"
    pool_count=$((pool_count + 1))
done
shopt -u nullglob

if [[ "$pool_count" -eq 0 ]]; then
    echo "[WARN] No Pool-seq reads found in ${POOL_RAW_DIR}."
fi

echo "[INFO] Running FastQC and MultiQC..."
shopt -s nullglob
fastq_files=("${ASSEMBLY_TRIM_DIR}"/*.fastq.gz "${POOL_TRIM_DIR}"/*.fastq.gz)
shopt -u nullglob
if [[ "${#fastq_files[@]}" -gt 0 ]]; then
    fastqc "${fastq_files[@]}" -o "${QC_DIR}" -t "${THREADS_QC}"
    multiqc "${QC_DIR}" -o "${QC_DIR}"
else
    echo "[WARN] No trimmed FASTQ files found for FastQC."
fi

echo "[INFO] Creating fastp summary table inside preprocessing step..."
python - <<'PY'
import json
import os
from pathlib import Path
import pandas as pd

qc_dir = Path(os.environ.get("QC_DIR", "02_fastqc_reports"))
qc_dir.mkdir(parents=True, exist_ok=True)
rows = []
for json_file in sorted(qc_dir.glob("*_fastp.json")):
    sample = json_file.name.replace("_fastp.json", "")
    with open(json_file, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    before = data.get("summary", {}).get("before_filtering", {})
    after = data.get("summary", {}).get("after_filtering", {})
    filtering = data.get("filtering_result", {})
    total_reads = before.get("total_reads", 0) or 0
    passed_reads = after.get("total_reads", 0) or 0
    rows.append({
        "Sample": sample,
        "Total_Reads": total_reads,
        "Passed_Reads": passed_reads,
        "Retention": (passed_reads / total_reads) if total_reads else None,
        "Q20_Rate": after.get("q20_rate"),
        "Q30_Rate": after.get("q30_rate"),
        "GC_Content": after.get("gc_content"),
        "Duplication_Rate": data.get("duplication", {}).get("rate"),
        "Low_Quality_Reads": filtering.get("low_quality_reads"),
        "Too_Short_Reads": filtering.get("too_short_reads"),
        "Too_Many_N_Reads": filtering.get("too_many_N_reads"),
        "Source_JSON": str(json_file),
    })
df = pd.DataFrame(rows)
df.to_csv(qc_dir / "fastp_summary.csv", sep="\t", index=False)
df.to_csv(qc_dir / "fastp_summary.tsv", sep="\t", index=False)
print(f"[OK] fastp summary written to {qc_dir / 'fastp_summary.tsv'}")
PY

echo "[INFO] Generating fastp QC plots..."
python qc_scripts/fastp_qc.py

echo "[OK] Preprocessing and QC finished."
