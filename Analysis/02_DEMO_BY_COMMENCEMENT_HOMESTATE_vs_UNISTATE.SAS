* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_ENR_COU_ALL data from Preprocessing steps, and summarises data by demographics for commencements;
* Cross-tabulating data with Home_state (residential) and Uni_state (uni) to explore the data, and by citizenship;

* This is done at National level and each state level, and breaks down into different field of education (dFOE);
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* COMMENCEMENT data;

************** UNI_STATE vs HOME_STATE ************************************;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;

%let CLASS = CLASS_YR; %let YR = SS_YR;

%let file = START; * Commencement;

* setting save directory;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\;
libname newdir "&savedir";

%let savedir = &savedir\&file\;
libname newdir "&savedir";
libname newdir clear;

*loading data;
DATA COMBINE_FINAL(KEEP= HOME_STATE UNI_STATE G_LEVEL &CLASS &YR COUNT AGE ATAR);
set aitsl.CS_ENR_COU_ALL_&d_type;
COUNT=1;
run;

* subsetting data here;
**********************************************************************************;
***** COMMENCEMENT **************;
data ALL UG PG EC PRI SEC MIX EO EC_UG PRI_UG SEC_UG MIX_UG EO_UG EC_PG PRI_PG SEC_PG MIX_PG EO_PG;
set COMBINE_FINAL;
if &YR ne .;
output ALL;
if G_LEVEL = 'UG' then output UG;
if G_LEVEL = 'PG' then output PG;

if &CLASS = 'EC' then output EC;
if &CLASS = 'PRI' then output PRI;
if &CLASS = 'SEC' then output SEC;
if &CLASS = 'MIX' then output MIX;
if &CLASS = 'EO' then output EO;

if G_LEVEL = 'UG' and &CLASS = 'EC' then output EC_UG;
if G_LEVEL = 'UG' and &CLASS = 'PRI' then output PRI_UG;
if G_LEVEL = 'UG' and &CLASS = 'SEC' then output SEC_UG;
if G_LEVEL = 'UG' and &CLASS = 'MIX' then output MIX_UG;
if G_LEVEL = 'UG' and &CLASS = 'EO' then output EO_UG;

if G_LEVEL = 'PG' and &CLASS = 'EC' then output EC_PG;
if G_LEVEL = 'PG' and &CLASS = 'PRI' then output PRI_PG;
if G_LEVEL = 'PG' and &CLASS = 'SEC' then output SEC_PG;
if G_LEVEL = 'PG' and &CLASS = 'MIX' then output MIX_PG;
if G_LEVEL = 'PG' and &CLASS = 'EO' then output EO_PG;
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




* getting demographics here;
%let datas = ALL UG PG EC PRI SEC MIX EO EC_UG PRI_UG SEC_UG MIX_UG EO_UG EC_PG PRI_PG SEC_PG MIX_PG EO_PG;

%macro OVERALL;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);


proc sort data=&data out=DATA_A; by &YR home_state uni_state; run;
proc summary data=DATA_A nway missing;
by &YR home_state uni_state;
VAR age;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
VAR ATAR;
output out=DATA_C(drop=_type_ AGE rename=(_freq_=FREQ)) Median=;
run;

data DATA_D;
merge DATA_B DATA_C;
by &YR home_state uni_state;
run;

proc sql noprint;
create table U_VARS_2 as
select distinct home_state, uni_state
from COMBINE_FINAL
quit;

proc sql;
create table U_VARS as select U_VARS_1A.&YR, U_VARS_2.home_state, U_VARS_2.uni_state
from U_VARS_1A, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR; run;
data standardise;
merge U_VARS(in=in1) DATA_D(in=in2);
by &YR home_state uni_state; 
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
by &YR Home_STATE;
var FREQ age ATAR;
id UNI_STATE;
run;

data DATA_E;
retain vACT vNSW vNT vQLD vSA vTAS vVIC vWA vMUL;
set DATA_E;
run;


data formatting;
retain VARS &YR home_state   ;
set DATA_E;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'ATAR' then VAR_Ord = 3;

if home_state = 'ACT' then HS_ORD=1;
if home_state = 'NSW' then HS_ORD=2;
if home_state = 'NT' then HS_ORD=3;
if home_state = 'QLD' then HS_ORD=4;
if home_state = 'SA' then HS_ORD=5;
if home_state = 'TAS' then HS_ORD=6;
if home_state = 'VIC' then HS_ORD=7;
if home_state = 'WA' then HS_ORD=8;
if home_state = 'NULL' then HS_ORD=9;

run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord HS_ORD); 
by VAR_Ord &YR HS_ORD ;
run;

%let savename = HOME_UNI_&file..xlsx;
libname HU XLSX "&savedir&savename";
data HU.&data;
set FINAL_DATA;
run;

%end;
%mend;
%overall;


libname HU clear;









* Looking at the data by citizenship;
****************************************************************************************************************************;
*** Multi By CTZN ***;

%let demo = CTZN;

*loading data;
DATA COMBINE_FINAL(KEEP= HOME_STATE G_LEVEL &CLASS &YR &demo COUNT AGE ATAR);
set aitsl.CS_ENR_COU_ALL_&d_type;
COUNT=1;
if UNI_STATE = 'MUL';
run;

* subsetting data again;
**********************************************************************************;
***** COMMENCEMENT **************;
data ALL UG PG EC PRI SEC MIX EO EC_UG PRI_UG SEC_UG MIX_UG EO_UG EC_PG PRI_PG SEC_PG MIX_PG EO_PG;
set COMBINE_FINAL;
if &YR ne .;
output ALL;
if G_LEVEL = 'UG' then output UG;
if G_LEVEL = 'PG' then output PG;

if &CLASS = 'EC' then output EC;
if &CLASS = 'PRI' then output PRI;
if &CLASS = 'SEC' then output SEC;
if &CLASS = 'MIX' then output MIX;
if &CLASS = 'EO' then output EO;

if G_LEVEL = 'UG' and &CLASS = 'EC' then output EC_UG;
if G_LEVEL = 'UG' and &CLASS = 'PRI' then output PRI_UG;
if G_LEVEL = 'UG' and &CLASS = 'SEC' then output SEC_UG;
if G_LEVEL = 'UG' and &CLASS = 'MIX' then output MIX_UG;
if G_LEVEL = 'UG' and &CLASS = 'EO' then output EO_UG;

if G_LEVEL = 'PG' and &CLASS = 'EC' then output EC_PG;
if G_LEVEL = 'PG' and &CLASS = 'PRI' then output PRI_PG;
if G_LEVEL = 'PG' and &CLASS = 'SEC' then output SEC_PG;
if G_LEVEL = 'PG' and &CLASS = 'MIX' then output MIX_PG;
if G_LEVEL = 'PG' and &CLASS = 'EO' then output EO_PG;
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
select distinct &YR, &demo
from COMBINE_FINAL
where &YR ne .;
quit;



* getting demographics;
%let datas = ALL UG PG EC PRI SEC MIX EO EC_UG PRI_UG SEC_UG MIX_UG EO_UG EC_PG PRI_PG SEC_PG MIX_PG EO_PG;

%macro OVERALL;
	%do i=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&i);


proc sort data=&data out=DATA_A; by &YR home_state &demo; run;
proc summary data=DATA_A nway missing;
by &YR home_state &demo;
VAR age;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) mean=;
VAR ATAR;
output out=DATA_C(drop=_type_ AGE rename=(_freq_=FREQ)) Median=;
run;

data DATA_D;
merge DATA_B DATA_C;
by &YR home_state &demo;
run;


proc sql noprint;
create table U_VARS_2 as
select distinct home_state
from COMBINE_FINAL
quit;

proc sql;
create table U_VARS as select U_VARS_1B.&YR,U_VARS_1B.&demo, U_VARS_2.home_state
from U_VARS_1B, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR home_state &demo; run;
data standardise;
merge U_VARS(in=in1) DATA_D(in=in2);
by &YR home_state &demo; 
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
by &YR Home_STATE;
var FREQ age ATAR;
id &demo;
run;


data formatting;
retain VARS &YR home_state   ;
set DATA_E;
if VARS = 'FREQ' then VAR_Ord = 1;
if VARS = 'AGE' then VAR_Ord = 2;
if VARS = 'ATAR' then VAR_Ord = 3;

if home_state = 'ACT' then HS_ORD=1;
if home_state = 'NSW' then HS_ORD=2;
if home_state = 'NT' then HS_ORD=3;
if home_state = 'QLD' then HS_ORD=4;
if home_state = 'SA' then HS_ORD=5;
if home_state = 'TAS' then HS_ORD=6;
if home_state = 'VIC' then HS_ORD=7;
if home_state = 'WA' then HS_ORD=8;
if home_state = 'NULL' then HS_ORD=9;

run;

Proc sort data=formatting out=FINAL_DATA(drop=VAR_Ord HS_ORD); 
by VAR_Ord &YR HS_ORD ;
run;

%let savename = HOME_MUL_CTZN_&file..xlsx;
libname HU XLSX "&savedir&savename";
data HU.&data;
set FINAL_DATA;
run;

%end;
%mend;
%overall;

libname HU clear;
****************************************************************************************************************************;

