# =============================================================================
# PRECISE open trial -- raw REDCap exports -> de-identified analysis datasets
# =============================================================================
# Input  (NOT in the repository; contain PHI -- see .gitignore):
#   data-raw/AIM2PRECISEInPersonC_DATA_LABELS_<date>.csv  visit-based assessments
#   data-raw/AIM2PRECISEEMA_DATA_LABELS_<date>.csv        ecological momentary assessment
# Output (public):
#   data/precise_visits.csv          30 participants x 3 visits, item-level + scale scores
#   data/precise_implementation.csv  post-treatment AIM / IAM / FIM / SUS (n = 28)
#   data/precise_demographics.csv    Table 1 variables, NOT linkable to any other file
#   data/precise_ema.csv             30 participants x 42 days x 5 prompts
#
# De-identification applied here
#   * all free text, names, phone numbers, dates of birth, visit dates, time
#     stamps, assessor initials and REDCap / Inclivio identifiers are dropped
#   * participants get new random IDs; visit IDs (P01-P30) and EMA IDs (E01-E30)
#     are drawn independently, so the two files cannot be linked to each other
#   * demographics carry no ID at all, and each column is permuted independently
#     (Table 1 reports marginal distributions only, so it is unaffected, while
#     no row describes a real person). Set PERMUTE_DEMOGRAPHICS <- FALSE to keep
#     real rows (still unlinked and row-shuffled).
#
# Run from the repository root:  Rscript R/01_clean_data.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

PERMUTE_DEMOGRAPHICS <- TRUE
set.seed(20261007)

raw_dir <- "data-raw"
out_dir <- "data"
dir.create(out_dir, showWarnings = FALSE)

latest <- function(pattern) {
  f <- sort(list.files(raw_dir, pattern = pattern, full.names = TRUE))
  if (!length(f)) stop("No raw file matching '", pattern, "' in ", raw_dir)
  f[length(f)]
}

# REDCap "labels" exports repeat column headers (e.g. "Complete?", "Describe:"),
# so columns are addressed by position, anchored on a labelled first column and
# checked against the expected label before use.
read_labels <- function(path) {
  d <- read_csv(path, col_types = cols(.default = col_character()),
                name_repair = "minimal", na = "")
  attr(d, "labels") <- gsub("\\s+", " ", trimws(names(d)))
  names(d) <- sprintf("c%04d", seq_along(d))
  d
}
col_at <- function(d, first_label, n = 1, nth = 1, exact = FALSE) {
  lab <- attr(d, "labels")
  hit <- if (exact) which(lab == first_label) else which(startsWith(lab, first_label))
  if (length(hit) < nth) stop("Column not found: ", first_label)
  names(d)[hit[nth] + seq_len(n) - 1]
}
lead_int <- function(x) suppressWarnings(as.integer(sub("^\\s*(\\d+).*$", "\\1", x)))

# =============================================================================
# 1. Visit-based assessments
# =============================================================================
# Two exports of the visit project are used:
#   v_full  the most recent export that includes the pre-visit event and the
#           baseline C-SSRS (demographics, enrolment, baseline severity)
#   v       the most recent export of the baseline / 6-week / 12-week
#           instruments
visit_files <- sort(list.files(raw_dir, pattern = "InPersonC_DATA_LABELS", full.names = TRUE))
if (!length(visit_files)) stop("No visit export found in ", raw_dir)
visit_exports <- lapply(visit_files, function(f) {
  d <- read_labels(f); names(d)[1:2] <- c("record_id", "event"); d
})
bl_label <- "Past Month Scoring: Which is the highest answer marked Yes?"
is_full <- vapply(visit_exports, function(d) bl_label %in% attr(d, "labels"), logical(1))
v_full <- visit_exports[[max(which(is_full))]]
v      <- visit_exports[[length(visit_exports)]]
message("Baseline C-SSRS / demographics from: ", basename(visit_files[max(which(is_full))]),
        "\nAll other visit data from:         ", basename(visit_files[length(visit_files)]))

# ---- Analytic sample ---------------------------------------------------------
# 32 people have a scored baseline C-SSRS. Two of them (REDCap records 201 and
# 222) did not enroll (no EMA start date, no follow-up visits), leaving the 30
# enrolled participants.
cssrs_bl <- col_at(v_full, bl_label)
not_started <- c("201", "222")
enrolled <- v_full %>%
  filter(event == "Baseline", !is.na(.data[[cssrs_bl]]), !record_id %in% not_started) %>%
  pull(record_id)
stopifnot(length(enrolled) == 30)

id_map <- tibble(record_id = enrolled,
                 id = sprintf("P%02d", sample(seq_along(enrolled))))

visits_raw <- v %>%
  filter(record_id %in% enrolled, event %in% c("Baseline", "6-Week", "12-Week")) %>%
  mutate(timepoint = factor(recode(event, "Baseline" = "baseline", "6-Week" = "week6",
                                   "12-Week" = "week12"),
                            levels = c("baseline", "week6", "week12"))) %>%
  left_join(id_map, by = "record_id")

# ---- C-SSRS: most severe ideation type endorsed in the past month (0-5) -----
cssrs_fu <- col_at(v, "In the past month: Which is the highest answer marked Yes?")
cssrs_baseline <- v_full %>%
  filter(event == "Baseline") %>%
  transmute(record_id, cssrs_baseline = .data[[cssrs_bl]])
cssrs <- visits_raw %>%
  left_join(cssrs_baseline, by = "record_id") %>%
  transmute(id, timepoint,
            cssrs = as.integer(if_else(timepoint == "baseline",
                                       cssrs_baseline, .data[[cssrs_fu]])))

# ---- MSSI: 18 clinician-rated items, each 0-3 --------------------------------
# Items 1-4 are screening items; items 5-18 are only administered when the
# screen is positive, so skipped items are structural zeros.
mssi_cols <- names(v)[match(col_at(v, "1. Wish to die"), names(v)) + seq(0, 34, by = 2)]
stopifnot(startsWith(attr(v, "labels")[match(mssi_cols[18], names(v))], "18. Actual Preparation"))
mssi <- visits_raw %>%
  transmute(id, timepoint, across(all_of(mssi_cols), lead_int)) %>%
  rename_with(~ sprintf("mssi_%02d", seq_along(.x)), all_of(mssi_cols))

# ---- PROMIS Depression (28-item bank) and Anxiety (29-item bank) -------------
promis_levels <- c("Never" = 1L, "Rarely" = 2L, "Sometimes" = 3L, "Often" = 4L, "Always" = 5L)
dep_cols <- col_at(v, "I felt worthless", 28)
anx_cols <- col_at(v, "I felt fearful.", 29)
stopifnot(attr(v, "labels")[match(dep_cols[28], names(v))] == "I felt emotionally exhausted",
          attr(v, "labels")[match(anx_cols[29], names(v))] == "I had difficulty calming down.")
dep_ids <- sprintf("EDDEP%02d", c(4, 5, 6, 7, 9, 14, 17, 19, 21, 22, 23, 26, 27, 28, 29, 30,
                                  31, 35, 36, 39, 41, 42, 44, 45, 46, 48, 50, 54))
anx_ids <- sprintf("EDANX%02d", c(1, 2, 3, 5, 7, 8, 12, 13, 16, 18, 20, 21, 24, 26, 27, 30,
                                  33, 37, 40, 41, 44, 46, 47, 48, 49, 51, 53, 54, 55))
promis <- visits_raw %>%
  transmute(id, timepoint,
            across(all_of(c(dep_cols, anx_cols)), ~ unname(promis_levels[.x]))) %>%
  rename_with(~ c(dep_ids, anx_ids), all_of(c(dep_cols, anx_cols)))

# ---- CERQ (36 items, 1-5) -----------------------------------------------------
# REDCap choice order follows the original CERQ anchors ((almost) never,
# sometimes, regularly, often, (almost) always): "Frequently" is the middle
# option (3) and "Often" is 4.
cerq_levels <- c("Almost Never" = 1L, "Sometimes" = 2L, "Frequently" = 3L,
                 "Often" = 4L, "Almost Always" = 5L)
cerq_cols <- col_at(v, "I feel that I am the one to blame for it.", 36)
stopifnot(attr(v, "labels")[match(cerq_cols[36], names(v))] ==
            "I feel that basically the cause lies with others.")
cerq <- visits_raw %>%
  transmute(id, timepoint, across(all_of(cerq_cols), ~ unname(cerq_levels[.x]))) %>%
  rename_with(~ sprintf("cerq_%02d", seq_along(.x)), all_of(cerq_cols))

# ---- CSES (26 items; REDCap response options were coded 1-10) -----------------
cses_cols <- col_at(v, "Keep from getting down in the dumps.", 26)
stopifnot(startsWith(attr(v, "labels")[match(cses_cols[26], names(v))], "Resist the impulse"))
cses <- visits_raw %>%
  transmute(id, timepoint, across(all_of(cses_cols), lead_int)) %>%
  rename_with(~ sprintf("cses_%02d", seq_along(.x)), all_of(cses_cols))

visits <- cssrs %>%
  left_join(mssi, by = c("id", "timepoint")) %>%
  left_join(promis, by = c("id", "timepoint")) %>%
  left_join(cerq, by = c("id", "timepoint")) %>%
  left_join(cses, by = c("id", "timepoint")) %>%
  arrange(id, timepoint)

# ---- Implementation outcomes (6-week visit) ------------------------------------
agree_levels <- c("Completely disagree" = 1L, "Disagree" = 2L, "Neither agree nor disagree" = 3L,
                  "Agree" = 4L, "Completely agree" = 5L)
imp_cols <- col_at(v, "The coaching sessions met my approval.", 12)
sus_cols <- col_at(v, "I think that I would like to use this system frequently.", 10)
implementation <- visits_raw %>%
  filter(timepoint == "week6") %>%
  transmute(id,
            across(all_of(imp_cols), ~ unname(agree_levels[.x])),
            across(all_of(sus_cols), lead_int)) %>%
  rename_with(~ c(sprintf("aim_%d", 1:4), sprintf("iam_%d", 1:4), sprintf("fim_%d", 1:4)),
              all_of(imp_cols)) %>%
  rename_with(~ sprintf("sus_%02d", 1:10), all_of(sus_cols)) %>%
  arrange(id)

# ---- Demographics (collected at the pre-visit) ---------------------------------
pv <- v_full %>% filter(record_id %in% enrolled, event == "Pre-Visit")
g <- function(label, ...) pv[[col_at(v_full, label, ...)]]
demographics <- tibble(
  age              = as.integer(g("Age", exact = TRUE)),
  sex_at_birth     = g("Sex assigned at birth"),
  gender_identity  = g("What is your primary gender identity today?"),
  race_ethnicity   = sub("\\s*\\(e\\.g\\..*$", "", g("Race/Ethnicity", exact = TRUE)),
  hispanic_latino  = g("Do you consider yourself to be of Hispanic"),
  education_years  = as.integer(g("What number of years of education have you completed")),
  current_student  = g("Are you currently a student?"),
  employment       = g("We would like to know about what you do"),
  relationship     = g("Relationship Status")
) %>%
  mutate(
    race_ethnicity = recode(race_ethnicity, "Black, or African American" = "Black or African American"),
    employment = recode(employment, "Part time employed for pay" = "Part-time employed",
                        "Full time employed for pay" = "Full-time employed"),
    relationship = recode(relationship, "A member of an unmarried couple" = "Member of an unmarried couple"),
    # One participant with an associate degree entered "3" (years of college)
    # rather than total years of schooling; corrected to 15.
    education_years = if_else(education_years == 3L, 15L, education_years)
  )
stopifnot(nrow(demographics) == 30, !anyNA(demographics))
demographics <- if (PERMUTE_DEMOGRAPHICS) {
  mutate(demographics, across(everything(), ~ sample(.x)))
} else {
  slice_sample(demographics, prop = 1)
}

# =============================================================================
# 2. Ecological momentary assessment
# =============================================================================
e <- read_labels(latest("EMA_DATA_LABELS"))
lab_e <- attr(e, "labels")
pick2 <- function(label, nth_am = 1, nth_pm = 2) {
  # each item exists twice: once in the morning survey (prompt 1) and once in
  # the daytime survey (prompts 2-5)
  coalesce(e[[col_at(e, label, nth = nth_am, exact = TRUE)]],
           e[[col_at(e, label, nth = nth_pm, exact = TRUE)]])
}
# The 0-100 negative-emotion sliders are five adjacent columns (Anger, Shame,
# Sad, Fear, Guilt), starting at the 1st "Anger" column in the morning survey
# and the 3rd in the daytime survey (the 2nd / 4th are yes/no follow-ups).
emo_names <- c("Anger", "Shame", "Sad", "Fear", "Guilt")
emo_am <- col_at(e, "Anger", 5, nth = 1, exact = TRUE)
emo_pm <- col_at(e, "Anger", 5, nth = 3, exact = TRUE)
stopifnot(identical(lab_e[match(emo_am, names(e))], emo_names),
          identical(lab_e[match(emo_pm, names(e))], emo_names))
slider <- function(label) {
  k <- match(label, emo_names)
  as.numeric(coalesce(e[[emo_am[k]]], e[[emo_pm[k]]]))
}
sev <- c("None" = 0L, "A little" = 1L, "Moderate" = 2L, "A lot" = 3L, "Severe" = 4L)
sev_code <- function(x) unname(sev[sub(" - .*$", "", x)])
intent_harm <- "Within the past 30 minutes, what has been your intention to harm yourself?"
intent_kill <- "Within the past 30 minutes, how strong has your intention been to kill yourself?"
intent_now  <- "What is your intention to kill yourself in this moment?"
any_sh <- which(startsWith(lab_e, "Have you attempted suicide or engaged in any self-harm in the past 30 minutes"))
si_am  <- col_at(e, "Have you thought about hurting or killing yourself since last night?")
si_pm  <- col_at(e, "Have you thought about hurting or killing yourself in the past few hours?")

ema_raw <- tibble(
  redcap_row   = seq_len(nrow(e)),
  inclivio_id  = e[[col_at(e, "Participant's ID from inclivio")]],
  inclivio_day = as.integer(e[[col_at(e, "Day number from inclivio")]]),
  ping         = as.integer(e[[col_at(e, "Ping Number from inclivio")]]),
  sent_gmt     = as.POSIXct(e[[col_at(e, "Response time stamp from inclivio")]],
                            format = "%a, %d %b %Y %H:%M:%S", tz = "GMT"),
  complete     = e[[col_at(e, "Complete?")]] == "Complete",
  anger = slider("Anger"), shame = slider("Shame"), sad = slider("Sad"),
  fear  = slider("Fear"),  guilt = slider("Guilt"),
  si_any             = coalesce(e[[si_am]], e[[si_pm]]),
  intent_selfharm_30m = sev_code(pick2(intent_harm)),
  intent_suicide_30m  = sev_code(pick2(intent_kill)),
  intent_suicide_now  = sev_code(pick2(intent_now)),
  selfharm_30m       = coalesce(e[[names(e)[any_sh[1]]]], e[[names(e)[any_sh[2]]]])
) %>%
  # 99 test / unlinked records have no Inclivio participant ID
  filter(!is.na(inclivio_id)) %>%
  mutate(local_date = as.Date(format(sent_gmt, tz = "America/Los_Angeles")),
         si_any = as.integer(si_any == "Yes"),
         selfharm_30m = as.integer(selfharm_30m == "Yes"))

# ---- Study day ----------------------------------------------------------------
# Inclivio restarted its day counter at 1 for three participants whose prompt
# schedule was stopped and re-launched. A new "run" starts whenever the gap
# between calendar day and Inclivio day jumps by more than one day. Study day
# continues from the last study day of the previous run, so days on which no
# prompts were scheduled are not counted; a run re-launched on the same
# calendar date as the previous run ended continues that same study day.
ema_raw <- ema_raw %>%
  group_by(inclivio_id) %>%
  mutate(offset = as.integer(local_date - min(local_date)) + 1L - inclivio_day) %>%
  arrange(sent_gmt, .by_group = TRUE) %>%
  mutate(run = cumsum(c(0L, diff(offset) > 1L)) + 1L) %>%
  ungroup()

run_shift <- ema_raw %>%
  group_by(inclivio_id, run) %>%
  summarise(first_date = min(local_date), last_date = max(local_date),
            n_days = max(inclivio_day), .groups = "drop_last") %>%
  arrange(run, .by_group = TRUE) %>%
  mutate(same_day_restart = coalesce(first_date == lag(last_date), FALSE),
         # days contributed by each run, net of a study day shared with the previous run
         shift = lag(cumsum(n_days - same_day_restart), default = 0L) - same_day_restart) %>%
  ungroup() %>%
  select(inclivio_id, run, shift)

ema_raw <- ema_raw %>%
  left_join(run_shift, by = c("inclivio_id", "run")) %>%
  mutate(study_day = inclivio_day + as.integer(shift))

# ---- One record per prompt ------------------------------------------------------
# Re-opened survey links create several records for the same prompt; keep the
# completed one (else the most recent).
ema_obs <- ema_raw %>%
  arrange(inclivio_id, study_day, ping, desc(complete), desc(redcap_row)) %>%
  distinct(inclivio_id, study_day, ping, .keep_all = TRUE) %>%
  filter(study_day <= 42)

ema_ids <- tibble(inclivio_id = unique(ema_obs$inclivio_id)) %>%
  mutate(ema_id = sprintf("E%02d", sample(n())))
stopifnot(nrow(ema_ids) == 30)

ema <- ema_ids %>%
  crossing(study_day = 1:42, ping = 1:5) %>%               # protocol: 42 days x 5 prompts
  left_join(ema_obs, by = c("inclivio_id", "study_day", "ping")) %>%
  transmute(ema_id, study_day, ping,
            completed = as.integer(coalesce(complete, FALSE)),
            across(c(anger, shame, sad, fear, guilt, si_any, intent_selfharm_30m,
                     intent_suicide_30m, intent_suicide_now, selfharm_30m),
                   ~ if_else(completed == 1L, .x, NA))) %>%
  arrange(ema_id, study_day, ping)

# =============================================================================
# 3. Write
# =============================================================================
write_csv(visits,         file.path(out_dir, "precise_visits.csv"), na = "")
write_csv(implementation, file.path(out_dir, "precise_implementation.csv"), na = "")
write_csv(demographics,   file.path(out_dir, "precise_demographics.csv"), na = "")
write_csv(ema,            file.path(out_dir, "precise_ema.csv"), na = "")

message("visits: ", nrow(visits), " rows | implementation: ", nrow(implementation),
        " | demographics: ", nrow(demographics), " | ema: ", nrow(ema),
        " prompts, ", sum(ema$completed), " completed")
