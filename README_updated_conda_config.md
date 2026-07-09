# 🧬 PoLoCo Workflow

**Reproducible workflow for pooled draft genome assembly and Pool-seq allele-frequency analysis of non-model invertebrates**

![workflow](https://github.com/user-attachments/assets/20c36866-0dfd-4626-a3d5-9b92721b1bf1)

---

## 📖 Overview

**PoLoCo** (Pooled Low-Coverage) is an open-source workflow designed for **non-model invertebrates** where individual high-quality genomes are difficult to obtain. It enables:

- **Draft genome assembly** from pooled, ethanol-preserved specimens.
- **Reference preparation and validation** for downstream Pool-seq analyses.
- **Read preprocessing, mapping, and BAM filtering** with strict QC.
- **Pool-seq sync generation and allele-frequency matrix construction** using **PoPoolation2** and downstream Bash-based filtering.
- **QC visualization** at key workflow stages for transparency and reproducibility.

PoLoCo is designed to produce filtered SNP tables and allele-frequency matrices that can be used for downstream population-genomic analyses. It does **not** aim to replace downstream tools for full population-genomic, landscape-genomic, or functional-enrichment analyses.

Functional annotation is **not part of the validated PoLoCo core workflow** used in the manuscript. Earlier annotation-related development files, if retained, should be kept outside the core workflow, for example in `experimental/annotation_not_validated/`.

In the manuscript case study, pooled population analyses are generated from filtered BAM files and processed through a reproducible PoPoolation2-based pipeline. This step creates a BAM list, generates an mpileup, converts it to a synchronized read-count file, retains true polymorphic sites, applies minimum coverage and minimum population representation filters, calculates global minor allele frequencies, and performs distance-based thinning.

The final retained analytical dataset for the manuscript case study is:

```text
PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv
```

This workflow was developed for *Entomobrya nivalis* (Collembola) and is adaptable to other taxa. A case-study ENA manifest and downloader are provided in `ena_example/` so users can reproduce the manuscript input structure from public reads.

It accompanies the manuscript:

> **PoLoCo: A reproducible pooled low-coverage workflow for draft genome assembly and allele frequency analysis from ethanol-preserved small non-model invertebrates**  
> Mohammad Jamil Shuvo, Gernot Segelbacher, Julia C. Geue, [link pending journal publication].

---

## ⚙️ Installation

### 1. Clone this repository

```bash
git clone git@github.com:MohammadJamilShuvo/PoLoCo-workflow.git
cd PoLoCo-workflow
```

### 2. Install the PoLoCo conda environments

PoLoCo uses modular conda environments internally because different bioinformatics tools can have different dependency requirements. To make installation easier, all required core environments are defined and installed from a single script:

```bash
bash configs/install_poloco_conda_envs.sh
```

This creates or checks the following environments:

```text
poloco_qc_mapping
poloco_poolseq
poloco_assembly
```

The environments are used for:

```text
poloco_qc_mapping   preprocessing, FastQC/MultiQC, mapping, BAM filtering, coverage
poloco_poolseq      mpileup/sync generation, Pool-seq filtering, allele-frequency matrix, QC plots
poloco_assembly     draft genome assembly and assembly validation
```

Annotation tools are not installed because functional annotation is not part of the validated PoLoCo core workflow.

### 3. Check the workflow configuration

Before running PoLoCo, check the central configuration file:

```text
configs/poloco_config.sh
```

This file defines the project name, input folders, output folders, filtering thresholds, reference paths, resource settings, and the PoPoolation2 path.

For the manuscript case study, the default settings are:

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

For a new dataset, users should edit `configs/poloco_config.sh` before running the workflow.

Common settings to adjust are:

| Setting | Meaning | When to change |
|---|---|---|
| `PROJECT_PREFIX` | Prefix used for output files | Use a short project or species label |
| `ASSEMBLY_RAW_DIR` | Folder containing reads for draft genome assembly | Change if assembly reads are stored elsewhere |
| `POOL_RAW_DIR` | Folder containing pooled population reads | Change if Pool-seq reads are stored elsewhere |
| `READ1_SUFFIX`, `READ2_SUFFIX` | Paired-end read naming pattern | Change if files do not end in `_R1.fastq.gz` and `_R2.fastq.gz` |
| `REF_FASTA` | Draft/reference genome used for mapping | Change if using an existing reference |
| `PUBLISHED_REF` | Optional published reference used for validation | Change or leave unused depending on the project |
| `MINCOV` | Minimum read depth per pool at a site | Adjust based on sequencing depth |
| `MINPOP_MODE` | Use an absolute or proportional population threshold | Use `absolute` for fixed thresholds or `proportion` for new datasets |
| `MINPOP_ABS` | Minimum number of informative pools | For the manuscript case study, this is `55` |
| `MINPOP_PROP` | Minimum proportion of informative pools | Useful for datasets with different numbers of pools |
| `MAF` | Global minor allele-frequency threshold | Adjust for stricter or more relaxed SNP filtering |
| `THIN_DIST` | Distance-based thinning threshold in bp | Adjust depending on marker density and downstream goals |
| `MAPQ`, `BASEQ` | Mapping and base-quality thresholds | Adjust for stricter or more relaxed filtering |
| `POPOOLATION2_DIR` | PoPoolation2 installation path | Change if `mpileup2sync.pl` is installed elsewhere |

For new projects with a different number of pooled populations, we recommend using proportional minimum population filtering, for example:

```bash
MINPOP_MODE="proportion"
MINPOP_PROP=0.67
```

This keeps approximately two-thirds population representation, similar to the manuscript case study, without hard-coding `55`.

---

## 📥 Input Data and ENA Case-Study Example

PoLoCo requires **paired-end Illumina FASTQ files** as input. Users can start the workflow in three ways:

1. use their own local FASTQ files,
2. download the public *Entomobrya nivalis* case-study reads from ENA using the example manifest, or
3. adapt the ENA example manifest to their own publicly archived ENA dataset.

The manuscript case study uses ethanol-preserved *Entomobrya nivalis* pooled libraries deposited under European Nucleotide Archive (ENA) BioProject:

```text
PRJEB111482
```

The folder `ena_example/` contains the case-study manifest and a helper script for downloading the reads into the expected PoLoCo input structure:

```text
ena_example/
├── poloco_ena_case_study_manifest.tsv
└── download_poloco_ena_case_study_reads.py
```

The manifest separates the **single assembly library** from the **82 retained Pool-seq libraries** used in the manuscript case study.

### Expected raw-read directory structure

PoLoCo expects raw paired-end reads to be organized as follows:

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

The folder `01_raw_reads/assembly/` should contain the paired-end reads used for **draft genome assembly**.

The folder `01_raw_reads/pools/` should contain the paired-end reads used for **Pool-seq mapping, sync generation, SNP filtering, and allele-frequency estimation**.

Input files should be gzip-compressed paired-end FASTQ files, preferably with names ending in:

```text
_R1.fastq.gz
_R2.fastq.gz
```

If your files use another naming pattern, update `READ1_SUFFIX` and `READ2_SUFFIX` in `configs/poloco_config.sh`.

### Option 1: Use your own local FASTQ files

If you already have FASTQ files locally, create the expected input folders:

```bash
mkdir -p 01_raw_reads/assembly
mkdir -p 01_raw_reads/pools
```

Copy the assembly-pool reads into `01_raw_reads/assembly/`:

```bash
cp /path/to/assembly_pool_R1.fastq.gz 01_raw_reads/assembly/
cp /path/to/assembly_pool_R2.fastq.gz 01_raw_reads/assembly/
```

Copy the population Pool-seq reads into `01_raw_reads/pools/`:

```bash
cp /path/to/pool_*_R1.fastq.gz 01_raw_reads/pools/
cp /path/to/pool_*_R2.fastq.gz 01_raw_reads/pools/
```

Then check `configs/poloco_config.sh` and make sure the file suffixes and input folders match your data.

### Option 2: Download the PoLoCo case-study reads from ENA

To reproduce the manuscript case-study input structure, use the manifest and downloader in `ena_example/`.

First, run a dry run to check which files would be downloaded:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads \
  --dry-run
```

To download a small example subset consisting of the assembly library and three Pool-seq libraries, run:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads \
  --max-pools 3
```

To download the full manuscript case-study dataset, including the assembly library and all 82 retained Pool-seq libraries, run:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads
```

The downloader places the files into:

```text
01_raw_reads/assembly/
01_raw_reads/pools/
```

and verifies MD5 checksums when available.

For a small subset run, adjust `MINPOP_MODE` and `MINPOP_ABS` or `MINPOP_PROP` in `configs/poloco_config.sh`, because the manuscript value `MINPOP_ABS=55` is only appropriate for the full 82-pool case study.

For example, for three pools:

```bash
MINPOP_MODE="absolute"
MINPOP_ABS=2
```

or:

```bash
MINPOP_MODE="proportion"
MINPOP_PROP=0.67
```

### Option 3: Adapt the ENA example to your own public ENA dataset

Users with their own publicly available ENA data can adapt the example by editing:

```text
ena_example/poloco_ena_case_study_manifest.tsv
```

At minimum, the manifest should define:

```text
sample_id
library_role
run_accession
read1_url
read2_url
read1_filename
read2_filename
```

The `library_role` column should contain one of the following values:

```text
assembly
poolseq
```

Use `assembly` for the library used to build the draft reference genome, and use `poolseq` for pooled population libraries used for mapping and allele-frequency estimation.

After editing the manifest for another ENA project, run:

```bash
python ena_example/download_poloco_ena_case_study_reads.py \
  --manifest ena_example/poloco_ena_case_study_manifest.tsv \
  --outdir 01_raw_reads
```

The same PoLoCo workflow can then be run on the downloaded reads after updating `configs/poloco_config.sh`.

---

## 📂 Workflow Steps

The revised PoLoCo core workflow is organized into the following steps. Assembly is performed before mapping so that the project-specific draft genome can be prepared as the mapping reference.

| Step | Script | Tools | Environment | Main outputs |
|------|--------|-------|-------------|--------------|
| **0. Input checks** | `scripts/00_check_inputs.sh` | Bash | base / active shell | Checks input folders, read pairs, config, reference requirements |
| **1. Preprocessing & QC** | `scripts/01_preprocessing_qc.sh` | fastp, FastQC, MultiQC | `poloco_qc_mapping` | Trimmed FASTQ, QC reports |
| **2. Draft assembly** | `scripts/02_assembly.sh` | MEGAHIT, BUSCO | `poloco_assembly` | Draft genome assembly |
| **3. Reference preparation** | `scripts/03_prepare_reference.sh` | BWA, samtools | `poloco_qc_mapping` | `ref/poloco_draft.fa`, BWA index, FASTA index |
| **4. Assembly validation** | `scripts/04_validation.sh` | QUAST, FastANI, MUMmer4 | `poloco_assembly` | Assembly metrics, ANI, alignment validation |
| **5. Mapping & BAM filtering** | `scripts/05_mapping_dedup_filter.sh` | BWA, samtools, Picard | `poloco_qc_mapping` | Filtered BAM files |
| **6. Coverage estimation** | `scripts/06_coverage_depth.sh` | samtools | `poloco_qc_mapping` | Mean coverage per pool |
| **7. Pool-seq pipeline** | `scripts/07_poolseq_pipeline.sh` | samtools, PoPoolation2, Bash, awk/Python | `poloco_poolseq` | BAM list, mpileup, sync file, SNP table, allele-frequency matrix |
| **8. QC visualization** | `scripts/08_qc_visualization.sh` | Python QC scripts | `poloco_poolseq` | QC plots, summary tables, integrated QC report |

QC helper scripts are in `qc_scripts/`:

- `fastp_qc.py` – summarizes fastp reports.
- `alignment_qc.py` – summarizes BAM mapping statistics.
- `poolseq_af_qc.py` – visualizes allele-frequency distribution and missingness from the final retained dataset.
- `poolseq_summary_stats_qc.py` – computes SNP and population-level summary statistics from the final retained dataset.
- `final_qc_master.py` – integrates all QC results.

Functional annotation is not included in the validated core workflow.

---

## 🚀 Usage

Before running the workflow:

1. install the conda environments,
2. prepare or download input FASTQ files,
3. check `configs/poloco_config.sh`,
4. run the workflow mode that matches your project.

### Full workflow

Use this when you want PoLoCo to preprocess reads, assemble a draft genome, prepare the reference, map Pool-seq libraries, and create the allele-frequency matrix:

```bash
bash scripts/run_poloco_pipeline.sh --mode full
```

The full workflow runs:

```text
00_check_inputs
01_preprocessing_qc
02_assembly
03_prepare_reference
04_validation
05_mapping_dedup_filter
06_coverage_depth
07_poolseq_pipeline
08_qc_visualization
```

### Pool-seq-only workflow

Use this when you already have a reference genome and only want to run mapping, sync generation, SNP filtering, and allele-frequency matrix construction:

```bash
bash scripts/run_poloco_pipeline.sh --mode poolseq-only
```

Before using this mode, set `REF_FASTA` in `configs/poloco_config.sh` to the reference genome you want to use.

### Assembly-only workflow

Use this when you only want to assemble and validate a draft genome:

```bash
bash scripts/run_poloco_pipeline.sh --mode assembly-only
```

### Run a single step

For debugging or rerunning a specific part of the workflow:

```bash
bash scripts/run_poloco_pipeline.sh --step 7
```

The step number corresponds to the workflow table above.

On SLURM-based HPC systems, the same commands can be submitted through `sbatch`, depending on local cluster configuration. For example:

```bash
sbatch scripts/run_poloco_pipeline.sh --mode full
```

---

## 📊 Expected Outputs

The main output folders are:

- `01_raw_reads/assembly/` – raw paired-end reads used for draft genome assembly
- `01_raw_reads/pools/` – raw paired-end Pool-seq libraries used for population-level analysis
- `02_trimmed_reads/assembly/` – trimmed assembly reads
- `02_trimmed_reads/pools/` – trimmed Pool-seq reads
- `02_fastqc_reports/` – fastp, FastQC, and MultiQC reports
- `03_alignments/` – mapped BAMs
- `04_bam_filtered/` – filtered BAMs with duplicates removed and mapping-quality filtering applied
- `05_coverage/` – coverage estimates
- `08_assembly/` – draft genome contigs and assembly outputs
- `09_validation/` – QUAST metrics, FastANI comparisons, and alignment validation outputs
- `PoPoolation2/metadata/bamlist_clean.txt` – BAM list used for Pool-seq analysis
- `PoPoolation2/results/` – Pool-seq outputs, including mpileup, sync file, filtered SNP table, and allele-frequency matrix
- `07_plots/` – QC plots and integrated QC summaries

For the manuscript case study, the key final allele-frequency matrix is:

```text
PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv
```

---

## 🧪 Downstream use

PoLoCo produces filtered SNP tables and allele-frequency matrices. These outputs can be used for downstream analyses such as:

- PCA or ordination of allele-frequency variation,
- pairwise genetic differentiation,
- reference-comparison analyses,
- landscape-genomic or genotype-environment association analyses.

These analyses are downstream uses of PoLoCo outputs and are not required for the validated core workflow.

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
