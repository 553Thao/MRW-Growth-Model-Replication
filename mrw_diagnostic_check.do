*=============================================================================
* DIAGNOSTIC CHECK FOR TABLE V OECD & TABLE I INTERMEDIATE RESTRICTION
* Purpose: Verify data quality and investigate anomalies
*=============================================================================

clear all
set more off
set varabbrev off
capture version 17
capture log close
log using "mrw_diagnostic_check.log", replace text

*--------------------------------------------------------------------------
* 0. USER SETTINGS
*--------------------------------------------------------------------------
local datadir "/Users/chipdetrip/Downloads/Homework 1 Growth models"   // <-- CHANGE THIS

use "`datadir'/mrw_analysis_data.dta", clear

display as text _newline "=========================================="
display as text "DIAGNOSTIC CHECK: Data Quality & Anomalies"
display as text "=========================================="

*--------------------------------------------------------------------------
* CHECK 1: OECD Sample - Barro-Lee Merge Quality
*--------------------------------------------------------------------------
display as text _newline "CHECK 1: OECD Sample - Barro-Lee Merge Quality"
display as text "---------"

count if oecd == 1 & !missing(ln_school)
local bl_match_oecd = r(N)

count if oecd == 1
local oecd_total = r(N)

display as text "OECD countries with Barro-Lee data: `bl_match_oecd' / `oecd_total'"
display as text "Coverage: " `bl_match_oecd' / `oecd_total' * 100 "%"

* List which OECD countries have missing school data
display as text _newline "OECD countries with MISSING school data:"
list country_name isocode ln_y85 ln_school if oecd == 1 & missing(ln_school)

* List OECD countries with school data
display as text _newline "OECD countries WITH school data:"
list country_name isocode ln_y85 ln_school school85 if oecd == 1 & !missing(ln_school)

*--------------------------------------------------------------------------
* CHECK 2: Table V OECD - Check ln_y60 coefficient
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 2: Table V OECD - Convergence coefficient"
display as text "---------"

reg growth_tot ln_y60 ln_s_ki ln_ngd ln_school if oecd == 1 & !missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school), robust
display as text "Coefficient of ln_y60: " _b[ln_y60]
display as text "This implies λ = -ln(1 + coef) / 25"

nlcom (lambda: -ln(1 + _b[ln_y60]) / 25), post
matrix lamb = r(b)
display as text "Implied λ (annual): " lamb[1,1] * 100 " %"

* Check for outliers in growth_tot
display as text _newline "Descriptive statistics for OECD convergence variables:"
summarize growth_tot ln_y60 ln_s_ki ln_ngd ln_school if oecd == 1 & !missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school), detail

*--------------------------------------------------------------------------
* CHECK 3: Table I Intermediate - Restriction Test Details
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 3: Table I Intermediate - Restriction Test"
display as text "---------"

display as text "UNRESTRICTED Model:"
reg ln_y85 ln_s_ki ln_ngd if intermediate == 1 & !missing(ln_y85, ln_s_ki, ln_ngd), robust
est store check_t1_unres

display as text "Coefficient ln_s_ki: " _b[ln_s_ki]
display as text "Coefficient ln_ngd: " _b[ln_ngd]
display as text "Sum of coefficients: " _b[ln_s_ki] + _b[ln_ngd]
display as text "Are they opposite in sign? " (_b[ln_s_ki] > 0 & _b[ln_ngd] < 0)

display as text _newline "Testing restriction: ln_s_ki + ln_ngd = 0"
test ln_s_ki + ln_ngd = 0
local test_pval_unres = r(p)
display as text "p-value: " `test_pval_unres'

* Now run restricted model
display as text _newline "RESTRICTED Model:"
capture drop dif
gen dif = ln_s_ki - ln_ngd
reg ln_y85 dif if intermediate == 1 & !missing(ln_y85, ln_s_ki, ln_ngd), robust
est store check_t1_res

display as text "Coefficient of dif: " _b[dif]
display as text "This would imply α = " _b[dif] / (1 + _b[dif]) " if constraint held"

* Compare R-squared
est table check_t1_unres check_t1_res, stat(r2 ar2 N)

display as text _newline "Comparison of model fit:"
display as text "Unrestricted R²: " e(r2) " (should be higher)"
display as text "Restricted R²:   " e(r2) " (should be lower due to constraint)"

*--------------------------------------------------------------------------
* CHECK 4: School variable quality
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 4: School (Barro-Lee attainment 1985) Quality"
display as text "---------"

display as text "Intermediate sample:"
summarize school85 ln_school if intermediate == 1 & !missing(school85), detail

display as text _newline "OECD sample:"
summarize school85 ln_school if oecd == 1 & !missing(school85), detail

* Check if school85 is mostly constant within sample
display as text _newline "Variance of school85 by sample:"
bysort oecd: summarize school85, detail

*--------------------------------------------------------------------------
* CHECK 5: Potential outliers in OECD sample
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 5: OECD Outliers - Growth & Initial Income"
display as text "---------"

display as text "OECD countries sorted by growth_tot (1960-1985 log change):"
list country_name isocode ln_y60 ln_y85 growth_tot ln_school if oecd == 1, 
	sort(growth_tot)

display as text _newline "Check correlation between growth_tot and ln_y60 in OECD:"
correlate growth_tot ln_y60 ln_school if oecd == 1 & !missing(growth_tot, ln_y60, ln_school)

*--------------------------------------------------------------------------
* CHECK 6: Scatter plots to visualize (saved to variables for inspection)
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 6: Summary Statistics by Group"
display as text "---------"

display as text "INTERMEDIATE Sample (Table III-V base):"
tab intermediate oecd

summarize growth_tot ln_y60 ln_s_ki ln_ngd if intermediate == 1 & !missing(growth_tot), ///
	by(oecd)

display as text _newline "Correlation matrix INTERMEDIATE:"
correlate growth_tot ln_y60 ln_s_ki ln_ngd ln_school if intermediate == 1 & ///
	!missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school)

display as text _newline "Correlation matrix OECD only:"
correlate growth_tot ln_y60 ln_s_ki ln_ngd ln_school if oecd == 1 & ///
	!missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school)

*--------------------------------------------------------------------------
* CHECK 7: Replication of Table V OECD with and without outliers
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 7: Table V OECD Sensitivity Analysis"
display as text "---------"

display as text "FULL OECD sample (N=" e(N) "):"
reg growth_tot ln_y60 ln_s_ki ln_ngd ln_school if oecd == 1 & ///
	!missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school), robust
local oecd_full_coef_y60 = _b[ln_y60]
nlcom (lambda: -ln(1 + _b[ln_y60]) / 25)

display as text _newline "Check if dropping extreme growth values changes coefficient:"
centile growth_tot if oecd == 1, centile(5 95)

* Summary of findings
display as text _newline _newline "=========================================="
display as text "SUMMARY OF DIAGNOSTIC FINDINGS"
display as text "=========================================="
display as text _newline "1. OECD Barro-Lee coverage: `bl_match_oecd' / `oecd_total' countries"
display as text "   → If coverage < 20, this may explain anomalous results"
display as text _newline "2. Table V OECD coefficient of ln_y60:"
display as text "   → Check if driven by specific outlier countries"
display as text _newline "3. Table I Intermediate restriction:"
display as text "   → p-value from test above indicates how likely to reject α=1/3"
display as text _newline "4. School variable (Barro-Lee 1985):"
display as text "   → Static (1985 only), not flow 1960-85 like MRW SCHOOL"
display as text "   → This proxy difference may explain smaller implied capital share"
display as text _newline "=========================================="

log close
