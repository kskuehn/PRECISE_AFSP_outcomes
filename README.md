# PRECISE open trial: data and analysis code

De-identified data and code to reproduce the analyses in:

> Kuehn KS, Moore RC, Foster KT, Depp CA. *Preliminary Effects of PRECISE, a
> Personalized and Idiographically-Tailored Adjunctive Intervention for Treating
> Suicidal Ideation and Psychiatric Symptoms in Young Adults: Open Trial.*

PRECISE (PeRsonalizEd Clinical Intervention for Suicidal Events) is a six-week
blended intervention that personalizes DBT skills using idiographic models of
each participant's ecological momentary assessment (EMA) data. Thirty young
adults (18–26) with active suicidal ideation took part in a single-arm open
trial with assessments at baseline, 6 weeks and 12 weeks
(ClinicalTrials.gov NCT07749391).

## Contents

| Path | What it is |
|---|---|
| `PRECISE_analysis.Rmd` | Analysis code: scores every measure from item-level data and produces Tables 1, 2, 4 and 5, Figure 2, Figure S1 (Multimedia Appendix 1), and the EMA compliance, missingness and safety results |
| `PRECISE_analysis.html` | Rendered output of the above |
| `make_figure2.R` | Figure 2 (model-estimated trajectories of the CSSRS and MSSI); run by the Rmd |
| `make_figureS1.R` | Figure S1 (EMA compliance by study day and prompt); run by the Rmd |
| `figures/` | Publication figures: PDF, 600-dpi TIFF and PNG for Figures 1, 2 and S1, plus the values plotted in Figures 2 and S1 |
| `data/precise_visits.csv` | Baseline, 6-week and 12-week assessments (30 participants, 84 visits) |
| `data/precise_implementation.csv` | Post-treatment AIM, IAM, FIM and SUS items (n = 28) |
| `data/precise_demographics.csv` | Baseline demographics for Table 1 (N = 30) |
| `data/precise_ema.csv` | EMA: one row per scheduled prompt (6,251 prompts, 4,043 completed) |
| `data/promis_item_parameters.csv` | Published PROMIS graded-response-model item parameters used for T-scores |
| `codebook.md` | Variable-level documentation for every file |
| `01_clean_data.R` | Builds the visit, implementation and demographics files from the raw REDCap exports (raw exports are not shared) |
| `02_prepare_ema.R` | Builds `data/precise_ema.csv` from the EMA export (not shared) |

Figure 1 (CONSORT flow diagram) is drawn from study tracking records and is
included in `figures/` as a static image.

## Reproducing the results

```r
install.packages(c("dplyr", "tidyr", "readr", "ggplot2", "patchwork", "brms",
                   "bayestestR", "lme4", "knitr", "rmarkdown"))
rmarkdown::render("PRECISE_analysis.Rmd")
```

Run from the repository root. `brms` needs a working C++ toolchain for Stan
(<https://mc-stan.org/users/interfaces/rstan>). The first render compiles and
samples seven models (about 10 minutes on a laptop) and caches them in `fits/`;
later renders take seconds.

Results in `PRECISE_analysis.html` were produced with R 4.3.3, brms 2.20.4,
rstan 2.32.5, bayestestR 0.13.1 and lme4 1.1-35.1. Posterior summaries vary in
the second decimal place across Stan versions and platforms.

## Analyses

- **Change over time.** Bayesian multilevel models, `y ~ timepoint + (1 | id)`,
  Gaussian likelihood, 4 chains × 3,000 iterations (1,000 warm-up), using all
  available observations from all 30 participants. Reported for each change
  coefficient: posterior median, 95% credible interval, probability of
  direction, percentage of the posterior inside a region of practical
  equivalence of ±0.1 SD, and a standardized effect (change divided by the
  model-implied pooled SD).
- **PROMIS T-scores.** Expected a posteriori scoring under the graded response
  model with fixed published item parameters and a standard normal prior.
- **EMA compliance.** A prompt counts as completed when a survey was submitted.
  Compliance is reported overall, per participant, by study week and by prompt
  of the day.
- **EMA missingness.** Logistic mixed-effects models of a missed prompt on
  study week, prompt number, and negative emotion or suicidal ideation at the
  preceding prompt.
- **Response.** ≥50% reduction from each participant's own baseline.

Table 3 (session attendance), treatment fidelity and the adverse-event log are
based on study tracking records that are not part of these datasets.

## De-identification

The public files were prepared to prevent re-identification of participants:

- No names, contact details, dates, times, free-text responses, assessor
  initials, or REDCap / Inclivio identifiers are included.
- Participant IDs are random and carry no enrollment order. Visit IDs
  (`P01`–`P30`) and EMA IDs (`E01`–`E30`) were assigned independently, so
  **visit and EMA records cannot be linked**.
- `precise_demographics.csv` has no participant ID and **each column was
  permuted independently**. Marginal distributions (everything Table 1 reports)
  are exact, but a row does not describe a real person and demographics cannot
  be related to outcomes.
- EMA timing is reduced to study day (the participant's 1st, 2nd, … EMA day;
  1–42, or 43 for one participant whose schedule was relaunched) and prompt
  number (1–5).

Requests for data beyond what is shared here should be directed to the
corresponding author and are subject to UC San Diego IRB approval.

## Funding

American Foundation for Suicide Prevention Young Investigator Grant
YIG-0-078-22 and National Institute of Mental Health K23MH137367
(PI: Kevin S. Kuehn, PhD).
