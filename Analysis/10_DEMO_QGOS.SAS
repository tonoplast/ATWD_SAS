* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads HEIMS_QGOS data from Preprocessing steps, and summarises data by demographics;
* This is done at National level and each state level, and breaks down into different field of education (dFOE);
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* The output is for the demographics of individuals who completed QILT_GOS (graduate outcome survey) from QILT perspective;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let startyear = 2005;
%let thisyear = 2017;
%let ext_year = 2017;
%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;

%let THIS_STATE = HOME_STATE; ** CHANGE THIS FOR STATE -- HOME_STATE UNI_STATE EMP_STATE **;

%let CLASS = CLASS_COU; %let YR = QGOS_YEAR; %let FTPT = FTPT_COU;  %let MODE = MODE_COU;
%let AGE = QGOS_AGE;

* check this later;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\QGOS\;
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
if QGOS=1;
run;


** getting states;
proc sql noprint;
select distinct &THIS_STATE into: STATES separated by ' '
from COMBINE_FINAL;
quit;
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

*to not get empty/missing data under a column;
**********************************************************************************;
***** DATA **************;
data AUS_ALL AUS_UG AUS_PG;
set COMBINE_FINAL;
output AUS_ALL;
if G_LEVEL = 'UG' then output AUS_UG;
if G_LEVEL = 'PG' then output AUS_PG;
run;




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

* overall data;
%macro OVERALL;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);

	%do j=1 %to %sysfunc(countw(&demos));
		%let demo = %scan(&demos,&j);

proc sort data=&data out=DATA_A; by &YR SECTOR ; run;
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
drop &AGE;
run;

proc sort data=standardise; by &YR; run;
proc transpose data=standardise out=DATA_C (rename=(_NAME_ = VARS)) prefix=v;
by &YR;
var FREQ AGE DUR SALARY;
id &demo  ;
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
retain VARS &YR;
set DATA_C;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'DUR' then VAR_Ord = 3;
if VARS = 'SALARY' then VAR_Ord = 4;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord); 
by VAR_Ord &YR;
run;

%let savename = OVERALL_&data..xlsx;
libname OVERALL XLSX "&savedir1&savename";
data OVERALL.&demo;
set FINAL_DATA;
run;
%end;
%end;
%end;
%mend;
%OVERALL;

libname OVERALL clear;

proc datasets lib=work nolist;
delete DATA_A DATA_B DATA_C FORMATTING U_VARS_2 U_VARS;
quit;


* dFOE data;
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
drop &AGE;
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
retain VARS &YR &CLASS ;
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
by VAR_Ord Group_Ord &YR;
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




*************************************************************************************;
*** doing more cross tabs here *** ; 
%let DATAS = ALL UG PG EC PRI SEC MIX EO;
%let Cross_Tabs = CRSPREP LFCLASS QUALIMP GENDER SAME_STATE_HU SAME_STATE_HJ SAME_STATE_UJ;
**********************************************************************************;
DATA COMBINE_SMALL(keep= G_LEVEL CLASS_COU CATEGORY &Cross_Tabs &AGE SALARY &YR );
set COMBINE_FINAL;
run;

***** DATA **************;
data &DATAS;
set COMBINE_SMALL;
output ALL;
if G_LEVEL = 'UG' then output UG;
if G_LEVEL = 'PG' then output PG;
if CLASS_COU = 'EC' then output EC;
if CLASS_COU = 'PRI' then output PRI;
if CLASS_COU = 'SEC' then output SEC;
if CLASS_COU = 'MIX' then output MIX;
if CLASS_COU = 'EO' then output EO;
run;


%macro XTAB;
	%do m=1 %to %sysfunc(countw(&DATAS));
		%let DATA = %scan(&DATAS,&m);

	%do k=1 %to %sysfunc(countw(&Cross_Tabs));
		%let Cross_Tab = %scan(&Cross_Tabs,&k);


proc sort data=&data out=DATA_A; by &YR CATEGORY &Cross_Tab; run;
proc summary data=DATA_A nway missing;
by &YR CATEGORY &Cross_Tab;
VAR &AGE SALARY;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
run;

proc sql noprint;
create table U_VARS_2 as
select distinct CATEGORY, &Cross_Tab
from COMBINE_FINAL;
quit;

proc sql;
create table U_VARS as select U_VARS_1A.&YR, U_VARS_2.CATEGORY, U_VARS_2.&Cross_Tab
from U_VARS_1A, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_B(in=in2);
by &YR CATEGORY &Cross_Tab; 
if in1;
run;

data standardise;
set standardise;
AGE=round(&AGE);
SALARY = ROUND(SALARY);
array change _numeric_;
do over change;
if change=. then change=0;
end;
drop &AGE;
run;

proc sort data=standardise; by &YR &Cross_Tab; run;
proc transpose data=standardise out=DATA_C (rename=(_NAME_ = VARS)) prefix=v;
by &YR  &Cross_Tab ;
var FREQ AGE SALARY;
id  CATEGORY ;
run;

data DATA_C;
retain vEC_SCH vPRI_ED	vSEC_ED	vPRI_SEC vSCH_ED vSP_ED vTECH_VET vOTH_ED vOTH_EMP vNA;
set DATA_C;
run;

data formatting;
retain VARS &YR &Cross_Tab;
set DATA_C;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'SALARY' then VAR_Ord = 3;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord); 
by VAR_Ord &YR;
run;

data FINAL_DATA;
set FINAL_DATA;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;


%let savename = CATEGORY_&data..xlsx;
libname CATEGORY XLSX "&savedir&savename";
data CATEGORY.&Cross_Tab;
set FINAL_DATA;
run;
%end;
%end;
%mend;
%XTAB;

libname CATEGORY clear;
