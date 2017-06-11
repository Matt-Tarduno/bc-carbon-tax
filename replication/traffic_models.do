*Make docstring
*maybe relegate diagnostics to other do-files? 


if c(os) == "MacOSX" & c(username) == "malsan" {
	local work "/Users/malsan/Dropbox/BC carbon tax"
}
else if c(os) == "MacOSX" & c(username) == "koren" {
	local work "/Users/koren/Dropbox/ATUS_project"
}
else if c(os) == "Unix" & c(hostname) == "scrivener" {
    local work "/home/jgs/Dropbox/research/projects/active/ATUS_project"
}
else {
	local work "/home/koren/Dropbox/ATUS_project"
}

set matsize 11000
set more off 
ssc install outreg2
ssc install lincomest

set scheme s1mono

import delimited using "`work'/Data/Traffic/Traffic_daily_2004_2015", clear
encode tmp, gen(tmp_factor)
encode dayofweek, gen(dayofweek_factor)

gen p1=0
gen p2=0
gen p3=0
gen p4=0
gen p5=0
replace p1=1 if linearday1>=0
replace p2=1 if linearday1>=365 
replace p3=1 if linearday1>=730 
replace p4=1 if linearday1>=1095 
replace p5=1 if linearday1>=1461 
*these cutoffs are correct, to leap years 
drop if volume<1
drop v1
duplicates drop
drop if linearday1>2190
*as per 2014 speed limit changes (July 2nd 2014) 

gen olympic_dummy=0
replace olympic_dummy=1 if year==2010 & month==1 
replace olympic_dummy=1 if year==2010 & month==2 
replace olympic_dummy=1 if year==2010 & month==3 

gen big_sensor=0 
replace big_sensor=1 if tmp==siteno
save "`work'/Data/Traffic/all_sensors", replace
*label this []
*differentiate from "Analysis_Data"


********************************************************************************
*Congestion
********************************************************************************

*local work "/Users/malsan/Dropbox/BC carbon tax"
*use "`work'/Data/Traffic/all_sensors", clear


*negative (W, S)
preserve
import delimited using "`work'/Data/Traffic/output", clear
*rename variables 
destring v6 v7 v8 v9 v10 v11, replace force
rename v1 month
rename v2 day 
rename v3 year 
rename v4 sitename
rename v5 tmp 
rename v6 average_site_speed
rename v7 median_site_speed
rename v8 average_neg
rename v9 median_neg
rename v10 average_pos
rename v11 median_pos
rename v12 posted_speed_neg
destring posted_speed, replace force
drop average_pos median_pos average_site_speed median_site_speed
*tmp already match 
tempfile neg_temp 
save `neg_temp'
restore

preserve
import delimited using "`work'/Data/Traffic/output", clear
*rename variables 
destring v6 v7 v8 v9 v10 v11, replace force
rename v1 month
rename v2 day 
rename v3 year 
rename v4 sitename
rename v5 tmp 
rename v6 average_site_speed
rename v7 median_site_speed
rename v8 average_neg
rename v9 median_neg
rename v10 average_pos
rename v11 median_pos
rename v12 posted_speed_pos
destring posted_speed, replace force
drop average_neg median_neg average_site_speed median_site_speed
generate south_west= substr(tmp,-1, .)
replace tmp= substr(tmp,1,length(tmp)-1)
replace tmp=tmp+"E" if south_west=="W"
replace tmp=tmp+"N" if south_west=="S"
tempfile pos_temp 
drop south_west
save `pos_temp'
restore


merge 1:1 month year day tmp using `pos_temp'
rename _merge merge1
merge 1:1 month year day tmp using `neg_temp'
rename _merge merge2
gen average=average_pos
gen median=median_pos
gen posted_speed=posted_speed_pos
replace average=average_neg if average==.
replace median=median_neg if median==.
replace posted_speed=posted_speed_neg if posted_speed==.
drop merge1 merge2 average_neg average_pos median_pos median_neg


********************************************************************************
*Diagnostics:
********************************************************************************


************************************************************
*Section 1: What's the deal with the directional components?
************************************************************


preserve
count
keep if big_sensor==0
collapse (sum) volume, by(siteno linearday1)
rename volume sum
tempfile sensor_diagnostic
save `sensor_diagnostic'
count
restore

preserve
count
keep if big_sensor==1
merge 1:1 siteno linearday1 using `sensor_diagnostic'
tab _merge 
gen mismatch=0 
replace mismatch=1 if sum!=volume
count if _merge==3 & mismatch==1 
restore

*verdict: there are a fair number (~1/4 of sitenumbers [read: not observations]) that don't form a full {big sensor, little sensor, little sensor} set. 
*of sets like this, only two sensor-day observations don't add properly, and they might be honest measurement error (302 vs 300, and 528 vs 607) 
*should we limit to only full trios?

******************************
*Section 2: Sensor Birth/Death
******************************


preserve
gen x=1
collapse(count) x, by(tmp)
gen pass =0  
replace pass=1 if x>3700
*missing less than a full year of obs. 
tempfile full_sensor_list  
save `full_sensor_list'
restore

preserve
keep if big_sensor==1
merge m:1 tmp using `full_sensor_list'
keep if pass==1
drop x
gen x=1
collapse (count) x, by (linearday1)
*how many sensors report on a given day 
*graph twoway scatter x linearday, msize(tiny) 
*graph export "`work'/Graphs/sensors_per_day_restricted.pdf", replace
restore

*these seem to be our problem days: 

gen dummy=0
replace dummy=1 if linearday1==-1345 | linearday1==-1185 | linearday1==250 | linearday1==-821 | linearday1==-114 | linearday1==621 | linearday1==153 | linearday1==153 | linearday1==-841
drop if dummy==1 
 
keep if big_sensor==0
merge m:1 tmp using `full_sensor_list'
keep if pass==1
drop x 
drop _merge

save "`work'/Data/Traffic/Analysis_Data", replace 


********************************************************************************
* Sensor-specific RDs, Sensor response distributions [Histograms]
********************************************************************************

***********
* Setup GIS
***********

preserve
import excel using "`work'/Data/Traffic/sensor_coordinates.xlsx", clear firstrow 
rename SiteNo tmp
keep if strpos(tmp, "P-")


generate south_west_indicator= substr(tmp,-1, .)
replace tmp= substr(tmp,1,length(tmp)-1)
tempfile south_west_sensors
save `south_west_sensors'
replace tmp= substr(tmp,1,length(tmp)-1)
replace tmp=tmp+south_west_indicator
append using `south_west_sensors'
drop south_west_indicator
tempfile coordinates
duplicates drop tmp, force
save `coordinates'
restore


foreach i in 1 2 3 4 5 {
preserve
local year=2007+`i'
rename linearday`i' lnd
drop linearday*
rename lnd linearday
rename p`i' post
keep if year==`year'
keep if month==6 | month==7
duplicates drop
gen x=1
collapse (count) x, by (tmp_factor tmp)
gen factor_ID=int(tmp_factor)
gen pass=0
replace pass=1 if x>60
tempfile RD_sensor_temp
save `RD_sensor_temp'
restore 

preserve 
local year=2007+`i'
rename linearday`i' lnd
drop linearday*
rename lnd linearday
rename p`i' post
keep if year==`year'
keep if month==6 | month==7
duplicates drop
merge m:1 tmp_factor using `RD_sensor_temp'
keep if pass==1

regr logvolume i.tmp_factor i.dayofweek_factor#i.tmp_factor i.tmp_factor#c.linearday i.tmp_factor#c.linearday#post i.tmp_factor#post

matrix b = e(b)
matrix c=b'
putexcel A1=matrix(c, names) using "`work'/Code/results.xlsx", replace

clear
import excel using "`work'/Code/results.xlsx"
drop if strpos(A, "linearday")
drop if strpos(A, "dayofweek_factor")
keep if strpos(A, "tmp_factor#1.p")

destring B, replace

summarize B
local m=r(mean)
tempfile estimates
replace A=subinstr(A, "b.tmp_factor#1.post","",.)
replace A=subinstr(A, ".tmp_factor#1.post","",.)
destring A, replace
save `estimates'
hist B, freq bin(50) kdensity color(bluishgray) graphregion(color(white)) plotregion(fcolor(white)) lcolor(black) addplot(pci 0 `m' 20 `m') legend(order(1 "Sensors" 2 "Kernel Density" 3 "Mean")) xtitle("Percent Change in Passing Vehiles") ytitle("Frequency (Sensors)") title("Diagram of Sensor-Specific Responses") yla(,nogrid)


graph export "`work'/Graphs/Traffic_`year'_PDF.pdf", replace
restore

preserve
generate A=int(tmp_factor)
merge m:1 A using `estimates'
collapse (mean) volume B, by(tmp)
keep if B!=.
regress volume B
gen gross_change=volume*B
summarize gross_change
local m=r(mean)
hist gross_change, freq bin(50) kdensity color(bluishgray) graphregion(color(white)) plotregion(fcolor(white)) lcolor(black) addplot(pci 0 `m' 20 `m') legend(order(1 "Sensors" 2 "Kernel Density" 3 "Mean")) xtitle("Estmated Change in Passing Vehicles") ytitle("Frequency (Sensors)") title("Diagram of Sensor-Specific Gross Responses") yla(,nogrid)
graph export "`work'/Graphs/Traffic_`year'_gross_PDF.pdf", replace
restore


************
* Output GIS
************

preserve
import excel using "`work'/Code/results.xlsx", clear
drop if strpos(A, "linearday")
drop if strpos(A, "dayofweek_factor")
keep if strpos(A, "tmp_factor#1.p")
replace A=subinstr(A, "b.tmp_factor#1.post","",.)
replace A=subinstr(A, ".tmp_factor#1.post","",.)
destring A, replace
destring B, replace
rename A tmp_factor
rename B estimate
tempfile estimates
save `estimates'

use "/Users/malsan/Dropbox/BC carbon tax/Data/Traffic/Analysis_Data", clear
gen x=1
collapse (count) x, by (tmp tmp_factor)
drop x 
drop if tmp_factor==.
merge 1:1 tmp_factor using `estimates'
drop _merge 

merge 1:1 tmp using `coordinates'
keep if _merge==3
drop _merge tmp_factor
export delimited using "/Users/malsan/Dropbox/BC carbon tax/Data/Traffic/gis_data_`year'.csv", replace
restore
}


********************************************************************************
* RD Models 1-4
********************************************************************************



local work "/Users/malsan/Dropbox/BC carbon tax"
use "`work'/Data/Traffic/Analysis_Data", clear 
*figure out how to add stars after using stats -- is there a way to store locals as regressions instead? 

merge m:1 tmp using `full_sensor_list.dta'
*keep if pass==1
collapse (mean) volume, by (day month year dayofweek_factor weekofyear dayofyear linearday* p1 p2 p3 p4 p5 olympic_dummy)
gen logvolume=log(volume)

preserve
count

*Column 1 (month, linear trends, different slope each period, DOW dummies)
eststo clear 

eststo: regr logvolume i.dayofweek_factor i.month c.linearday1 c.linearday1#1.p1 c.linearday1#1.p2 c.linearday1#1.p3 c.linearday1#1.p4 c.linearday1#1.p5 p1 p2 p3 p4 p5 olympic_dummy

lincom p1+0
estadd scalar post1 r(estimate)
estadd scalar se1 r(se)

lincom p2+(365*1.p2#c.linearday1)
estadd scalar post2 r(estimate)
estadd scalar se2 r(se)

lincom p3+(730*1.p3#c.linearday1)
estadd scalar post3 r(estimate)
estadd scalar se3 r(se)

lincom p4+(1095*1.p4#c.linearday1)
estadd scalar post4 r(estimate)
estadd scalar se4 r(se)

lincom p5+(1461*1.p5#c.linearday1)
estadd scalar post5 r(estimate)
estadd scalar se5 r(se)

*Column 2 (week of year, linear trends, different slope each period, DOW dummies)
eststo: regr logvolume i.dayofweek_factor i.weekofyear c.linearday1 c.linearday1#1.p1 c.linearday1#1.p2 c.linearday1#1.p3 c.linearday1#1.p4 c.linearday1#1.p5 p1 p2 p3 p4 p5 olympic_dummy 

lincom p1+0
estadd scalar post1 r(estimate)
estadd scalar se1 r(se)

lincom p2+(365*1.p2#c.linearday1)
estadd scalar post2 r(estimate)
estadd scalar se2 r(se)

lincom p3+(730*1.p3#c.linearday1)
estadd scalar post3 r(estimate)
estadd scalar se3 r(se)

lincom p4+(1095*1.p4#c.linearday1)
estadd scalar post4 r(estimate)
estadd scalar se4 r(se)

lincom p5+(1461*1.p5#c.linearday1)
estadd scalar post5 r(estimate)
estadd scalar se5 r(se)


*Column 3 (day of year, linear trends, different slope each period, DOW dummies)
eststo: regr logvolume i.dayofweek_factor i.dayofyear c.linearday1 c.linearday1#1.p1 c.linearday1#p2 c.linearday1#1.p3 c.linearday1#1.p4 c.linearday1#1.p5 p1 p2 p3 p4 p5 olympic_dummy 

lincom p1+0
estadd scalar post1 r(estimate)
estadd scalar se1 r(se)

lincom p2+(365*1.p2#c.linearday1)
estadd scalar post2 r(estimate)
estadd scalar se2 r(se)

lincom p3+(730*1.p3#c.linearday1)
estadd scalar post3 r(estimate)
estadd scalar se3 r(se)

lincom p4+(1095*1.p4#c.linearday1)
estadd scalar post4 r(estimate)
estadd scalar se4 r(se)

lincom p5+(1461*1.p5#c.linearday1)
estadd scalar post5 r(estimate)
estadd scalar se5 r(se)

*Column 4 (month, quadratic trends, different slope each period, DOW dummies )
eststo: regr logvolume i.dayofweek_factor i.month c.linearday1 c.linearday1##c.linearday1#1.p1 c.linearday1##c.linearday1#1.p2 c.linearday1##c.linearday1#1.p3 c.linearday1##c.linearday1#1.p4 c.linearday1##c.linearday1#1.p5 p1 p2 p3 p4 p5 olympic_dummy

lincom p1+0
estadd scalar post1 r(estimate)
estadd scalar se1 r(se)

lincom p2+((365*1.p2#c.linearday1)+((365*365)*1.p2#c.linearday1#c.linearday1))
estadd scalar post2 r(estimate)
estadd scalar se2 r(se)

lincom p3+((730*1.p3#c.linearday1)+((730*730)*1.p3#c.linearday1#c.linearday1))
estadd scalar post3 r(estimate)
estadd scalar se3 r(se)

lincom p4+((1095*1.p4#c.linearday1)+((1095*1095)*1.p4#c.linearday1#c.linearday1))
estadd scalar post4 r(estimate)
estadd scalar se4 r(se)

lincom p5+((1461*1.p5#c.linearday1)+((1461*1461)*1.p5#c.linearday1#c.linearday1))
estadd scalar post5 r(estimate)
estadd scalar se5 r(se)

esttab using "`work'/Tables/Traffic_simultaneous_RD.tex", stats(post1 se1 post2 se2 post3 se3 post4 se4 post5 se5) drop(*.weekofyear *dayofyear *month* *.dayofweek_factor *linearday* p1 p2 p3 p4 p5 olympic_dummy) replace 
*need to add significance levels

restore



********************************************************************************
* Aggregate to Make RD pictures
********************************************************************************

*make this into a for loop -- generate placebo lineardays (linearday-1 linearday0, linearday6)
*maybe do this as well for the histograms. 

use "`work'/Data/Traffic/Analysis_Data", clear  /* only necessary for running codes in chunks*/


merge m:1 tmp using `full_sensor_list.dta'
keep if pass==1
collapse (mean) volume, by (day month year dayofweek_factor weekofyear linearday* p1 p2 p3 p4 p5 olympic_dummy)
gen logvolume=log(volume)

preserve
keep if year==2005
keep if month==6 | month==7
rename p1 post
gen linearday_placebo=linearday1+1095
rename linearday_placebo linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals

twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2005") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2005_placebo.pdf", replace
restore

preserve
keep if year==2006
keep if month==6 | month==7
rename p1 post
gen linearday_placebo=linearday1+730
rename linearday_placebo linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals

twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2006") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2006_placebo.pdf", replace
restore

preserve
keep if year==2007
keep if month==6 | month==7
rename p1 post
gen linearday_placebo=linearday1+365
rename linearday_placebo linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals

twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2007") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2007_placebo.pdf", replace
restore

preserve
keep if year==2008
keep if month==6 | month==7
rename p1 post
rename linearday1 linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals

twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2008") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2008.pdf", replace
restore

preserve
keep if year==2009
keep if month==6 | month==7
rename p1 post
rename linearday2 linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals
twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2009") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2009.pdf", replace
restore

preserve
keep if year==2010
keep if month==6 | month==7
rename p1 post
rename linearday3 linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals
twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2010") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2010.pdf", replace
restore

preserve
keep if year==2011
keep if month==6 | month==7
rename p1 post
rename linearday4 linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals
twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2011") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2011.pdf", replace
restore

preserve
keep if year==2012
keep if month==6 | month==7
rename p1 post
rename linearday5 linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals
twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 2012") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid)
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2012.pdf", replace
restore

preserve
keep if year==2013
keep if month==6 | month==7
rename p1 post
gen linearday_placebo=linearday5-365
rename linearday_placebo linearday
regr logvolume i.dayofweek_factor 
predict residuals, residuals

twoway lpolyci residuals linearday if inrange(linearday, -30,-1), deg(0) graphregion(color(white)) bgcolor(white)  || lpolyci residuals linearday if inrange(linearday, 0,30), deg(0)  || scatter residuals linearday if inrange(linearday, -30, 30), tline(-0.5 , lpattern(dash)) mcolor(navy) msize(small) legend(label(2 "Tax Period 1") label(3 "Pre-tax")) tlabel(-0.5 "1 July 20013") xtitle("") ytitle("Residuals in Aggregate Traffic Volume") xscale(range(-30,30)) yla(,nogrid) 
graph export "`work'/Graphs/Aggregate_Volume_Residuals_2013_placebo.pdf", replace
restore

********************************************************************************
* Aggregate RD to match pictures above
********************************************************************************

eststo clear

*local work "/Users/malsan/Dropbox/BC carbon tax"
*use "`work'/Data/Traffic/Analysis_Data", clear 

foreach i in 1 2 3 4 5 {
preserve
local year=2007+`i'
keep if year==`year'
keep if month==6 | month==7
rename p`i' post
rename linearday`i' linearday
eststo: quietly regress logvolume i.dayofweek_factor c.linearday c.linearday#post post 
restore
}
esttab using "`work'/Tables/Traffic_local_RD.tex", keep(post) replace


********************************************************************************
* RD on Speed
********************************************************************************

eststo clear
use "`work'/Data/Traffic/Analysis_Data", clear 
keep if average!=.
drop if average==0

gen tag=0
replace tag=1 if average>140

*impose arbitrary cutoff that average speed must be within 1.25 of posted speed
*remove any sensor that at any time register a daily average over 135 km/hr 

foreach i in 1 2{
preserve
local year=2007+`i'
keep if year==2004 | year==2005 | year==2007 | year==2008
keep if month==6 
collapse (mean) average tag volume, by (tmp_factor tmp posted_speed)
generate A=int(tmp_factor)
drop if (posted_speed*1.25)<average
drop if tag>0
rename average average_june_`year'
rename volume volume_june_`year'
keep tmp A average_june_`year' posted_speed volume_june_`year'
tempfile file`year'
save `file`year''
restore
}


preserve
collapse (mean) average tag, by (tmp_factor tmp posted_speed)
drop if (posted_speed*1.5)<average
drop if tag>0
generate A=int(tmp_factor)
keep tmp A average posted_speed
tempfile speed_analysis
save `speed_analysis'
restore

merge m:1 tmp using `speed_analysis'
keep if _merge==3
drop _merge
gen logaverage=log(average)

*******************
* Period 1 Speed RD  
*******************

foreach i in 1 2 {
preserve
local year=2007+`i'
keep if year==`year'
keep if month==6 | month==7
rename p`i' post
rename linearday`i' linearday
eststo: quietly regress logaverage i.dayofweek_factor#i.tmp_factor c.linearday#i.tmp_factor c.linearday#post#i.tmp_factor post i.tmp_factor
restore
}
*esttab using "`work'/Tables/speed_local_RD.tex", keep(post) replace

****************
*Speed Histogram
****************

foreach i in 1 2 {
preserve
local year=2007+`i'
rename linearday`i' lnd
drop linearday*
rename lnd linearday
rename p`i' post
keep if year==`year'
keep if month==6 | month==7

regr logaverage i.tmp_factor i.dayofweek_factor#i.tmp_factor i.tmp_factor#c.linearday i.tmp_factor#c.linearday#post i.tmp_factor#post


mat b=e(b)' // transpose e(b) into matrix b
*svmat double b, n(beta) // convert matrix b into variable beta1 (see help svmat)

mat V=e(V) // place e(V) in V
loca nv =`= rowsof(b)' // count number of right hand variables
mat se=J(`nv',1,-9999) // create empty matrix for standard errors
forval i=1/`nv' {
    mat se[`i',1]=sqrt(V[`i',`i']) // convert the variances into the se one at a time
}   
*svmat double se, n(se) // convert matrix se into variable se1
putexcel A1=matrix(b, names) C1=matrix(se, names)  using "`work'/Code/results.xlsx", replace

clear
import excel using "`work'/Code/results.xlsx"

drop if strpos(A, "linearday")
drop if strpos(A, "dayofweek_factor")
keep if strpos(A, "tmp_factor#1.p")

replace A=subinstr(A, "b.tmp_factor#1.post","",.)
replace A=subinstr(A, ".tmp_factor#1.post","",.)
destring A, replace

destring B, replace
summarize B

drop C
destring D, replace

merge 1:1 A using `speed_analysis'
drop _merge
merge 1:1 A using `file`year''


local m=r(mean)
hist B, freq bin(50) kdensity color(bluishgray) graphregion(color(white)) plotregion(fcolor(white)) lcolor(black) addplot(pci 0 `m' 20 `m') legend(order(1 "Sensors" 2 "Kernel Density" 3 "Mean")) ytitle("Frequency (Sensors)") xtitle("Percent Change in Average Daily Speed") yla(,nogrid)
graph export "`work'/Graphs/Speed_`year'_PDF.pdf", replace


gen ratio = average_june_`year'/posted_speed
serrbar B D ratio, ytitle("Estimated Percent Change in Average Speed") xtitle("Ratio of Average Daily Speed to Speed Limit") yla(,nogrid)
graph export "`work'/Graphs/Speed_`year'_Congestion.pdf", replace
graph twoway scatter B ratio [w=volume_june_`year'], msymbol(circle_hollow) xline(1) ytitle("Estimated Percent Change in Average Speed") xtitle("Ratio of Average Daily Speed to Speed Limit") yla(,nogrid)
graph export "`work'/Graphs/Speed_`year'_Congestion2.pdf", replace


restore

}
