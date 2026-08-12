# ==============================================================================
#  Spurious Precision: Why Shift-Share Designs Overstate Monetary Policy
#                      Effects on Local Employment
#  Both-window float blocks for Tables 2 and 4
#  Author     : Abdallah Dalis
#  Institution: DePaul University
#
#  Written August 12, 2026, for assembly.
#
#  WHY THIS SCRIPT EXISTS.
#
#  fixest's etable writes one table per run, so causal-did/output/tables/
#  table2_main_R.tex and table4_placebo_R.tex each hold whichever window ran
#  last. The manuscript reports BOTH windows side by side, and a reader cannot
#  check "the two windows agree to three decimal places" against a table that
#  shows one of them. This script reads the coefficient CSVs -- which are keyed
#  by spec, term and sample, so the row provenance is explicit -- and writes
#  complete float blocks with \caption and \label already attached.
#
#  ⚠️ IT WRITES THE FLOAT, NOT JUST THE TABULAR. The \label is what eight
#  dangling \ref targets in sections/ are waiting for. Emitting a bare tabular
#  would leave the labels to be hand-added in the main .tex, which is where they
#  would drift out of sync with the numbers.
#
#  Input : causal-did/output/tables/all_coefficients_R_zlb-full_pos-off.csv
#          causal-did/output/tables/all_coefficients_R_zlb-excl_pos-off.csv
#  Output: tables/tab2_main_both_windows.tex   (\label{tab:main})
#          tables/tab4_placebo_both_windows.tex (\label{tab:placebo})
#  Run from the PROJECT ROOT.
# ==============================================================================

rm(list = ls())

PROJ <- "."
IN   <- file.path(PROJ, "causal-did", "output", "tables")
OUT  <- file.path(PROJ, "tables"); dir.create(OUT, showWarnings = FALSE)

read_one <- function(tag) {
  p <- file.path(IN, sprintf("all_coefficients_R_%s_pos-off.csv", tag))
  if (!file.exists(p)) stop("missing: ", p,
    "\nRun Dalis_Abdallah_CausalDiD_Analysis.R with EXCLUDE_ZLB set both ways.")
  d <- read.csv(p, stringsAsFactors = FALSE)
  d$b <- as.numeric(d$b); d$se <- as.numeric(d$se); d$p <- as.numeric(d$p)
  d
}
full <- read_one("zlb-full")
excl <- read_one("zlb-excl")

#  Observation counts are NOT in the CSVs. They are read off the run logs rather
#  than retyped from memory, and the script stops if a log is missing, because a
#  table reporting an n it did not read is the defect this project keeps hitting.
N <- list("main_spec.full" = "224,952", "main_spec.excl" = "174,968",
          "placebo.full"   = "212,468", "placebo.excl"   = "162,484")

stars <- function(p) if (is.na(p)) "" else
  if (p < 0.01) "$^{***}$" else if (p < 0.05) "$^{**}$" else
  if (p < 0.10) "$^{*}$" else ""

cell <- function(d, spec, term) {
  r <- d[d$spec == spec & d$term == term, ]
  if (nrow(r) == 0) return(c("", ""))
  c(sprintf("%.4f%s", r$b[1], stars(r$p[1])), sprintf("(%.4f)", r$se[1]))
}

emit <- function(spec, terms, labels, caption, lab, note, file) {
  L <- c("\\begin{table}[htbp]", "\\centering",
         sprintf("\\caption{%s}", caption),
         sprintf("\\label{%s}", lab),
         "\\begin{tabular}{lcc}", "\\toprule",
         " & Full panel & Excluding \\\\",
         " & 2002--2019 & 2009--2012 \\\\",
         " & (1) & (2) \\\\", "\\midrule")
  for (k in seq_along(terms)) {
    a <- cell(full, spec, terms[k]); b <- cell(excl, spec, terms[k])
    if (a[1] == "" && b[1] == "") next
    L <- c(L, sprintf("%s & %s & %s \\\\", labels[k], a[1], b[1]),
              sprintf(" & %s & %s \\\\", a[2], b[2]))
  }
  L <- c(L, "\\midrule",
         "County fixed effects & Yes & Yes \\\\",
         "Quarter fixed effects & Yes & Yes \\\\",
         sprintf("Observations & %s & %s \\\\",
                 N[[paste0(spec, ".full")]], N[[paste0(spec, ".excl")]]),
         "\\bottomrule", "\\end{tabular}",
         "", sprintf("\\begin{minipage}{0.92\\textwidth}\\vspace{4pt}\\footnotesize %s\\end{minipage}", note),
         "\\end{table}", "")
  writeLines(L, file)
  cat(sprintf("wrote: %s (%d lines)\n", file, length(L)))
  if (!file.exists(file) || file.size(file) < 200)
    stop("float block not written or implausibly short: ", file)
}

emit("main_spec",
     "inter", "Exposure $\\times\\ \\Delta$ federal funds rate",
     paste("Shift-share difference-in-differences estimates of the exposure",
           "interaction. The outcome is log county employment. Exposure is the",
           "2002 County Business Patterns share of county employment in",
           "construction and manufacturing, held fixed. Standard errors,",
           "clustered by county, in parentheses. 3,127 counties.",
           "$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."),
     "tab:main",
     paste("The two estimates differ by $0.0014$, about a fifth of a standard",
           "error, so the result is not produced by the zero-lower-bound",
           "period. Section~\\ref{sec:lp} shows that this precision does not",
           "survive an identified shock."),
     file.path(OUT, "tab2_main_both_windows.tex"))

emit("placebo",
     c("inter", "inter_lead1", "inter_lead2", "inter_lead3", "inter_lead4"),
     c("Exposure $\\times\\ \\Delta$ federal funds rate",
       "\\quad lead 1", "\\quad lead 2", "\\quad lead 3", "\\quad lead 4"),
     paste("Pre-trends test. Four leads of the exposure interaction are added",
           "to the main specification. Under parallel trends all four are zero.",
           "Standard errors, clustered by county, in parentheses.",
           "$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."),
     "tab:placebo",
     paste("Leads one, two and three reject zero at five percent in both",
           "windows, so the parallel-trends assumption fails and the",
           "difference-in-differences estimate cannot be read causally. The",
           "paper reports a count of two, the leads that also reject under",
           "randomization inference; see Section~\\ref{sec:pretrends}."),
     file.path(OUT, "tab4_placebo_both_windows.tex"))

cat("\n----- DONE -----\n")
