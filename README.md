# Wear-location comparability

Analysis code for **"Towards harmonised accelerometer-derived physical activity: A
comparability study across wrist, thigh, and hip wear locations"**.

The study assesses the agreement of movement behaviours derived from wrist-, thigh-
and hip-worn accelerometers in free-living adults, using data from *SMART Work & Life*
(wrist vs. thigh), the *Raine Study Gen1* (wrist vs. hip), and *CAP-24* as external
validation.

> **Citation** — 
> DOI: `TBC`

## Repository structure

```
process_raw/     Raw accelerometer processing (Python + R)
R/1-prep/        Phenotype and covariate derivation
R/2-analysis/    Quality control, main, stratified, sensitivity and validation analyses
main.R           Runs the full R pipeline in order
output/          Data and results — NOT distributed
```

## Data availability

**No participant data are included in this repository.** Access to the underlying data is governed by each study:

| Study | Access |
|---|---|
| SMART Work & Life and CAP-24| Access to SWAL and CAP-24 study data can be obtained by contacting Charlotte Edwardson (ce95@leicester.ac.uk); proposals requesting access must specify the intended use of the data and require approval from the trial co-investigator team prior to release.  |
| Raine Study Gen1 | The Raine Study encourages collaboration with national and international researchers. More details on how to get access to the data are published on the website of the Raine Study (www.rainestudy.org.au). |


## Processing raw accelerometer data

Replace `<RAW_DIR>` and `<OUT_DIR>` with your own paths. All commands run from the
project root.

**1. Wrist-worn files via the OxWearables packages**

```shell
python process_raw/batch_process_oxwearables.py -d <RAW_DIR> -o <OUT_DIR> -p actinet
python process_raw/batch_process_oxwearables.py -d <RAW_DIR> -o <OUT_DIR> -p stepcount
```

Run once per cohort: Axivity AX3 (SMART Work & Life) and ActiGraph GT3X (Raine Gen1).

**2. Restore the wear-time column in `stepcount` daily summaries**

`stepcount` omits `WearTime(hours)` from its adjusted daily output, so it is merged back
in from the unadjusted file:

```shell
python process_raw/merge_stepcount_daily_csvs.py -d <OUT_DIR>
```

**3. Thigh- and hip-worn files via actipy (ENMO)**

```shell
python process_raw/batch_process_oxwearables.py -d <RAW_DIR> -o <OUT_DIR> -p actipy
```

**4. Collate per-participant outputs into CSVs**

```shell
python process_raw/collate_oxwearables_output.py -d <OUT_DIR> -p actinet
```

Repeat with `-p stepcount` and `-p actipy`.

**5. Derive ActiLife phenotypes and cadence metrics (R)**

Set the data directory at the top of each file, then run interactively:

- `process_raw/generate_actilife_phenotypes.Rmd` — 24-hour and waking-hour activity,
  step and sleep summaries from 60s-epoch ActiLife data
- `process_raw/batch_process_cadence.Rmd` — peak 1-min and peak 30-min cadence from
  PALbatch or ActiLife 60s-epoch data

## Running the analysis

With steps 1–5 complete and the collated files in place:

```r
source("main.R")
```

| Step | Script | Produces |
|---|---|---|
| 1a | `R/1-prep/01_prepare_swl_phenotypes.Rmd` | SWL wrist and thigh summaries |
| 1b | `R/1-prep/02_prepare_raine_phenotypes.Rmd` | Raine wrist and hip summaries |
| 1c | `R/1-prep/03_prepare_covariates.Rmd` | Covariates for both cohorts |
| 2a | `R/2-analysis/01_qc_participants.Rmd` | Exclusion table |
| 2b | `R/2-analysis/02_main_analyses.Rmd` | Tables 1–2, Figures 1, S2–S6 |
| 2c | `R/2-analysis/03_stratified_analyses.Rmd` | Table S2, Figures S7–S9 |
| 2d | `R/2-analysis/04_sensitivity_analyses.Rmd` | Table S3, Figure S10 |
| 2e | `R/2-analysis/05_external_validation.Rmd` | Tables S4–S5, Figures 2–3, S11–S15 |

Tables and figures are written to `output/prepared/`.

## Requirements

**Python** — two conda environments, `actinet` and `stepcount`:

```shell
conda create -n actinet python=3.9 && conda activate actinet && pip install actinet actipy
conda create -n stepcount python=3.9 && conda activate stepcount && pip install stepcount
```

**R** — 4.4 or later. Packages are installed on first run via `pacman::p_load`. Key
dependencies: `here`, `data.table`, `dplyr`, `tidyr`, `ggplot2`, `ckbplotr`, `gtsummary`,
`gt`, `officer`, `flextable`, `openxlsx`, `psych`, `smatr`, `irr`, `equivalence`,
`PhysicalActivity`.

Steps 1–4 above were run on a Slurm cluster; `process_raw/write_BMRC_script.py` generates
the submission scripts and will need adapting to your own scheduler.

## Licence

This software is intended for use by academics carrying out research and not for use by
consumers of commercial business, see academic use licence file. If you are interested in
using this software commercially, please contact Oxford University Innovation Limited to
negotiate a licence. Contact details are enquiries@innovation.ox.ac.uk