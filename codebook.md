# Codebook

All files are comma-separated with a header row; empty cells are missing values.
Item wording is not reproduced here because several instruments are
copyrighted; item numbers follow each instrument's published order.

## precise_visits.csv

One row per participant per completed visit (30 baseline, 28 six-week,
26 twelve-week).

| Variable | Description | Values |
|---|---|---|
| `id` | Random participant ID. Not linkable to `precise_ema.csv` | `P01`–`P30` |
| `timepoint` | Study visit | `baseline`, `week6`, `week12` |
| `cssrs` | Columbia-Suicide Severity Rating Scale: most severe type of suicidal ideation endorsed in the past month (clinician interview) | 0 = none, 1 = wish to be dead, 2 = non-specific active thoughts, 3 = method without intent, 4 = some intent without plan, 5 = plan and intent |
| `mssi_01`–`mssi_18` | Modified Scale for Suicidal Ideation items (clinician-rated, past 1–2 days). Items 1–4 are screening items; items 5–18 were administered only after a positive screen and are empty otherwise | 0–3 |
| `EDDEP04` … `EDDEP54` | PROMIS Depression v1.0 item bank, 28 items, named by official PROMIS item ID (past 7 days) | 1 = never, 2 = rarely, 3 = sometimes, 4 = often, 5 = always |
| `EDANX01` … `EDANX55` | PROMIS Anxiety v1.0 item bank, 29 items, named by official PROMIS item ID (past 7 days) | 1 = never … 5 = always |
| `cerq_01`–`cerq_36` | Cognitive Emotion Regulation Questionnaire, items in published order | 1 = almost never, 2 = sometimes, 3 = regularly ("frequently"), 4 = often, 5 = almost always |
| `cses_01`–`cses_26` | Coping Self-Efficacy Scale, items in published order. The study's REDCap form offered ten response options | 1 = cannot do at all … 5 = moderately certain can do … 10 = certain can do |

Derived scores (computed in `PRECISE_analysis.Rmd`):

| Score | Rule | Range |
|---|---|---|
| MSSI total | Sum of the 18 items; unadministered items 5–18 count as 0 | 0–54 |
| CERQ subscales | Items *k*, *k*+9, *k*+18, *k*+27 for *k* = 1…9: self-blame, acceptance, rumination, positive refocusing, refocus on planning, positive reappraisal, putting into perspective, catastrophizing, other-blame | 4–20 each |
| CERQ Adaptive | Acceptance + positive refocusing + refocus on planning + positive reappraisal + putting into perspective (20 items) | 20–100 |
| CERQ Maladaptive | Self-blame + rumination + catastrophizing + other-blame (16 items) | 16–80 |
| CSES total | Sum of 26 items; requires ≥80% of items, prorated for missing items | 26–260 |
| PROMIS Depression / Anxiety T | 50 + 10 × EAP θ under the graded response model with the parameters in `promis_item_parameters.csv` and a N(0, 1) prior; requires ≥80% of items | M = 50, SD = 10 in the US general population |

## precise_implementation.csv

One row per participant who completed the 6-week (post-treatment) visit (n = 28).

| Variable | Description | Values |
|---|---|---|
| `id` | Same ID as `precise_visits.csv` | `P01`–`P30` |
| `aim_1`–`aim_4` | Acceptability of Intervention Measure | 1 = completely disagree … 5 = completely agree |
| `iam_1`–`iam_4` | Intervention Appropriateness Measure | 1–5, as above |
| `fim_1`–`fim_4` | Feasibility of Intervention Measure | 1–5, as above |
| `sus_01`–`sus_10` | System Usability Scale, rated for the EMA / telehealth platform | 1 = strongly disagree … 5 = strongly agree |

AIM, IAM and FIM totals are item sums (4–20). SUS total = 2.5 × [Σ(odd items − 1) + Σ(5 − even items)], range 0–100.

## precise_demographics.csv

Thirty rows, **no participant ID, each column permuted independently** (see
README). Use for marginal summaries only.

| Variable | Description |
|---|---|
| `age` | Age in years at enrollment |
| `sex_at_birth` | Sex assigned at birth |
| `gender_identity` | Current primary gender identity |
| `race_ethnicity` | Self-identified race/ethnicity (single choice) |
| `hispanic_latino` | Hispanic, Latino, Spanish, or Mexican origin or heritage |
| `education_years` | Years of education completed |
| `current_student` | Currently a student |
| `employment` | Employment status |
| `relationship` | Relationship status |

## precise_ema.csv

One row per scheduled EMA prompt: 30 participants × 42 study days × 5 prompts =
6,300 rows. Survey variables are empty when `completed` = 0.

| Variable | Description | Values |
|---|---|---|
| `ema_id` | Random participant ID. Not linkable to `precise_visits.csv` | `E01`–`E30` |
| `study_day` | Day of the six-week EMA protocol. For three participants whose prompt schedule was stopped and re-launched, numbering continues across the gap | 1–42 |
| `ping` | Prompt number within the day (1 = morning survey) | 1–5 |
| `completed` | A completed survey was submitted for this prompt | 0, 1 |
| `anger`, `shame`, `sad`, `fear`, `guilt` | Momentary negative emotion sliders. The negative-emotion composite is their mean | 0–100 |
| `si_any` | Gating item: thought about hurting or killing yourself since last night (prompt 1) / in the past few hours (prompts 2–5) | 0 = no, 1 = yes |
| `intent_selfharm_30m` | Intention to harm self, past 30 minutes (asked if `si_any` = 1) | 0 = none, 1 = a little, 2 = moderate, 3 = a lot, 4 = severe (harmed self) |
| `intent_suicide_30m` | Intention to kill self, past 30 minutes (asked if `intent_selfharm_30m` ≥ 1) | 0 = none, 1 = a little (brief thought, no intent), 2 = moderate (some thought, no intent), 3 = a lot (started planning), 4 = severe (specific plan) |
| `intent_suicide_now` | Intention to kill self in this moment (asked if `intent_suicide_30m` ≥ 1) | 0–4, as above |
| `selfharm_30m` | Attempted suicide or engaged in any self-harm in the past 30 minutes (asked if `si_any` = 1) | 0 = no, 1 = yes |

When a participant opened the same prompt more than once, the completed
submission (or, failing that, the most recent one) was kept.

## promis_item_parameters.csv

Graded response model parameters for the PROMIS v1.0 Depression (28 items) and
Anxiety (29 items) emotional distress item banks (Pilkonis et al., *Assessment*
2011;18:263–283), as distributed with the `PROsetta` R package.

| Variable | Description |
|---|---|
| `item_id` | Official PROMIS item ID; matches the column names in `precise_visits.csv` |
| `bank` | `depression` or `anxiety` |
| `position` | Order of the item within the bank as administered |
| `a` | Discrimination (logistic metric) |
| `b1`–`b4` | Category threshold parameters |
