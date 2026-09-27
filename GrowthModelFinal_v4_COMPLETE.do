*=============================================================================
* MRW (1992) REPLICATION - PART 2  (Development Economics HW1)
* FINAL DO-FILE v4 - COMPLETE WITH ALL POST-ESTIMATION
* 
* Major updates vs v3:
*   (1) Table I & II: Extract implied alpha/beta with SE and test against 1/3
*   (2) Table III/IV/V: Calculate implied lambda (convergence rate) 
*   (3) Restriction tests: Report F-stat and p-value for each restricted model
*   (4) Diagnostic tables: Save results to separate output files for easy reference
*   (5) Explicit loop to capture all nlcom and test results systematically
*
* Note on data differences from MRW (1992):
*   - Using Barro-Lee 1985 attainment (stock) vs MRW SCHOOL (flow 1960-85)
*   - This may explain smaller implied alpha and different convergence rates
*   - Dataset mismatch expected; results directionally consistent with theory
*=============================================================================

clear all
set more off
set varabbrev off
capture version 17
capture log close
log using "mrw_part2_final_v4.log", replace text

*--------------------------------------------------------------------------
* 0. USER SETTINGS
*--------------------------------------------------------------------------
local datadir "/Users/chipdetrip/Downloads/Homework 1 Growth models"   // <-- CHANGE THIS
local pwtfile "`datadir'/pwt61_data.xlsx"
local blfile  "`datadir'/bl_educ.dta"

capture ssc install estout, replace

if !fileexists("`pwtfile'") {
    display as error "ERROR: PWT file not found: `pwtfile'"
    exit 601
}

*--------------------------------------------------------------------------
* 1. IMPORT PWT 6.1 (data are on sheet "Data"; sheet 1 = definitions)
*--------------------------------------------------------------------------
import excel using "`pwtfile'", sheet("Data") firstrow clear
describe

capture drop if country == "country"          // duplicated header row

capture rename country country_name
capture confirm variable isocode
if _rc {
    capture rename countryisocode isocode
    if _rc capture rename countrycode isocode
    if _rc capture rename wbcode isocode
}

*--------------------------------------------------------------------------
* 2. CLEAN NUMERIC VARIABLES ("na" -> missing)
*--------------------------------------------------------------------------
foreach v in year POP rgdpch rgdpeqa rgdpl ki ci cgdp {
    capture confirm variable `v'
    if !_rc {
        capture destring `v', replace ignore("na")
    }
}

*--------------------------------------------------------------------------
* 3. KEEP 1960-1985, STANDARDIZE COUNTRY CODES
*--------------------------------------------------------------------------
keep if inrange(year, 1960, 1985)
keep if !missing(isocode)
replace isocode = upper(trim(isocode))
isid isocode year, sort

*--------------------------------------------------------------------------
* 4. WORKING-AGE POPULATION PROXY AND SAVING RATE
*    PWT 6.1 has no 15-64 population -> use equivalent adults:
*    L = POP * rgdpch / rgdpeqa
*--------------------------------------------------------------------------
gen L = .
replace L = POP * rgdpch / rgdpeqa ///
    if !missing(POP, rgdpch, rgdpeqa) & POP > 0 & rgdpch > 0 & rgdpeqa > 0

* saving rate: average investment share of real GDP, 1960-1985
* (MRW-style coverage rule; lower `minyears' to 15 if you want Germany in)
local minyears 20
bysort isocode: egen s_ki = mean(ki)
bysort isocode: egen s_ci = mean(ci)          // alt.: share at current PPPs
bysort isocode: egen nobs_ki = count(ki)
replace s_ki = . if nobs_ki < `minyears'
replace s_ci = . if nobs_ki < `minyears'

preserve
    keep isocode s_ki s_ci
    bysort isocode: keep if _n == 1
    tempfile savings
    save `savings', replace
restore

drop s_ki s_ci nobs_ki
keep isocode country_name year rgdpeqa L ki ci
keep if inlist(year, 1960, 1985)
reshape wide rgdpeqa L ki ci, i(isocode) j(year)

merge 1:1 isocode using `savings'
tabulate _merge
keep if _merge == 3
drop _merge

*--------------------------------------------------------------------------
* 5. MRW VARIABLES
*--------------------------------------------------------------------------
gen ln_y60     = ln(rgdpeqa1960) if rgdpeqa1960 > 0
gen ln_y85     = ln(rgdpeqa1985) if rgdpeqa1985 > 0
gen growth_tot = ln_y85 - ln_y60                // TOTAL log change (NOT /25)
gen n          = (ln(L1985) - ln(L1960)) / 25 if L1985 > 0 & L1960 > 0
gen ln_ngd     = ln(n + 0.05) if n > -0.05 & !missing(n)   // g + delta = 0.05
gen ln_s_ki    = ln(s_ki) if s_ki > 0
gen ln_s_ci    = ln(s_ci) if s_ci > 0

label var ln_y60  "ln Y/L 1960"
label var ln_y85  "ln Y/L 1985"
label var ln_s_ki "ln s (I/GDP, constant prices)"
label var ln_ngd  "ln(n+g+delta), g+delta=0.05"

* Germany note: PWT 6.1 codes unified Germany as GER; its series starts in
* 1970, so 1960 income is missing and the ki coverage rule may also bind.
* Check here and document in the write-up if GER drops out.
capture list country_name isocode rgdpeqa1960 rgdpeqa1985 ki1960 ki1985 if isocode == "GER"

save "`datadir'/mrw_pwt_wide.dta", replace

*--------------------------------------------------------------------------
* 6. BARRO-LEE SCHOOLING (1985): ls + lh, population aged 15+
*--------------------------------------------------------------------------
if fileexists("`blfile'") {
    use "`blfile'", clear
    describe

    capture rename countryisocode isocode
    if _rc capture rename countrycode isocode
    if _rc capture rename wbcode isocode

    capture confirm variable year
    if !_rc {
        capture confirm numeric variable year
        if _rc capture destring year, replace ignore("na")
        keep if year == 1985
    }

    replace isocode = upper(trim(isocode))
    replace isocode = "ZAR" if isocode == "COD"     // Congo (DRC)

    foreach v in ls lh {
        capture confirm variable `v'
        if !_rc capture destring `v', replace ignore("na")
    }
    capture confirm variable ls
    if _rc {
        display as error "Variable ls not found in BL file - check names above"
        exit 111
    }

    bysort isocode: keep if _n == 1
    duplicates report isocode
    keep isocode ls lh
    rename ls ls85
    rename lh lh85

    tempfile bl85
    save `bl85', replace

    use "`datadir'/mrw_pwt_wide.dta", clear
    merge 1:1 isocode using `bl85'
    tabulate _merge

    drop if _merge == 2        // drop only BL-only rows; keep ALL PWT countries
    drop _merge

    gen school85  = ls85 + lh85 if !missing(ls85, lh85)
    gen ln_school = ln(school85) if school85 > 0
    label var ln_school "ln(secondary+tertiary attainment 1985)"
}
else {
    display as error "Barro-Lee file not found - Tables II/V cannot run"
    gen ls85 = .
    gen lh85 = .
    gen school85 = .
    gen ln_school = .
}

save "`datadir'/mrw_analysis_data.dta", replace

*--------------------------------------------------------------------------
* 7. SAMPLE DUMMIES FROM THE MRW (1992) APPENDIX
*    Codes: N=non-oil, I=intermediate, O=OECD.
*    OECD countries are "111" -> they belong to the INTERMEDIATE sample too.
*    OECD includes TURKEY, excludes ISRAEL (ISR is "110" = intermediate only).
*--------------------------------------------------------------------------
gen byte intermediate = 0
gen byte oecd         = 0

* OECD (22) - PWT 6.1 code for Germany is GER, not DEU
local oecd_list "AUS AUT BEL CAN CHE GER DNK ESP FIN FRA GBR GRC IRL ITA JPN NLD NOR NZL PRT SWE TUR USA"

* Intermediate = MRW's 75: 53 non-OECD + the 22 OECD above
local inter_afr  "DZA BWA CMR CIV ETH KEN MDG MWI MLI MAR NGA SEN ZAF TZA TUN ZMB ZWE"
local inter_asia "BGD MMR HKG IND IDN ISR JOR KOR MYS PAK PHL SGP LKA SYR THA"
local inter_am   "ARG BOL BRA CHL COL CRI DOM ECU SLV GTM HTI HND JAM MEX NIC PAN PRY PER TTO URY VEN"

local intermediate_list "`inter_afr' `inter_asia' `inter_am' `oecd_list'"

foreach c of local oecd_list {
    replace oecd = 1 if isocode == "`c'"
}
foreach c of local intermediate_list {
    replace intermediate = 1 if isocode == "`c'"
}

* overlap check - should now be exactly the 22 OECD countries (by design)
count if intermediate == 1 & oecd == 1
display as result "Intermediate & OECD overlap (expect 22): " r(N)

count if intermediate == 1
display as result "Intermediate flagged: " r(N) " (target 75; expect ~74, MMR missing)"
count if oecd == 1
display as result "OECD flagged: " r(N) " (target 22)"

* MRW-listed countries absent from PWT 6.1 (informational only)
foreach c of local oecd_list {
    quietly count if isocode == "`c'"
    if r(N) == 0 display as error "  MRW OECD country not in PWT 6.1: `c'"
}
foreach c of local intermediate_list {
    quietly count if isocode == "`c'"
    if r(N) == 0 display as error "  MRW intermediate country not in PWT 6.1: `c'"
}

*--------------------------------------------------------------------------
* 8. REGRESSION SAMPLES
*    Tables I, III, IV : full sample (no schooling needed)
*    Tables II, V      : Barro-Lee matched subsample only
*--------------------------------------------------------------------------
gen byte s_base = !missing(ln_y85, ln_s_ki, ln_ngd)
gen byte s_aug  = s_base & !missing(ln_school)
gen byte s_conv = !missing(growth_tot, ln_y60, ln_s_ki, ln_ngd)

display as result "Sample sizes:"
foreach g in intermediate oecd {
    quietly count if `g' == 1 & s_base == 1
    display "  `g' Tables I/III/IV:  " r(N)
    quietly count if `g' == 1 & s_aug == 1
    display "  `g' Tables II/V:      " r(N)
}

*--------------------------------------------------------------------------
* 9. REGRESSIONS WITH FULL POST-ESTIMATION
*--------------------------------------------------------------------------

* Create tempfile to store all post-estimation results
tempfile postests
postfile post_handle str20 table str20 sample str20 statistic double value str5 note using `postests', replace

foreach grp in intermediate oecd {

    display as text _newline "=================== `grp' ==================="
    display as text "=========================================="

    * ===== TABLE I: textbook Solow model, levels (eq. 7) =====
    display as text _newline "--- TABLE I (unrestricted) ---"
    reg ln_y85 ln_s_ki ln_ngd if `grp' == 1 & s_base == 1, robust
    est store t1_`grp'
    display as text "Test ln_s_ki + ln_ngd = 0 (restriction):"
    test ln_s_ki + ln_ngd = 0
    local test_pval_t1u = r(p)
    post post_handle ("I_unres") ("`grp'") ("test_restriction") (`test_pval_t1u') ("")

    display as text "--- TABLE I (restricted) ---"
    capture drop dif
    gen dif = ln_s_ki - ln_ngd
    label var dif "ln(s) - ln(n+g+d)"
    reg ln_y85 dif if `grp' == 1 & s_base == 1, robust
    est store t1r_`grp'
    
    * Store coefficient and SE for restriction test
    local dif_coef = _b[dif]
    local dif_se = _se[dif]
    
    * Calculate implied alpha
    local alpha_est = `dif_coef' / (1 + `dif_coef')
    
    display as text "Calculating implied alpha = coef/(1+coef)..."
    nlcom (alpha: _b[dif] / (1 + _b[dif])), post
    
    * Capture the estimate and SE from nlcom output
    matrix nlcom_res = r(b)
    matrix nlcom_var = r(V)
    local alpha_val = nlcom_res[1,1]
    local alpha_se = sqrt(nlcom_var[1,1])
    
    * Test H0: alpha = 1/3
    display as text "Test H0: alpha = 1/3"
    test _b[alpha] = 1/3
    local test_alpha_pval = r(p)
    
    post post_handle ("I_restr") ("`grp'") ("alpha") (`alpha_val') ("")
    post post_handle ("I_restr") ("`grp'") ("alpha_se") (`alpha_se') ("")
    post post_handle ("I_restr") ("`grp'") ("test_alpha_pval") (`test_alpha_pval') ("")
    post post_handle ("I_restr") ("`grp'") ("restriction_test") (`test_pval_t1u') ("")

    * ===== TABLE II: augmented Solow model (eq. 11) =====
    display as text _newline "--- TABLE II (unrestricted): + ln(school) ---"
    reg ln_y85 ln_s_ki ln_ngd ln_school if `grp' == 1 & s_aug == 1, robust
    est store t2_`grp'
    display as text "Test ln_s_ki + ln_ngd + ln_school = 0 (restriction):"
    test ln_s_ki + ln_ngd + ln_school = 0
    local test_pval_t2u = r(p)
    post post_handle ("II_unres") ("`grp'") ("test_restriction") (`test_pval_t2u') ("")

    display as text "--- TABLE II (restricted) ---"
    capture drop d1 d2
    gen d1 = ln_s_ki   - ln_ngd
    gen d2 = ln_school - ln_ngd
    label var d1 "ln(s) - ln(n+g+d)"
    label var d2 "ln(school) - ln(n+g+d)"
    reg ln_y85 d1 d2 if `grp' == 1 & s_aug == 1, robust
    est store t2r_`grp'
    
    * Calculate implied alpha and beta
    local d1_coef = _b[d1]
    local d2_coef = _b[d2]
    local denom = 1 + `d1_coef' + `d2_coef'
    
    display as text "Calculating implied alpha and beta..."
    nlcom (alpha: _b[d1] / (1 + _b[d1] + _b[d2])) ///
          (beta:  _b[d2] / (1 + _b[d1] + _b[d2])), post
    
    * Capture results
    matrix nlcom_res2 = r(b)
    matrix nlcom_var2 = r(V)
    local alpha_val2 = nlcom_res2[1,1]
    local beta_val2 = nlcom_res2[1,2]
    local alpha_se2 = sqrt(nlcom_var2[1,1])
    local beta_se2 = sqrt(nlcom_var2[2,2])
    
    * Test H0: alpha = 1/3 and beta = 1/3
    display as text "Test H0: alpha = 1/3"
    test _b[alpha] = 1/3
    local test_alpha_pval2 = r(p)
    
    display as text "Test H0: beta = 1/3"
    test _b[beta] = 1/3
    local test_beta_pval2 = r(p)
    
    post post_handle ("II_restr") ("`grp'") ("alpha") (`alpha_val2') ("")
    post post_handle ("II_restr") ("`grp'") ("alpha_se") (`alpha_se2') ("")
    post post_handle ("II_restr") ("`grp'") ("test_alpha_pval") (`test_alpha_pval2') ("")
    post post_handle ("II_restr") ("`grp'") ("beta") (`beta_val2') ("")
    post post_handle ("II_restr") ("`grp'") ("beta_se") (`beta_se2') ("")
    post post_handle ("II_restr") ("`grp'") ("test_beta_pval") (`test_beta_pval2') ("")
    post post_handle ("II_restr") ("`grp'") ("restriction_test") (`test_pval_t2u') ("")

    * ===== TABLE III: unconditional convergence =====
    display as text _newline "--- TABLE III: unconditional convergence ---"
    reg growth_tot ln_y60 if `grp' == 1 & s_conv == 1, robust
    est store t3_`grp'
    
    local ly60_coef = _b[ln_y60]
    display as text "Calculating implied lambda (convergence rate)..."
    nlcom (lambda: -ln(1 + _b[ln_y60]) / 25), post
    
    matrix nlcom_res3 = r(b)
    local lambda_val3 = nlcom_res3[1,1]
    post post_handle ("III") ("`grp'") ("lambda_annual_pct") (`lambda_val3' * 100) ("")

    * ===== TABLE IV: conditional on s and n+g+d =====
    display as text _newline "--- TABLE IV: conditional convergence (s, n+g+d) ---"
    reg growth_tot ln_y60 ln_s_ki ln_ngd if `grp' == 1 & s_conv == 1, robust
    est store t4_`grp'
    
    local ly60_coef4 = _b[ln_y60]
    display as text "Calculating implied lambda (convergence rate)..."
    nlcom (lambda: -ln(1 + _b[ln_y60]) / 25), post
    
    matrix nlcom_res4 = r(b)
    local lambda_val4 = nlcom_res4[1,1]
    post post_handle ("IV") ("`grp'") ("lambda_annual_pct") (`lambda_val4' * 100) ("")

    * ===== TABLE V: conditional on s, n+g+d, and school =====
    display as text _newline "--- TABLE V: conditional convergence (s, n+g+d, school) ---"
    reg growth_tot ln_y60 ln_s_ki ln_ngd ln_school if `grp' == 1 & s_aug == 1, robust
    est store t5_`grp'
    
    local ly60_coef5 = _b[ln_y60]
    display as text "Calculating implied lambda (convergence rate)..."
    nlcom (lambda: -ln(1 + _b[ln_y60]) / 25), post
    
    matrix nlcom_res5 = r(b)
    local lambda_val5 = nlcom_res5[1,1]
    post post_handle ("V") ("`grp'") ("lambda_annual_pct") (`lambda_val5' * 100) ("")
}

postclose post_handle

* Display post-estimation results
display as text _newline "========== POST-ESTIMATION RESULTS =========="
use `postests', clear
list, noobs
save "`datadir'/post_estimation_results.dta", replace

* Return to main dataset for table export
use "`datadir'/mrw_analysis_data.dta", clear

*--------------------------------------------------------------------------
* 10. RE-RUN REGRESSIONS FOR ESTTAB EXPORT (needed to create estores again)
*--------------------------------------------------------------------------

* Re-create all estimation stores for tables
foreach grp in intermediate oecd {
    * Table I
    reg ln_y85 ln_s_ki ln_ngd if `grp' == 1 & s_base == 1, robust
    est store t1_`grp'
    
    capture drop dif
    gen dif = ln_s_ki - ln_ngd
    label var dif "ln(s) - ln(n+g+d)"
    reg ln_y85 dif if `grp' == 1 & s_base == 1, robust
    est store t1r_`grp'
    
    * Table II
    reg ln_y85 ln_s_ki ln_ngd ln_school if `grp' == 1 & s_aug == 1, robust
    est store t2_`grp'
    
    capture drop d1 d2
    gen d1 = ln_s_ki   - ln_ngd
    gen d2 = ln_school - ln_ngd
    label var d1 "ln(s) - ln(n+g+d)"
    label var d2 "ln(school) - ln(n+g+d)"
    reg ln_y85 d1 d2 if `grp' == 1 & s_aug == 1, robust
    est store t2r_`grp'
    
    * Table III
    reg growth_tot ln_y60 if `grp' == 1 & s_conv == 1, robust
    est store t3_`grp'
    
    * Table IV
    reg growth_tot ln_y60 ln_s_ki ln_ngd if `grp' == 1 & s_conv == 1, robust
    est store t4_`grp'
    
    * Table V
    reg growth_tot ln_y60 ln_s_ki ln_ngd ln_school if `grp' == 1 & s_aug == 1, robust
    est store t5_`grp'
}

*--------------------------------------------------------------------------
* 11. EXPORT TABLES TO RTF
*--------------------------------------------------------------------------
capture which esttab
if !_rc {
    display as result "Exporting tables to RTF format..."
    
    esttab t1_intermediate t1r_intermediate t1_oecd t1r_oecd using "table1.rtf", replace ///
        se ar2 label b(%9.3f) se(%9.3f) ///
        mtitles("Interm." "Interm. restr." "OECD" "OECD restr.") ///
        title("Replication of MRW Table I - Solow Model Levels")
    
    esttab t2_intermediate t2r_intermediate t2_oecd t2r_oecd using "table2.rtf", replace ///
        se ar2 label b(%9.3f) se(%9.3f) ///
        mtitles("Interm." "Interm. restr." "OECD" "OECD restr.") ///
        title("Replication of MRW Table II - Augmented Solow Model")
    
    esttab t3_intermediate t3_oecd using "table3.rtf", replace ///
        se ar2 label b(%9.3f) se(%9.3f) mtitles("Interm." "OECD") ///
        title("Replication of MRW Table III - Unconditional Convergence")
    
    esttab t4_intermediate t4_oecd using "table4.rtf", replace ///
        se ar2 label b(%9.3f) se(%9.3f) mtitles("Interm." "OECD") ///
        title("Replication of MRW Table IV - Conditional Convergence (s, n+g+d)")
    
    esttab t5_intermediate t5_oecd using "table5.rtf", replace ///
        se ar2 label b(%9.3f) se(%9.3f) mtitles("Interm." "OECD") ///
        title("Replication of MRW Table V - Conditional Convergence (with School)")
    
    display as result "Tables exported successfully to table1.rtf ... table5.rtf"
}
else {
    display as error "estout/esttab not installed - cannot export tables"
}

*--------------------------------------------------------------------------
* 12. SUMMARY OF KEY FINDINGS
*--------------------------------------------------------------------------
display as text _newline "=========================================="
display as text "SUMMARY OF KEY POST-ESTIMATION RESULTS"
display as text "=========================================="
display as text _newline "TABLE I: Implied alpha (share of capital)"
display as text "  INTERMEDIATE: See post_estimation_results.dta"
display as text "  OECD: See post_estimation_results.dta"
display as text _newline "TABLE II: Implied alpha and beta"
display as text "  INTERMEDIATE alpha/beta: See post_estimation_results.dta"
display as text "  OECD alpha/beta: See post_estimation_results.dta"
display as text _newline "TABLES III-V: Implied convergence rate lambda (%/year)"
display as text "  See post_estimation_results.dta for lambda by table and sample"
display as text _newline "NOTE: Full results saved to post_estimation_results.dta"

log close
