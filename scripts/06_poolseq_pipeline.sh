#!/usr/bin/env bash
#SBATCH --job-name=poloco_poolseq
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=72:00:00
#SBATCH --output=logs/06_poolseq_%j.out
#SBATCH --error=logs/06_poolseq_%j.err

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

activate_env poloco_poolseq
mkdir -p "${POOLSEQ_METADATA_DIR}" "${POOLSEQ_RESULTS_DIR}" logs

if [[ ! -f "${REF_FASTA}" ]]; then
    echo "[ERROR] Reference genome not found: ${REF_FASTA}"
    exit 1
fi
if [[ ! -f "${MPILEUP2SYNC}" ]]; then
    echo "[ERROR] mpileup2sync.pl not found: ${MPILEUP2SYNC}"
    echo "[ERROR] Edit POPOOLATION2_DIR in configs/poloco_config.sh if needed."
    exit 1
fi

BAMLIST="${POOLSEQ_METADATA_DIR}/bamlist_clean.txt"
find "${FILTERED_BAM_DIR}" -name "*.filtered.bam" | sort > "${BAMLIST}"
N_POOLS=$(wc -l < "${BAMLIST}" | tr -d ' ')
if [[ "${N_POOLS}" -eq 0 ]]; then
    echo "[ERROR] No filtered BAM files found in ${FILTERED_BAM_DIR}."
    exit 1
fi
MINPOP_VALUE=$(get_minpop "${N_POOLS}")
MAF_LABEL="${MAF/./}"

MPILEUP="${POOLSEQ_RESULTS_DIR}/${PROJECT_PREFIX}.mpileup"
SYNC="${POOLSEQ_RESULTS_DIR}/${PROJECT_PREFIX}.sync"
SNP_SYNC="${POOLSEQ_RESULTS_DIR}/${PROJECT_PREFIX}_snps.sync"
SNP_TABLE="${POOLSEQ_RESULTS_DIR}/${PROJECT_PREFIX}_snps_LD_MAF${MAF_LABEL}.txt"
AF_MATRIX="${POOLSEQ_RESULTS_DIR}/geno_AF_matrix_LD_MAF${MAF_LABEL}.csv"
SUMMARY="${POOLSEQ_RESULTS_DIR}/${PROJECT_PREFIX}_filtering_summary.tsv"

echo "============================================================"
echo "PoLoCo Pool-seq pipeline"
echo "============================================================"
echo "[INFO] Pools: ${N_POOLS}"
echo "[INFO] MINCOV=${MINCOV}"
echo "[INFO] MINPOP=${MINPOP_VALUE} (${MINPOP_MODE})"
echo "[INFO] MAF=${MAF}"
echo "[INFO] THIN_DIST=${THIN_DIST}"
echo "[INFO] MAPQ=${MAPQ}; BASEQ=${BASEQ}"

if [[ ! -f "${MPILEUP}" ]]; then
    echo "[INFO] Generating mpileup..."
    samtools mpileup \
      -B \
      -q "${MAPQ}" \
      -Q "${BASEQ}" \
      -f "${REF_FASTA}" \
      -b "${BAMLIST}" \
      > "${MPILEUP}"
else
    echo "[SKIP] Existing mpileup found: ${MPILEUP}"
fi

if [[ ! -f "${SYNC}" ]]; then
    echo "[INFO] Converting mpileup to sync..."
    perl "${MPILEUP2SYNC}" --input "${MPILEUP}" --output "${SYNC}" --fastq-type sanger --min-qual "${BASEQ}"
else
    echo "[SKIP] Existing sync file found: ${SYNC}"
fi

if [[ ! -f "${SYNC}" ]]; then
    echo "[ERROR] Sync file was not created: ${SYNC}"
    exit 1
fi

echo "[INFO] Filtering sync file and constructing allele-frequency matrix..."
python - <<'PY'
from __future__ import annotations
import csv
import os
from pathlib import Path

sync_file = Path(os.environ["SYNC"])
snp_sync = Path(os.environ["SNP_SYNC"])
snp_table = Path(os.environ["SNP_TABLE"])
af_matrix = Path(os.environ["AF_MATRIX"])
summary_file = Path(os.environ["SUMMARY"])
mincov = int(os.environ["MINCOV"])
minpop = int(os.environ["MINPOP_VALUE"])
maf = float(os.environ["MAF"])
thindist = int(os.environ["THIN_DIST"])

# PoPoolation2 sync count order is A:T:C:G:N:del for each pool.
alleles = ["A", "T", "C", "G"]
rows = []
counts_summary = {
    "sync_rows_total": 0,
    "polymorphic_rows": 0,
    "after_minpop": 0,
    "after_maf": 0,
    "after_distance_thinning": 0,
}

with sync_file.open("r", encoding="utf-8") as handle, snp_sync.open("w", encoding="utf-8") as snp_handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line:
            continue
        counts_summary["sync_rows_total"] += 1
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        chrom, pos, ref = parts[0], int(parts[1]), parts[2]
        pool_fields = parts[3:]
        pool_counts = []
        global_counts = {a: 0 for a in alleles}
        informative = 0

        for field in pool_fields:
            values = field.split(":")
            if len(values) < 4:
                counts = [0, 0, 0, 0]
            else:
                try:
                    counts = [int(values[i]) for i in range(4)]
                except ValueError:
                    counts = [0, 0, 0, 0]
            cov = sum(counts)
            pool_counts.append((counts, cov))
            if cov >= mincov:
                informative += 1
                for a, c in zip(alleles, counts):
                    global_counts[a] += c

        nonzero_alleles = [(a, c) for a, c in global_counts.items() if c > 0]
        if len(nonzero_alleles) < 2:
            continue
        counts_summary["polymorphic_rows"] += 1
        snp_handle.write(line + "\n")

        if informative < minpop:
            continue
        counts_summary["after_minpop"] += 1

        ranked = sorted(nonzero_alleles, key=lambda x: (-x[1], x[0]))
        major, major_count = ranked[0]
        minor, minor_count = ranked[1]
        total_informative = sum(global_counts.values())
        global_maf = minor_count / total_informative if total_informative else 0.0
        if global_maf < maf:
            continue
        counts_summary["after_maf"] += 1

        af_values = []
        for counts, cov in pool_counts:
            if cov < mincov:
                af_values.append("NA")
            else:
                idx = alleles.index(minor)
                af_values.append(f"{counts[idx] / cov:.6f}")

        rows.append({
            "chrom": chrom,
            "pos": pos,
            "snp_id": f"{chrom}_{pos}",
            "ref": ref,
            "major": major,
            "minor": minor,
            "informative_pools": informative,
            "global_maf": global_maf,
            "af_values": af_values,
        })

# Sort by scaffold and position before distance thinning.
rows.sort(key=lambda r: (r["chrom"], r["pos"]))
thinned = []
last_by_chrom: dict[str, int] = {}
for row in rows:
    chrom = row["chrom"]
    pos = row["pos"]
    if chrom not in last_by_chrom or pos - last_by_chrom[chrom] > thindist:
        thinned.append(row)
        last_by_chrom[chrom] = pos
counts_summary["after_distance_thinning"] = len(thinned)

with snp_table.open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle, delimiter="\t")
    writer.writerow(["SNP_ID", "Scaffold", "Position", "Reference", "Major", "Minor", "Informative_Pools", "Global_MAF"])
    for row in thinned:
        writer.writerow([
            row["snp_id"], row["chrom"], row["pos"], row["ref"], row["major"], row["minor"],
            row["informative_pools"], f"{row['global_maf']:.6f}"
        ])

with af_matrix.open("w", encoding="utf-8") as handle:
    for row in thinned:
        handle.write(row["snp_id"] + "," + ",".join(row["af_values"]) + "\n")

with summary_file.open("w", encoding="utf-8") as handle:
    handle.write("Step\tRetained_Sites\n")
    for key, value in counts_summary.items():
        handle.write(f"{key}\t{value}\n")

print(f"[OK] SNP table: {snp_table}")
print(f"[OK] Allele-frequency matrix: {af_matrix}")
print(f"[OK] Filtering summary: {summary_file}")
PY

echo "[OK] Pool-seq pipeline finished."
