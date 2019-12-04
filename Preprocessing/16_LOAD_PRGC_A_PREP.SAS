* This file loads HEIMS Load file, and classifies units into subject grouping by each referenceyear;



libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = LCE_E461E462; * Change this accordingly;
%let d_type = A;
* ===================================================;

***************** CHANGE THIS FOR DIFFERENT DETAILS *******************;
%let PRG_LVL = PRG_D_DES;
%let lvl_of_detail = %sysfunc(scan(&PRG_LVL,2,"_"));
***********************************************************************;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type;

%let startyear = 2005;
%let thisyear = 2017;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */




data temp(drop=e310 e306_name_abbrev e313 chessn e307 e489 e490 e461 e462 MODE_YR); *e354 course_name;
set &indata;
run;

* loading enrolment data;
data ENR(keep=e306 rec_e313 referenceyear COU G_LEVEL FYS_COU LYC_COU CLASS_COU);
set AITSL.CS_ENR_COU_ALL_&d_type;
run;


*adding cleaned rec_e313 into load file ;
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


*merging new e464 description for pipeline reporting;
proc sort data=temp_A; by e464; run;
proc sort data=AITSL.ASCED_PRG out=ASCED(keep=e464 e464_des &PRG_LVL); by e464; run;

options mergenoby=warn msglevel=I;
data temp_A_new ASCED_new inBoth NOmatch1 NOmatch2 allRECS NOmatch;
	sysecho "merging temp_B_new..";
merge temp_A(IN=In1)  ASCED(IN=In2);
by e464;
if In1=1 then output temp_A_new; * this is the file we want;
if In2=1 then output ASCED_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

proc datasets library=work;
save temp_A_new;
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
data temp_B_new(drop=e354 e464 e464_des rename=(&PRG_LVL=PRGC));
set temp_A_new;

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


* count by person (rec_e313) per course (cou);
proc sort data=temp_B_new out=B; by e306 rec_e313 cou referenceyear e329; run;



** getting Subject Grouping counts for later use;
data B_SUBJ(KEEP=e306 rec_e313 referenceyear G_LEVEL FYS_COU LYC_COU  COU CLASS_COU PRGC COUNT EFT);
set B;
run;



*****************************************************************************************;
** BY YEAR **;
proc sort data=B_SUBJ; by e306 rec_e313 referenceyear G_LEVEL COU CLASS_COU PRGC COUNT;


* getting last number for each subjects in each year;
DATA SUBJ_COUNTING(drop=EFT COUNT);
set B_SUBJ;
by e306 rec_e313 referenceyear G_LEVEL COU CLASS_COU PRGC COUNT;

* counting by PRGC & for total (which are the same in this instance);
if first.PRGC then do; 
SUBJ_GRP_CNT=0; SUBJ_GRP_EFT=0;
end;
SUBJ_GRP_CNT + 1; SUBJ_GRP_EFT + EFT;
if last.PRGC;
run;


proc sql noprint;
select distinct PRGC into : U_PRGC separated by ' '
from B_SUBJ;
quit;
*********************************************;
** BY YEAR -- having one line per year **;
%let U_YR = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&U_PRGC)),%str( ), %str(_YR )))))_YR;
%let U_EFT = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&U_PRGC)),%str( ), %str(_EFT )))))_EFT;

* arraying it with subject code;
DATA SUBJ_YR (drop=SUBJ_GRP_CNT SUBJ_GRP_EFT PRGC);
set SUBJ_COUNTING;
array a &U_PRGC;
array d &U_EFT;
 
do over a;
if PRGC = vname(a) then do;
a = SUBJ_GRP_CNT;  
d = SUBJ_GRP_EFT;
end;
if a=0 then a=.; if d=0 then d=.;
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
