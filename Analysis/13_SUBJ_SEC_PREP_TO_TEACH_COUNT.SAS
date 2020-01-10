* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads HE_LOAD_PRGC data from Preprocessing steps, and counts number of students who are being train to teach certain subjects;
* Uses logics to determine those that are being trained to teach;

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_HE_LOAD_PRGC; * Change this accordingly;
%let d_type = M;
%let lvl_of_detail = D;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type._&lvl_of_detail._COU;


/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */



* check this later;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\SUBJECTS\;
libname newdir "&savedir";
libname newdir clear;



data temp;
set &indata;
run;



* MACRO VARIABLES *;
proc sql noprint;
select tranwrd(name,'_COU','') into: VARS_SUBJ separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and name?'COU' and not name?'EFT' 
and not name?'_CONT' and not name?'_PEDA' and not name?'FYS_' and not name?'LYC_';

select tranwrd(name,'_COU','') into: VARS_PEDA separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and name?'_PEDA';

select tranwrd(name,'_COU','') into: VARS_CONT separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and name?'_CONT';
quit;

%let CAN_TEACH = CAN_TEACH_%sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&VARS_SUBJ)),%str( ), %str( CAN_TEACH_)))));

proc sql noprint;
select catx('=',name,tranwrd(name,'_COU','')) into: rename_list separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and name?'COU' and not name?'FYS_' and not name?'LYC_';
quit;

data Toni_request(keep=G_LEVEL &VARS_SUBJ &VARS_PEDA &VARS_CONT);
set temp;
if LYC_COU = 2017 and CLASS_COU = 'SEC';
rename &rename_list;
run;


/* ============================================================================= */
/* ==================================== LOGIC ================================== */
/* ============================================================================= */


** 4 Contents, 2 Pedagogy for UG**;
data CAN_TEACH_LOGIC_FULL;
set Toni_request;
array A &VARS_PEDA; array B &VARS_CONT; array C &CAN_TEACH;
do over A;
* if both Pedagogy and Contents are 2 and 4 or more, respectively;
/*if G_LEVEL = 'UG' and (2 <= A and 4 <= B) then C = 1;*/
if G_LEVEL = 'UG' and 2 <= A then C = 1; * this is for just 2 pedagogy;
if G_LEVEL = 'PG' and 2 <= A then C = 1; * if 2 or more for PG;
end;
run;


** 1-3 Contents and/or 1 Pedagogy for UG**;
data CAN_TEACH_LOGIC_PARTIAL;
set Toni_request;
array A &VARS_PEDA; array B &VARS_CONT; array C &CAN_TEACH;
do over A;
* if either content or pedagogy is 1 or more, but not both are more than 4 and 2 respectively;
/*if G_LEVEL = 'UG' and (1<= A or 1<= B) and not (2<= A and 4<= B) then C = 1;*/
if G_LEVEL = 'UG' and A = 1 then C = 1; * if just 1 Peda for UG;
if G_LEVEL = 'PG' and A = 1 then C = 1; * if just 1 Peda for PG;
end;
run;

** 0 Contents and/or 0 Pedagogy for UG & PG**;
data CAN_TEACH_LOGIC_ZERO;
set Toni_request;
array A &VARS_PEDA; array B &VARS_CONT; array C &CAN_TEACH; array D &VARS_SUBJ;
do over A;
* if Both content or pedagogy are 0 -- but studied UNITS are not zero!!;
/*if G_LEVEL = 'UG' and D ~= . and (A=. and B=.) then C = 1;*/
if G_LEVEL = 'UG' and D ~= . and A = . then C = 1;
if G_LEVEL = 'PG' and D ~= . and A = . then C = 1;
end;
run;



*****************************************************************************************************************;

*loading subject name file;
DATA SUBJECT_NAME(keep=SUBJECT LABEL);
set AITSL.SUBJECTS;
RUN;


%let DATAS = CAN_TEACH_LOGIC_FULL CAN_TEACH_LOGIC_PARTIAL CAN_TEACH_LOGIC_ZERO;


%macro CAN_TEACH;
%do i=1 %to %sysfunc(countw(&DATAS));
%let DATA = %scan(&DATAS,&i);

**********************************;
************* SUBJ ***************;
data SUBJ(keep=G_LEVEL &VARS_SUBJ sum_across);
set &DATA;
sum_across = sum(of &VARS_SUBJ);
if sum_across =. then delete;
run;

proc summary data=SUBJ nway missing;
CLASS G_LEVEL;
var &VARS_SUBJ;
output out=SUBJ_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc transpose data=SUBJ_this out=SUBJ_this_tpose(rename=(_NAME_=SUBJECT));
ID G_LEVEL;
run;

proc sort data=SUBJ_this_tpose; by SUBJECT;
data MERGED;
merge SUBJ_this_tpose(in=in1) SUBJECT_NAME(in=in2);
by SUBJECT;
if in1;
if SUBJECT = 'Students' then LABEL=SUBJECT;
run;

data FINAL_SUBJ(drop=SUBJECT rename=(LABEL=SUBJECT));
retain LABEL UG PG;
set MERGED;
run;




**********************************;
************* PEDA ***************;
data PEDA(keep=G_LEVEL &VARS_PEDA sum_across);
set &DATA;
sum_across = sum(of &VARS_PEDA);
if sum_across =. then delete;
run;

proc summary data=PEDA nway missing;
CLASS G_LEVEL;
var &VARS_PEDA;
output out=PEDA_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql noprint;
select catx('=',name,tranwrd(name,'_PEDA','')) into: rename_list separated by ' '
from dictionary.columns
where libname = 'WORK' and memname='PEDA_THIS' and name?'_PEDA';
quit;

data PEDA_this;
set PEDA_this;
rename &rename_list;
run;

proc transpose data=PEDA_this out=PEDA_this_tpose(rename=(_NAME_=SUBJECT));
ID G_LEVEL;
run;

proc sort data=PEDA_this_tpose; by SUBJECT;
data MERGED;
merge PEDA_this_tpose(in=in1) SUBJECT_NAME(in=in2);
by SUBJECT;
if in1;
if SUBJECT = 'Students' then LABEL=SUBJECT;
run;

data FINAL_PEDA(drop=SUBJECT rename=(LABEL=SUBJECT));
retain LABEL UG PG;
set MERGED;
rename UG=UG_PEDA PG=PG_PEDA;
run;





**********************************;
************* CONT ***************;
data CONT(keep=G_LEVEL &VARS_CONT sum_across);
set &DATA;
sum_across = sum(of &VARS_CONT);
if sum_across =. then delete;
run;

proc summary data=CONT nway missing;
CLASS G_LEVEL;
var &VARS_CONT;
output out=CONT_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql noprint;
select catx('=',name,tranwrd(name,'_CONT','')) into: rename_list separated by ' '
from dictionary.columns
where libname = 'WORK' and memname='CONT_THIS' and name?'_CONT';
quit;

data CONT_this;
set CONT_this;
rename &rename_list;
run;

proc transpose data=CONT_this out=CONT_this_tpose(rename=(_NAME_=SUBJECT));
ID G_LEVEL;
run;

proc sort data=CONT_this_tpose; by SUBJECT;
data MERGED;
merge CONT_this_tpose(in=in1) SUBJECT_NAME(in=in2);
by SUBJECT;
if in1;
if SUBJECT = 'Students' then LABEL=SUBJECT;
run;

data FINAL_CONT(drop=SUBJECT rename=(LABEL=SUBJECT));
retain LABEL UG PG;
set MERGED;
rename UG=UG_CONT PG=PG_CONT;
run;



**********************************;
************* CAN_TEACH ***************;
data CAN_TEACH(keep=G_LEVEL &CAN_TEACH sum_across);
set &DATA;
sum_across = sum(of &CAN_TEACH);
if sum_across =. then delete;
run;

proc summary data=CAN_TEACH nway missing;
CLASS G_LEVEL;
var &CAN_TEACH;
output out=CAN_TEACH_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql noprint;
select catx('=',name,tranwrd(name,'CAN_TEACH_','')) into: rename_list separated by ' '
from dictionary.columns
where libname = 'WORK' and memname='CAN_TEACH_THIS' and name?'CAN_TEACH';
quit;

data CAN_TEACH_this;
set CAN_TEACH_this;
rename &rename_list;
run;

proc transpose data=CAN_TEACH_this out=CAN_TEACH_this_tpose(rename=(_NAME_=SUBJECT));
ID G_LEVEL;
run;

proc sort data=CAN_TEACH_this_tpose; by SUBJECT;
data MERGED;
merge CAN_TEACH_this_tpose(in=in1) SUBJECT_NAME(in=in2);
by SUBJECT;
if in1;
if SUBJECT = 'Students' then LABEL=SUBJECT;
run;

data FINAL_CAN_TEACH(drop=SUBJECT rename=(LABEL=SUBJECT));
retain LABEL UG PG;
set MERGED;
rename UG=UG_CAN_TEACH PG=PG_CAN_TEACH;
run;

* this is for the last sheet that just shows full partial and zero;
%let set_name = %sysfunc(scan("&DATA",-1,"_"));

proc sort data=FINAL_SUBJ; by subject; run;
proc sort data=FINAL_PEDA; by subject; run;
proc sort data=FINAL_CONT; by subject; run;
proc sort data=FINAL_CAN_TEACH; by subject; run;

DATA MERGE_ALL;
merge FINAL_SUBJ(in=in1) FINAL_PEDA FINAL_CONT FINAL_CAN_TEACH;
by SUBJECT;
if in1;
run;

DATA FINAL_ALL;
retain SUBJECT UG UG_PEDA UG_CONT UG_CAN_TEACH PG PG_PEDA PG_CONT PG_CAN_TEACH;
set MERGE_ALL(where=(SUBJECT='Students')) MERGE_ALL(where=(SUBJECT ne 'Students'));
run;


%let savename = SEC_2017_CAN_TEACH_2PEDA_&lvl_of_detail..xlsx;
libname SEC XLSX "&savedir&savename";
data SEC.&DATA;
set FINAL_ALL;
run;

libname SEC clear;


** starting from here, just getting full / partial / zero in one sheet without peda/cont;
DATA &set_name(drop=UG_PEDA UG_CONT PG_PEDA PG_CONT);
set FINAL_ALL;
rename UG_CAN_TEACH= UG_&set_name PG_CAN_TEACH=PG_&set_name;
run;
%end;

*clearing workspace;
proc datasets lib=work nolist;
save TEMP Toni_request &DATAS FULL PARTIAL ZERO SUBJECT_NAME;
quit;

*merging those;
Data MERGE_FPZ;
retain SUBJECT UG UG_FULL UG_PARTIAL UG_ZERO PG PG_FULL PG_PARTIAL PG_ZERO;
merge FULL PARTIAL ZERO;
RUN;

libname SEC XLSX "&savedir&savename";
data SEC.FULL_PARTIAL_ZERO;
set MERGE_FPZ;
run;


libname SEC clear;

%mend;
%CAN_TEACH;
