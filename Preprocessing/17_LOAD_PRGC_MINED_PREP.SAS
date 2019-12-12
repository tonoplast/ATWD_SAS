* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads HEIMS Load data -- Mined data, and classifies into subject grouping -- by each referenceyear;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = LCE_E461E462; * Change this accordingly;
%let d_type = M;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type;

***************** CHANGE THIS FOR DIFFERENT DETAILS *******************;
%let PRG_LVL = PRG_D_DES; * change middle character(s), D = detailed, T = Toni, AC = All Curriculum. This determines the level of grouping;
%let lvl_of_detail = %sysfunc(scan(&PRG_LVL,2,"_"));
***********************************************************************;

%let startyear = 2005;
%let thisyear = 2017;


/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */

data temp(drop=e310 e306_name_abbrev e313 chessn e307 e489 e490 e461 e462 MODE_YR); *e354 course_name;
set &indata;
run;

* Loading Enrolment file;
data ENR(keep=e306 rec_e313 referenceyear COU G_LEVEL FYS_COU LYC_COU CLASS_COU);
set AITSL.CS_ENR_COU_ALL_&d_type;
run;


*merging;
options mergenoby=warn msglevel=I;
data temp_A ENR_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
		sysecho "merging temp_new..";
merge temp(IN=In1)  ENR(IN=In2);
by e306 rec_e313 referenceyear;
if In1=1 then output temp_A; * this is the file we want;
if In2=1 then output ENR_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

* clearing workspace;
proc datasets library=work nolist;
save temp_A;
run;


*****************************************************************************************************************************************;
* making ED_OTH macro here;
proc sql;
create table cc as
select distinct content as ED_OTH
from temp_a
where substr(content,1,2) = '07' and content not in ('070101','070103','070105','070107','070109','070111','070113','070115','070117');

create table pp as
select distinct pedagogy as ED_OTH
from temp_a
where substr(pedagogy,1,2) = '07' and pedagogy not in ('070101','070103','070105','070107','070109','070111','070113','070115','070117');

create table ee as
select distinct e464 as ED_OTH
from temp_a
where substr(e464,1,2) = '07' and e464 not in ('070101','070103','070105','070107','070109','070111','070113','070115','070117');
quit;

data merged;
merge cc pp ee;
run;

proc sql noprint;
select ED_OTH into: ED_OTH separated by ' '
from merged;
quit;

/*%put &ed_oth;*/
/*%let ED_OTH = '070000', '070100', '070199', '070300', '070301', '070303', '079900', '079999';*/
*****************************************************************************************************************************************;


*if e464 is already EC PRI SEC and;
*if content and pedagogy is general then not replacing;
data temp_B(drop=content pedagogy replaced_temp); *ori_e464;
set TEMP_A;
ori_e464 = e464;
*CONTENT;
if Content ne '' then do;
CONT = 'YES'; 

* if mined data is not general, then replace e464 with content;
if content not in (&ED_OTH) then do;
e464 = Content; REPLACED_temp = 1;
end;

*if original e464 is EC PRI SEC, and mined data has "07", then bring it back to the way it was before;
if ori_e464 in ('070101','070103','070105') and substr(content,1,2)='07' then do;
e464 = ori_e464; REPLACED_temp='';
end;

end;

*PEDAGOGY;
if Pedagogy ne '' then do;
PEDA = 'YES'; 
if Pedagogy not in (&ED_OTH) then do;
e464 = Pedagogy; REPLACED_temp = 1;
end;

if ori_e464 in ('070101','070103','070105') and substr(Pedagogy,1,2)='07' then do;
e464 = ori_e464; REPLACED_temp='';
end;

end;

REPLACED = REPLACED_temp; if ori_e464 = e464 then REPLACED = '';

rename Literacy=LIT Numeracy=NUM Prof_Pract=PRACT;
run;


*merging new e464 description for pipeline reporting;
proc sort data=temp_B; by e464; run;
proc sort data=AITSL.ASCED_PRG out=ASCED(keep=e464 e464_des &PRG_LVL); by e464; run;

options mergenoby=warn msglevel=I;
data temp_B_new ASCED_new inBoth NOmatch1 NOmatch2 allRECS NOmatch;
	sysecho "merging temp_B_new..";
merge temp_B(IN=In1)  ASCED(IN=In2);
by e464;
if In1=1 then output temp_B_new; * this is the file we want;
if In2=1 then output ASCED_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

DATA ASCED_ori;
set ASCED;
rename e464=ori_e464 e464_des=ori_e464_des PRG_D_des=ori_PRG_D_des;
run;

proc sort data=temp_B_new; by ori_e464; run;

data temp_B_new_2;
merge temp_B_new (in=in1) ASCED_ori(in=in2);
by ori_e464;
if in1;
run;


proc datasets library=work;
save temp_B_new_2;
run; 


************************** for Toni *************************;
/*data Toni_Check;*/
/*set temp_B_new_2;*/
/*if referenceyear = '2017' and CLASS_COU='SEC';*/
/*run;*/
/**/
/*proc sql;*/
/*create table U_unit as*/
/*select distinct e306,e354,ori_e464,ori_e464_des, ori_prg_d_des,e464,e464_des,course_name,prg_d_des*/
/*from Toni_Check;*/
/*quit;*/
*******************************************************************;

* if recoded then 1, if not 2 and getting rid of some variables;
data temp_B_new(drop=e354 ori_e464 ori_PRG_D_DES ori_e464_des e464 e464_des course_name );
set temp_B_new_2;
if COURSE_NAME ne '' then SUBJ_MATCHED = 1;
if COURSE_NAME = '' then SUBJ_MATCHED = 2;
EFT = e339/10000000;
COUNT = 1;
drop e339;
run;

** to get the number of units Matched **;
/*proc summary data=temp_B_new nway missing;*/
/*CLASS referenceyear SUBJ_MATCHED;*/
/*var SUBJ_MATCHED;*/
/*output out=CHECK (drop = _TYPE_ rename=(_FREQ_=COUNT)) N=;*/
/*run;*/
/**/
/*proc transpose data=CHECK out=CHECK_TPOSE(drop=_NAME_) prefix=v;*/
/*by referenceyear;*/
/*var COUNT;*/
/*ID SUBJ_RECODED;*/
/*run;*/


%let VARS = CONT PEDA;
%let VARS_CNT = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&VARS)),%str( ), %str(_CNT )))))_CNT;


* this is needed to add up how many peda etc they did each unit to sum later;
data temp_B_new_A (drop= &VARS PRGC LIT NUM PRACT rename=(&PRG_LVL=PRGC CONT_CNT=CONT PEDA_CNT=PEDA)); *LIT_CNT=LIT NUM_CNT=NUM PRACT_CNT=PRACT ;
set temp_B_new;
array X &VARS;
array Y &VARS_CNT;

do over X;
if X = 'YES' then Y=1;
end;
run;


* count by person (rec_e313) per course (cou);
proc sort data=temp_B_new_A out=B; by e306 rec_e313 cou referenceyear e329; run;

%let VARS = CONT PEDA;
%let VARS_CNT = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&VARS)),%str( ), %str(_CNT )))))_CNT;

** getting Subject Grouping counts for later use;
data B_SUBJ(KEEP=e306 rec_e313 referenceyear G_LEVEL FYS_COU LYC_COU  COU CLASS_COU PRGC COUNT EFT &VARS);
set B;
run;



*****************************************************************************************;
** BY YEAR **;
proc sort data=B_SUBJ; by e306 rec_e313 referenceyear G_LEVEL COU CLASS_COU PRGC COUNT;


* getting last number for each subjects in each year;
DATA SUBJ_COUNTING(drop=EFT COUNT &VARS);
set B_SUBJ;
by e306 rec_e313 referenceyear G_LEVEL COU CLASS_COU PRGC COUNT;

* counting by PRGC & for total (which are the same in this instance);
if first.PRGC then do; 
SUBJ_GRP_CNT=0; SUBJ_GRP_EFT=0;
CONT_CNT = 0; PEDA_CNT = 0;
end;
SUBJ_GRP_CNT + 1; SUBJ_GRP_EFT + EFT;
CONT_CNT+CONT; PEDA_CNT+PEDA;
if last.PRGC;
run;


proc sql noprint;
select distinct PRGC into : U_PRGC separated by ' '
from B_SUBJ;
quit;
*********************************************;
** BY YEAR -- having one line per year **;
%let U_YR = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&U_PRGC)),%str( ), %str(_YR )))))_YR;
%let U_PEDA = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&U_PRGC)),%str( ), %str(_PEDA )))))_PEDA;
%let U_CONT = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&U_PRGC)),%str( ), %str(_CONT )))))_CONT;
%let U_EFT = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&U_PRGC)),%str( ), %str(_EFT )))))_EFT;

* arraying it with subject code;
DATA SUBJ_YR (drop=SUBJ_GRP_CNT SUBJ_GRP_EFT PRGC CONT_CNT PEDA_CNT);
set SUBJ_COUNTING;
array a &U_PRGC;
array b &U_PEDA;
array c &U_CONT;
array d &U_EFT;
 
do over a;
if PRGC = vname(a) then do;
a = SUBJ_GRP_CNT;  
b = PEDA_CNT; 
c = CONT_CNT; 
d = SUBJ_GRP_EFT;
end;
if a=0 then a=.; if b=0 then b=.; if c=0 then c=.; if d=0 then d=.;
end;
run;


options missing= ' ';
** compressing multiple data in the same year into one **;
data Compress_SUBJ_YR;
		sysecho "Compressing D_SUBJ_YR..";
update SUBJ_YR(obs=0) SUBJ_YR;
by e306 rec_e313 referenceyear;
run;
options missing= '.';


DATA AITSL.CS_HE_LOAD_PRGC_&d_type._&lvl_of_detail._YR;
set Compress_SUBJ_YR;
run;
