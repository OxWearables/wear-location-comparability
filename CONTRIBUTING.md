# Contributing to wear-location-comparability

Thank you for taking the time to contribute! :+1:

This repository holds the analysis code for the study *"Towards harmonised
accelerometer-derived physical activity: A comparability study across wrist, thigh, and
hip wear locations"*. It is research code accompanying a publication rather than a
general-purpose software package, so most contributions will be bug reports, questions
about reproducing the analysis, or small fixes. All are welcome.

## Reporting an issue or asking a question

Before opening a ticket, please check the [existing
issues](https://github.com/OxWearables/wear-location-comparability/issues). When reporting
a bug, include enough detail to reproduce it: the script or step involved, your R (and, if
relevant, Python) version, and the error message or unexpected output.

For how to cite the study, see [`CITATION.cff`](CITATION.cff).

We are a team of researchers first and developers second, so please be patient if your
issue or PR takes a while to be addressed.

## Setup

This is an R project (with some Python helper scripts under `process_raw/` for raw
accelerometer processing). It is driven by `main.R`, which renders the `.Rmd` files under
`R/1-prep/` then `R/2-analysis/` in order.

1. Fork the repository and clone your fork:
    ```bash
    git clone https://github.com/your_github_account/wear-location-comparability.git
    cd wear-location-comparability/
    ```
2. Open `wear-location-comparability.Rproj` in RStudio (recommended), or set the working
   directory to the project root. R package dependencies are installed on first run via
   `pacman::p_load` — see the [README](README.md#requirements) for the R version and key
   packages. The Python steps additionally need the `actinet` and `stepcount` conda
   environments described there.

**No participant data are included in this repository, and the full pipeline cannot be run
without access to the gated study data** (see the [README](README.md) for data-access
details). You can still edit and inspect the code, and run individual steps if you have
suitable inputs. Please never commit participant data, derived sensitive outputs,
credentials, or local file paths.

## Submitting a change

We use the [fork and pull request
workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/forking-workflow):
branch off `main`, do your work, push the branch to your fork, and open a pull request
against this repository. You don't need to open an issue first — use the PR description to
explain the motivation, as you would an issue. If your change affects the analysis method
or the participant set (rather than being a self-contained bug or documentation fix),
please open an issue to discuss it first.

Keep commits focused, and write clear, imperative commit subjects ("Fix covariate merge",
not "fixed some stuff"). See the [Pro Git commit
guidelines](https://git-scm.com/book/en/Distributed-Git-Contributing-to-a-Project#Commit-Guidelines)
for good practice.

Because this is analysis code, a change may legitimately alter the numbers, tables, or
figures it produces. If yours is expected to change the outputs (e.g. a bugfix that
corrects a computation), say so explicitly in the PR and explain why the new result is
correct. Most external contributors will not be able to run the pipeline or regenerate
outputs, since that requires the gated data — that is fine; maintainers will re-run the
affected code against the real data. To make your PR reviewable, describe what you did run
(the script or step and, where relevant, `sessionInfo()` and package versions) and include
any error logs or before/after output summaries you can.

If accepted, your contribution may be modified before merging. You will retain author
attribution for your Git commits.

## Source code style

For R code, we broadly follow the [tidyverse style guide](https://style.tidyverse.org/).
For the Python helper scripts under `process_raw/`, follow [PEP
8](https://peps.python.org/pep-0008/). In both cases, keep new code consistent with the
style of the file you are editing (2-space indentation, as configured in the `.Rproj`).

## Licensing of contributions

This project is released under an academic-use, non-commercial licence (see
[`LICENCE.md`](LICENCE.md)) — not a standard permissive open-source licence. By
contributing, you agree that your contributions are licensed under those same terms.
