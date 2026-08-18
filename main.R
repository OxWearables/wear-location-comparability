library(here)
library(rmarkdown)

render_step <- function(path, step_label) {
  cat("\n", strrep("=", 60), "\n", sep = "")
  cat(" ", step_label, "\n")
  cat(strrep("=", 60), "\n", sep = "")
  rmarkdown::render(here(path), envir = new.env())
  cat("Done:", path, "\n")
}

# ── 1. Prepare phenotypes and covariates ────────────────────────────────────
render_step("R/1-prep/01_prepare_swl_phenotypes.Rmd",
            "Step 1a: Prepare SWL phenotypes")

render_step("R/1-prep/02_prepare_raine_phenotypes.Rmd",
            "Step 1b: Prepare Raine phenotypes")

render_step("R/1-prep/03_prepare_covariates.Rmd",
            "Step 1c: Prepare covariates")

# ── 2. Analyses ─────────────────────────────────────────────────────────────
render_step("R/2-analysis/01_qc_participants.Rmd",
            "Step 2: QC participants")

render_step("R/2-analysis/02_main_analyses.Rmd",
            "Step 3a: Main analyses")

render_step("R/2-analysis/03_stratified_analyses.Rmd",
            "Step 3b: Stratified analyses")

render_step("R/2-analysis/04_sensitivity_analyses.Rmd",
            "Step 3c: Sensitivity analyses")

render_step("R/2-analysis/05_external_validation.Rmd",
            "Step 3d: External validation")

cat("\n", strrep("=", 60), "\n", sep = "")
cat(" All steps complete.\n")
cat(strrep("=", 60), "\n", sep = "")