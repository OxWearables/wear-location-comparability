# Load required packages 
if(!require(pacman)) install.packages("pacman")
pacman::p_load(here, dplyr, ggplot2, ckbplotr, smatr)
source(here("R", "2-analysis", "utils_analysis.R"))


# Helper function that displays a scatter plot
scatter.plot <- function(df,
                         col1,
                         col2,
                         fit_model,
                         equation_text = NULL,
                         title = NULL,
                         axes_lims = NULL,
                         x_label = NULL,
                         y_label = NULL,
                         include_xy_line = TRUE,
                         include_fit_line = TRUE,
                         height = unit(5, "cm"),
                         base_size = 8,
                         ratio = 1,
                         plot.margin = margin(0, 0, 0, 0, unit = "cm"),
                         axis.title.margin = 0.25,
                         paper = "transparent") {
  
  # Prepare regression line
  coef <- coef(fit_model)
  intercept <- coef[1]
  slope <- coef[2]
  
  # Determine x and y range to plot the fitted line over
  x_min <- min(df[[col1]], na.rm = TRUE)
  x_max <- max(df[[col1]], na.rm = TRUE)
  y_min <- intercept + slope * x_min
  y_max <- intercept + slope * x_max
  
  # Prepare plot
  plot <- ggplot(df, aes(x = .data[[col1]], y = .data[[col2]])) +
    geom_point(size = 0.5) +
    labs(x = x_label,
         y = y_label,
         title = title) +
    ckb_style(xlims = axes_lims,
              ylims = axes_lims,
              base_size = base_size, 
              ratio = ratio, 
              height = height, 
              plot.margin = plot.margin, 
              axis.title.margin = axis.title.margin,
              paper = paper)
  
  # Include dashed line of equality x=y
  if (include_xy_line) {
    plot <- plot + 
      geom_abline(intercept = 0,
                  slope = 1,
                  linetype = "dashed",
                  color = "black",
                  size = 0.4)
  }
  
  # Include line of fit
  if (include_fit_line) {
    plot <- plot +
      annotate("segment",
               x = x_min, 
               y = y_min,
               xend = x_max, 
               yend = y_max,
               colour = "black", 
               size = 0.5)
  }
  
  # Include equation text
  if (!is.null(equation_text)) {
    plot <- plot + 
      annotate("text",
               x = Inf,
               y = -Inf,
               label = equation_text,
               hjust = 1.05,
               vjust = -0.5, #-0.25,
               size = base_size / .pt,
               lineheight = 0.85,
               parse = FALSE)
    }
  
  return(plot)
}


# Helper function that prepares data and creates agreement scatter plot
make_scatter_plot <- function(merged_df,
                              phenotype,
                              title,
                              axes_lims = NULL,
                              phenotype_units = NULL,
                              skewed_phenotype = FALSE,
                              show_equation = TRUE,
                              include_fit_line = TRUE,
                              include_xy_line = TRUE,
                              height = unit(5, "cm"),
                              base_size = 8,
                              ratio = 1,
                              plot.margin = margin(0, 0, 0, 0, unit = "cm"),
                              axis.title.margin = 0.25) {
  
  # Prepare column names and labels
  if (length(phenotype_units) == 1) phenotype_units <- rep(phenotype_units, 2)
  
  if (paste0(phenotype, "_thigh") %in% names(merged_df)) {
    y_col <- paste0(phenotype, "_thigh")
    x_label <- paste0("Wrist (", phenotype_units[1], ")")
    y_label <- paste0("Thigh (", phenotype_units[2], ")")
  } else {
    y_col <- paste0(phenotype, "_hip")
    x_label <- paste0("Wrist (", phenotype_units[1], ")")
    y_label <- paste0("Hip (", phenotype_units[2], ")")
  }
  x_col <- paste0(phenotype, "_wrist")
  
  # Calculate correlation coefficient (week-level agreement)
  corr_results <- calculate_corr(merged_df,
                                 col1 = x_col,
                                 col2 = y_col,
                                 is_skewed = skewed_phenotype)
  
  # Fit standardised major-axis regression model
  form <- as.formula(paste(y_col, "~", x_col))
  fit_model <- smatr::sma(form, data = merged_df)
  if (show_equation) {
    equation_text <- prep_regression_equation(fit_model)
  } else {
    equation_text <- NULL
  }
  
  # Prepare title text with correlation
  title <- paste0(title, "\n (", corr_results$corr_text, ")")
  
  # Make plot
  plot <- scatter.plot(merged_df,
                       x_col,
                       y_col,
                       fit_model,
                       equation_text = equation_text,
                       title = title,
                       axes_lims = axes_lims,
                       x_label = x_label,
                       y_label = y_label,
                       include_xy_line = include_xy_line,
                       include_fit_line = include_fit_line,
                       height = height,
                       base_size = base_size,
                       ratio = ratio,
                       plot.margin = plot.margin,
                       axis.title.margin = axis.title.margin)
  
  return(plot)
}


# Helper function that prepares data and creates Bland-Altman plot
make_bland_altman_plot <- function(merged_df,
                                   phenotype,
                                   title,
                                   phenotype_units = NULL,
                                   height = unit(5, "cm"),
                                   base_size = 8,
                                   ratio = 1,
                                   plot.margin = ggplot2::margin(0, 0, 0, 0, unit = "cm"),
                                   axis.title.margin = 0.25,
                                   digits = 1) {
  
  # Prepare column names and labels
  if (paste0(phenotype, "_thigh") %in% names(merged_df)) {
    comp_col <- paste0(phenotype, "_thigh")
    comp_name <- "Thigh"
  } else {
    comp_col <- paste0(phenotype, "_hip")
    comp_name <- "Hip"
  }
  wrist_col <- paste0(phenotype, "_wrist")
  
  # Mean and difference with Wrist as the reference
  merged_df$mean_value <- (merged_df[[wrist_col]] + merged_df[[comp_col]]) / 2
  merged_df$diff_value <- merged_df[[comp_col]] - merged_df[[wrist_col]]  
  
  # Calculate Bland Altman stats (week-level)
  mean_diff <- mean(merged_df$diff_value, na.rm = TRUE)
  sd_diff   <- sd(merged_df$diff_value, na.rm = TRUE)
  
  # Calculate limits of agreement
  loa_upper <- mean_diff + 1.96 * sd_diff
  loa_lower <- mean_diff - 1.96 * sd_diff
  
  # Prepare axes labels
  x_label <- paste0("Mean of ", comp_name, " and Wrist (", phenotype_units, ")")
  y_label <- paste0("Difference (", comp_name, " - Wrist; ", phenotype_units, ")")
  
  # Make plot
  plot <- ggplot(merged_df, aes(x = mean_value, y = diff_value)) +
    geom_point(size = 0.5) +
    geom_hline(yintercept = mean_diff,
               linetype = "solid",
               color = "blue",
               size = 0.5) +
    geom_hline(yintercept = loa_upper,
               linetype = "dashed",
               color = "red",
               size = 0.5) +
    geom_hline(yintercept = loa_lower,
               linetype = "dashed",
               color = "red",
               size = 0.5) +
    annotate("text",
             x = Inf,
             y = mean_diff,
             label = "Mean",
             hjust = 1.02,
             vjust = -0.3,
             size = base_size / .pt) +
    annotate("text",
             x = Inf,
             y = loa_upper,
             label = "+1.96 SD",
             hjust = 1.02,
             vjust = -0.3,
             size = base_size / .pt) +
    annotate("text",
             x = Inf,
             y = loa_lower,
             label = "-1.96 SD",
             hjust = 1.02,
             vjust = -0.3,
             size = base_size / .pt) +
    labs(
      x = x_label,
      y = y_label,
      title = paste0(
        title,
        "\n Bias=",
        round(mean_diff, digits),
        ", LoA= [",
        round(loa_lower, digits),
        ", ",
        round(loa_upper, digits),
        "]"
      )
    ) +
    
    ckb_style(base_size = base_size,
              ratio = ratio,
              height = height,
              plot.margin = plot.margin,
              axis.title.margin = axis.title.margin)
  
  return(plot)
}


# Helper function to decrease/increase 'row' for subgroup ICCs
move_rows <- function(datatoplot){
  datatoplot <- mutate(datatoplot,
                       row = if_else(subgroup_numbered == "gp1", 
                                     row - 0.15, 
                                     row + 0.15))
  return(datatoplot)
}