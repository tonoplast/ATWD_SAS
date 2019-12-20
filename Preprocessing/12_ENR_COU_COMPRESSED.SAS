* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file compresses / summarises the data at Course level;
* This is not a necessary/cruicial step for this report;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_ENR_COU_ALL; * Change this accordingly;
%let d_type = M;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */

%let startyear = 2005;
%let thisyear = 2017;

proc sort data=&indata out=temp; by e306 rec_e313 referenceyear; run;

****************************************************************************************************;
** adding enrolment information here - PP (Per Person) and PC (Per Course) **;
proc sql noprint;
select distinct referenceyear into: year seprated by ' '
from temp;
quit;

%let PPyears = PP%sysfunc(tranwrd(%sysfunc(compbl(&year)),%str( ), %str( PP)));
%let PCyears = PC%sysfunc(tranwrd(%sysfunc(compbl(&year)),%str( ), %str( PC)));
/*%put &years;*/

data dFOE_YEAR;
set temp;
array x &PPyears;
array y &PCyears;
do over x;
if ReferenceYear=strip(tranwrd(vname(x),'PP','')) then do;
x=1; y=1; end;
end;
run;

options missing= ' ';
** enrolment info per person **;
data TIME_LINE_PP(keep=e306 rec_e313 &PPyears);
		sysecho "Compressing..";
update dFOE_YEAR(obs=0) dFOE_YEAR;
by e306 rec_e313;
run;

** enrolment info per course **;
data TIME_LINE_PC(drop=referenceyear &PPyears);
		sysecho "Compressing..";
update dFOE_YEAR(obs=0) dFOE_YEAR;
by e306 rec_e313 COU;
run;
options missing= '.';

data TIME_LINE_MERGED;
merge TIME_LINE_PC(in=in1) TIME_LINE_PP(in=in2);
by e306 rec_e313;
if in1;
run;


* deleting workspace;
proc datasets lib=work nolist;
save temp TIME_LINE_MERGED;
quit;


proc sort data=temp; by e306 COU rec_e313 ReferenceYear; run;

%let NoNeed = SS_YR CC_YR DD_YR XX_YR;

****************************************************************************************************;
** Compressing other info into start and end;
data Start_End(drop=&NoNeed);
set temp;
by e306 COU rec_e313 ReferenceYear;
if first.rec_e313 then first=1;
if last.rec_e313 then last=2;

if first =. and last=. then delete;
run;

proc sql noprint;
select distinct COU into: cou_lists separated by ' '
from Start_End;
quit;



*********************************************************************************************************************************;
***** FOR CHARACTER VARIABLES *****;

%let listC=; %let listC_1=; %let listC_2=;
%let listC = G_LEVEL CLASS_GLVL CLASS_COU ATAR_GRP ATAR_SEC BOA e307 e308 e310 COU_TYPE e350 e461 e462 HIGHEST_ED HIGHEST_ED_YEAR HOME_PC HOME_STATE UNI_STATE POSTAL_PC POSTAL_STATE; 
%let listC_1 = %sysfunc(tranwrd(%sysfunc(compbl(&listC)),%str( ), %str(_1 )))_1;
%let listC_2 = %sysfunc(tranwrd(%sysfunc(compbl(&listC)),%str( ), %str(_2 )))_2;

* get max length;
proc sql noprint;
select nvar into :nvars
from dictionary.tables
where libname="WORK" and memname="START_END";
quit;

data maxlen(keep=namex len form);
set Start_End end=eof;
array charx[*] _character_;
array varx[&nvars] _temporary_;
do i = 1 to dim(charx);
varx[i]= max(varx[i],length(charx[i]));
end;

if eof then do i=1 to dim(charx);
length namex $32;
namex=vname(charx[i]);
LEN=varx[i];
form=cat(LEN, '.');
output;
end;
run;


proc sort data=maxlen; by descending LEN;
run;

data _null_;
set maxlen(obs=1);
call symput('MAXLEN',LEN);
drop namex;
run;

data A(keep=e306 rec_e313 referenceyear &listC_1 &listC_2);
set Start_End;
array x $&MAXLEN &listC;
array y $&MAXLEN &listC_1;
array z $&MAXLEN &listC_2;

do over x;
if first = 1 then y=x; if last = 2 then z=x;
end;
run;


* shortening;
proc sql noprint;
select nvar into :nvars
from dictionary.tables
where libname="WORK" and memname="A";
quit;

data maxlen(keep=namex len form);
set A end=eof;
array charx[*] _character_;
array varx[&nvars] _temporary_;
do i = 1 to dim(charx);
varx[i]= max(varx[i],length(charx[i]));
end;

if eof then do i=1 to dim(charx);
length namex $32;
namex=vname(charx[i]);
LEN=varx[i];
form=cat(LEN, '.');
output;
end;
run;


proc print;
run;
filename tempfile temp;

options missing= ' ';
data _null_;
file tempfile;
if 0 then set A;
if _n_ eq 1 then do;
put 'retain ' (_all_) (=) ';' @;
_file_ = translate(_file_,' ','=');
put;
end;
set maxlen;
put 'Length ' namex '$' len ';';
put 'Format ' namex '$' form ';';
put 'Informat ' namex '$' form ';';
run;
options missing= '.';

data outdata;
%include tempfile / source2;
set A;
run;


* re-ordering variables;
%let varC=;
proc sql noprint;
select name into:varC separated by ' '
from dictionary.columns
where libname eq 'WORK' and memname eq 'A' and not name = 'e306' and not name = 'rec_e313' and not name = 'referenceyear'
order by name;
quit;

data A;
retain e306 rec_e313 referenceyear &varC;
set A;
run;


**********************************************************************************************************************************************;
***** FOR NUMERIC VARIABLES *****;

*getting these for begining and end of each course -- These are numeric variables;
%let listN=; %let listN_1=; %let listN_2=;
%let listn = REF_YR AGE FTPT_GLVL FTPT_COU Mode_GLVL Mode_COU SUM_FPT MAJOR DISAB SES ATAR CTZN METRO SAME_STATE_HU ACT NSW NT QLD SA TAS VIC WA NULL; * change these accordingly;
%let listn_1 = %sysfunc(tranwrd(%sysfunc(compbl(&listN)),%str( ), %str(_1 )))_1;
%let listn_2 = %sysfunc(tranwrd(%sysfunc(compbl(&listN)),%str( ), %str(_2 )))_2;



data B(keep=e306 rec_e313 referenceyear &listN_1 &listN_2);
set Start_End;
array x &listN;
array y &listN_1;
array z &listN_2;

do over x;
if first = 1 then y=x; if last = 2 then z=x;
end;
run;

* re-ordering variables;
%let varN=;
proc sql noprint;
select name into:varN separated by ' '
from dictionary.columns
where libname eq 'WORK' and memname eq 'B' and not name = 'e306' and not name = 'rec_e313' and not name = 'referenceyear'
order by name;
quit;

data B;
retain e306 rec_e313 referenceyear &varN;
set B;
run;

proc sort data=START_END; by e306 rec_e313 referenceyear;
proc sort data=A; by e306 rec_e313 referenceyear;
proc sort data=B; by e306 rec_e313 referenceyear;


data merge_all;
merge START_END(drop=&listC &listN) A B;
by e306 rec_e313 referenceyear;
run;

options missing= ' ';
** enrolment info per person **;
data Compress_all;
		sysecho "Compressing..";
update merge_all(obs=0) merge_all;
by e306 rec_e313 COU;
run;
options missing= '.';

data Final_data (drop=first last referenceyear &listC &listN);
merge compress_all time_line_merged;
by e306 rec_e313 COU;
run;


data AITSL.CS_ENR_COU_COMPRESSED_&d_type;
set Final_data;
run;

