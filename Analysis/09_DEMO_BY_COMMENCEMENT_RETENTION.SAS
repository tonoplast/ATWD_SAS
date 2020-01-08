* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_ENR_COU_ALL data from Preprocessing steps, and summarises data by demographics;
* This is done at National level and each state level, and breaks down into different field of education (dFOE);
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* The output is for the demographics of individuals who were retained in a course after 1 year;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


**************************************************************************************************;
******************************* THINGS ARE MODIFED FOR OVERALLS **********************************;
**************************************************************************************************;
%let startyear = 2005;
%let thisyear = 2017;
%let ext_year = 2017;
%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;


%let CLASS = CLASS_YR; %let YR = FYS_COU; %let FTPT = FTPT_YR;  %let MODE = MODE_YR;

%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\RETENTION\;
options dlcreatedir;
libname newdir "&savedir";
libname newdir clear;

* demographics to extract;
%let DEMOS=;
%let DEMOS = GENDER SES DISAB CTZN ATSI METRO &FTPT &MODE ATAR_GRP ATAR_SIMPLE_COU ATAR_SEC BOA HIGHEST_ED HOME_STATE UNI_STATE SAME_STATE_HU UNI_TYPE MULTIPLE_COU COU;

* get max start year;
proc sql noprint;
select max(&YR) into :LastYear
from aitsl.CS_ENR_COU_ALL_&d_type;
quit;

* note that I am doing first_index_COU because I want DEMOGRAPHICS of the start year, not end;
data COMBINE(keep= &demos AGE e306 UNI_TYPE rec_e313 COU COU_TYPE &YR &CLASS LYC_COU LYD_COU first_index_COU ATAR UG);
set aitsl.CS_ENR_COU_ALL_&d_type;
by e306 rec_e313 referenceyear;

* getting data that has START;
* doing this by course (first_index_COU);
* all UG;
* getting rid of last year of the record because there is no retention data for the latest year;
if &YR ne . and first_index_COU = 1 and G_LEVEL = 'UG' and &YR ne &LastYear ;
UG=1;
run;

*to not get empty/missing data under a column;
proc sql noprint;
create table U_VARS_1A as
select distinct &YR
from COMBINE;
quit;


data LOGICS(drop= e306 rec_e313 LYD_COU LYC_COU last_index_cou e306_type first_index_COU);
set COMBINE;

* getting only Regular Bachelor; 
* Start must not be Completed;
if cou_type='BPASS' and &YR ne LYC_COU then BPASS=1; *not same completion as start;
if BPASS=1 and &YR ne LYD_COU then RETAINED=1; *getting those that dropped on the year they commenced;
run;


DATA UG BPASS RETAINED;
set LOGICS;
if UG=1 then output UG;
if BPASS=1 then output BPASS;
if RETAINED=1 then output RETAINED;
drop UG BPASS RETAINED;
run;

************************************************************************************************************;

* getting UG BPASS and RETAINED to compare among these datasets;
%macro overall;
%LET DATAS = UG BPASS RETAINED;

%do i=1 %to %sysfunc(countw(&DATAS));
%let DATA = %scan(&DATAS,&i);

%let savedir1 = &savedir\&DATA\;
options dlcreatedir;
libname newdir "&savedir1";


%let LVLS = ALL EC PRI SEC MIX EO;

data &LVLS;
set &DATA;
OUTPUT ALL;

if &CLASS ='EC' then output EC;
if &CLASS ='PRI' then output PRI;
if &CLASS ='SEC' then output SEC;
if &CLASS ='MIX' then output MIX;
if &CLASS ='EO' then output EO;

run;

%do j=1 %to %sysfunc(countw(&LVLS));
%let LVL = %scan(&LVLS,&j);

proc sort data=&LVL out=OVERALL_A; by &YR; run;
proc summary data=OVERALL_A nway missing;
by &YR;
VAR age;
output out=OVERALL_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
VAR ATAR;
output out=OVERALL_C(drop=_type_ AGE rename=(_freq_=FREQ)) Median=;
run;

data OVERALL_D;
merge OVERALL_B OVERALL_C;
by &YR;
run;

proc sort data=U_VARS_1A; by &YR; run;
data standardise;
merge U_VARS_1A(in=in1) OVERALL_D(in=in2);
by &YR; 
if in1;
run;

data standardise;
set standardise;
age=round(age);
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

%let savename = &DATA._&LVL..xlsx;
libname RET XLSX "&savedir1&savename";
data RET.OVERALL;
set standardise;
run;


%do k=1 %to %sysfunc(countw(&DEMOS));
%let DEMO = %scan(&DEMOS,&k);

proc sort data=&LVL out=DATA_A; by &YR &demo; run;
proc summary data=DATA_A nway missing;
by &YR &demo;
VAR age;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
VAR ATAR;
output out=DATA_C(drop=_type_ AGE rename=(_freq_=FREQ)) Median=;
run;

data DATA_D;
merge DATA_B DATA_C;
by &YR &demo;
run;

******************************************************;
proc sql noprint;
create table U_VARS_2 as
select distinct &demo
from COMBINE;
quit;

proc sql;
create table U_VARS as select U_VARS_1A.&YR, U_VARS_2.&demo 
from U_VARS_1A, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_D(in=in2);
by &YR &demo; 
if in1;
run;

data standardise;
set standardise;
age=round(age);
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &YR; run;
proc transpose data=standardise out=DATA_E (rename=(_NAME_ = VARS)) prefix=v;
by &YR ;
var FREQ age ATAR;
id &demo ;
run;


%if "&demo" = "HOME_STATE" %then %do;
data DATA_E;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vNULL;
set DATA_E;
run;
%end;

%if "&demo" = "UNI_STATE" %then %do;
data DATA_E;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vMUL;
set DATA_E;
run;
%end;

data formatting;
retain VARS &YR  ;
set DATA_E;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'ATAR' then VAR_Ord = 3;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord); 
by VAR_Ord &YR;
run;



%let savename = &DATA._&LVL..xlsx;
libname RET XLSX "&savedir1&savename";
data RET.&demo;
set FINAL_DATA;
run;

%end;
%end;
%end;
%mend;
%overall;

libname RET clear;
