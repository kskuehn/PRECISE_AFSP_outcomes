# =============================================================================
# PRECISE open trial -- EMA export -> de-identified public EMA dataset
# =============================================================================
# Input  (NOT in the repository; contains REDCap identifiers and time stamps):
#   data-raw/precise.ema.csv   one row per scheduled prompt (6,293 rows)
# Output (public):
#   data/precise_ema.csv       one row per scheduled prompt (6,251 rows)
#
# Run from the repository root:
#   Rscript 02_prepare_ema.R                      # reads data-raw/precise.ema.csv
#   Rscript 02_prepare_ema.R path/to/export.csv
#
# Definitions (these match the manuscript)
#  1. Duplicate prompts: 42 participant-day-prompt combinations appear twice in
#     the export, each as one completed and one empty row (a re-sent prompt).
#     The completed row is kept, leaving 6,251 scheduled prompts.
#  2. A prompt counts as completed when a survey was submitted (non-missing
#     response time stamp): 4,043 of 6,251 (64.7%).
#  3. De-identification: REDCap/Inclivio identifiers, record IDs and response
#     time stamps are dropped; study day is the participant's nth EMA day (dense
#     rank of the original day number, which closes the gaps left by the three
#     relaunched prompt schedules; one participant has 43 EMA days); EMA IDs are
#     random (E01-E30) and cannot be linked to visit IDs (P01-P30).
#
# This replaces the EMA section of an earlier version of 01_clean_data.R, which
# counted only surveys REDCap flagged "Complete", padded every participant to
# 42 days x 5 prompts, and dropped days after 42 (4,000 of 6,300 prompts).
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(readr) })

args <- commandArgs(trailingOnly = TRUE)
src  <- if (length(args)) args[1] else "data-raw/precise.ema.csv"
raw  <- read_csv(src, show_col_types = FALSE, guess_max = 10000)

raw <- raw %>%
  mutate(completed = as.integer(!is.na(responsetimestamp) &
                                  as.character(responsetimestamp) != ""))

dedup <- raw %>%
  arrange(PID, daynumber, pingnumber, desc(completed), desc(responsetimestamp)) %>%
  distinct(PID, daynumber, pingnumber, .keep_all = TRUE)

set.seed(20260917)
id_map <- tibble(PID = sample(unique(dedup$PID)),
                 ema_id = sprintf("E%02d", seq_along(unique(dedup$PID))))

ema <- dedup %>%
  group_by(PID) %>%
  mutate(study_day = dense_rank(daynumber)) %>%
  ungroup() %>%
  left_join(id_map, by = "PID") %>%
  transmute(ema_id, study_day, ping = pingnumber, completed,
            anger, shame, sad, fear, guilt,
            si_any              = sh_gating,
            intent_selfharm_30m = sh_intention_30,
            intent_suicide_30m  = sui_intent_30,
            intent_suicide_now  = sui_intent_now,
            selfharm_30m        = sh_30) %>%
  # survey variables are empty for prompts that were not completed
  mutate(across(anger:selfharm_30m, ~ ifelse(completed == 1, .x, NA))) %>%
  arrange(ema_id, study_day, ping)

dir.create("data", showWarnings = FALSE)
write_csv(ema, "data/precise_ema.csv", na = "")

cat(sprintf("Export rows: %d | duplicate prompts removed: %d | scheduled prompts: %d\n",
            nrow(raw), nrow(raw) - nrow(dedup), nrow(ema)))
cat(sprintf("Completed: %d (%.1f%%)\n", sum(ema$completed), 100 * mean(ema$completed)))
pp <- ema %>% group_by(ema_id) %>% summarise(r = mean(completed))
cat(sprintf("Per-participant compliance: M = %.1f%%, SD = %.1f%%\n",
            100 * mean(pp$r), 100 * sd(pp$r)))
