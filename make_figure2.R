# =============================================================================
# Figure 2. Model-estimated trajectories of the primary suicide outcomes
# (CSSRS, MSSI) from the Bayesian multilevel models reported in Table 4.
#
# Point = posterior median of the model-implied mean at each timepoint
#         (b_Intercept + b_timepoint, computed draw by draw).
# Bars  = 95% credible interval of that same quantity, taken directly from
#         the posterior draws, so it accounts for the covariance between the
#         intercept and the change coefficients and matches Table 4.
# Grey  = each participant's observed scores (optional; SHOW_INDIVIDUAL).
#
# The models are specified exactly as in PRECISE_analysis.Rmd (same formula,
# priors, sampler settings, seed and cache files in fits/), so if you have
# already knit the Rmd they load from fits/ instead of refitting.
#
# Run from the repository root:  Rscript make_figure2.R
# Outputs: figures/figure2.{pdf,tiff,png} and figures/figure2_values.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(brms)
})

SHOW_INDIVIDUAL <- TRUE        # faint per-participant observed trajectories
SEED <- 20260917               # same seed as PRECISE_analysis.Rmd
options(mc.cores = min(4, parallel::detectCores()))
dir.create("fits", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)

tp_levels <- c("baseline", "week6", "week12")
tp_labels <- c("Baseline", "6-Week", "12-Week")

# --- Data -------------------------------------------------------------------
# The Rmd reads data/precise_visits.csv; the CSVs currently sit in the repo
# root, so accept either location.
visits_path <- c("data/precise_visits.csv", "precise_visits.csv")
visits_path <- visits_path[file.exists(visits_path)][1]
if (is.na(visits_path)) stop("Cannot find precise_visits.csv")

visits <- read_csv(visits_path, show_col_types = FALSE) %>%
  mutate(timepoint = factor(timepoint, levels = tp_levels))

# MSSI: items 5-18 are administered only after a positive screen on items 1-4,
# so unadministered items contribute 0 (same rule as the Rmd; range 0-54).
mssi_items <- sprintf("mssi_%02d", 1:18)
scores <- visits %>%
  mutate(mssi = rowSums(across(all_of(mssi_items)), na.rm = TRUE)) %>%
  select(id, timepoint, cssrs, mssi)

# --- Models (identical to the Rmd's fit_outcome) ------------------------------
fit_outcome <- function(var) {
  d <- scores %>% select(id, timepoint, y = all_of(var)) %>% filter(!is.na(y))
  brm(y ~ timepoint + (1 | id), data = d, family = gaussian(),
      prior = c(set_prior("normal(0, 10)", class = "b"),
                set_prior("student_t(3, 0, 5)", class = "sd")),
      chains = 4, iter = 3000, warmup = 1000, seed = SEED,
      control = list(adapt_delta = 0.95), refresh = 0,
      file = file.path("fits", var), file_refit = "on_change")
}
fits <- list(cssrs = fit_outcome("cssrs"), mssi = fit_outcome("mssi"))

# --- Model-implied means from the posterior draws ----------------------------
panel_labels <- c(cssrs = "CSSRS", mssi = "MSSI")

estimated_means <- function(fit, var) {
  d <- as_draws_df(fit)
  m <- cbind(d$b_Intercept,
             d$b_Intercept + d$b_timepointweek6,
             d$b_Intercept + d$b_timepointweek12)
  tibble(var = var,
         timepoint = factor(tp_labels, levels = tp_labels),
         n     = as.integer(table(fit$data$timepoint)[tp_levels]),
         mean  = apply(m, 2, median),
         lower = apply(m, 2, quantile, probs = 0.025),
         upper = apply(m, 2, quantile, probs = 0.975))
}
fig2 <- bind_rows(Map(estimated_means, fits, names(fits))) %>%
  mutate(panel = factor(panel_labels[var], levels = panel_labels))

observed <- scores %>%
  pivot_longer(c(cssrs, mssi), names_to = "var", values_to = "y") %>%
  filter(!is.na(y)) %>%
  mutate(timepoint = factor(tp_labels[match(timepoint, tp_levels)], levels = tp_labels),
         panel = factor(panel_labels[var], levels = panel_labels))

# Values behind the figure, to check against Table 4 / the Results text
fig2 %>%
  transmute(Outcome = var, Timepoint = timepoint, n,
            `Mean` = round(mean, 2), `95% CrI lower` = round(lower, 2),
            `95% CrI upper` = round(upper, 2)) %>%
  write_csv("figures/figure2_values.csv")
print(read_csv("figures/figure2_values.csv", show_col_types = FALSE))

# --- Plot --------------------------------------------------------------------
# Styled after the original Figure 2: centred title, bold panel titles, black
# means joined by a line, grey 95% CrI bars, dotted horizontal gridlines and an
# italic note underneath.

# Fixed y-ranges per panel (invisible points). CSSRS keeps the original 0-6
# axis; the MSSI axis has to extend beyond the original 0-14 to fit the
# individual trajectories, and slightly below 0 because the Gaussian model's
# MSSI intervals do (clipping them would misrepresent the posterior).
y_range <- tibble(panel = factor(panel_labels, levels = panel_labels),
                  timepoint = factor("Baseline", levels = tp_labels)) %>%
  slice(rep(1:2, each = 2)) %>%
  mutate(y = c(0, 6,
               min(0, fig2$lower[fig2$var == "mssi"]),
               if (SHOW_INDIVIDUAL) max(observed$y[observed$var == "mssi"]) else 14))

note <- paste0(
  "Black points are posterior medians of the model-estimated means; error bars show 95% credible intervals\n",
  "computed from the posterior draws (see Table 4 for pd and ROPE).",
  if (SHOW_INDIVIDUAL) " Grey lines show individual participants' observed scores." else "",
  "\nn = 30 at baseline, 28 at 6 weeks, and 26 at 12 weeks.")

p <- ggplot(fig2, aes(timepoint, mean, group = 1)) +
  geom_blank(data = y_range, aes(timepoint, y), inherit.aes = FALSE)

if (SHOW_INDIVIDUAL) {
  p <- p +
    geom_line(data = observed, aes(timepoint, y, group = id),
              inherit.aes = FALSE, colour = "grey70", alpha = 0.6, linewidth = 0.35) +
    geom_point(data = observed, aes(timepoint, y),
               inherit.aes = FALSE, colour = "grey70", alpha = 0.6, size = 0.9)
}

p <- p +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.06,
                colour = "grey50", linewidth = 0.8) +
  geom_line(colour = "black", linewidth = 0.9) +
  geom_point(colour = "black", size = 3) +
  facet_wrap(~ panel, scales = "free_y") +
  scale_y_continuous(breaks = function(l) pretty(l, n = 6),
                     expand = expansion(mult = c(0.02, 0.04))) +
  scale_x_discrete(expand = expansion(add = 0.2)) +
  labs(title = "Model-Estimated Trajectories of Suicidal Ideation (Bayesian Multilevel Models)",
       x = NULL, y = "Estimated mean score", caption = note) +
  theme_classic(base_size = 11, base_family = "sans") +
  theme(plot.title = element_text(hjust = 0.5, size = 12.5, margin = margin(b = 14)),
        strip.background = element_blank(),
        strip.text = element_text(face = "bold", size = 12.5),
        panel.grid.major.y = element_line(colour = "grey82", linewidth = 0.3,
                                          linetype = "dotted"),
        axis.text = element_text(colour = "black", size = 10),
        panel.spacing = unit(2, "lines"),
        plot.caption = element_text(face = "italic", hjust = 0.5, size = 8.5,
                                    colour = "grey15", lineheight = 1.1,
                                    margin = margin(t = 10)),
        plot.caption.position = "plot",
        plot.margin = margin(8, 12, 8, 8))

# Print sizes: 7.5 in wide; journals typically want vector PDF/EPS or a
# >= 300 dpi TIFF.
ggsave("figures/figure2.pdf",  p, width = 7.5, height = 4.6, device = cairo_pdf)
ggsave("figures/figure2.tiff", p, width = 7.5, height = 4.6, dpi = 600, compression = "lzw")
ggsave("figures/figure2.png",  p, width = 7.5, height = 4.6, dpi = 300)
message("Saved figures/figure2.{pdf,tiff,png}")
