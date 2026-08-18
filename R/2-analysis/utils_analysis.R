# Load required packages 
if(!require(pacman)) install.packages("pacman")
pacman::p_load(tidyr, stringr, forcats, psych, smatr, irr, equivalence, dplyr, conflicted)
conflict_prefer("select", "dplyr")
conflict_prefer("filter", "dplyr")
conflict_prefer("first",  "dplyr")
conflict_prefer("last",   "dplyr")


# Helper function to solve discrepancies with duplicate IDs
fix_duplicates <- function(df_primary, df_reference) {
  
  # Create reference pid|date keys
  ref_keys <- with(df_reference, paste0(as.character(pid), "|", as.character(date_start_wear)))
  
  df_primary <- df_primary %>%
    # Create same keys in primary df and mark if they appear in reference
    mutate(
      .key = paste0(as.character(pid), "|", as.character(date_start_wear)),
      .is_match = .key %in% ref_keys
    ) %>%
    # Prefer matched rows, then prefer later dates
    arrange(pid, desc(.is_match), desc(date_start_wear)) %>%
    group_by(pid) %>%
    slice_head(n = 1) %>%
    ungroup() %>%
    select(-any_of(c(".key", ".is_match")))
  
  return(df_primary)
}


# Helper function to prepare actipy info files
prepare_info <- function(df) {
  
  # Prepare unique participant IDs
  df <- df %>%
    mutate(
      filename = basename(Filename),
      filename = str_remove(
        filename,
        regex("\\.(cwa(\\.gz)?|gt3x(\\.gz)?|csv(\\.gz)?)$", ignore_case = TRUE)
      ),
      filename = str_remove(filename, "\\s.*$"),
      pid = str_split(filename, "[-_]", simplify = TRUE)[, 1]
    )
  
  # Rename columns
  df <- df %>%
    dplyr::rename(calibration_ok = CalibOK, covers_24h_ok = Covers24hOK)
  
  # Keep relevant columns for QC
  cols_to_keep <- c('filename', 'pid', 'calibration_ok', 'covers_24h_ok')
  df <- df[, cols_to_keep]
  
  return(df)
}


# Helper function to keep track of participant exclusions
track_exclusions <- function(tab, df, excl, label) {
  cond <- eval(substitute(excl), df)
  cond[is.na(cond)] <- FALSE
  n_before <- nrow(df)
  n_excluded <- sum(cond)
  df_after <- df[!cond, , drop = FALSE]
  
  new_row <- data.frame(
    reason = label,
    n_remaining = nrow(df_after),
    n_excluded = n_excluded,
    stringsAsFactors = FALSE
  )
  
  tab <- rbind(tab, new_row)
  list(tab = tab, df = df_after)
}


# Function to convert NA to "Missing" for specified columns
convert_na_to_missing <- function(df, selected_cols) {
  for (col in selected_cols) {
    if (is.factor(df[[col]])) {
      df[[col]] <- forcats::fct_na_value_to_level(df[[col]], "Missing")
    }
  }
  return(df)
}


# Helper function to convert total wear time to daily wear time
add_daily_wear <- function(df) {
  wear_cols <- names(df)[grepl("^wear_time_hours_", names(df))]
  
  for (col in wear_cols) {
    new_col <- paste0("daily_", col)
    days_col <- sub("wear_time_hours", "num_days", col)
    df[[new_col]] <- df[[col]] / df[[days_col]]
  }
  
  return(df)
}

# Helper function to reshape data to wide format
prep_wide <- function(df, study_name) {
  df_mean <- df %>%
    mutate(id = row_number(), study = study_name) %>%
    select(id, study, matches("_mean_")) %>%
    pivot_longer(
      cols = matches("_mean_"),
      names_to = c("phenotype", "wear_location"),
      names_pattern = "(.*)_mean_(.*)",
      values_to = "value"
    ) %>%
    mutate(study_wear_location = paste0(study, "_", wear_location)) %>%
    pivot_wider(
      id_cols = c(id, study_wear_location),
      names_from = phenotype,
      values_from = value
    )
  
  df_wear <- df %>%
    mutate(id = row_number(), study = study_name) %>%
    select(id, study, matches("^daily_wear_time_hours_")) %>%
    pivot_longer(
      cols = matches("^daily_wear_time_hours_"),
      names_to = "wear_location",
      names_pattern = "daily_wear_time_hours_(.*)",
      values_to = "daily_wear_time_hours"
    ) %>%
    mutate(study_wear_location = paste0(study, "_", wear_location)) %>%
    select(id, study_wear_location, daily_wear_time_hours)
  
  df <- df_mean %>%
    left_join(df_wear, by = c("id", "study_wear_location"))
  
  return(df)
}


# Helper function to format estimate (95% CI) text
format_est <- function(est, lci, uci, sep="-") {
  if (sep=="-")
    fmt_txt <- sprintf("%.2f (%.2f-%.2f)", est, lci, uci)
  else if (sep==",")
    fmt_txt <- sprintf("%.2f (%.2f, %.2f)", est, lci, uci)
  return(fmt_txt)
}

# Helper function to calculate week-level agreement ICC
calculate_icc <- function(df,
                          col1,
                          col2,
                          fmt_sep = ",") {

  # Two-way mixed effects model measuring absolute agreement
  ratings <- cbind(df[[col1]], df[[col2]])
  icc_res <- irr::icc(ratings,
                      model = "twoway",
                      type = "agreement",
                      unit = "single",
                      conf.level = 0.95)

  icc_est <- icc_res$value
  icc_lci <- icc_res$lbound
  icc_uci <- icc_res$ubound
  icc_text <- format_est(icc_est, icc_lci, icc_uci, fmt_sep)

  return(list(
    icc_est = icc_est,
    icc_lci = icc_lci,
    icc_uci = icc_uci,
    icc_text = icc_text
  ))
}

# Helper function to calculate week-level correlations
calculate_corr <- function(df,
                           col1,
                           col2,
                           is_skewed = FALSE,
                           n_bootstrap = 1000) {

  # Run correlation
  if (is_skewed){
    corr_res <- psych::cor.ci(
      df[, c(col1, col2)],
      method = "spearman",
      n.iter = n_bootstrap,
      plot = FALSE
    )

    # Extract results
    corr_est <- unname(corr_res$rho[1, 2])
    corr_lci <- corr_res$ci[1, "low.e"]
    corr_uci <- corr_res$ci[1, "up.e"]

  } else {
    corr_res <- cor.test(
      df[[col1]],
      df[[col2]],
      method = "pearson"
    )

    # Extract results
    corr_est <- unname(corr_res$estimate)
    corr_lci <- corr_res$conf.int[1]
    corr_uci <- corr_res$conf.int[2]
  }

  # Prepare correlation text
  corr_text <- sprintf(
    "%s = %.2f",
    ifelse(is_skewed, "\u03C1", "r"),
    corr_est
  )

  return(list(
    corr_est = corr_est,
    corr_lci = corr_lci,
    corr_uci = corr_uci,
    corr_text = corr_text
  ))
}

# Helper function to produce formatted regression equation
prep_regression_equation <- function(fit_model) {
  intercept_num <- as.numeric(coef(fit_model)[1])
  slope_num <- as.numeric(coef(fit_model)[2])
  intercept_f <- formatC(signif(intercept_num, digits = 3), 
                         digits = 4, 
                         format = "g")
  slope_f <- formatC(signif(slope_num, digits = 3), 
                     digits = 3, 
                     format = "g")
  equation_text <- sprintf("Y = %s + %s X", intercept_f, slope_f)
  return(equation_text)
}

# Helper function to calculate correlations and regression equation in subgroups
stratified_correlation <- function(df,
                                   phenotype,
                                   subgroup,
                                   skewed_phenotype = FALSE) {
  
  # Prepare column names
  x_col <- paste0(phenotype, "_wrist")
  if (paste0(phenotype, "_thigh") %in% names(df)) {
    y_col <- paste0(phenotype, "_thigh")
  } else {
    y_col <- paste0(phenotype, "_hip")
  }
  
  compute_one <- function(subdf) {
    
    # Compute correlations
    corr_res <- calculate_corr(subdf,
                               col1 = x_col,
                               col2 = y_col,
                               is_skewed = skewed_phenotype)
    
    # Fit standardised major-axis regression model
    fit_model <- smatr::sma(as.formula(paste(y_col, "~", x_col)), data = subdf)
    equation_text <- prep_regression_equation(fit_model)
    corr_text <- format_est(corr_res$corr_est, 
                            corr_res$corr_lci, 
                            corr_res$corr_uci,
                            ",")
    
    return(
      tibble(
        n = nrow(subdf),
        corr_est = corr_res$corr_est,
        corr_lci = corr_res$corr_lci,
        corr_uci = corr_res$corr_uci,
        corr_text = corr_text,
        equation_text = equation_text
      )
    )
  }
  
  # Prepare results DataFrame
  result <- df %>%
    filter(!if_any(all_of(subgroup), is.na)) %>%
    unite("subgroup", all_of(subgroup), sep = " - ", remove = FALSE) %>%
    group_by(subgroup) %>%
    group_modify(~ compute_one(.x)) %>%
    ungroup() %>%
    select(subgroup, n, corr_est, corr_lci, corr_uci, corr_text, equation_text)
  
  return(result)
}

# Helper function to conduct equivalence tests
equivalence_test <- function(merged_df,
                             phenotype,
                             eq_zone = 0.1,
                             alpha = 0.05) {
  # Prepare column names
  if (paste0(phenotype, "_thigh") %in% names(merged_df)) {
    y_col <- paste0(phenotype, "_thigh")
  } else {
    y_col <- paste0(phenotype, "_hip")
  }
  x_col <- paste0(phenotype, "_wrist")

  x <- merged_df[[x_col]]
  y <- merged_df[[y_col]]

  # Run equivalence test
  tost_res <- equivalence::tost(x,
                                y,
                                epsilon = eq_zone * mean(x),
                                paired = TRUE,
                                alpha = alpha)

  # Extract results
  mean_ratio <- 1 - unname(tost_res$estimate) / mean(x)
  lci <- 1 - tost_res$tost.interval[2] / mean(x)
  uci <- 1 - tost_res$tost.interval[1] / mean(x)
  is_equivalent <- tost_res$tost.p.value < alpha

  equi_text <-  format_est(mean_ratio, lci, uci)

  return(list(
    mean_ratio = mean_ratio,
    lci      = lci,
    uci      = uci,
    is_equivalent = is_equivalent,
    equi_text  = equi_text
  ))
}

# Helper function to create semi-formatted regression equations table
make_equations_table <- function(df, study_str, phenotypes, subgroup_cols) {
  
  # Subset and reshape equations
  out <- df %>%
    filter(study == study_str) %>%
    mutate(phenotype = factor(phenotype, levels = phenotypes)) %>%
    group_by(phenotype, subgroup) %>%
    summarise(equation_text = first(equation_text), .groups = "drop") %>%
    pivot_wider(names_from = subgroup, values_from = equation_text) %>%
    arrange(phenotype) %>%
    select(phenotype, all_of(subgroup_cols))
  
  # Get number of participants within each subgroup
  counts <- df %>%
    filter(study == study_str) %>%
    distinct(subgroup, n) %>%
    { setNames(.$n, .$subgroup) }
  
  # Rename cols to include counts
  new_names <- paste0(subgroup_cols, " (n=", ifelse(is.na(counts[subgroup_cols]), "", counts[subgroup_cols]), ")")
  names(out)[match(subgroup_cols, names(out))] <- new_names
  
  return(out)
}
