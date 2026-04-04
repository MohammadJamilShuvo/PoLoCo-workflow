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

This workflow was developed for *Entomobrya nivalis* (Collembola) and is adaptable to other taxa.  
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
