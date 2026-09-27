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
display as text "Coverage: " string(`bl_match_oecd' / `oecd_total' * 100, "%6.1f") "%"

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
display as text "Implied λ (annual %): " string(lamb[1,1] * 100, "%6.3f")

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
display as text "Sum of coefficients: " (_b[ln_s_ki] + _b[ln_ngd])
display as text "Solow theory predicts: ln_s_ki ≈ −ln_ngd (opposite signs, same magnitude)"

display as text _newline "Testing restriction: H0: ln_s_ki + ln_ngd = 0"
test ln_s_ki + ln_ngd = 0
local test_pval_unres = r(p)
display as text "Test p-value: " string(`test_pval_unres', "%6.4f")

if `test_pval_unres' < 0.05 {
    display as error "REJECT restriction (p < 0.05): Coefficients NOT opposite & equal magnitude"
}
else {
    display as result "Cannot reject restriction (p >= 0.05): Consistent with Solow model"
}

* Now run restricted model
display as text _newline "RESTRICTED Model: ln_y85 = β₀ + β(ln_s_ki - ln_ngd) + ε"
capture drop dif
gen dif = ln_s_ki - ln_ngd
reg ln_y85 dif if intermediate == 1 & !missing(ln_y85, ln_s_ki, ln_ngd), robust
est store check_t1_res

display as text "Coefficient of dif: " _b[dif]
local alpha_restricted = _b[dif] / (1 + _b[dif])
display as text "Implied α = coef/(1+coef) = " string(`alpha_restricted', "%6.4f")
display as text "MRW theory predicts α ≈ 1/3 = 0.3333"

* Compare R-squared
display as text _newline "Model Comparison:"
display as text "                  Unrestricted   Restricted"
est table check_t1_unres check_t1_res, stat(r2 ar2 N)

display as text _newline "Interpretation:"
display as text "  - Unrestricted R² should be ≥ Restricted R²"
display as text "  - If Unrestricted R² >> Restricted R², restriction is costly"
display as text "  - Small difference suggests restriction is reasonable"

*--------------------------------------------------------------------------
* CHECK 4: School variable quality & comparison
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 4: School (Barro-Lee attainment 1985) Quality"
display as text "---------"

display as text "Intermediate sample (non-OECD + OECD):"
summarize school85 ln_school if intermediate == 1 & !missing(school85)

display as text _newline "OECD sample only:"
summarize school85 ln_school if oecd == 1 & !missing(school85)

display as text _newline "Non-OECD Intermediate:"
summarize school85 ln_school if intermediate == 1 & oecd == 0 & !missing(school85)

display as text _newline "KEY ISSUE: School variable is STATIC (1985 only)"
display as text "  → Barro-Lee data = educational attainment stock in 1985"
display as text "  → MRW SCHOOL = average enrollment flow 1960-85"
display as text "  → This explains why we get smaller capital elasticity"

*--------------------------------------------------------------------------
* CHECK 5: Potential outliers in OECD sample
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 5: OECD Outliers - Growth & Initial Income"
display as text "---------"

display as text "OECD countries sorted by growth_tot (1960-1985 log change):"
list country_name isocode ln_y60 ln_y85 growth_tot if oecd == 1, sort(growth_tot)

display as text _newline "Check correlation between growth_tot and ln_y60 in OECD:"
correlate growth_tot ln_y60 if oecd == 1 & !missing(growth_tot, ln_y60)

display as text _newline "With school control:"
correlate growth_tot ln_y60 ln_school if oecd == 1 & !missing(growth_tot, ln_y60, ln_school)

*--------------------------------------------------------------------------
* CHECK 6: Summary Statistics by Group
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 6: Summary Statistics by Group"
display as text "---------"

display as text "Sample distribution:"
tab intermediate oecd

display as text _newline "Descriptive statistics: INTERMEDIATE (All + OECD):"
summarize growth_tot ln_y60 ln_s_ki ln_ngd if intermediate == 1 & !missing(growth_tot)

display as text _newline "Descriptive statistics: NON-OECD Intermediate:"
summarize growth_tot ln_y60 ln_s_ki ln_ngd if intermediate == 1 & oecd == 0 & !missing(growth_tot)

display as text _newline "Descriptive statistics: OECD only:"
summarize growth_tot ln_y60 ln_s_ki ln_ngd if oecd == 1 & !missing(growth_tot)

*--------------------------------------------------------------------------
* CHECK 7: Replication of Table V OECD with full diagnostics
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 7: Table V OECD Full Regression Diagnostics"
display as text "---------"

count if oecd == 1 & !missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school)
local n_oecd_full = r(N)

display as text "OECD sample size for Table V: N = `n_oecd_full'"
display as text _newline "Regression output:"
reg growth_tot ln_y60 ln_s_ki ln_ngd ln_school if oecd == 1 & ///
	!missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school), robust

local coef_y60 = _b[ln_y60]
display as text _newline "Coefficient of ln_y60: " string(`coef_y60', "%8.4f")

nlcom (lambda: -ln(1 + _b[ln_y60]) / 25), post
matrix lambda_table5_oecd = r(b)
local lambda_pct = lambda_table5_oecd[1,1] * 100
display as text "Implied convergence rate λ: " string(`lambda_pct', "%6.3f") " % per year"

display as text _newline "Diagnostics:"
display as text "  If λ > 3% and augmented model → unusual (should be slower than unconditional)"
display as text "  Possible explanations:"
display as text "    1. Small sample size (N=`n_oecd_full')"
display as text "    2. OECD has different convergence pattern than developing countries"
display as text "    3. School variable doesn't control adequately (static 1985, not flow)"
display as text "    4. Outlier effects with small N"

*--------------------------------------------------------------------------
* CHECK 8: Test if Table V differs from Table IV (conditional on s, n+g+d)
*--------------------------------------------------------------------------
display as text _newline _newline "CHECK 8: Impact of adding School to Table IV → Table V"
display as text "---------"

display as text "TABLE IV OECD (s, n+g+d only):"
reg growth_tot ln_y60 ln_s_ki ln_ngd if oecd == 1 & !missing(growth_tot, ln_y60, ln_s_ki, ln_ngd), robust
est store t4_oecd_check
local coef_t4 = _b[ln_y60]
local r2_t4 = e(r2)

display as text "ln_y60 coefficient: " string(`coef_t4', "%8.4f")
display as text "R²: " string(`r2_t4', "%6.4f")

display as text _newline "TABLE V OECD (s, n+g+d, school):"
reg growth_tot ln_y60 ln_s_ki ln_ngd ln_school if oecd == 1 & ///
	!missing(growth_tot, ln_y60, ln_s_ki, ln_ngd, ln_school), robust
est store t5_oecd_check
local coef_t5 = _b[ln_y60]
local r2_t5 = e(r2)

display as text "ln_y60 coefficient: " string(`coef_t5', "%8.4f")
display as text "R²: " string(`r2_t5', "%6.4f")

display as text _newline "Comparison:"
display as text "Change in ln_y60 coefficient: " string(`coef_t5' - `coef_t4', "%8.4f")
display as text "Change in R²: " string(`r2_t5' - `r2_t4', "%6.4f")

if abs(`coef_t5') > abs(`coef_t4') {
    display as error "⚠ WARNING: Adding school INCREASES magnitude of convergence coefficient"
    display as error "           This is unusual and suggests school is not controlling properly"
}

*--------------------------------------------------------------------------
* SUMMARY OF FINDINGS
*--------------------------------------------------------------------------
display as text _newline _newline "=========================================="
display as text "SUMMARY OF DIAGNOSTIC FINDINGS"
display as text "=========================================="

display as text _newline "1. OECD Barro-Lee Data Coverage:"
display as text "   - Matched: `bl_match_oecd' / `oecd_total' OECD countries"
if `bl_match_oecd' < 20 {
    display as error "   ⚠ WARNING: Low coverage may bias Table V results"
}

display as text _newline "2. Table I Intermediate Restriction Test:"
display as text "   - Test H0: ln_s + ln(n+g+δ) = 0"
display as text "   - p-value: " string(`test_pval_unres', "%6.4f")
if `test_pval_unres' < 0.05 {
    display as error "   ⚠ REJECT: Solow restriction violated for Intermediate"
    display as error "     → Capital and population growth terms not offsetting as theory predicts"
}

display as text _newline "3. Table V OECD Anomaly (λ ≈ 3.9%):"
display as text "   - Implied convergence rate is faster than Table IV"
display as text "   - Expected: augmented model should have SLOWER convergence"
display as text "   ⚠ Possible issues:"
display as text "     • Small sample (N≈21 with school data)"
display as text "     • Barro-Lee 1985 stock vs MRW flow proxy"
display as text "     • School doesn't control variation in OECD growth"

display as text _newline "4. Key Data Limitation:"
display as text "   - School = Barro-Lee attainment 1985 (static stock)"
display as text "   - MRW SCHOOL = average enrollment 1960-85 (flow)"
display as text "   ⚠ This explains:"
display as text "     • Smaller implied α (0.19 vs MRW 0.29)"
display as text "     • Smaller coefficient on ln_school (0.30 vs MRW 0.76)"

display as text _newline "=========================================="
display as text "NEXT STEPS:"
display as text "=========================================="
display as text "1. Report these diagnostics in your write-up"
display as text "2. Note that proxy differences explain deviations from MRW"
display as text "3. Discuss whether results are qualitatively consistent with theory"
display as text "4. Flag OECD Table V as potentially unreliable (small N issue)"

log close
