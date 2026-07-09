# 🧬 PoLoCo Workflow

**Reproducible workflow for pooled draft genome assembly and Pool-seq allele-frequency analysis of non-model invertebrates**

![workflow](https://github.com/user-attachments/assets/20c36866-0dfd-4626-a3d5-9b92721b1bf1)

---

## 📖 Overview

**PoLoCo** (Pooled Low-Coverage) is an open-source workflow for projects where population genomic analyses need to be performed on small, non-model invertebrates for which high-quality individual reference genomes are difficult to obtain.

The workflow supports:

- **Draft genome assembly** from a pooled assembly library, for example ethanol-preserved specimens.
- **Automatic reference preparation** from the draft assembly for downstream mapping.
- **Assembly validation** against an optional published or external reference genome.
- **Read preprocessing, mapping, and BAM filtering** for pooled population libraries.
- **Pool-seq sync generation and allele-frequency matrix construction** using PoPoolation2 and configurable downstream filtering.
- **QC summaries and visualization** for read quality, mapping, coverage, and final allele-frequency outputs.

PoLoCo produces filtered SNP tables and allele-frequency matrices that can be used for downstream population-genomic or landscape-genomic analyses. The workflow itself focuses on reproducible data processing up to the allele-frequency matrix stage.

The workflow was developed for the *Entomobrya nivalis* case study described in the manuscript:

> **PoLoCo: A reproducible pooled low-coverage workflow for draft genome assembly and allele frequency analysis from ethanol-preserved small non-model invertebrates**  
> Mohammad Jamil Shuvo, Gernot Segelbacher, Julia C. Geue, [link pending journal publication].

---

## Repository structure

The main folders are:

```text
PoLoCo-workflow/
├── README.md
├── configs/
│   ├── install_poloco_conda_envs.sh
│   └── poloco_config.sh
├── ena_example/
│   ├── poloco_ena_case_study_manifest.tsv
│   └── download_poloco_ena_case_study_reads.py
├── scripts/
│   ├── 00_check_inputs.sh
│   ├── 01_preprocessing_qc.sh
│   ├── 02_assembly.sh
│   ├── 03_validation.sh
│   ├── 04_mapping_dedup_filter.sh
│   ├── 05_coverage_depth.sh
│   ├── 06_poolseq_pipeline.sh
│   ├── 07_qc_visualization.sh
│   └── run_poloco_pipeline.sh
└── qc_scripts/
    ├── fastp_qc.py
    ├── alignment_qc.py
    ├── poolseq_af_qc.py
    ├── poolseq_summary_stats_qc.py
    └── final_qc_master.py
```

All user-facing instructions are in this main `README.md`.

---

## ⚙️ Installation

### 1. Clone the repository

```bash
git clone git@github.com:MohammadJamilShuvo/PoLoCo-workflow.git
cd PoLoCo-workflow
```

HTTPS can also be used:

```bash
git clone https://github.com/MohammadJamilShuvo/PoLoCo-workflow.git
cd PoLoCo-workflow
```

### 2. Install the required conda environments

PoLoCo uses modular conda environments internally because the workflow combines tools with different dependency requirements. To keep installation simple, all required environments are created with one installer script:

```bash
bash configs/install_poloco_conda_envs.sh
```

This creates or checks:

```text
poloco_qc_mapping
poloco_poolseq
poloco_assembly
```

These environments are used automatically by the workflow scripts.

| Environment | Used for |
|---|---|
| `poloco_qc_mapping` | read preprocessing, FastQC/MultiQC, mapping, BAM filtering, coverage |
| `poloco_poolseq` | mpileup/sync generation, Pool-seq filtering, allele-frequency matrix, QC summaries |
| `poloco_assembly` | draft assembly and assembly validation |

You normally do not need to activate environments manually when running the full workflow through `scripts/run_poloco_pipeline.sh`. For testing a single environment manually, use for example:

```bash
conda activate poloco_qc_mapping
```

---

## 🧩 Configure the workflow

Before running PoLoCo, check:

```text
configs/poloco_config.sh
```

This file controls the project label, input folders, output folders, filtering thresholds, reference paths, resource settings, and PoPoolation2 path.

The default values reproduce the *Entomobrya nivalis* case-study settings:

```bash
PROJECT_PREFIX="envilis"
MINCOV=4
MINPOP_MODE="absolute"
MINPOP_ABS=55
MINPOP_PROP=0.67
MAF=0.05
THIN_DIST=200
MAPQ=30
BASEQ=20
```

Common settings to check or adjust:

| Setting | What it controls | Typical action |
|---|---|---|
| `PROJECT_PREFIX` | prefix used in output files | change to a short project/species label |
| `RAW_DIR` | raw-read parent folder | usually keep as `01_raw_reads` |
| `ASSEMBLY_RAW_DIR` | raw reads used for draft assembly | usually `01_raw_reads/assembly` |
| `POOL_RAW_DIR` | raw pooled population reads | usually `01_raw_reads/pools` |
| `READ1_SUFFIX`, `READ2_SUFFIX` | paired-end FASTQ naming pattern | edit if your files do not end in `_R1.fastq.gz` and `_R2.fastq.gz` |
| `REF_FASTA` | reference used for mapping | default is `ref/poloco_draft.fa` |
| `PUBLISHED_REF` | optional reference for validation | edit if comparing against a published genome |
| `MAPQ`, `BASEQ` | mapping/base-quality thresholds | increase for stricter filtering, decrease only with caution |
| `MINCOV` | minimum coverage per pool at a site | adjust based on sequencing depth |
| `MINPOP_MODE` | minimum population filter mode | use `absolute` or `proportion` |
| `MINPOP_ABS` | fixed minimum number of informative pools | case study uses `55` |
| `MINPOP_PROP` | proportional minimum number of informative pools | useful for new datasets |
| `MAF` | global minor allele-frequency threshold | case study uses `0.05` |
| `THIN_DIST` | distance-based thinning in bp | case study uses `200` |
| `POPOOLATION2_DIR` | PoPoolation2 location | edit if `mpileup2sync.pl` is installed elsewhere |

For a new dataset with a different number of pooled populations, proportional filtering is usually easier than a fixed number:

```bash
MINPOP_MODE="proportion"
MINPOP_PROP=0.67
```

For a small test run with only three pools, the case-study setting `MINPOP_ABS=55` will not work. Use for example:

```bash
MINPOP_MODE="absolute"
MINPOP_ABS=2
```

or:

```bash
MINPOP_MODE="proportion"
MINPOP_PROP=0.67
```

---

## 📥 Input data

PoLoCo requires **paired-end Illumina FASTQ files**. Reads can be provided in three ways:

1. use local FASTQ files,
2. download the public PoLoCo case-study reads from ENA,
3. adapt the ENA manifest to another public ENA dataset.

### Expected input folder structure

PoLoCo expects assembly reads and pooled population reads to be separated:

```text
01_raw_reads/
├── assembly/
│   ├── assembly_pool_R1.fastq.gz
│   └── assembly_pool_R2.fastq.gz
└── pools/
    ├── pool_001_R1.fastq.gz
    ├── pool_001_R2.fastq.gz
    ├── pool_002_R1.fastq.gz
    ├── pool_002_R2.fastq.gz
    └── ...
```

Use:

```text
01_raw_reads/assembly/
```

for the paired-end reads used to build the draft genome.

Use:

```text
01_raw_reads/pools/
```

for the paired-end reads used for population-level Pool-seq mapping and allele-frequency estimation.

Input files should be gzip-compressed paired-end FASTQ files, preferably named with:

```text
_R1.fastq.gz
_R2.fastq.gz
```

If your files use another naming pattern, update `READ1_SUFFIX` and `READ2_SUFFIX` in `configs/poloco_config.sh`.

### Option 1: Use local FASTQ files

Create the input folders:

```bash
mkdir -p 01_raw_reads/assembly
mkdir -p 01_raw_reads/pools
```

Copy the assembly-pool reads:

```bash
cp /path/to/assembly_pool_R1.fastq.gz 01_raw_reads/assembly/
cp /path/to/assembly_pool_R2.fastq.gz 01_raw_reads/assembly/
```

Copy the pooled population reads:

```bash
cp /path/to/pool_*_R1.fastq.gz 01_raw_reads/pools/
cp /path/to/pool_*_R2.fastq.gz 01_raw_reads/pools/
```

Then check `configs/poloco_config.sh` and make sure the folder paths and suffixes match your data.

### Option 2: Download the PoLoCo case-study reads from ENA

The manuscript case study uses ethanol-preserved *Entomobrya nivalis* pooled libraries deposited under ENA BioProject:

```text
PRJEB111482
```

The repository includes:

```text
ena_example/
├── poloco_ena_case_study_manifest.tsv
└── download_poloco_ena_case_study_reads.py
```

The manifest separates the single assembly library from the 82 retained Pool-seq libraries.

First, run a dry run to see what would be downloaded:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads \
  --dry-run
```

To download the assembly library and three Pool-seq libraries for a small test:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads \
  --max-pools 3
```

To download the full case-study dataset:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads
```

The downloader places files into:

```text
01_raw_reads/assembly/
01_raw_reads/pools/
```

and verifies MD5 checksums when available.

### Option 3: Adapt the ENA example to another public ENA dataset

Users with their own public ENA data can adapt:

```text
ena_example/poloco_ena_case_study_manifest.tsv
```

At minimum, the manifest should include:

```text
sample_id
library_role
run_accession
read1_url
read2_url
read1_filename
read2_filename
```

Use `library_role=assembly` for the library used to build the draft reference genome.

Use `library_role=poolseq` for pooled population libraries used for mapping and allele-frequency estimation.

After editing the manifest, run:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads
```

Then update `configs/poloco_config.sh` for your dataset before running PoLoCo.

---

## 📂 Workflow steps

The simplified PoLoCo core workflow is organized as follows. The assembly step also prepares the draft assembly as the mapping reference, so there is no separate reference-preparation step.

| Step | Script | Main tools | Environment | Main outputs |
|---|---|---|---|---|
| 0 | `scripts/00_check_inputs.sh` | Bash | active shell | checks config, folders, read pairs, required inputs |
| 1 | `scripts/01_preprocessing_qc.sh` | fastp, FastQC, MultiQC | `poloco_qc_mapping` | trimmed reads, fastp/FastQC/MultiQC summaries |
| 2 | `scripts/02_assembly.sh` | MEGAHIT, BUSCO, BWA, samtools | `poloco_assembly` | draft assembly, `ref/poloco_draft.fa`, reference indexes |
| 3 | `scripts/03_validation.sh` | QUAST, FastANI, MUMmer4 | `poloco_assembly` | assembly metrics and optional reference comparison |
| 4 | `scripts/04_mapping_dedup_filter.sh` | BWA, samtools, Picard | `poloco_qc_mapping` | mapped, deduplicated, filtered BAM files |
| 5 | `scripts/05_coverage_depth.sh` | samtools | `poloco_qc_mapping` | per-pool coverage summaries |
| 6 | `scripts/06_poolseq_pipeline.sh` | samtools, PoPoolation2, Bash/awk | `poloco_poolseq` | BAM list, mpileup, sync file, filtered SNP table, allele-frequency matrix |
| 7 | `scripts/07_qc_visualization.sh` | Python QC scripts | `poloco_poolseq` | QC plots and integrated QC summaries |

QC helper scripts are in `qc_scripts/`:

```text
fastp_qc.py
alignment_qc.py
poolseq_af_qc.py
poolseq_summary_stats_qc.py
final_qc_master.py
```

---

## 🚀 Running the workflow

Before running PoLoCo:

1. install conda environments,
2. prepare or download input FASTQ files,
3. check `configs/poloco_config.sh`,
4. choose the workflow mode.

### Full workflow

Use this when you want PoLoCo to preprocess reads, assemble a draft genome, prepare the reference, validate the assembly, map Pool-seq libraries, and create the allele-frequency matrix:

```bash
bash scripts/run_poloco_pipeline.sh --mode full
```

The full workflow runs:

```text
00_check_inputs
01_preprocessing_qc
02_assembly
03_validation
04_mapping_dedup_filter
05_coverage_depth
06_poolseq_pipeline
07_qc_visualization
```

### Pool-seq-only workflow

Use this when you already have a reference genome and only want to run preprocessing, mapping, coverage, Pool-seq filtering, and QC summaries:

```bash
bash scripts/run_poloco_pipeline.sh --mode poolseq-only
```

Before using this mode, set `REF_FASTA` in `configs/poloco_config.sh` to the reference genome you want to use. The reference should already be available and indexable.

### Assembly-only workflow

Use this when you only want to assemble and validate a draft genome:

```bash
bash scripts/run_poloco_pipeline.sh --mode assembly-only
```

### Run one step

For debugging or rerunning a specific part of the workflow:

```bash
bash scripts/run_poloco_pipeline.sh --step 06
```

The step number corresponds to the workflow table above.

### SLURM/HPC use

On SLURM-based systems, the same runner can be submitted with `sbatch`, depending on local cluster configuration:

```bash
sbatch scripts/run_poloco_pipeline.sh --mode full
```

Users may need to adjust resources in `configs/poloco_config.sh` and/or cluster-specific `sbatch` settings according to their HPC system.

---

## 📊 Main outputs

The main output folders are:

```text
01_raw_reads/assembly/       raw paired-end reads for draft genome assembly
01_raw_reads/pools/          raw paired-end Pool-seq reads
02_trimmed_reads/assembly/   trimmed assembly reads
02_trimmed_reads/pools/      trimmed Pool-seq reads
02_fastqc_reports/           fastp, FastQC, and MultiQC reports
03_alignments/               mapped BAM files
04_bam_filtered/             deduplicated and mapping-quality-filtered BAM files
05_coverage/                 coverage summaries
08_assembly/                 draft assembly outputs
09_validation/               QUAST, FastANI, and alignment validation outputs
PoPoolation2/metadata/       BAM lists and Pool-seq metadata
PoPoolation2/results/        mpileup, sync file, SNP table, allele-frequency matrix
07_plots/                    QC plots and integrated QC reports
```

For the manuscript case study, the key final allele-frequency matrix is:

```text
PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv
```

Other important Pool-seq outputs include:

```text
PoPoolation2/results/envilis.mpileup
PoPoolation2/results/envilis.sync
PoPoolation2/results/envilis_snps.sync
PoPoolation2/results/envilis_snps_LD_MAF05.txt
```

The exact prefix depends on `PROJECT_PREFIX` in `configs/poloco_config.sh`.

---

## 🧪 Downstream use

PoLoCo outputs can be used for downstream analyses such as:

- PCA or ordination of allele-frequency variation,
- pairwise genetic differentiation,
- reference-comparison analyses,
- landscape-genomic or genotype-environment association analyses.

These are downstream uses of PoLoCo outputs and are not required for running the core workflow.

---

## Troubleshooting

### Conda environment creation fails

Try updating conda first:

```bash
conda update -n base -c defaults conda
```

Then rerun:

```bash
bash configs/install_poloco_conda_envs.sh
```

### PoPoolation2 is not found

Check the path in:

```text
configs/poloco_config.sh
```

Specifically:

```bash
POPOOLATION2_DIR="${CONDA_PREFIX:-}/share/popoolation2"
MPILEUP2SYNC="${POPOOLATION2_DIR}/mpileup2sync.pl"
```

If `mpileup2sync.pl` is installed elsewhere, update `POPOOLATION2_DIR`.

### The small ENA example fails during Pool-seq filtering

If you downloaded only a few pools using `--max-pools`, change the minimum population threshold in `configs/poloco_config.sh`.

For example:

```bash
MINPOP_MODE="absolute"
MINPOP_ABS=2
```

or:

```bash
MINPOP_MODE="proportion"
MINPOP_PROP=0.67
```

### The workflow cannot find paired reads

Check that files are in the expected folders and match the suffixes in `configs/poloco_config.sh`:

```bash
READ1_SUFFIX="_R1.fastq.gz"
READ2_SUFFIX="_R2.fastq.gz"
```

---

## 🙌 Contributing

Contributions, bug reports, and feature requests are welcome. Please open an issue or pull request on GitHub.

---

## 📖 Citation

If you use this workflow, please cite:

> Mohammad Jamil Shuvo *et al.* (2026). **PoLoCo: A reproducible pooled low-coverage workflow for draft genome assembly and allele frequency analysis from ethanol-preserved small non-model invertebrates**. [Journal link pending].

Also cite the core tools used by the workflow:

- [fastp](https://github.com/OpenGene/fastp)
- [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
- [MultiQC](https://multiqc.info/)
- [BWA](https://github.com/lh3/bwa)
- [samtools](http://www.htslib.org/)
- [Picard](https://broadinstitute.github.io/picard/)
- [PoPoolation2](https://sourceforge.net/projects/popoolation2/)
- [MEGAHIT](https://github.com/voutcn/megahit)
- [BUSCO](https://busco.ezlab.org)
- [QUAST](https://github.com/ablab/quast)
- [FastANI](https://github.com/ParBLiSS/FastANI)
- [MUMmer4](https://github.com/mummer4/mummer)

---

## 📜 License

This project is released under the MIT License.
