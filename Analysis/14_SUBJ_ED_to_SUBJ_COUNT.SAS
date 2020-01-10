* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads HE_LOAD_PRGC data from Preprocessing steps, and looks at the difference between recoded and not recoded data;
* This is to see how many has become 'more known' through re-coding -- Education Other -> Particular Subject Curriculum;
* Focuses on 2017 Secondary ITE only;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_LOAD_PRGC; * Change this accordingly;
%let d_type = M_vs_A;
* ===================================================;
%let PRG_LVL = PRG_D_DES; * change middle character(s), D = detailed, T = Toni, AC = All Curriculum;
%let lvl_of_detail = %sysfunc(scan(&PRG_LVL,2,"_"));

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type._&lvl_of_detail;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */


* check this later;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\SUBJECTS\;
libname newdir "&savedir";

%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\SUBJECTS\RECODING\;
libname newdir "&savedir";
libname newdir clear;



** USING REPLACED for What we want -- HERE we use REPLACED_SUBJ because it'll be based on SUBJ rather than code replaced;
data temp_ENR temp_START temp_COMP;
set &indata;
REF_YR = input(referenceyear,4.);
REPLACED = REPLACED_SUBJ; ** IF needed, change this accordingly;
output temp_ENR;
if FYS_COU = REF_YR and FYS_COU ne . then output temp_START; *START data for that year;
if LYC_COU = REF_YR and LYC_COU ne . then output temp_COMP; *COMP data for that year;
run;


%let TEMPS = temp_ENR temp_START temp_COMP;

** 2017 SEC ONLY ***;

%let YRS = REF_YR FYS_COU LYC_COU;
%let SAVE_YRS = ENR START COMP;

%MACRO SUBJ_RECODE;

%do j=1 %to %sysfunc(countw(&YRS));
%let YR = %scan(&YRS,&j);
%let SAVE_YR = %scan(&SAVE_YRS,&j);
%let TEMP = %scan(&TEMPS,&j);

data ALL UG PG SEC_ALL SEC_UG SEC_PG;
set &TEMP;
if &YR = 2017 then output ALL;
if &YR = 2017 and G_LEVEL = 'UG' then output UG;
if &YR = 2017 and G_LEVEL = 'PG' then output PG;

if &YR = 2017 and CLASS_COU = 'SEC' then output SEC_ALL;
if &YR = 2017 and CLASS_COU = 'SEC' and G_LEVEL = 'UG' then output SEC_UG;
if &YR = 2017 and CLASS_COU = 'SEC' and G_LEVEL = 'PG' then output SEC_PG;
run;

%let datas = ALL UG PG SEC_ALL SEC_UG SEC_PG;

%do i=1 %to %sysfunc(countw(&DATAS));
%let DATA = %scan(&DATAS,&i);

proc sql;
create table U_UNITS_A as
select distinct PRG_A as SUBJECT, count(*) as COUNT_A
from &data
group by PRG_A;
quit;


proc summary data=&data nway missing;
Class PRG_M;
VAR REPLACED CONT PEDA;
output out=U_UNITS_M(drop=_TYPE_ rename=(_FREQ_=COUNT_M PRG_M=SUBJECT)) N=;
run;


data SUBJECTS(keep=SUBJECT LABEL);
set AITSL.SUBJECTS;
run;

data Before_After;*(drop=SUBJECT rename=(LABEL=SUBJECT));
merge U_UNITS_A U_UNITS_M SUBJECTS;
by SUBJECT;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

* These are the main subjects used for pipeline report;
%let SUB_ORD = ENG E_ALD SCI_OTH MATH CHEM BIOL	EARTH_ENV_SCI PHYS ENGIN PSY 
ICT C_ARTS DANCE DRAMA BUS_MAN HUM ECON HIST INDIG HEALTH PE MUS AGR_ENV EC PRI SEC ED_OTH;

proc sql;
select SUBJECT into: SUBJ separated by ' '
from Before_After;
quit;

%let pid=\b%sysfunc(prxchange(s/\s+/\b|\b/,-1,&SUB_ORD))\b;
%let SUB_ORD_REST=%sysfunc(compbl(%sysfunc(prxchange(s/&pid//i,-1,&SUBJ))));
%let SUB_ORD_ALL = &SUB_ORD &SUB_ORD_REST;

data Before_After_ORD;
set Before_After;
array x &sub_ord_all;
do i = 1 to dim(x);
if SUBJECT = vname(x[i]) then ORD=i;
end;
drop i &sub_ord_all;
run;

proc sort data=Before_After_ORD; by ORD; run;
data SAVE_THIS;
retain SUBJECT LABEL;
set Before_After_ORD;
run;

%let savename = SUBJ_RECODING_&SAVE_YR..XLSX;
libname COMBINE XLSX "&savedir&savename";

data COMBINE.&data;
set SAVE_THIS;
run;

%end;
%end;
%mend;
%SUBJ_RECODE;

libname COMBINE clear;




**** HISTORICAL DATA for ALL CURRICULUM and ED ****************************************;

%let SUB_CURR = ENG E_ALD SCI_OTH MATH CHEM BIOL EARTH_ENV_SCI PHYS ENGIN PSY 
ICT C_ARTS DANCE DRAMA BUS_MAN HUM ECON HIST INDIG HEALTH PE MUS AGR_ENV;

* adding " " around the macro variables;
%let CURR = %sysfunc(compbl(%sysfunc(prxchange(s/(\S+)/"\1"/,-1,&SUB_CURR))));

%MACRO SUBJ_RECODE;

%do j=1 %to %sysfunc(countw(&YRS));
%let YR = %scan(&YRS,&j);
%let SAVE_YR = %scan(&SAVE_YRS,&j);
%let TEMP = %scan(&TEMPS,&j);

data ALL_HIST UG_HIST PG_HIST SEC_ALL_HIST SEC_UG_HIST SEC_PG_HIST;
set &TEMP;

if PRG_A in (&CURR) then ALL_CURR_A = 1;
if PRG_A in ("EC" "PRI" "SEC" "ED_OTH") then ALL_CURR_A = 2;
if PRG_M in (&CURR) then do;
ALL_CURR_M = 1;
if REPLACED = 1 then REPLACED_CURR = 1;
if CONT = 1 then CONT_CURR = 1;
if PEDA = 1 then PEDA_CURR = 1;
end;
if PRG_M in ("EC" "PRI" "SEC" "ED_OTH") then do;
ALL_CURR_M = 2;
if REPLACED = 1 then REPLACED_CURR = 2;
if CONT = 1 then CONT_CURR = 2;
if PEDA = 1 then PEDA_CURR = 2;
end;

output ALL_HIST;
if G_LEVEL = 'UG' then output UG_HIST;
if G_LEVEL = 'PG' then output PG_HIST;

if CLASS_COU = 'SEC' then output SEC_ALL_HIST;
if CLASS_COU = 'SEC' and G_LEVEL = 'UG' then output SEC_UG_HIST;
if CLASS_COU = 'SEC' and G_LEVEL = 'PG' then output SEC_PG_HIST;
run;


%let DATAS = ALL_HIST UG_HIST PG_HIST SEC_ALL_HIST SEC_UG_HIST SEC_PG_HIST;

	%do i=1 %to %sysfunc(countw(&DATAS));
	%let DATA = %scan(&DATAS,&i);

************* AS IS *****************************************;
proc summary data=&DATA nway missing;
class &YR ALL_CURR_A; 
var ALL_CURR_A;
output out=DATA_A(drop=_TYPE_ rename=(_FREQ_ = FREQ)) N=;
run;

data DATA_A;
set DATA_A;
if ALL_CURR_A = . then delete;
if &YR = . then delete;
run;

proc sort data=DATA_A; by &YR; run;
proc transpose data=DATA_A out=DATA_A_TPOSE (drop=_NAME_)  prefix=v;
by &YR;
var FREQ;
ID ALL_CURR_A;
run;

DATA FINAL_A;
set DATA_A_TPOSE;
rename v1=BEFORE_AC v2=BEFORE_ED;
run;


************* MINED *****************************************;

proc summary data=&DATA nway missing;
class &YR ALL_CURR_M; 
var ALL_CURR_M;
output out=DATA_A(drop=_TYPE_ rename=(_FREQ_ = FREQ)) N=;
run;

data DATA_A;
set DATA_A;
if ALL_CURR_M = . then delete;
if &YR = . then delete;
run;

proc sort data=DATA_A; by &YR; run;
proc transpose data=DATA_A out=DATA_A_TPOSE (drop=_NAME_)  prefix=v;
by &YR;
var FREQ;
ID ALL_CURR_M;
run;

DATA FINAL_M;
set DATA_A_TPOSE;
rename v1=AFTER_AC v2=AFTER_ED;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;



************* OHTER DETAILS *****************************************;
%let VARS = REPLACED CONT PEDA;

proc summary data=&DATA nway missing;
class &YR ALL_CURR_M; 
var ALL_CURR_M &VARS;
output out=DATA_A(drop=_TYPE_ rename=(_FREQ_ = FREQ)) N=;
run;

data DATA_A;
set DATA_A;
if ALL_CURR_M = . then delete;
if &YR = . then delete;
run;


	%do k=1 %to %sysfunc(countw(&VARS));
	%let VAR = %scan(&VARS,&k);


proc sort data=DATA_A; by &YR; run;
proc transpose data=DATA_A out=DATA_A_TPOSE (drop=_NAME_) prefix=v;
by &YR;
var &VAR;
ID ALL_CURR_M;
run;

DATA FINAL_&VAR;
set DATA_A_TPOSE;
rename v1=&VAR._AC v2=&VAR._ED;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

	%end;



*************************** MERGE all together ******************************************;

proc sql;
select memname into: FINAL_DATAS separated by ' '
from dictionary.tables
where libname='WORK' and memname?'FINAL';
quit;


DATA M_vs_A;
retain &YR BEFORE_AC AFTER_AC BEFORE_ED AFTER_ED REPLACED_AC REPLACED_ED CONT_AC CONT_ED PEDA_AC PEDA_ED;
MERGE &FINAL_DATAS;
by &YR;
run;

%let savename = SUBJ_RECODING_&SAVE_YR..XLSX;
libname COMBINE XLSX "&savedir&savename";

data COMBINE.&data;
set M_vs_A;
run;


**************************************************************************************************************;
************************************** DEMOS *****************************************************************;
**************************************************************************************************************;


%let DEMOS = UNI_STATE UNI_NAME UNI_TYPE;

	%do l=1 %to %sysfunc(countw(&DEMOS));
	%let DEMO = %scan(&DEMOS,&l);


************* AS IS *****************************************;
proc summary data=&DATA nway missing;
class &YR &DEMO ALL_CURR_A; 
var ALL_CURR_A;
output out=DATA_A(drop=_TYPE_ rename=(_FREQ_ = FREQ)) N=;
run;

data DATA_A;
set DATA_A;
if ALL_CURR_A = . then delete;
if &YR = . then delete;
run;

proc sort data=DATA_A; by &YR &DEMO; run;
proc transpose data=DATA_A out=DATA_A_TPOSE (drop=_NAME_)  prefix=v;
by  &YR &DEMO;
var FREQ;
ID ALL_CURR_A;
run;

DATA FINAL_A;
set DATA_A_TPOSE;
rename v1=BEFORE_AC v2=BEFORE_ED;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;


************* MINED *****************************************;

proc summary data=&DATA nway missing;
class  &YR &DEMO ALL_CURR_M; 
var ALL_CURR_M;
output out=DATA_A(drop=_TYPE_ rename=(_FREQ_ = FREQ)) N=;
run;

data DATA_A;
set DATA_A;
if ALL_CURR_M = . then delete;
if &YR = . then delete;
run;

proc sort data=DATA_A; by  &YR &DEMO; run;
proc transpose data=DATA_A out=DATA_A_TPOSE (drop=_NAME_)  prefix=v;
by  &YR &DEMO;
var FREQ;
ID ALL_CURR_M;
run;

DATA FINAL_M;
set DATA_A_TPOSE;
rename v1=AFTER_AC v2=AFTER_ED;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;



************* OHTER DETAILS *****************************************;
%let VARS = REPLACED CONT PEDA;

proc summary data=&DATA nway missing;
class &YR &DEMO ALL_CURR_M; 
var ALL_CURR_M &VARS;
output out=DATA_A(drop=_TYPE_ rename=(_FREQ_ = FREQ)) N=;
run;

data DATA_A;
set DATA_A;
if ALL_CURR_M = . then delete;
if &YR = . then delete;
run;


	%do m=1 %to %sysfunc(countw(&VARS));
	%let VAR = %scan(&VARS,&m);

proc sort data=DATA_A; by &YR &DEMO; run;
proc transpose data=DATA_A out=DATA_A_TPOSE (drop=_NAME_) prefix=v;
by &YR &DEMO;
var &VAR;
ID ALL_CURR_M;
run;

DATA FINAL_&VAR;
set DATA_A_TPOSE;
rename v1=&VAR._AC v2=&VAR._ED;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

	%end;


DATA M_vs_A;
retain &YR &DEMO BEFORE_AC AFTER_AC BEFORE_ED AFTER_ED REPLACED_AC REPLACED_ED CONT_AC CONT_ED PEDA_AC PEDA_ED;
MERGE &FINAL_DATAS;
by &YR &DEMO;
run;

*******************************************************;
*to not get empty/missing data under a column;
proc sql noprint;
create table U_VARS_1 as
select distinct &YR
from temp_ENR
where &YR ne .;
quit;

proc sql noprint;
create table U_VARS_2 as
select distinct &DEMO
from temp_ENR
where &YR ne .;
quit;

proc sql;
create table U_VARS as select U_VARS_1.&YR, U_VARS_2.&demo 
from U_VARS_1, U_VARS_2;
quit;
*******************************************************;

proc sort data =  M_vs_A; by &YR &demo; run;
proc sort data =  U_VARS; by &YR &demo; run;

data standardise;
merge U_VARS (in=in1) M_vs_A (in=in2);
by &YR &demo;
if in1;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;


%let savename = SUBJ_RECODING_&SAVE_YR._&DEMO..XLSX;
libname COMBINE XLSX "&savedir&savename";

data COMBINE.&data;
set standardise;
run;



%end;
%end;
%end;
%mend;
%SUBJ_RECODE;

libname COMBINE clear;

