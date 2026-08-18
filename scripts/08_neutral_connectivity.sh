#!/usr/bin/env bash
#SBATCH --job-name=poloco_connectivity
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/08_neutral_connectivity_%j.out
#SBATCH --error=logs/08_neutral_connectivity_%j.err

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

set -a
source "configs/poloco_config.sh"
set +a

if [[ "${RUN_CONNECTIVITY_ANALYSIS:-no}" != "yes" ]]; then
    echo "[SKIP] Population structure and connectivity analysis is disabled."
    exit 0
fi

activate_env() {
    local env_name="$1"

    if ! command -v conda >/dev/null 2>&1; then
        echo "[ERROR] conda was not found."
        exit 1
    fi

    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${env_name}"
}

activate_env poloco_connectivity

if ! command -v Rscript >/dev/null 2>&1; then
    echo "[ERROR] Rscript was not found in poloco_connectivity."
    exit 1
fi

MAF_LABEL="${MAF/./}"
AF_MATRIX="${POOLSEQ_RESULTS_DIR}/geno_AF_matrix_LD_MAF${MAF_LABEL}.csv"
BAMLIST="${POOLSEQ_METADATA_DIR}/bamlist_clean.txt"

if [[ ! -s "${AF_MATRIX}" ]]; then
    echo "[ERROR] Allele-frequency matrix not found or empty: ${AF_MATRIX}"
    echo "[ERROR] Run Step 06 first."
    exit 1
fi

if [[ ! -s "${BAMLIST}" ]]; then
    echo "[ERROR] BAM order file not found or empty: ${BAMLIST}"
    echo "[ERROR] Run Step 06 first."
    exit 1
fi

if [[ ! -s "${COORDINATES_FILE}" ]]; then
    echo "[ERROR] Coordinate file not found or empty: ${COORDINATES_FILE}"
    exit 1
fi

mkdir -p "${CONNECTIVITY_DIR}" logs

echo "============================================================"
echo "PoLoCo Population structure and connectivity"
echo "============================================================"
echo "[INFO] Allele-frequency matrix: ${AF_MATRIX}"
echo "[INFO] BAM order: ${BAMLIST}"
echo "[INFO] Coordinates: ${COORDINATES_FILE}"
echo "[INFO] Output directory: ${CONNECTIVITY_DIR}"
echo "[INFO] Mantel permutations: ${MANTEL_PERMUTATIONS}"

export POLOCO_AF_MATRIX="${AF_MATRIX}"
export POLOCO_BAMLIST="${BAMLIST}"
export POLOCO_COORDINATES="${COORDINATES_FILE}"
export POLOCO_CONNECTIVITY_DIR="${CONNECTIVITY_DIR}"
export POLOCO_MANTEL_PERMUTATIONS="${MANTEL_PERMUTATIONS}"

Rscript - <<'POLOCO_R'
af_file <- Sys.getenv("POLOCO_AF_MATRIX")
bamlist_file <- Sys.getenv("POLOCO_BAMLIST")
coordinates_file <- Sys.getenv("POLOCO_COORDINATES")
output_dir <- Sys.getenv("POLOCO_CONNECTIVITY_DIR")
mantel_permutations <- as.integer(Sys.getenv("POLOCO_MANTEL_PERMUTATIONS"))

required_packages <- c("data.table", "ggplot2", "vegan", "openxlsx", "scales")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop(
    "Missing R packages in poloco_connectivity: ",
    paste(missing_packages, collapse = ", ")
  )
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

normalise_pool_id <- function(x) {
  x <- basename(as.character(x))
  x <- sub("\\.filtered\\.bam$", "", x)
  x <- sub("^ENIV_pool_", "", x)
  x
}

# Read sample order from the exact BAM list used to create the matrix.
bam_paths <- readLines(bamlist_file, warn = FALSE)
bam_paths <- bam_paths[nzchar(trimws(bam_paths))]
if (length(bam_paths) < 3) {
  stop("At least three pools are required for the connectivity analysis.")
}

pool_ids <- normalise_pool_id(bam_paths)
if (anyDuplicated(pool_ids)) {
  stop("Duplicate pool IDs were derived from bamlist_clean.txt.")
}

# The PoLoCo allele-frequency matrix has no header:
# column 1 = SNP ID; remaining columns = pools in BAM-list order.
af <- data.table::fread(
  af_file,
  header = FALSE,
  na.strings = c("NA", "NaN", "")
)

expected_columns <- length(pool_ids) + 1L
if (ncol(af) != expected_columns) {
  stop(
    "Allele-frequency matrix contains ", ncol(af),
    " columns, but ", expected_columns,
    " were expected from bamlist_clean.txt."
  )
}

snp_ids <- as.character(af[[1]])
geno_mat <- as.matrix(af[, -1, with = FALSE])
storage.mode(geno_mat) <- "numeric"
colnames(geno_mat) <- pool_ids
rownames(geno_mat) <- snp_ids

# Remove unusable sites and mean-impute remaining missing values by SNP.
keep_not_all_na <- rowSums(!is.na(geno_mat)) > 0
geno_mat <- geno_mat[keep_not_all_na, , drop = FALSE]

if (nrow(geno_mat) == 0) {
  stop("No usable SNP rows remain after removing all-missing sites.")
}

snp_means <- rowMeans(geno_mat, na.rm = TRUE)
missing_index <- which(is.na(geno_mat), arr.ind = TRUE)
if (nrow(missing_index) > 0) {
  geno_mat[missing_index] <- snp_means[missing_index[, 1]]
}

keep_variable <- apply(geno_mat, 1, function(x) stats::var(x) > 0)
geno_mat <- geno_mat[keep_variable, , drop = FALSE]

if (nrow(geno_mat) < 2) {
  stop("Fewer than two variable SNPs remain for analysis.")
}

# Read and align projected coordinates.
coords <- data.table::fread(
  coordinates_file,
  colClasses = list(character = "pool_id")
)

required_coordinate_columns <- c("pool_id", "x", "y")
if (!all(required_coordinate_columns %in% names(coords))) {
  stop(
    "Coordinate file must contain: ",
    paste(required_coordinate_columns, collapse = ", ")
  )
}

coords <- coords[, ..required_coordinate_columns]
coords[, pool_id := normalise_pool_id(pool_id)]
coords[, x := as.numeric(x)]
coords[, y := as.numeric(y)]

if (anyNA(coords$x) || anyNA(coords$y)) {
  stop("Coordinate columns x and y must contain numeric projected coordinates.")
}
if (anyDuplicated(coords$pool_id)) {
  stop("Coordinate file contains duplicate pool_id values.")
}

missing_coordinates <- setdiff(pool_ids, coords$pool_id)
extra_coordinates <- setdiff(coords$pool_id, pool_ids)

if (length(missing_coordinates) > 0) {
  stop(
    "Coordinates are missing for these pools: ",
    paste(missing_coordinates, collapse = ", ")
  )
}

coords <- coords[match(pool_ids, pool_id)]
if (!all(coords$pool_id == pool_ids)) {
  stop("Coordinate order could not be aligned to the BAM-list order.")
}

# PCA of allele-frequency variation.
pca <- stats::prcomp(t(geno_mat), center = TRUE, scale. = FALSE)
eigenvalues <- pca$sdev^2
variance_explained <- eigenvalues / sum(eigenvalues)

pca_variance <- data.frame(
  Principal_Component = paste0("PC", seq_along(variance_explained)),
  Eigenvalue = eigenvalues,
  Variance_Explained = variance_explained,
  Variance_Explained_Percent = 100 * variance_explained
)

pca_scores <- data.frame(
  pool_id = rownames(pca$x),
  pca$x,
  check.names = FALSE
)

pca_plot_data <- merge(
  pca_scores[, c("pool_id", "PC1", "PC2")],
  as.data.frame(coords),
  by = "pool_id",
  sort = FALSE
)
pca_plot_data <- pca_plot_data[match(pool_ids, pca_plot_data$pool_id), ]

theme_poloco <- function() {
  ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0.5),
      axis.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

p_pca <- ggplot2::ggplot(pca_plot_data, ggplot2::aes(PC1, PC2)) +
  ggplot2::geom_point(size = 2.8, alpha = 0.85) +
  ggplot2::labs(
    title = "Neutral allele-frequency structure",
    x = paste0(
      "PC1 (",
      round(100 * variance_explained[1], 2),
      "% of variance)"
    ),
    y = paste0(
      "PC2 (",
      round(100 * variance_explained[2], 2),
      "% of variance)"
    )
  ) +
  theme_poloco()

ggplot2::ggsave(
  file.path(output_dir, "PCA_neutral_structure.png"),
  p_pca,
  width = 7,
  height = 6,
  dpi = 300
)

p_map <- ggplot2::ggplot(
  pca_plot_data,
  ggplot2::aes(x = x, y = y, colour = PC1)
) +
  ggplot2::geom_point(size = 3) +
  ggplot2::scale_colour_viridis_c(option = "plasma") +
  ggplot2::coord_equal() +
  ggplot2::labs(
    title = "Spatial pattern of the main neutral axis",
    x = "Easting (m)",
    y = "Northing (m)",
    colour = "PC1 score"
  ) +
  theme_poloco()

ggplot2::ggsave(
  file.path(output_dir, "PCA_PC1_spatial_map.png"),
  p_map,
  width = 7,
  height = 6,
  dpi = 300
)

# Isolation by distance.
genetic_distance <- as.matrix(stats::dist(t(geno_mat), method = "euclidean"))
coordinate_matrix <- as.matrix(coords[, .(x, y)])
rownames(coordinate_matrix) <- coords$pool_id
geographic_distance <- as.matrix(stats::dist(coordinate_matrix, method = "euclidean"))

rownames(genetic_distance) <- pool_ids
colnames(genetic_distance) <- pool_ids
rownames(geographic_distance) <- pool_ids
colnames(geographic_distance) <- pool_ids

set.seed(123)
mantel_result <- vegan::mantel(
  stats::as.dist(genetic_distance),
  stats::as.dist(geographic_distance),
  permutations = mantel_permutations,
  method = "pearson"
)

upper_index <- upper.tri(genetic_distance)
pair_index <- which(upper_index, arr.ind = TRUE)

pairwise_distances <- data.frame(
  pool_1 = rownames(genetic_distance)[pair_index[, 1]],
  pool_2 = colnames(genetic_distance)[pair_index[, 2]],
  genetic_distance = genetic_distance[upper_index],
  geographic_distance_m = geographic_distance[upper_index]
)

mantel_r <- as.numeric(mantel_result$statistic)
mantel_p <- as.numeric(mantel_result$signif)

if (mantel_p < 0.05 && mantel_r > 0) {
  interpretation <- "Significant positive isolation-by-distance pattern."
} else if (mantel_p < 0.05 && mantel_r < 0) {
  interpretation <- "Significant negative relationship between genetic and geographic distance."
} else {
  interpretation <- "No statistically significant isolation-by-distance pattern."
}

p_ibd <- ggplot2::ggplot(
  pairwise_distances,
  ggplot2::aes(geographic_distance_m, genetic_distance)
) +
  ggplot2::geom_point(alpha = 0.35, size = 1.2) +
  ggplot2::geom_smooth(method = "lm", se = TRUE) +
  ggplot2::scale_x_continuous(labels = scales::comma) +
  ggplot2::annotate(
    "text",
    x = Inf,
    y = Inf,
    label = paste0(
      "Mantel r = ", sprintf("%.3f", mantel_r),
      "\np = ", sprintf("%.4f", mantel_p)
    ),
    hjust = 1.05,
    vjust = 1.2,
    size = 3.5
  ) +
  ggplot2::labs(
    title = "Isolation by distance",
    x = "Geographic distance (m)",
    y = "Genetic distance"
  ) +
  theme_poloco()

ggplot2::ggsave(
  file.path(output_dir, "isolation_by_distance.png"),
  p_ibd,
  width = 7,
  height = 6,
  dpi = 300
)

analysis_summary <- data.frame(
  Metric = c(
    "Number of populations",
    "Number of variable SNPs",
    "PC1 variance explained (%)",
    "PC2 variance explained (%)",
    "Mantel r",
    "Mantel p value",
    "Mantel permutations",
    "Interpretation"
  ),
  Value = c(
    ncol(geno_mat),
    nrow(geno_mat),
    round(100 * variance_explained[1], 4),
    round(100 * variance_explained[2], 4),
    round(mantel_r, 6),
    round(mantel_p, 6),
    mantel_permutations,
    interpretation
  ),
  stringsAsFactors = FALSE
)

data.table::fwrite(
  analysis_summary,
  file.path(output_dir, "connectivity_summary.tsv"),
  sep = "\t"
)
data.table::fwrite(
  pca_variance,
  file.path(output_dir, "pca_variance.csv")
)
data.table::fwrite(
  pca_scores,
  file.path(output_dir, "pca_scores.csv")
)
data.table::fwrite(
  pairwise_distances,
  file.path(output_dir, "pairwise_distances.csv")
)

workbook <- openxlsx::createWorkbook()

openxlsx::addWorksheet(workbook, "Summary")
openxlsx::writeData(workbook, "Summary", analysis_summary)

openxlsx::addWorksheet(workbook, "PCA_variance")
openxlsx::writeData(workbook, "PCA_variance", pca_variance)

openxlsx::addWorksheet(workbook, "PCA_scores")
openxlsx::writeData(workbook, "PCA_scores", pca_scores)

openxlsx::addWorksheet(workbook, "Coordinates")
openxlsx::writeData(workbook, "Coordinates", as.data.frame(coords))

openxlsx::addWorksheet(workbook, "Pairwise_distances")
openxlsx::writeData(workbook, "Pairwise_distances", pairwise_distances)

openxlsx::saveWorkbook(
  workbook,
  file.path(output_dir, "neutral_connectivity_results.xlsx"),
  overwrite = TRUE
)

writeLines(
  c(
    paste0("Populations: ", ncol(geno_mat)),
    paste0("Variable SNPs: ", nrow(geno_mat)),
    paste0("PC1 variance explained: ", round(100 * variance_explained[1], 2), "%"),
    paste0("PC2 variance explained: ", round(100 * variance_explained[2], 2), "%"),
    paste0("Mantel r: ", sprintf("%.4f", mantel_r)),
    paste0("Mantel p value: ", sprintf("%.6f", mantel_p)),
    paste0("Interpretation: ", interpretation)
  ),
  file.path(output_dir, "analysis_interpretation.txt")
)

message("[OK] Results written to: ", output_dir)
if (length(extra_coordinates) > 0) {
  message(
    "[INFO] Coordinate rows not used because no matching BAM was present: ",
    paste(extra_coordinates, collapse = ", ")
  )
}
POLOCO_R

echo "[OK] Neutral population structure and connectivity analysis finished."
