# 🧬 PoLoCo Workflow!
**Reproducible pipeline for pooled draft genome assembly and Pool-seq allele-frequency analysis of non-model invertebrates**  

![workflow](https://github.com/user-attachments/assets/20c36866-0dfd-4626-a3d5-9b92721b1bf1)

---

## 📖 Overview

**PoLoCo** (Pooled Low-Coverage) is an open-source workflow designed for **non-model invertebrates** where individual high-quality genomes are difficult to obtain. It enables:

- **Draft genome assembly** from pooled, ethanol-preserved specimens.
- **Read preprocessing, mapping, and BAM filtering** with strict QC.
- **Pool-seq sync generation and allele-frequency matrix construction** using **PoPoolation2** and downstream Bash-based filtering.
- **QC visualization** at every stage for transparency and reproducibility.
- **Optional modules** for genome assembly validation and functional annotation.

In the final workflow version used for the manuscript, pooled population analyses are generated from filtered BAM files and processed through a reproducible PoPoolation2-based pipeline. This step creates a BAM list, generates an mpileup, converts it to a synchronized read-count file (`envilis.sync`), retains true polymorphic sites, applies minimum coverage and minimum population representation filters, calculates global minor allele frequencies, and performs distance-based thinning.

The final retained analytical dataset is:

`PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv`

This workflow was developed for *Entomobrya nivalis* (Collembola) and is adaptable to other taxa. A case-study ENA manifest and downloader are provided in `ena_example/` so users can reproduce the manuscript input structure from public reads.  
It accompanies the manuscript:

> **PoLoCo: A reproducible workflow for pooled draft genome assembly and allele-frequency analysis of ethanol-preserved non-model invertebrates**  
> Mohammad Jamil Shuvo *et al.*, [link pending journal publication].

---

## ⚙️ Installation

### 1. Clone this repository

```bash
git clone git@github.com:MohammadJamilShuvo/PoLoCo-workflow.git
cd PoLoCo-workflow
```

### 2. Install environments

PoLoCo uses **modular conda environments** to avoid dependency conflicts.

```bash
conda env create -f configs/envs_qc_mapping.yml
conda env create -f configs/envs_poolseq.yml
conda env create -f configs/envs_assembly.yml
conda env create -f configs/envs_annotation.yml
```

### 3. Activate the environment for each step

```bash
conda activate poloco_qc_mapping   # QC, mapping, coverage
conda activate poloco_poolseq      # Pool-seq sync generation, filtering, QC
conda activate poloco_assembly     # Assembly, validation
conda activate poloco_annotation   # Annotation
```

---

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

### Option 1: Use your own local FASTQ files

If you already have FASTQ files locally, create the expected input folders:

```bash
mkdir -p 01_raw_reads/assembly
mkdir -p 01_raw_reads/pools
```

Then copy the assembly-pool reads into `01_raw_reads/assembly/`:

```bash
cp /path/to/assembly_pool_R1.fastq.gz 01_raw_reads/assembly/
cp /path/to/assembly_pool_R2.fastq.gz 01_raw_reads/assembly/
```

Copy the population Pool-seq reads into `01_raw_reads/pools/`:

```bash
cp /path/to/pool_*_R1.fastq.gz 01_raw_reads/pools/
cp /path/to/pool_*_R2.fastq.gz 01_raw_reads/pools/
```

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

The same PoLoCo workflow can then be run on the downloaded reads.


## 📂 Workflow Steps

The PoLoCo workflow is organized into **eight steps**. Each step has its own script, toolset, and environment.

| Step | Script | Tools | Environment | Outputs |
|------|--------|-------|-------------|---------|
| **1. Preprocessing & QC** | `scripts/01_preprocessing_qc.sh` | fastp, FastQC, MultiQC | `poloco_qc_mapping` | Trimmed FASTQ, QC reports |
| **2. Mapping & Filtering** | `scripts/02_mapping_dedup_filter.sh` | BWA, samtools, Picard | `poloco_qc_mapping` | Filtered BAM files |
| **3. Coverage Estimation** | `scripts/03_coverage_depth.sh` | samtools | `poloco_qc_mapping` | Mean coverage per pool |
| **4. Pool-seq Pipeline** | `scripts/04_poolseq_pipeline.sh` | samtools, PoPoolation2, Bash, awk | `poloco_poolseq` | BAM list, mpileup, sync file, filtered SNP table, allele-frequency matrix |
| **5. QC Visualization** | `scripts/05_qc_visualization.sh` | Python QC scripts | `poloco_poolseq` | QC plots, summary tables |
| **6. Assembly** | `scripts/06_assembly.sh` | MEGAHIT, BUSCO | `poloco_assembly` | Draft genome assembly |
| **7. Validation** | `scripts/07_validation.sh` | QUAST, FastANI | `poloco_assembly` | Assembly metrics, ANI |
| **8. Annotation (optional)** | `scripts/08_annotation.sh` | RepeatModeler, RepeatMasker, BRAKER2, eggNOG, InterProScan | `poloco_annotation` | Masked genome, gene models, annotation tables |

QC helper scripts are in `qc_scripts/`:

- `fastp_qc.py` – summarizes fastp reports.
- `alignment_qc.py` – summarizes BAM mapping stats.
- `poolseq_af_qc.py` – visualizes allele-frequency distribution and missingness from the final retained dataset.
- `poolseq_summary_stats_qc.py` – computes SNP and population-level summary statistics from the final retained dataset.
- `final_qc_master.py` – integrates all QC results.

---

## 🚀 Usage

Before running the workflow, prepare the input data using one of the options above. For the ENA case-study example, the downloader creates the required `01_raw_reads/assembly/` and `01_raw_reads/pools/` folders automatically.

### Run the entire workflow

```bash
sbatch scripts/run_poloco_pipeline.sh --step all
```

### Run a single step (e.g., Pool-seq pipeline)

```bash
sbatch scripts/run_poloco_pipeline.sh --step 4
```

### Run QC visualization

```bash
sbatch scripts/run_poloco_pipeline.sh --step 5
```

---

## 📊 Expected Outputs

- `01_raw_reads/assembly/` – raw paired-end reads used for draft genome assembly
- `01_raw_reads/pools/` – raw paired-end Pool-seq libraries used for population-level analysis
- `02_trimmed_reads/` – trimmed FASTQ reads
- `03_alignments/` – mapped BAMs
- `04_bam_filtered/` – filtered BAMs (duplicates removed, MQ ≥ 30)
- `05_coverage/` – coverage estimates
- `PoPoolation2/metadata/bamlist_clean.txt` – BAM list used for Pool-seq analysis
- `PoPoolation2/results/envilis.mpileup` – mpileup generated from filtered BAMs
- `PoPoolation2/results/envilis.sync` – synchronized pooled read-count file
- `PoPoolation2/results/envilis_snps.sync` – polymorphic-site sync file
- `PoPoolation2/results/envilis_snps_LD_MAF05.txt` – final retained SNP annotation table
- `PoPoolation2/results/geno_AF_matrix_LD_MAF05.csv` – final retained allele-frequency matrix used in downstream analyses
- `07_plots/` – QC plots + integrated QC table (`poloco_master_qc.xlsx`)
- `08_assembly/` – draft genome contigs
- `09_validation/` – QUAST metrics, FastANI comparisons
- `10_annotation/` – annotation files (if step 8 is run)

---

## 🙌 Contributing

Contributions, bug reports, and feature requests are welcome! Please open an issue or pull request on GitHub.

---

## 📖 Citation

If you use this workflow, please cite:

> Mohammad Jamil Shuvo *et al.* (2025). **PoLoCo: A reproducible workflow for pooled draft genome assembly and allele-frequency analysis of ethanol-preserved non-model invertebrates**. [Journal link pending].

Also cite the tools used:

- [fastp](https://github.com/OpenGene/fastp)
- [PoPoolation2](https://sourceforge.net/projects/popoolation2/)
- [samtools](http://www.htslib.org/)
- [MEGAHIT](https://github.com/voutcn/megahit)
- [BUSCO](https://busco.ezlab.org)
- [BRAKER2](https://github.com/Gaius-Augustus/BRAKER)
- [eggNOG-mapper](http://eggnog-mapper.embl.de/)

---

## 📜 License

This project is released under the MIT License.
