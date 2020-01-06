* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_ENR_COU_ALL data from Preprocessing steps, and summarises data by demographics;
* This is done at National level and each state level, and breaks down into different field of education (dFOE);
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* COMMENCEMENT data;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO; * detailed FOE;

%let THIS_STATE = HOME_STATE; ** CHANGE THIS FOR STATE -- HOME_STATE UNI_STATE -- to look at state by residence or state by uni**;

%let CLASS = CLASS_YR; %let YR = SS_YR; %let FTPT = FTPT_YR; %let MODE = MODE_YR; * Summarising at YEAR level;

%let file = START; * looking at commencement;

* setting save directory;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\;
libname newdir "&savedir";

* setting save directory;
options dlcreatedir;
%let savedir = &savedir\&file\;
libname newdir "&savedir";

* setting save directory;
options dlcreatedir;
%let savedir1 = &savedir\&THIS_STATE\;
libname newdir "&savedir1";
libname newdir clear;

* demographics to extract;
%let demos = COUNT G_LEVEL &CLASS GENDER SES DISAB CTZN ATSI METRO COU_TYPE &FTPT &MODE ATAR_SIMPLE_COU ATAR_SEC_COU BOA_COU HIGHEST_ED_COU HOME_STATE UNI_STATE SAME_STATE_HU;

*loading data;
DATA COMBINE_FINAL(KEEP= &demos &YR COUNT AGE ATAR);
set aitsl.CS_ENR_COU_ALL_&d_type;
COUNT=1;
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
***** COMMENCEMENT **************;
data AUS_ALL AUS_UG AUS_PG;
set COMBINE_FINAL;
if &YR ne .;
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


* subsetting data into different states and Undergrad/postgrad;
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



* looping over data, counting by year and demographics, mean age and median ATAR;
%macro OVERALL;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);

	%do j=1 %to %sysfunc(countw(&demos));
		%let demo = %scan(&demos,&j);

proc sort data=&data out=DATA_A; by &YR &demo; run;
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
from COMBINE_FINAL
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
retain &YR;
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

%if "&demo" = "&CLASS" %then %do;
data DATA_E;
retain vEC vPRI vSEC vMIX vEO;
set DATA_E;
run;
%end;

%if "&demo" = "G_LEVEL" %then %do;
data DATA_E;
retain vUG vPG;
set DATA_E;
run;
%end;

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

%let savename = OVERALL_&data._&file..xlsx;
libname &file XLSX "&savedir1&savename";
data &file..&demo;
set FINAL_DATA;
run;
%end;

%end;
%mend;
%OVERALL;

libname &file clear;

proc datasets lib=work nolist;
delete DATA_A DATA_B DATA_C DATA_D DATA_E FORMATTING U_VARS_2 U_VARS;
quit;




%let demos_2 = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&demos)),%str(&CLASS), %str()))));

* doing the count for dFOE;
%macro dFOE;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);

	%do j=1 %to %sysfunc(countw(&demos_2));
		%let demo = %scan(&demos_2,&j);

proc sort data=&data out=DATA_A; by &CLASS &YR &demo; run;
proc summary data=DATA_A nway missing;
by &CLASS &YR &demo;
VAR age;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
VAR ATAR;
output out=DATA_C(drop=_type_ AGE rename=(_freq_=FREQ)) Median=;
run;

data DATA_D;
merge DATA_B DATA_C;
by &CLASS &YR &demo;
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

proc sort data=U_VARS; by &CLASS &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_D(in=in2);
by &CLASS &YR &demo; 
if in1;
run;

data standardise;
retain &YR;
set standardise;
age=round(age);
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &CLASS &YR; run;
proc transpose data=standardise out=DATA_E (rename=(_NAME_ = VARS)) prefix=v;
by &CLASS &YR ;
var FREQ age ATAR;
id &demo ;
run;

%if "&demo" = "G_LEVEL" %then %do;
data DATA_E;
retain vUG vPG;
set DATA_E;
run;
%end;

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
retain VARS &CLASS &YR  ;
set DATA_E;
if &CLASS = 'EC' then Group_Ord = 1;
if &CLASS = 'PRI' then Group_Ord = 2;
if &CLASS = 'SEC' then Group_Ord = 3;
if &CLASS = 'MIX' then Group_Ord = 4;
if &CLASS = 'EO' then Group_Ord = 5;

if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'ATAR' then VAR_Ord = 3;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord group_ord); 
by VAR_Ord Group_Ord &YR;
run;

%let savename = dFOE_&data._&file..xlsx;
libname &file XLSX "&savedir1&savename";
data &file..&demo;
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

libname &file clear;

proc datasets lib=work nolist;
delete DATA_A DATA_B DATA_C DATA_D DATA_E FORMATTING U_VARS_2 U_VARS;
quit;
