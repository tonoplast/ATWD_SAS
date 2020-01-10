* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads HE_LOAD_PRGC data from Preprocessing steps, and counts units that were recoded into a particular subject area;

* The output is for Secondary initial teacher education (as they have specialisation) for 2017;
* Counts Enrolment, Commencement, Completion, separated by Pedagogy and Content;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_HE_LOAD_PRGC; * Change this accordingly;
%let d_type = M;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type._YR;

* check this later;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\SUBJECTS\;
libname newdir "&savedir";
libname newdir clear;

data temp;
set &indata;
run;

proc sql noprint;
select name into: VARS_SUBJ separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and not name?'COU' and not name?'EFT' and not name?'_CONT' and not name?'_PEDA';

select name into: VARS_PEDA separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and name?'_PEDA';

select name into: VARS_CONT separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and name?'_CONT';
quit;


**********************************************************************************;
/* ============================================================================= */
/* ================================== ENROLLED ================================= */
/* ============================================================================= */
**********************************************************************************;

data Toni_request(keep=G_LEVEL &VARS_SUBJ &VARS_PEDA &VARS_CONT);
set temp;
if referenceyear = '2017' and CLASS_COU = 'SEC';
run;

*loading subject name file;
DATA SUBJECT_NAME(keep=SUBJECT LABEL);
set AITSL.SUBJECTS;
RUN;

**********************************;
************* SUBJ ***************;
data SUBJ(keep=G_LEVEL &VARS_SUBJ sum_across);
set Toni_request;
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
set Toni_request;
sum_across = sum(of &VARS_PEDA);
if sum_across =. then delete;
run;

proc summary data=PEDA nway missing;
CLASS G_LEVEL;
var &VARS_PEDA;
output out=PEDA_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql;
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
set Toni_request;
sum_across = sum(of &VARS_CONT);
if sum_across =. then delete;
run;

proc summary data=CONT nway missing;
CLASS G_LEVEL;
var &VARS_CONT;
output out=CONT_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql;
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


proc datasets lib=work nolist;
save TEMP Toni_request FINAL_SUBJ FINAL_CONT FINAL_PEDA;
quit;

proc sort data=FINAL_SUBJ; by subject; run;
proc sort data=FINAL_PEDA; by subject; run;
proc sort data=FINAL_CONT; by subject; run;

DATA MERGE_ALL;
merge FINAL_SUBJ(in=in1) FINAL_PEDA FINAL_CONT;
by SUBJECT;
if in1;
run;

DATA FINAL_ALL;
retain SUBJECT UG UG_PEDA UG_CONT PG PG_PEDA PG_CONT;
set MERGE_ALL(where=(SUBJECT='Students')) MERGE_ALL(where=(SUBJECT ne 'Students'));
run;


%let savename = SEC_2017.xlsx;
libname SEC XLSX "&savedir&savename";
data SEC.ENR;
set FINAL_ALL;
run;


libname SEC clear;





**********************************************************************************;
/* ============================================================================= */
/* ================================== COMMENCED ================================ */
/* ============================================================================= */
**********************************************************************************;

data Toni_request(keep=G_LEVEL &VARS_SUBJ &VARS_PEDA &VARS_CONT);
set temp;
if referenceyear = '2017' and FYS_COU = '2017' and CLASS_COU = 'SEC';
run;

*loading subject name file;
DATA SUBJECT_NAME(keep=SUBJECT LABEL);
set AITSL.SUBJECTS;
RUN;

**********************************;
************* SUBJ ***************;
data SUBJ(keep=G_LEVEL &VARS_SUBJ sum_across);
set Toni_request;
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
set Toni_request;
sum_across = sum(of &VARS_PEDA);
if sum_across =. then delete;
run;

proc summary data=PEDA nway missing;
CLASS G_LEVEL;
var &VARS_PEDA;
output out=PEDA_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql;
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
set Toni_request;
sum_across = sum(of &VARS_CONT);
if sum_across =. then delete;
run;

proc summary data=CONT nway missing;
CLASS G_LEVEL;
var &VARS_CONT;
output out=CONT_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql;
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


proc datasets lib=work nolist;
save TEMP Toni_request FINAL_SUBJ FINAL_CONT FINAL_PEDA;
quit;

proc sort data=FINAL_SUBJ; by subject; run;
proc sort data=FINAL_PEDA; by subject; run;
proc sort data=FINAL_CONT; by subject; run;

DATA MERGE_ALL;
merge FINAL_SUBJ(in=in1) FINAL_PEDA FINAL_CONT;
by SUBJECT;
if in1;
run;

DATA FINAL_ALL;
retain SUBJECT UG UG_PEDA UG_CONT PG PG_PEDA PG_CONT;
set MERGE_ALL(where=(SUBJECT='Students')) MERGE_ALL(where=(SUBJECT ne 'Students'));
run;


%let savename = SEC_2017.xlsx;
libname SEC XLSX "&savedir&savename";
data SEC.START;
set FINAL_ALL;
run;

libname SEC clear;


/* ============================================================================= */
/* ================================== COMPLETED ================================ */
/* ============================================================================= */


data Toni_request(keep=G_LEVEL &VARS_SUBJ &VARS_PEDA &VARS_CONT);
set temp;
if referenceyear = '2017' and LYC_COU = 2017 and CLASS_COU = 'SEC';
run;

*loading subject name file;
DATA SUBJECT_NAME(keep=SUBJECT LABEL);
set AITSL.SUBJECTS;
RUN;

**********************************;
************* SUBJ ***************;
data SUBJ(keep=G_LEVEL &VARS_SUBJ sum_across);
set Toni_request;
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
set Toni_request;
sum_across = sum(of &VARS_PEDA);
if sum_across =. then delete;
run;

proc summary data=PEDA nway missing;
CLASS G_LEVEL;
var &VARS_PEDA;
output out=PEDA_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql;
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
set Toni_request;
sum_across = sum(of &VARS_CONT);
if sum_across =. then delete;
run;

proc summary data=CONT nway missing;
CLASS G_LEVEL;
var &VARS_CONT;
output out=CONT_this(drop=_TYPE_ rename=(_FREQ_=Students)) N=;
run;

proc sql;
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


proc datasets lib=work nolist;
save TEMP Toni_request FINAL_SUBJ FINAL_CONT FINAL_PEDA;
quit;

proc sort data=FINAL_SUBJ; by subject; run;
proc sort data=FINAL_PEDA; by subject; run;
proc sort data=FINAL_CONT; by subject; run;

DATA MERGE_ALL;
merge FINAL_SUBJ(in=in1) FINAL_PEDA FINAL_CONT;
by SUBJECT;
if in1;
run;

DATA FINAL_ALL;
retain SUBJECT UG UG_PEDA UG_CONT PG PG_PEDA PG_CONT;
set MERGE_ALL(where=(SUBJECT='Students')) MERGE_ALL(where=(SUBJECT ne 'Students'));
run;


%let savename = SEC_2017.xlsx;
libname SEC XLSX "&savedir&savename";
data SEC.COMP;
set FINAL_ALL;
run;


libname SEC clear;
