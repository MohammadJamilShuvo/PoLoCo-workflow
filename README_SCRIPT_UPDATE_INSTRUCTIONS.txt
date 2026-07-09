PoLoCo simplified reordered script update
=======================================

This package replaces the old active workflow scripts with the simplified reordered core workflow.
It removes the separate reference-preparation script, removes the separate sync-to-AF helper, and does not add a separate fastp-summary helper.

Final active workflow:
  00_check_inputs.sh
  01_preprocessing_qc.sh
  02_assembly.sh                    # includes reference preparation
  03_validation.sh
  04_mapping_dedup_filter.sh
  05_coverage_depth.sh
  06_poolseq_pipeline.sh             # includes sync filtering and AF matrix construction
  07_qc_visualization.sh
  run_poloco_pipeline.sh

Important assumptions:
  - configs/poloco_config.sh exists and is correctly formatted.
  - configs/install_poloco_conda_envs.sh creates poloco_qc_mapping, poloco_poolseq, and poloco_assembly.
  - Raw reads are organized as:
      01_raw_reads/assembly/assembly_pool_R1.fastq.gz
      01_raw_reads/assembly/assembly_pool_R2.fastq.gz
      01_raw_reads/pools/*_R1.fastq.gz
      01_raw_reads/pools/*_R2.fastq.gz

How to apply:
  1. Back up the current active scripts:
       mkdir -p experimental/old_scripts_before_simplified_reorder
       cp scripts/*.sh experimental/old_scripts_before_simplified_reorder/ 2>/dev/null || true
       cp qc_scripts/*.py experimental/old_scripts_before_simplified_reorder/ 2>/dev/null || true

  2. Copy the scripts/ folder from this package into the repository, replacing the current scripts/ folder.

  3. Copy the qc_scripts/ folder from this package into the repository, replacing the current qc_scripts/ folder.

  4. Remove old active script names if they remain:
       rm -f scripts/02_mapping_dedup_filter.sh scripts/03_coverage_depth.sh scripts/04_poolseq_pipeline.sh
       rm -f scripts/05_qc_visualization.sh scripts/06_assembly.sh scripts/07_validation.sh scripts/08_annotation.sh

     Note: after copying the new scripts, files with names 02 to 07 will still exist, but with the new meaning/order:
       02_assembly.sh, 03_validation.sh, 04_mapping_dedup_filter.sh, 05_coverage_depth.sh, 06_poolseq_pipeline.sh, 07_qc_visualization.sh

  5. Test shell syntax:
       bash -n scripts/00_check_inputs.sh
       bash -n scripts/01_preprocessing_qc.sh
       bash -n scripts/02_assembly.sh
       bash -n scripts/03_validation.sh
       bash -n scripts/04_mapping_dedup_filter.sh
       bash -n scripts/05_coverage_depth.sh
       bash -n scripts/06_poolseq_pipeline.sh
       bash -n scripts/07_qc_visualization.sh
       bash -n scripts/run_poloco_pipeline.sh

  6. Test Python syntax:
       python -m py_compile qc_scripts/*.py

How to run:
  Full workflow:
       bash scripts/run_poloco_pipeline.sh --mode full

  Pool-seq only with existing ref/poloco_draft.fa:
       bash scripts/run_poloco_pipeline.sh --mode poolseq-only

  Assembly and validation only:
       bash scripts/run_poloco_pipeline.sh --mode assembly-only

  Single step example:
       bash scripts/run_poloco_pipeline.sh --step 06
