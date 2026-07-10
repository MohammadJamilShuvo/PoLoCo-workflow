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
│   ├── poloco_config.sh
│   └── poloco_smoke_config.sh
├── smoke_test/
│   └── data/
│       ├── assembly/
│       │   ├── assembly_pool_R1.fastq.gz
│       │   └── assembly_pool_R2.fastq.gz
│       └── pools/
│           ├── smoke_pool_01_R1.fastq.gz
│           ├── smoke_pool_01_R2.fastq.gz
│           ├── smoke_pool_02_R1.fastq.gz
│           ├── smoke_pool_02_R2.fastq.gz
│           ├── smoke_pool_03_R1.fastq.gz
│           └── smoke_pool_03_R2.fastq.gz
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

The repository includes a fixed lightweight smoke-test dataset (`smoke_test/data/`) for rapid end-to-end workflow validation and an ENA case-study example (`ena_example/`) for reproducing the published analysis. All user-facing instructions are provided in this `README.md`.

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

This creates missing environments and updates existing environments:

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

PoLoCo uses one permanent main configuration and optional dataset-specific override files:

```text
configs/poloco_config.sh
configs/poloco_smoke_config.sh
```

`configs/poloco_config.sh` contains the default *Entomobrya nivalis* case-study settings. All workflow scripts continue to source this same main file.

`configs/poloco_smoke_config.sh` contains only the settings that differ for the fixed lightweight smoke test. It is loaded as an override, so the case-study configuration does not need to be edited or restored.

### Which configuration should be used?

| Run type | Configuration approach | Command |
|---|---|---|
| Fixed smoke test | use the supplied smoke override | `POLOCO_OVERRIDE_CONFIG=configs/poloco_smoke_config.sh bash scripts/run_poloco_pipeline.sh --mode full` |
| Full ENA case study | use the default main configuration | `bash scripts/run_poloco_pipeline.sh --mode full` |
| Reduced ENA selection | copy the smoke override or make a new override and adjust paths/thresholds | `POLOCO_OVERRIDE_CONFIG=configs/my_project_config.sh bash scripts/run_poloco_pipeline.sh --mode full` |
| User's own dataset | copy the main config to a new project-specific override and edit it | `POLOCO_OVERRIDE_CONFIG=configs/my_project_config.sh bash scripts/run_poloco_pipeline.sh --mode full` |

### Case-study defaults

The default `configs/poloco_config.sh` contains:

```bash
PROJECT_PREFIX="envilis"
RAW_DIR="01_raw_reads"
MINCOV=4
MINPOP_MODE="absolute"
MINPOP_ABS=55
MINPOP_PROP=0.67
MAF=0.05
THIN_DIST=200
MAPQ=30
BASEQ=20
RUN_BUSCO="yes"
```

These values are intended for the complete case study with 82 Pool-seq libraries.

### Smoke-test configuration

The supplied `configs/poloco_smoke_config.sh` already contains:

```bash
PROJECT_PREFIX="poloco_smoke"
RAW_DIR="smoke_test/data"
MINCOV=2
MINPOP_MODE="absolute"
MINPOP_ABS=2
MAF=0.01
THIN_DIST=50
MIN_CONTIG_LEN=500
RUN_BUSCO="no"
```

Users should not edit the main case-study config to run the smoke test.

### User's own dataset

Create a separate override:

```bash
cp configs/poloco_smoke_config.sh configs/my_project_config.sh
```

Then edit `configs/my_project_config.sh`. At minimum, check:

| Setting | What to adjust |
|---|---|
| `PROJECT_PREFIX` | short project/species label |
| `RAW_DIR`, `ASSEMBLY_RAW_DIR`, `POOL_RAW_DIR` | locations of the input FASTQs |
| `ASSEMBLY_R1`, `ASSEMBLY_R2` | assembly read filenames |
| output directories | use a separate project output root |
| `READ1_SUFFIX`, `READ2_SUFFIX` | change only if paired-read suffixes differ |
| `REF_FASTA` | required for `poolseq-only` mode |
| `PUBLISHED_REF` | optional external genome for validation |
| `MINCOV` | minimum coverage per pool |
| `MINPOP_MODE`, `MINPOP_ABS`, `MINPOP_PROP` | minimum informative pools |
| `MAF`, `THIN_DIST` | SNP filtering |
| `RUN_BUSCO` | `yes` for full assembly assessment, `no` for a quick functional test |
| thread settings | adjust to the available computer or HPC allocation |

For a dataset with a different number of pools, do not retain the case-study value `MINPOP_ABS=55`. Proportional filtering is often easier:

```bash
MINPOP_MODE="proportion"
MINPOP_PROP=0.67
```


---

## 📥 Input data

PoLoCo requires **paired-end Illumina FASTQ files**. Inputs can be provided in four ways:

1. run the fixed lightweight smoke test included in the repository,
2. use local FASTQ files,
3. download the public PoLoCo case-study reads from ENA,
4. adapt the ENA manifest to another public ENA dataset.

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


### Option 1: Run the fixed lightweight smoke test

The repository includes a small, fixed paired-end test dataset under:

```text
smoke_test/data/
├── assembly/
│   ├── assembly_pool_R1.fastq.gz
│   └── assembly_pool_R2.fastq.gz
└── pools/
    ├── smoke_pool_01_R1.fastq.gz
    ├── smoke_pool_01_R2.fastq.gz
    ├── smoke_pool_02_R1.fastq.gz
    ├── smoke_pool_02_R2.fastq.gz
    ├── smoke_pool_03_R1.fastq.gz
    └── smoke_pool_03_R2.fastq.gz
```

These files are permanently stored in the repository; users do not generate them. They are intended only to check that Steps 00–07 connect and execute correctly. They do not reproduce the manuscript assembly statistics or biological results.

The smoke test uses the supplied override configuration. No manual editing of `configs/poloco_config.sh` is required.

Remove an earlier smoke-test output, if present:

```bash
rm -rf smoke_test/output
rm -f smoke_test_run.log
```

Run the complete smoke test:

```bash
POLOCO_OVERRIDE_CONFIG=configs/poloco_smoke_config.sh \
bash scripts/run_poloco_pipeline.sh --mode full \
  2>&1 | tee smoke_test_run.log
```

A successful functional test ends with:

```text
[OK] PoLoCo workflow completed: full
```

The default case-study configuration remains unchanged after the smoke test.


### Option 2: Use local FASTQ files

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

### Option 3: Download the PoLoCo case-study reads from ENA

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
conda run -n poloco_poolseq python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads \
  --dry-run
```

To download the assembly library and three Pool-seq libraries as a reduced **real-data selection** (still a large download and not the lightweight smoke test):

```bash
conda run -n poloco_poolseq python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads \
  --max-pools 3
```

To download the full case-study dataset:

```bash
conda run -n poloco_poolseq python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads
```

The downloader places files into:

```text
01_raw_reads/assembly/
01_raw_reads/pools/
```

and verifies MD5 checksums when available.

For the complete 82-pool case study, the default `configs/poloco_config.sh` can be used. For a reduced ENA selection, create a separate override and reduce `MINPOP_ABS` or use proportional filtering before running the workflow.

### Option 4: Adapt the ENA example to another public ENA dataset

Users with their own public ENA data can adapt:

```text
ena_example/poloco_ena_case_study_manifest.tsv
```

Use the same columns as the supplied manifest. The essential fields used by the downloader are:

```text
sample_id
study_accession
library_role
library_name
submitted_read1
submitted_read2
read1_md5
read2_md5
standard_read1
standard_read2
```

Use `library_role=assembly` for the library used to build the draft reference genome.

Use `library_role=poolseq` for pooled population libraries used for mapping and allele-frequency estimation.

After editing the manifest, run:

```bash
conda run -n poloco_poolseq python ena_example/download_poloco_ena_case_study_reads.py \
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
3. select the appropriate configuration or override,
4. choose the workflow mode.

### Full workflow

Use this when you want PoLoCo to preprocess reads, assemble a draft genome, prepare the reference, validate the assembly, map Pool-seq libraries, and create the allele-frequency matrix:

For the complete ENA case study, use the default configuration:

```bash
bash scripts/run_poloco_pipeline.sh --mode full
```

For the fixed smoke test, use:

```bash
POLOCO_OVERRIDE_CONFIG=configs/poloco_smoke_config.sh \
bash scripts/run_poloco_pipeline.sh --mode full
```

For a user's own project, use a project-specific override:

```bash
POLOCO_OVERRIDE_CONFIG=configs/my_project_config.sh \
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

The master runner executes all steps sequentially and should be run with `bash` on a workstation or inside an interactive HPC allocation. Do not submit the master runner itself with `sbatch`, because the resource directives inside child scripts are ignored when they are called with `bash`.

For SLURM batch execution, submit the numbered scripts separately after editing `configs/poloco_config.sh` for the selected dataset. For example:

```bash
mkdir -p logs

J0=$(sbatch --parsable scripts/00_check_inputs.sh full)
J1=$(sbatch --parsable --dependency=afterok:${J0} scripts/01_preprocessing_qc.sh)
J2=$(sbatch --parsable --dependency=afterok:${J1} scripts/02_assembly.sh)
J3=$(sbatch --parsable --dependency=afterok:${J2} scripts/03_validation.sh)
J4=$(sbatch --parsable --dependency=afterok:${J3} scripts/04_mapping_dedup_filter.sh)
J5=$(sbatch --parsable --dependency=afterok:${J4} scripts/05_coverage_depth.sh)
J6=$(sbatch --parsable --dependency=afterok:${J5} scripts/06_poolseq_pipeline.sh)
sbatch --dependency=afterok:${J6} scripts/07_qc_visualization.sh
```

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
PoPoolation2/results/geno_AF_matrix_LD_MAF005.csv
```

Other important Pool-seq outputs include:

```text
PoPoolation2/results/envilis.mpileup
PoPoolation2/results/envilis.sync
PoPoolation2/results/envilis_snps.sync
PoPoolation2/results/envilis_snps_LD_MAF005.txt
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

Step 06 automatically detects `mpileup2sync.pl` after activating `poloco_poolseq`. Check the installation with:

```bash
conda run -n poloco_poolseq bash -lc 'command -v mpileup2sync.pl'
```

If automatic discovery is not possible, set the absolute path in `configs/poloco_config.sh`:

```bash
MPILEUP2SYNC="/absolute/path/to/mpileup2sync.pl"
```

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
