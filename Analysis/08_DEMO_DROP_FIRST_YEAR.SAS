* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_ENR_COU_ALL data from Preprocessing steps, and summarises data by demographics;
* This is done at National level and each state level, and breaks down into different field of education (dFOE);
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* The output is for the demographics of individuals who dropped out of a course after 1 year, by commencement year;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


**************************************************************************************************;
******************************* THINGS ARE MODIFED FOR OVERALLS **********************************;
**************************************************************************************************;

%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;

%let THIS_STATE = HOME_STATE; ** CHANGE THIS FOR STATE -- HOME_STATE UNI_STATE **;

%let TYPE = UNI_TYPE; ** this is for further Provider Type breakdown;

%let CLASS = CLASS_YR; %let YR = FYS_COU; %let FTPT = FTPT_YR;  %let MODE = MODE_YR;

* Saving directory;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\NCB\;
options dlcreatedir;
libname newdir "&savedir";

%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\NCB\&THIS_STATE\;
libname newdir "&savedir";

%let savedir1 = &savedir\OVERALL\;
libname newdir "&savedir1";

%let savedir2 = &savedir\TYPE\;
libname newdir "&savedir2";
libname newdir clear;

* demographics to extract;
%let demos = COUNT G_LEVEL &CLASS GENDER SES DISAB CTZN ATSI METRO COU_TYPE &FTPT &MODE ATAR_GRP ATAR_SEC BOA HIGHEST_ED HOME_STATE UNI_STATE SAME_STATE_HU UNI_TYPE MULTIPLE_COU COU;

* note that I am doing first_index_COU because I want DEMOGRAPHICS of the start year, not end;
data COMBINE(keep= &demos AGE e306 UNI_TYPE rec_e313 COU &YR LYC_COU LYD_COU first_index_COU single_entry COUNT);
set aitsl.CS_ENR_COU_ALL_&d_type;
by e306 rec_e313 referenceyear;
if first.rec_e313 and last.rec_e313 then single_entry = 1;
COUNT=1;
run;

***********************************************************************************************;
* get max start year;
proc sql noprint;
select max(&YR) into :LastYear
from COMBINE;
quit;

** getting states;
proc sql noprint;
select distinct &THIS_STATE into: STATES separated by ' '
from COMBINE;
quit;

* removing data that is latest year & giving a flag for someone who dropped out on the same year;
data DROPPED(drop= e306 rec_e313 LYD_COU last_index_cou e306_type single_entry LYC_COU first_index_COU);
set COMBINE;

if &YR ne &LastYear; * getting rid of last year of the record because there is no never came back data for the latest year;
if first_index_COU = 1; * doing this by course;

if &YR ne . then START=1; * getting all starts;
if START=1;
if &YR = LYD_COU then DROPPED=1; *getting those that dropped on the year they commenced;
if single_entry and DROPPED then NCB=1;
run;


********************************************** For Standardised output *****************************************;
*to not get empty/missing data under a column;

proc sql noprint;
create table U_START as
select distinct &YR
from DROPPED
where &YR ne .;
quit;

proc sql noprint;
create table U_START_CLASS as
select distinct &YR, &CLASS
from DROPPED
where &YR ne .;
quit;

*** For unique START, CLASS and TYPE ***;
proc sql noprint;
create table U_TYPE as
select distinct UNI_TYPE
from DROPPED;
quit;

proc sql;
create table U_SC_TYPE as select U_START_CLASS.&YR, U_START_CLASS.&CLASS, U_TYPE.UNI_TYPE
from U_START_CLASS, U_TYPE;
quit;

proc sort data=U_SC_TYPE; by UNI_TYPE &CLASS &YR; run;
*********************************************************************************************************************;


************************************************************************************************************;
***** COMBINED DATA **************;
data AUS_ALL AUS_UG AUS_PG;
set DROPPED;
output AUS_ALL;
if G_LEVEL = 'UG' then output AUS_UG;
if G_LEVEL = 'PG' then output AUS_PG;
run;

* making state breakdown data;
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


%macro overall;
%do i=1 %to %sysfunc(countw(&DATAS));
%let data = %scan(&DATAS,&i);

proc sort data= &data out=OUT_DATA; by &YR;
proc summary data=OUT_DATA nway missing;
class &YR &CLASS;
var DROPPED NCB START;
output out=DROPPED_A(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_START_CLASS(in=in1) DROPPED_A(in=in2);
by &YR &CLASS;
if in1;
run;

data standardise;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &YR;
proc transpose data=standardise out=DROPPED_B (rename=(_NAME_ = VARS));
by &YR ;
var DROPPED NCB START;
id &CLASS;
run;

proc sort data=DROPPED_B; by VARS &YR; run;
data DROPPED_B;
retain VARS &YR EC PRI SEC MIX EO;
set DROPPED_B;
run;

DATA FINAL_DATA;
set DROPPED_B;
TOTAL = sum(of &lvls);
run;

%let savename1 = COMBINE.XLSX;
libname COMBINE XLSX "&savedir1&savename1";

data COMBINE.&data;
set FINAL_DATA;
run;
%end;
%mend;
%overall;

libname COMBINE clear;


%macro UNI_TYPE;
%do i=1 %to %sysfunc(countw(&DATAS));
%let data = %scan(&DATAS,&i);

proc sort data= &data out=OUT_DATA; by &YR ;
proc summary data=OUT_DATA nway missing;
class UNI_TYPE &CLASS &YR;
var DROPPED NCB START;
output out=DROPPED_A(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_SC_TYPE(in=in1) DROPPED_A(in=in2);
by UNI_TYPE &CLASS &YR;
if in1;
run;

data standardise;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &YR;
proc transpose data=standardise out=DROPPED_B (rename=(_NAME_ = VARS));
by &YR UNI_TYPE;
var DROPPED NCB START;
id &CLASS;
run;

proc sort data=DROPPED_B; by VARS UNI_TYPE &YR; run;

data DROPPED_B;
retain VARS &YR UNI_TYPE EC PRI SEC MIX EO;
set DROPPED_B;
run;

DATA FINAL_DATA;
set DROPPED_B;
TOTAL = sum(of &lvls);
run;

%let savename2 = TYPE.XLSX;
libname TYPE XLSX "&savedir2&savename2";

data TYPE.&data;
set FINAL_DATA;
run;
%end;
%mend;
%UNI_TYPE;

libname TYPE clear;



****************************************************************************************************************************************;
***************************************************************** DEMO *****************************************************************;
****************************************************************************************************************************************;

%let PICKS = START DROPPED NCB;

%macro OVERALL;

%do i = 1 %to %sysfunc(countw(&datas));
	%let data = %scan(&datas,&i);

	%do j=1 %to %sysfunc(countw(&PICKS));
		%let PICK = %scan(&PICKS,&j);

		data PICKED;
		set &data;
		if &PICK = 1;
		run;

	%do k=1 %to %sysfunc(countw(&demos));
		%let demo = %scan(&demos,&k);

proc sort data=PICKED out=DATA_A; by &YR &demo; run;
proc summary data=DATA_A nway missing;
by &YR &demo;
VAR age;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
run;

******************************************************;
proc sql noprint;
create table U_VARS_2 as
select distinct &demo
from DROPPED
quit;

proc sql;
create table U_VARS as select U_START.&YR, U_VARS_2.&demo 
from U_START, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_B(in=in2);
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
proc transpose data=standardise out=DATA_C (rename=(_NAME_ = VARS)) prefix=v;
by &YR;
var FREQ age;
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

data formatting;
retain VARS &YR;
set DATA_C;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord); 
by VAR_Ord &YR;
run;

%let savedir1_1 = &savedir1\&PICK\;
options dlcreatedir;
libname newdir "&savedir1_1";
libname newdir clear;

%let savename = OVERALL_&data._&PICK..xlsx;
libname DEMO XLSX "&savedir1_1&savename";
data DEMO.&demo;
set FINAL_DATA;
run;
%end;

%end;
%end;
%mend;
%OVERALL;

libname DEMO clear;



%let demos_2 = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&demos)),%str(&CLASS), %str()))));

%macro dFOE;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);

		%do j=1 %to %sysfunc(countw(&PICKS));
		%let PICK = %scan(&PICKS,&j);

		data PICKED;
		set &data;
		if &PICK = 1;
		run;

	%do k=1 %to %sysfunc(countw(&demos_2));
		%let demo = %scan(&demos_2,&k);

proc sort data=PICKED out=DATA_A; by &CLASS &YR &demo; run;
proc summary data=DATA_A nway missing;
by &CLASS &YR &demo;
VAR age;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
run;

******************************************************;
proc sql noprint;
create table U_VARS_2 as
select distinct &demo
from DROPPED;
quit;

proc sql;
create table U_VARS as select U_START_CLASS.&YR, U_START_CLASS.&CLASS, U_VARS_2.&demo 
from U_START_CLASS, U_VARS_2;
quit;

proc sort data=U_VARS; by &CLASS &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_B(in=in2);
by  &CLASS &YR &demo; 
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

proc sort data=standardise; by &CLASS &YR; run;
proc transpose data=standardise out=DATA_C (rename=(_NAME_ = VARS)) prefix=v;
by &CLASS &YR;
var FREQ age;
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
	
data formatting;
retain VARS &CLASS &YR;
set DATA_C;
if &CLASS = 'EC' then Group_Ord = 1;
if &CLASS = 'PRI' then Group_Ord = 2;
if &CLASS = 'SEC' then Group_Ord = 3;
if &CLASS = 'MIX' then Group_Ord = 4;
if &CLASS = 'EO' then Group_Ord = 5;

if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'DUR' then VAR_Ord = 3;
run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord group_ord); 
by VAR_Ord Group_Ord &YR;
run;


%let savedir1_1 = &savedir1\&PICK\;
options dlcreatedir;
libname newdir "&savedir1_1";
libname newdir clear;

%let savename = dFOE_&data._&PICK..xlsx;
libname dFOE XLSX "&savedir1_1&savename";
data dFOE.&demo;
set FINAL_DATA;
run;

%end;
%end;

* deleting workspace;
proc datasets lib=work nolist;
delete &data;
quit;


%end;
%mend;
%dFOE;

libname dFOE clear;
