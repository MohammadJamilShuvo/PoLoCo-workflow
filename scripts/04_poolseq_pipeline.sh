#!/bin/bash
#SBATCH --job-name=poloco_poolseq
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output=logs/04_poolseq_%j.out
#SBATCH --error=logs/04_poolseq_%j.err

# ===============================
# Step 4: Pool-seq Sync Generation + Filtering
# Tools: samtools, PoPoolation2, Bash, awk
# Conda env: poloco_poolseq
#
# Inputs from previous steps:
#   - filtered BAM files in 04_bam_filtered/
#   - draft reference genome in ref/poloco_draft.fa
#
# Final retained outputs:
#   - PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv
#   - PoPoolation2/results/envilis_snps_LD_MAF05.txt
# ===============================

source ~/miniconda3/etc/profile.d/conda.sh
conda activate poloco_poolseq

PROJECT_ROOT=$(pwd)

REF="${PROJECT_ROOT}/ref/poloco_draft.fa"
FILTER_DIR="${PROJECT_ROOT}/04_bam_filtered"

POOLSEQ_DIR="${PROJECT_ROOT}/PoPoolation2"
RESULTS="${POOLSEQ_DIR}/results"
META_DIR="${POOLSEQ_DIR}/metadata"

BAMLIST="${META_DIR}/bamlist_clean.txt"
MPILEUP="${RESULTS}/envilis.mpileup"
SYNC="${RESULTS}/envilis.sync"
SNPFILE="${RESULTS}/envilis_snps.sync"

MINCOV=4
MINPOP=55
LD_DIST=200

mkdir -p "${RESULTS}" "${META_DIR}" logs

echo "[INFO] Step 4: Pool-seq sync generation + filtering"
echo "[INFO] Reference: ${REF}"
echo "[INFO] Filtered BAM directory: ${FILTER_DIR}"

if [[ ! -f "${REF}" ]]; then
    echo "[ERROR] Reference genome not found: ${REF}"
    exit 1
fi

find "${FILTER_DIR}" -maxdepth 1 -name "*.filtered.bam" | sort > "${BAMLIST}"

if [[ ! -s "${BAMLIST}" ]]; then
    echo "[ERROR] No filtered BAM files found in ${FILTER_DIR}"
    exit 1
fi

BAMCOUNT=$(wc -l < "${BAMLIST}")
echo "[INFO] BAM files listed: ${BAMCOUNT}"
echo "[INFO] BAM list written to: ${BAMLIST}"

echo "[INFO] Running samtools mpileup..."
samtools mpileup \
    -B \
    -q 30 \
    -Q 20 \
    -f "${REF}" \
    -b "${BAMLIST}" \
    > "${MPILEUP}"

echo "[INFO] Running mpileup2sync.pl..."
mpileup2sync.pl \
    --input "${MPILEUP}" \
    --output "${SYNC}" \
    --fastq-type sanger \
    --min-qual 20

if [[ ! -s "${SYNC}" ]]; then
    echo "[ERROR] Sync file was not created: ${SYNC}"
    exit 1
fi

echo "[INFO] Detecting polymorphic SNPs..."

awk '
{
A=0;T=0;C=0;G=0

for(i=4;i<=NF;i++){
split($i,a,":")
A+=a[1]
T+=a[2]
C+=a[3]
G+=a[4]
}

alleles=0
if(A>0) alleles++
if(T>0) alleles++
if(C>0) alleles++
if(G>0) alleles++

if(alleles>=2){
print
}
}
' "${SYNC}" > "${SNPFILE}"

echo "[INFO] SNP count after polymorphic-site detection:"
wc -l "${SNPFILE}"

echo "[INFO] Building allele matrix..."

awk -v MINCOV="${MINCOV}" -v MINPOP="${MINPOP}" '
BEGIN{FS="\t";OFS=","}

{
chr=$1
pos=$2

valid=0

A_tot=0;T_tot=0;C_tot=0;G_tot=0

for(i=4;i<=NF;i++){

split($i,a,":")

A=a[1];T=a[2];C=a[3];G=a[4]

cov=A+T+C+G

if(cov>=MINCOV){

valid++

A_tot+=A
T_tot+=T
C_tot+=C
G_tot+=G

popcov[i-3]=cov
popA[i-3]=A
popT[i-3]=T
popC[i-3]=C
popG[i-3]=G

}else{
popcov[i-3]=0
}

}

if(valid>=MINPOP){

snp=chr"_"pos

total=A_tot+T_tot+C_tot+G_tot

max=0
major="N"
minor="N"

if(A_tot>max){max=A_tot;major="A"}
if(T_tot>max){max=T_tot;major="T"}
if(C_tot>max){max=C_tot;major="C"}
if(G_tot>max){max=G_tot;major="G"}

second=0

if(A_tot<max && A_tot>second){second=A_tot;minor="A"}
if(T_tot<max && T_tot>second){second=T_tot;minor="T"}
if(C_tot<max && C_tot>second){second=C_tot;minor="C"}
if(G_tot<max && G_tot>second){second=G_tot;minor="G"}

maf=second/total

printf snp","maf","chr","pos","major","minor","valid

for(j=1;j<=NF-3;j++){

if(popcov[j]>0){

if(minor=="A") freq=popA[j]/popcov[j]
if(minor=="T") freq=popT[j]/popcov[j]
if(minor=="C") freq=popC[j]/popcov[j]
if(minor=="G") freq=popG[j]/popcov[j]

printf ","freq

}else{
printf ",NA"
}

}

printf "\n"

}

delete popcov
delete popA
delete popT
delete popC
delete popG

}
' "${SNPFILE}" > "${RESULTS}/noLD_matrix_full.tmp"

echo "[INFO] Applying MAF filters..."

awk -F',' '$2>=0.05' "${RESULTS}/noLD_matrix_full.tmp" > "${RESULTS}/noLD_MAF05.tmp"
awk -F',' '$2>=0.10' "${RESULTS}/noLD_matrix_full.tmp" > "${RESULTS}/noLD_MAF10.tmp"

echo "[INFO] Applying distance-based thinning..."

cut -d',' -f1 "${RESULTS}/noLD_MAF05.tmp" \
| awk -F'_' '{print $1"\t"$2}' \
> "${RESULTS}/maf05_positions.txt"

awk -v dist="${LD_DIST}" '
{
chr=$1
pos=$2

if(chr!=prev_chr || pos-prev_pos>dist){
print
prev_chr=chr
prev_pos=pos
}
}
' "${RESULTS}/maf05_positions.txt" \
> "${RESULTS}/thinned_positions.txt"

grep -Ff <(awk '{print $1"_"$2}' "${RESULTS}/thinned_positions.txt") \
"${RESULTS}/noLD_MAF05.tmp" > "${RESULTS}/LD_MAF05.tmp"

grep -Ff <(awk '{print $1"_"$2}' "${RESULTS}/thinned_positions.txt") \
"${RESULTS}/noLD_MAF10.tmp" > "${RESULTS}/LD_MAF10.tmp"

echo "[INFO] Writing final retained outputs..."

cut -d',' -f3,4,5,6,7 "${RESULTS}/LD_MAF05.tmp" \
> "${RESULTS}/envilis_snps_LD_MAF05.txt"

cut -d',' -f1,8- "${RESULTS}/LD_MAF05.tmp" \
> "${RESULTS}/geno_AF_matrix_LD_MAF05.csv"

echo "[OK] Pool-seq pipeline complete."
echo "[OK] Final retained SNP table: ${RESULTS}/envilis_snps_LD_MAF05.txt"
echo "[OK] Final retained dataset: ${RESULTS}/geno_AF_matrix_LD_MAF05.csv"
date
