# =============================================================================
# Supplementary Figure S1. EMA compliance by study day and by prompt of the day
# (responds to co-author comment requesting a visual of the missingness pattern)
#
# Run from the repository root:  Rscript make_figureS1.R
# Outputs: figures/figureS1.{pdf,tiff,png} and figures/figureS1_values.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})
dir.create("figures", showWarnings = FALSE)

ema_path <- c("data/precise_ema.csv", "precise_ema.csv")
ema_path <- ema_path[file.exists(ema_path)][1]
ema <- read_csv(ema_path, show_col_types = FALSE)

# Per-participant compliance first, then mean and SE across participants, so
# each participant counts equally.
summarise_by <- function(group_var, panel) {
  ema %>%
    group_by(ema_id, x = .data[[group_var]]) %>%
    summarise(rate = mean(completed), .groups = "drop") %>%
    group_by(x) %>%
    summarise(n = n(), mean = 100 * mean(rate), se = 100 * sd(rate) / sqrt(n()),
              .groups = "drop") %>%
    mutate(panel = panel)
}
by_day  <- summarise_by("study_day", "A. By study day")
# Days beyond 42 exist only for a participant whose schedule was relaunched
# (n = 1), so panel A shows days 1-42.
n_extra_days <- sum(by_day$x > 42)
by_day  <- by_day %>% filter(x <= 42)
by_ping <- summarise_by("ping", "B. By prompt of the day")
overall <- 100 * mean(ema$completed)

bind_rows(by_day, by_ping) %>%
  mutate(across(c(mean, se), ~ round(.x, 1))) %>%
  write_csv("figures/figureS1_values.csv")

base_theme <- theme_classic(base_size = 11, base_family = "sans") +
  theme(plot.title = element_text(face = "bold", size = 11.5),
        panel.grid.major.y = element_line(colour = "grey82", linewidth = 0.3,
                                          linetype = "dotted"),
        axis.text = element_text(colour = "black"))

p_day <- ggplot(by_day, aes(x, mean)) +
  geom_ribbon(aes(ymin = mean - se, ymax = mean + se), fill = "grey85") +
  geom_hline(yintercept = overall, linetype = "dashed", colour = "grey45") +
  geom_line(colour = "black", linewidth = 0.8) +
  geom_point(colour = "black", size = 1.4) +
  geom_vline(xintercept = seq(7.5, 35.5, 7), colour = "grey88", linewidth = 0.3) +
  scale_x_continuous(breaks = c(1, seq(7, 42, 7)), expand = expansion(add = 0.8)) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(title = "A. By study day", x = "Study day", y = "Prompts completed (%)") +
  base_theme

p_ping <- ggplot(by_ping, aes(factor(x), mean)) +
  geom_col(fill = "grey70", width = 0.65) +
  geom_errorbar(aes(ymin = mean - se, ymax = mean + se), width = 0.15,
                colour = "black", linewidth = 0.6) +
  geom_hline(yintercept = overall, linetype = "dashed", colour = "grey45") +
  scale_x_discrete(labels = c("1\n(morning)", "2", "3", "4", "5")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(title = "B. By prompt of the day", x = "Prompt", y = NULL) +
  base_theme

note <- paste0(
  "Values are the mean of participants' compliance rates (N = 30); shading and error bars show \u00b11 SE.\n",
  sprintf("Dashed line = overall compliance (%.1f%% of %s scheduled prompts).\n", overall, format(nrow(ema), big.mark = ",")),
  "Vertical lines mark study weeks",
  if (n_extra_days > 0) "; days 1\u201342 shown (one participant had a 43rd day after a schedule relaunch)." else ".")

if (requireNamespace("patchwork", quietly = TRUE)) {
  library(patchwork)
  p <- (p_day + p_ping + plot_layout(widths = c(2.2, 1))) +
    plot_annotation(
      title = "EMA Compliance Across the Six-Week Protocol",
      caption = note,
      theme = theme(plot.title = element_text(hjust = 0.5, size = 12.5),
                    plot.caption = element_text(face = "italic", hjust = 0.5,
                                                size = 8.5, lineheight = 1.1)))
  ggsave("figures/figureS1.pdf",  p, width = 7.5, height = 4, device = cairo_pdf)
  ggsave("figures/figureS1.tiff", p, width = 7.5, height = 4, dpi = 600, compression = "lzw")
  ggsave("figures/figureS1.png",  p, width = 7.5, height = 4, dpi = 300)
} else {
  # Without patchwork, save the two panels separately.
  ggsave("figures/figureS1A.pdf", p_day,  width = 5,   height = 3.5, device = cairo_pdf)
  ggsave("figures/figureS1B.pdf", p_ping, width = 2.8, height = 3.5, device = cairo_pdf)
}
message(sprintf("Overall compliance: %.1f%%", overall))
print(by_ping)
print(by_day %>% mutate(week = ceiling(x / 7)) %>% group_by(week) %>%
        summarise(mean = round(mean(mean), 1)))
