* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
* This file loads HEIMS_QGOS data from Preprocessing steps, and summarises data by demographics;
* This is done at National level and each state level, and breaks down into different field of education (dFOE);
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* The output is for the demographics of individuals who completed QILT_GOS (graduate outcome survey);
* Zooming in those who completed in 2015 and 2016 to capture those who did the survey in 2016 and 2017;
* This is because of the linking between QILT data and HEIMS data;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;

%let THIS_STATE = UNI_STATE; ** CHANGE THIS FOR STATE -- HOME_STATE UNI_STATE EMP_STATE **;

%let CLASS = CLASS_COU; %let YR = QGOS; %let FTPT = FTPT_COU;  %let MODE = MODE_COU;
%let AGE = AGE;

* check this later;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\QGOS_vs_HEIMS\;
libname newdir "&savedir";
libname newdir clear;

* check this later;
options dlcreatedir;
%let savedir1 = &savedir\&THIS_STATE\;
libname newdir "&savedir1";
libname newdir clear;

* demographics to extract;
%let demos = COUNT G_LEVEL &CLASS GENDER SES DISAB CTZN ATSI METRO COU_TYPE &FTPT &MODE HOME_STATE UNI_STATE EMP_STATE SAME_STATE_HU SAME_STATE_HJ SAME_STATE_UJ FYS_COU LYC_COU
CRSPREP FINDJOB GADAPT GCOLLAB GFOUND LFCLASS QUALIMP SECTOR CEQ_GSS_A CEQ_GTS_A CEQ_OSI_A SAL_MOD CATEGORY;

*loading data;
DATA COMBINE_FINAL(KEEP= &demos &YR &AGE DUR SALARY);
set AITSL.CS_HEIMS_QGOS_&d_type;
COUNT=1;
DUR=COMP_DUR_COU;
if LYC_COU in (2015,2016);
run;

** getting states;
proc sql noprint;
select distinct &THIS_STATE into: STATES separated by ' '
from COMBINE_FINAL;
quit;

*to not get empty/missing data under a column;
proc sql noprint;
create table U_VARS_1 as
select distinct &YR, &CLASS
from COMBINE_FINAL
where &YR ne .;
quit;

**********************************************************************************;
***** DATA **************;
data AUS_ALL AUS_UG AUS_PG;
set COMBINE_FINAL;
output AUS_ALL;
if G_LEVEL = 'UG' then output AUS_UG;
if G_LEVEL = 'PG' then output AUS_PG;
run;

*to not get empty/missing data under a column -- for OVERALL;
proc sql noprint;
create table U_VARS_1A as
select distinct &YR
from COMBINE_FINAL
where &YR ne .;
quit;

*to not get empty/missing data under a column -- for CLASS BREAKDOWN;
proc sql noprint;
create table U_VARS_1B as
select distinct &YR, &CLASS
from COMBINE_FINAL
where &YR ne .;
quit;


%macro STATE_DATAS;
%do i=1 %to %sysfunc(countw(&STATES));
%let STATE = %scan(&STATES,&i);

data &STATE._ALL; 
set AUS_ALL;
if &THIS_STATE = "&STATE" then output &STATE._ALL;
run;

data &STATE._UG; 
set AUS_UG;
if &THIS_STATE = "&STATE" then output &STATE._UG;
run;

data &STATE._PG; 
set AUS_PG;
if &THIS_STATE = "&STATE" then output &STATE._PG;
run;

%end;
%mend;
%STATE_DATAS;


proc sql noprint;
select distinct memname into: DATAS separated by ' '
from dictionary.columns
where libname = "WORK" and memname?'_ALL' or
libname = "WORK" and memname?'_UG' or
libname = "WORK" and memname?'_PG' ;
quit;

%macro OVERALL;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);

	%do j=1 %to %sysfunc(countw(&demos));
		%let demo = %scan(&demos,&j);

proc sort data=&data out=DATA_A; by &YR &demo; run;
proc summary data=DATA_A nway missing;
by &YR &demo;
VAR &AGE DUR SALARY;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
run;

******************************************************;
proc sql noprint;
create table U_VARS_2 as
select distinct &demo
from COMBINE_FINAL;
quit;

proc sql;
create table U_VARS as select U_VARS_1A.&YR, U_VARS_2.&demo 
from U_VARS_1A, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_B(in=in2);
by &YR &demo; 
if in1;
run;

data standardise;
retain &YR;
set standardise;
AGE=round(&AGE);
DUR=round(DUR,0.01);
SALARY = ROUND(SALARY);
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &YR; run;
proc transpose data=standardise out=DATA_C (rename=(_NAME_ = VARS)) prefix=v;
by &YR;
var FREQ AGE DUR SALARY;
id &demo;
run;

%if "&demo" = "&CLASS" %then %do;
data DATA_C;
retain vEC vPRI vSEC vMIX vEO;
set DATA_C;
run;
%end;

%if "&demo" = "G_LEVEL" %then %do;
data DATA_C;
retain vUG vPG;
set DATA_C;
run;
%end;

%if "&demo" = "HOME_STATE" %then %do;
data DATA_C;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vNULL;
set DATA_C;
run;
%end;

%if "&demo" = "UNI_STATE" %then %do;
data DATA_C;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vMUL;
set DATA_C;
run;
%end;

%if "&demo" = "EMP_STATE" %then %do;
data DATA_C;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vNA;
set DATA_C;
run;
%end;

%if "&demo" = "CATEGORY" %then %do;
data DATA_C;
retain vEC_SCH	vPRI_ED	vSEC_ED	vPRI_SEC vSCH_ED vSP_ED vTECH_VET vOTH_ED vOTH_EMP vNA;
set DATA_C;
run;
%end;

data formatting;
retain &YR VARS ;
set DATA_C;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'DUR' then VAR_Ord = 3;
if VARS = 'SALARY' then VAR_Ord = 4;
run;


Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord); 
by VAR_Ord &YR ;
run;

%let savename = OVERALL_&data..xlsx;
libname OVERALL XLSX "&savedir1&savename";
data OVERALL.&demo;
set FINAL_DATA;
run;
%end;

%end;
%mend;
%OVERALL;

libname OVERALL clear;

proc datasets lib=work nolist;
delete DATA_A DATA_B DATA_C FORMATTING U_VARS_2 U_VARS;
quit;



%let demos_2 = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&demos)),%str(&CLASS), %str()))));



%macro dFOE;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);

	%do j=1 %to %sysfunc(countw(&demos_2));
		%let demo = %scan(&demos_2,&j);

proc sort data=&data out=DATA_A; by &CLASS &YR &demo; run;
proc summary data=DATA_A nway missing;
by &CLASS &YR &demo;
VAR &AGE DUR SALARY;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
run;

******************************************************;
proc sql noprint;
create table U_VARS_2 as
select distinct &demo
from COMBINE_FINAL
quit;

proc sql;
create table U_VARS as select U_VARS_1B.&YR, U_VARS_1B.&CLASS, U_VARS_2.&demo 
from U_VARS_1B, U_VARS_2;
quit;

proc sort data=U_VARS; by  &CLASS &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_B(in=in2);
by  &CLASS &YR &demo; 
if in1;
run;

data standardise;
retain &YR;
set standardise;
AGE=round(&AGE);
DUR=round(DUR,0.01);
SALARY=round(SALARY);
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &CLASS &YR; run;
proc transpose data=standardise out=DATA_C (rename=(_NAME_ = VARS)) prefix=v;
by &CLASS &YR;
var FREQ AGE DUR SALARY;
id &demo;
run;


%if "&demo" = "G_LEVEL" %then %do;
data DATA_C;
retain vUG vPG;
set DATA_C;
run;
%end;

%if "&demo" = "HOME_STATE" %then %do;
data DATA_C;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vNULL;
set DATA_C;
run;
%end;

%if "&demo" = "UNI_STATE" %then %do;
data DATA_C;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vMUL;
set DATA_C;
run;
%end;

%if "&demo" = "EMP_STATE" %then %do;
data DATA_C;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vNA;
set DATA_C;
run;
%end;

	
data formatting;
retain VARS &YR   &CLASS  ;
set DATA_C;
if &CLASS = 'EC' then Group_Ord = 1;
if &CLASS = 'PRI' then Group_Ord = 2;
if &CLASS = 'SEC' then Group_Ord = 3;
if &CLASS = 'MIX' then Group_Ord = 4;
if &CLASS = 'EO' then Group_Ord = 5;

if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'DUR' then VAR_Ord = 3;
if VARS = 'SALARY' then VAR_Ord = 4;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord group_ord); 
by VAR_Ord &YR  Group_Ord &YR;
run;

%let savename = dFOE_&data..xlsx;
libname dFOE XLSX "&savedir1&savename";
data dFOE.&demo;
set FINAL_DATA;
run;

%end;

* deleting workspace;
proc datasets lib=work nolist;
delete &data;
quit;


%end;
%mend;
%dFOE;

libname dFOE clear;

proc datasets lib=work nolist;
delete DATA_A DATA_B DATA_C FORMATTING U_VARS_2 U_VARS;
quit;
**********************************************************************************;

