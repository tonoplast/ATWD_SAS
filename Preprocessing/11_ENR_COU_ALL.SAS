* This file creates master data for Enrolment + Course.
* More variables are added & simplified; 
* Addition of more things on how data are cut -- Course or Year (Commencement, completions etc); 
* The reason is that we are looking at the data retrospectively;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_HE_COU_LOGIC; * Change this accordingly;
%let d_type = M;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */

%let startyear = 2005;
%let thisyear = 2017;

proc sort data=&indata; by e306 rec_e313 descending referenceyear; run;

data COU_CNT(keep=e306 rec_e313 referenceyear COU_CNT);
set &indata;
retain filledX;
If not missing(COU_CNT) then filledX=COU_CNT;
COU_CNT=filledX;
run;

proc sort data=&indata; by e306 rec_e313 referenceyear; run;

data temp(drop=first_metro first_regional first_remote first_SES_SA1 SES_SA1 postaladdress_countryname residentialaddress_countryname A B C D E collectionperiod COU_CNT);
set &indata;

		sysecho "loading file and adding things..";

REF_YR = input(referenceyear,4.);
if start = 'SS' then SS_YR = input(referenceyear,4.);
if comp = 'CC' then CC_YR =input(referenceyear,4.);
if comp = 'CC' then CC_YR_HEIMS = input(comp_year,4.);
if drop = 'DD' then DD_YR = input(referenceyear,4.);
if OONS = 'XX' then XX_YR = input(referenceyear,4.);

if rec_e346 = ' ' then rec_e346 = '0000';
e346 = rec_e346;
substr(e346,3)='00';

*country of birth - 1: australia 2: others;
if e346 = '1100' then COB = 1; else COB = 2;

*getting age here;
	AGE = referenceyear-rec_yob-1; 

*getting ATAR range;
	if e369 = '800' then e369 = '080'; *fixing some potential entry error;
	ATAR_GRP = e369; * adding ATAR group;

	if 30 =< e369 =< 50 then ATAR_GRP = '050';
	if 51 =< e369 =< 60 then ATAR_GRP = '060';
	if 61 =< e369 =< 70 then ATAR_GRP = '070';
	if 71 =< e369 =< 80 then ATAR_GRP = '080';
	if 81 =< e369 =< 90 then ATAR_GRP = '090';
	if 91 =< e369 =< 100 then ATAR_GRP = '100';

	if e327 = '33' then ATAR_SEC=ATAR_GRP;
	if e327 = '33' and 1<ATAR_SEC<101 then ATAR=input(e369,3.);

*modifying e327  -- BOA;	
BOA = e327;
if e327 in ('02','03') then BOA = '99';


* having modified prior education;
HIGHEST_ED = substr(e493,1,2);
HIGHEST_ED_YEAR = substr(e493,3,-4);

* changing region into METRO or not;
if region in ('METRO') then METRO = 1; 
if region in ('REMOTE','REGIONAL') then METRO = 2;
if region in ('NULL') then METRO=99;

*getting CITIZEN related;
CTZN = input(e358,1.);
if e358 in ('1','2','3','8') then CTZN = 1; *used to be 3 for '3' and '8';
if e358 in ('4','5') then CTZN = 2; *used to be 4;

* getting AITS here;
ATSI =  input(rec_e316,1.); 
if rec_e316 in ('2') then ATSI=2; * 2 means non indigenous;
if rec_e316 in ('3','4','5') then ATSI=3; * 3 meamsn indigenous;

if SES_PC in ('h') then SES = 1;
if SES_PC in ('m') then SES = 2;
if SES_PC in ('l') then SES = 3;
if SES_PC in ('x','z') then SES = 99;

if LCOU='A' then MULTIPLE_COU = 1;
if LCOU ne 'A' then MULTIPLE_COU = 2;

GENDER = rec_e315;
YOB = rec_YOB;
UNI_NAME = e306_name_abbrev;
UNI_STATE = STATE;

if HOME_STATE  eq UNI_STATE then SAME_STATE_HU = 1; *same;
if HOME_STATE not in ('NULL') and UNI_STATE not in ('MUL') and HOME_STATE ne UNI_STATE then SAME_STATE_HU= 2; *diff;
if HOME_STATE not in ('NULL') and UNI_STATE in ('MUL') then SAME_STATE_HU = 3; *home/multi;
if HOME_STATE in ('NULL') and  UNI_STATE not in ('MUL') then SAME_STATE_HU = 4; *unknown / uni;
if HOME_STATE in ('NULL') and  UNI_STATE in ('MUL') then SAME_STATE_HU = 5; *both dunno;

if SE ne ' ' then STILL_ENROLLED = 1;

rename e386_mod=DISAB e310_des=COU_TYPE;

drop e346 e312 rec_e315 e315 rec_e316 e316 rec_e346 e346 e358 rec_YOB YoB e306_name_abbrev STATE COB SES_PC
flag_chessn ori_e922 e922 comp_year ori_comp_year countx_mod cou_ea comp_cou start oons comp drop region e493 e369 e327 SE LC
EC PRI SEC MIX EO
;
run;

proc sort data=COU_CNT; by e306 rec_e313 referenceyear;
data merged_temp;
merge temp COU_CNT;
by e306 rec_e313 referenceyear;
run;

data SS_CC_YR(keep=e306 rec_e313 referenceyear COU G_LEVEL SS_YR CC_YR DD_YR );
set merged_temp;
run;

*** PERSON ***;
data INDEX_PERSON;
set SS_CC_YR;
by e306 rec_e313 referenceyear;
if first.rec_e313 then first_index_person = 1;
if last.rec_e313 then last_index_person = 1;

if SS_YR = . then SS_YR = 9999;
if CC_YR = . then CC_YR = 1111;
if DD_YR = . then DD_YR = 1111;
run;

proc sort data=INDEX_PERSON; by e306 rec_e313 SS_YR; run;
data INDEX_PERSON_2;
set INDEX_PERSON;
by e306 rec_e313 SS_YR;
if first.rec_e313 and SS_YR ne 9999 then temp=SS_YR;
if first.rec_e313 then FYS_PERSON = temp;
else FYS_PERSON = coalesce(temp, FYS_PERSON);
retain FYS_PERSON;
drop temp;
run;

proc sort data=INDEX_PERSON_2; by e306 rec_e313 descending CC_YR; run;
data INDEX_PERSON_3;
set INDEX_PERSON_2;
by e306 rec_e313 descending CC_YR;
if first.rec_e313 and CC_YR ne 1111 then temp=CC_YR;
if first.rec_e313 then LYC_PERSON = temp;
else LYC_PERSON = coalesce(temp, LYC_PERSON);
retain LYC_PERSON;
drop temp;
run;

proc sort data=INDEX_PERSON_3; by e306 rec_e313 descending DD_YR; run;
data INDEX_PERSON_4;
set INDEX_PERSON_3;
by e306 rec_e313 descending DD_YR;
if first.rec_e313 and DD_YR ne 1111 then temp=DD_YR;
if first.rec_e313 then LYD_PERSON = temp;
else LYD_PERSON = coalesce(temp, LYD_PERSON);
retain LYD_PERSON;
drop temp;
run;


*** GLVL ***;
proc sort data=INDEX_PERSON_4; by e306 G_LEVEL rec_e313 referenceyear; run;
data INDEX_GLVL;
set INDEX_PERSON_4;
by e306 G_LEVEL rec_e313 referenceyear;
if first.rec_e313 then first_index_GLVL = 1;
if last.rec_e313 then last_index_GLVL = 1;
run;

proc sort data=INDEX_GLVL; by e306 G_LEVEL rec_e313 SS_YR; run;
data INDEX_GLVL_2;
set INDEX_GLVL;
by e306 G_LEVEL rec_e313 SS_YR;
if first.rec_e313 and SS_YR ne 9999 then temp=SS_YR;
if first.rec_e313 then FYS_GLVL = temp;
else FYS_GLVL = coalesce(temp, FYS_GLVL);
retain FYS_GLVL;
drop temp;
run;

proc sort data=INDEX_GLVL_2; by e306 G_LEVEL rec_e313 descending CC_YR; run;
data INDEX_GLVL_3;
set INDEX_GLVL_2;
by e306 G_LEVEL rec_e313 descending CC_YR;
if first.rec_e313 and CC_YR ne 1111 then temp=CC_YR;
if first.rec_e313 then LYC_GLVL = temp;
else LYC_GLVL = coalesce(temp, LYC_GLVL);
retain LYC_GLVL;
drop temp;
run;

proc sort data=INDEX_GLVL_3; by e306 G_LEVEL rec_e313 descending DD_YR; run;
data INDEX_GLVL_4;
set INDEX_GLVL_3;
by e306 G_LEVEL rec_e313 descending DD_YR;
if first.rec_e313 and DD_YR ne 1111 then temp=DD_YR;
if first.rec_e313 then LYD_GLVL = temp;
else LYD_GLVL = coalesce(temp, LYD_GLVL);
retain LYD_GLVL;
drop temp G_LEVEL;
run;


*** COURSE ***;
proc sort data=INDEX_GLVL_4; by e306 COU rec_e313 referenceyear; run;
data INDEX_COU;
set INDEX_GLVL_4;
by e306 COU rec_e313 referenceyear;
if first.rec_e313 then first_index_COU = 1;
if last.rec_e313 then last_index_COU = 1;
run;


proc sort data=INDEX_COU; by e306 COU rec_e313 SS_YR; run;
data INDEX_COU_2;
set INDEX_COU;
by e306 COU rec_e313 SS_YR;
if first.rec_e313 and SS_YR ne 9999 then temp=SS_YR;
if first.rec_e313 then FYS_COU = temp;
else FYS_COU = coalesce(temp, FYS_COU);
retain FYS_COU;
drop temp;
run;

proc sort data=INDEX_COU_2; by e306 COU rec_e313 descending CC_YR; run;
data INDEX_COU_3;
set INDEX_COU_2;
by e306 COU rec_e313 descending CC_YR;
if first.rec_e313 and CC_YR ne 1111 then temp=CC_YR;
if first.rec_e313 then LYC_COU = temp;
else LYC_COU = coalesce(temp, LYC_COU);
retain LYC_COU;
drop temp SS_YR CC_YR;
run;


proc sort data=INDEX_COU_3; by e306 COU rec_e313 descending DD_YR; run;
data INDEX_COU_4;
set INDEX_COU_3;
by e306 COU rec_e313 descending DD_YR;
if first.rec_e313 and DD_YR ne 1111 then temp=DD_YR;
if first.rec_e313 then LYD_COU = temp;
else LYD_COU = coalesce(temp, LYD_COU);
retain LYD_COU;
drop temp SS_YR CC_YR COU DD_YR;
run;


DATA COMP_DUR;
set INDEX_COU_4;

*Completion duration here;
if FYS_COU ne . and LYC_COU ne . then COMP_DUR_COU = LYC_COU+1-FYS_COU;
if FYS_GLVL ne . and LYC_GLVL ne . then COMP_DUR_GLVL = LYC_GLVL+1-FYS_GLVL;
if FYS_PERSON ne . and LYC_PERSON ne . then COMP_DUR_PERSON = LYC_PERSON+1-FYS_PERSON;
run;

proc sql noprint;
select name into: VAR_ORD separated by ' '
from dictionary.columns
where libname = 'WORK' and memname = 'COMP_DUR' and not name = 'e306' and not name = 'rec_e313' and not name = 'referenceyear'
order by name;
quit;

data output;
retain &VAR_ORD;
set COMP_DUR;
run;

* adding HEP type into the dataset;
data UNI(keep=e306 e306_type HEP_type);
set AITSL.UNI_INFO;
run;

proc sort data=output; by e306 rec_e313 referenceyear;
data FINAL_DATA;
merge merged_temp output;
by e306 rec_e313 referenceyear;
run;

data FINAL_DATA;
merge FINAL_DATA(in=in1) UNI(in=in2);
by e306;
if in1;
run;

* deleting workspace;
proc datasets lib=work nolist;
save FINAL_DATA merged_temp;
quit;


****************************************************************************************************;
** getting first data and paste down by group -- ATAR and BOA etc for completion data later;
data ATAR_STUFF(keep=e306 rec_e313 referenceyear COU ATAR_GRP ATAR_SEC ATAR BOA HIGHEST_ED);
set merged_temp;
run;

proc sort data=ATAR_STUFF; by e306 COU rec_e313 referenceyear; run;

proc sql noprint;
select cats(name,'=',cats(name,'_COU')) into: renaming_list separated by ' '
from dictionary.columns
where libname='WORK' and memname='ATAR_STUFF' and not name='e306' and not name='referenceyear' and not name='COU' and not name ='rec_e313';
quit;

data FIRST_DATA;
set ATAR_STUFF;
by e306 COU rec_e313;
if first.rec_e313;
rename &renaming_list;
run;

data M_ATAR(drop=ATAR_GRP ATAR_SEC ATAR BOA HIGHEST_ED);
merge ATAR_STUFF(in=in1) FIRST_DATA(in=in2);
by e306 COU rec_e313; 
if in1;
run;
****************************************************************************************************;

proc sort data=M_ATAR; by e306 rec_e313 referenceyear;

data FINAL_MERGE;
merge FINAL_DATA(in=in1) M_ATAR(in=in2);
by e306 rec_e313 referenceyear;
run;


data FINAL_MERGE;
set FINAL_MERGE;
if find(HEP_TYPE," A") ge 1 then UNI_TYPE = "A";
if find(HEP_TYPE," B") ge 1 then UNI_TYPE = "B";
if find(HEP_TYPE,"NON") ge 1 then UNI_TYPE = "N";

ATAR_SIMPLE_COU = ATAR_SEC_COU;
if ATAR_SEC_COU not in ('','001','998','999') then ATAR_SIMPLE_COU = 'YES';
if ATAR_SEC_COU = '' then ATAR_SIMPLE_COU = 'NA';
run;



%let STATES = ACT NSW NT QLD SA TAS VIC WA;
/*%let SQL_STATES = %sysfunc(tranwrd(%quote(&STATES),%str( ), %str(, )));*/

data AITSL.CS_ENR_COU_ALL_&d_type;
set FINAL_MERGE;
array x &STATES;
do over x;
if HOME_STATE = vname(x) and UNI_STATE = vname(x) then x = 1;
if HOME_STATE = vname(x) and UNI_STATE = "MUL" then x = 1;
if HOME_STATE = vname(x) and x ne 1 then x=2;
if HOME_STATE ne vname(x) and UNI_STATE = vname(x) then x=3;
end;
if HOME_STATE = 'NULL' and UNI_STATE = 'MUL' then NULL=1;
run;
