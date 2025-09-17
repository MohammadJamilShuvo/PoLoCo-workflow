# 🧬 PoLoCo Workflow  
**Reproducible pipeline for pooled draft genome assembly and Pool-Seq SNP analysis of non-model invertebrates**  

---

## 📖 Overview  

**PoLoCo** (Pooled Low-Coverage) is an open-source workflow designed for **non-model invertebrates** where individual high-quality genomes are difficult to obtain. It enables:  

- **Draft genome assembly** from pooled, ethanol-preserved specimens.  
- **Read preprocessing, mapping, and BAM filtering** with strict QC.  
- **SNP discovery and allele frequency estimation** using **ANGSD**.  
- **QC visualization** at every stage for transparency and reproducibility.  
- **Optional modules** for genome assembly validation and functional annotation.  

This workflow was developed for *Entomobrya nivalis* (Collembola) and is easily adaptable to other taxa.  
It accompanies the manuscript:  

> **PoLoCo: A reproducible workflow for pooled draft genome assembly and population genomics of ethanol-preserved invertebrates**  
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
conda env create -f configs/envs_angsd.yml
conda env create -f configs/envs_assembly.yml
conda env create -f configs/envs_annotation.yml
```

### 3. Activate the environment for each step  
```bash
conda activate poloco_qc_mapping   # QC, mapping, coverage
conda activate poloco_angsd        # SNP calling, QC visualization
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
| **4. SNP Discovery** | `scripts/04_angsd_snp_calling.sh` | ANGSD, bcftools | `poloco_angsd` | SAF, SFS, MAF, SNP stats |
| **5. QC Visualization** | `scripts/05_qc_visualization.sh` | Python QC scripts | `poloco_angsd` | SNP histograms, QC tables |
| **6. Assembly** | `scripts/06_assembly.sh` | MEGAHIT, BUSCO | `poloco_assembly` | Draft genome assembly |
| **7. Validation** | `scripts/07_validation.sh` | QUAST, FastANI | `poloco_assembly` | Assembly metrics, ANI |
| **8. Annotation (optional)** | `scripts/08_annotation.sh` | RepeatModeler, RepeatMasker, BRAKER2, eggNOG, InterProScan | `poloco_annotation` | Masked genome, gene models, annotation tables |

QC helper scripts are in `qc_scripts/`:
- `fastp_qc.py` – summarizes fastp reports.  
- `alignment_qc.py` – summarizes BAM mapping stats.  
- `angsd_sfs_maf_qc.py` – visualizes MAF distribution.  
- `angsd_summary_stats_qc.py` – computes SNP summaries.  
- `final_qc_master.py` – integrates all QC results.  

---

## 🚀 Usage  

### Run the entire workflow  
```bash
sbatch scripts/run_poloco_pipeline.sh --step all
```

### Run a single step (e.g., SNP calling)  
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
- `06_angsd/` – ANGSD SNP outputs (MAF, SFS, SAF)  
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

> Mohammad Jamil Shuvo *et al.* (2025). **PoLoCo: A reproducible workflow for pooled draft genome assembly and population genomics of ethanol-preserved invertebrates**. [Journal link pending].  

Also cite the tools used:  
- [fastp](https://github.com/OpenGene/fastp)  
- [ANGSD](http://www.popgen.dk/angsd)  
- [MEGAHIT](https://github.com/voutcn/megahit)  
- [BUSCO](https://busco.ezlab.org)  
- [BRAKER2](https://github.com/Gaius-Augustus/BRAKER)  
- [eggNOG-mapper](http://eggnog-mapper.embl.de/)  

---

## 📜 License  

This project is released under the MIT License.  
