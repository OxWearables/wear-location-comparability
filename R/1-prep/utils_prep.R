# Load required packages 
if(!require(pacman)) install.packages("pacman")
pacman::p_load(dplyr, lubridate, stringr)


prepare_oxwearables_phenotypes <- function(df_actinet, df_stepcount) {

  # Combine package outputs into one DataFrame
  df_oxwearables <- merge(
    df_actinet,
    df_stepcount,
    by = c("Filename", "Date"),
    all = TRUE,
    suffixes = c("_actinet", "_stepcount")
  )
  
  # Prepare unique participant IDs
  df_oxwearables <- df_oxwearables %>%
    mutate(
      filename = basename(Filename),
      filename = str_remove(
        filename,
        regex("\\.(cwa(\\.gz)?|gt3x)$", ignore_case = TRUE)
      ),
      pid = str_split(filename, "_", simplify = TRUE)[, 1]
    )
  
  # Rename columns
  df_oxwearables <- df_oxwearables %>%
    rename(
      date = Date,
      wear_time_hours = `WearTime(hours)_actinet`,
      overall_activity = `ENMO Adjusted(mg)`,
      steps = `Steps`,
      cadence_peak1 = `CadencePeak1(steps/min)`,
      cadence_peak30 = `CadencePeak30(steps/min)`,
      mvpa = `Moderate-vigorous Adjusted(hours)`,
      lipa = `Light Adjusted(hours)`,
      sedentary = `Sedentary Adjusted(hours)`
    )
  
  # Keep selected columns
  cols_to_keep <-
    c(
      'filename',
      'pid',
      'date',
      'wear_time_hours',
      'overall_activity',
      'steps',
      'cadence_peak1',
      'cadence_peak30',
      'mvpa',
      'lipa',
      'sedentary'
    )
  
  df_oxwearables <- df_oxwearables[, cols_to_keep]
  
  return(df_oxwearables)
}


prepare_palbatch_phenotypes <- function(df_enmo,
                                        df_crea, 
                                        df_cadence) {
  
  # Remove Filename suffixes
  df_enmo <- df_enmo %>%
    mutate(Filename = basename(Filename)) %>%
    mutate(Filename = str_remove(Filename, "\\.csv\\.gz$")) %>%
    mutate(Filename = str_extract(Filename, "^[^ ]+")) # for problematic IDs
  
  df_crea <- df_crea %>%
    mutate(Filename = str_extract(Filename, "^[^ ]+"))
  
  df_cadence <- df_cadence %>%
    mutate(Filename = str_extract(Filename, "^[^ ]+"))
  
  # Convert dates to Date format
  df_enmo$Date <- as.Date(df_enmo$Date)
  df_crea$Date <- as.Date(df_crea$Date, format = "%d-%b-%y")
  df_cadence$Date <- as.Date(df_cadence$Date)
  
  # Combine CREA and cadence outputs into one DataFrame
  df_palbatch <- merge(
    df_crea,
    df_cadence,
    by = c("Filename", "Date"),
    all = TRUE,
    suffixes = c("_crea", "_cadence")
  )
  
  # Fix problematic IDs
  df_palbatch <- df_palbatch %>%
    mutate(
      filename_length = str_length(Filename),
      Filename = if_else(filename_length == 17, str_sub(Filename, 1, 16), Filename)
    )
  
  # Combine all outputs into one DataFrame
  df_palbatch <- merge(
    df_palbatch,
    df_enmo,
    by = c("Filename", "Date"),
    all = TRUE
  )
  
  # Prepare unique participant IDs
  df_palbatch <- df_palbatch %>%
    mutate(pid = str_split(Filename, "-", simplify = TRUE)[, 1],
           pid = str_remove_all(pid, "_"))
  
  # Prepare total wear time
  df_palbatch <- df_palbatch %>%
    mutate(wear_time_hours = (`TotalTime(m)` - `NonWearTime(m)`) / 60)
  
  # Prepare overall activity phenotype 
  df_palbatch$overall_activity <- df_palbatch$enmo_without_nonwear
  
  # Prepare MVPA phenotype
  df_palbatch <- df_palbatch %>%
    mutate(
      mvpa =
        (`TimeInRLMsInCadenceBand(>=100spm,<125spm)InBouts(>=10s,<1m)` +
           `TimeInRLMsInCadenceBand(>=100spm,<125spm)InBouts(>=1m,<5m)` +
           `TimeInRLMsInCadenceBand(>=100spm,<125spm)InBouts(>=5m,<10m)` +
           `TimeInRLMsInCadenceBand(>=100spm,<125spm)InBouts(>=10m,<20m)` +
           `TimeInRLMsInCadenceBand(>=100spm,<125spm)InBouts(>=20m)` +
           `TimeInRLMsInCadenceBand(>=125spm)InBouts(>=10s,<1m)` +
           `TimeInRLMsInCadenceBand(>=125spm)InBouts(>=1m,<5m)` +
           `TimeInRLMsInCadenceBand(>=125spm)InBouts(>=5m,<10m)` +
           `TimeInRLMsInCadenceBand(>=125spm)InBouts(>=10m,<20m)` +
           `TimeInRLMsInCadenceBand(>=125spm)InBouts(>=20m)`) / 60
    )
  
  # Prepare light physical activity phenotype
  df_palbatch <- df_palbatch %>%
    mutate(
      lipa =
        (`StandingTime(m)` +
           `TimeInRLMsInCadenceBand(<75spm)InBouts(>=10s,<1m)` +
           `TimeInRLMsInCadenceBand(<75spm)InBouts(>=1m,<5m)` +
           `TimeInRLMsInCadenceBand(<75spm)InBouts(>=5m,<10m)` +
           `TimeInRLMsInCadenceBand(<75spm)InBouts(>=10m,<20m)` +
           `TimeInRLMsInCadenceBand(<75spm)InBouts(>=20m)` +
           `TimeInRLMsInCadenceBand(>=75spm,<100spm)InBouts(>=10s,<1m)` +
           `TimeInRLMsInCadenceBand(>=75spm,<100spm)InBouts(>=1m,<5m)` +
           `TimeInRLMsInCadenceBand(>=75spm,<100spm)InBouts(>=5m,<10m)` +
           `TimeInRLMsInCadenceBand(>=75spm,<100spm)InBouts(>=10m,<20m)` +
           `TimeInRLMsInCadenceBand(>=75spm,<100spm)InBouts(>=20m)`) / 60
    )
  
  # Prepare sedentary behaviour phenotype
  df_palbatch <- df_palbatch %>%
    mutate(sedentary = `TotalSedentaryTime(m)` / 60)
  
  # Rename columns
  df_palbatch <- df_palbatch %>%
    rename(
      filename = Filename,
      date = Date,
      valid_day = ValidDay,
      steps = daily_steps,
      cadence_peak1 = peak_1_cadence,
      cadence_peak30 = peak_30_cadence
    )
  
  # Keep selected columns
  cols_to_keep <-
    c(
      'filename',
      'pid',
      'date',
      'wear_time_hours',
      'valid_day',
      'overall_activity',
      'steps',
      'cadence_peak1',
      'cadence_peak30',
      'mvpa',
      'lipa',
      'sedentary'
    )
  df_palbatch <- df_palbatch[, cols_to_keep]
  
  return(df_palbatch)
}


prepare_actilife_phenotypes <- function(df_actilife) {
  
  # Convert dates to Date format
  df_actilife$Date <- as.Date(df_actilife$Date)
  
  # Rename columns
  df_actilife <- df_actilife %>%
    rename(
      filename = Filename,
      pid = ID,
      date = Date,
      overall_activity_counts = vector_magnitude,
      steps = daily_steps,
      cadence_peak1 = peak_1_cadence,
      cadence_peak30 = peak_30_cadence
    )
  
  # Keep selected columns
  cols_to_keep <-
    c(
      'filename',
      'pid',
      'date',
      'wear_time_hours',
      'overall_activity',
      'overall_activity_counts',
      'steps',
      'cadence_peak1',
      'cadence_peak30',
      'mvpa',
      'lipa',
      'sedentary'
    )
  df_actilife <- df_actilife[, cols_to_keep]
  
  return(df_actilife)
}


summarise_weekly_activity <- function(df_daily, cols_to_summarise) {
  
  # Ensure date is Date class
  df_daily <- df_daily %>% mutate(date = as.Date(date))
  
  # Average same weekdays per recording (representative weekday)
  df_daily_rep <- df_daily %>%
    mutate(weekday = lubridate::wday(date, week_start = 1)) %>%
    group_by(filename, pid, weekday) %>%
    summarise(across(all_of(cols_to_summarise), ~ mean(.x, na.rm = TRUE), .names = "{.col}"), .groups = "drop")
  
  # Aggregate weekday representatives to weekly summary
  df_weekly <- df_daily_rep %>%
    group_by(filename, pid) %>%
    summarise(across(
      all_of(cols_to_summarise),
      list(
        mean = ~ mean(.x, na.rm = TRUE),
        median = ~ median(.x, na.rm = TRUE)
      ),
      .names = "{.col}_{.fn}"
    ), .groups = "drop")
  
  # Prepare num_days, wear_time, and start/end dates
  helper_df <- df_daily %>%
    group_by(filename, pid) %>%
    summarise(
      num_days = n_distinct(date),
      wear_time_hours = sum(wear_time_hours, na.rm = TRUE),
      date_start_wear = min(as.Date(date)),
      date_end_wear   = max(as.Date(date)),
      .groups = "drop"
    )
  
  # Merge and return
  df_weekly <- helper_df %>%
    left_join(df_weekly, by = c("filename", "pid"))
  
  return(df_weekly)
}