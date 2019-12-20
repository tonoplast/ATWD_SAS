* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file is used to get QILT GOS data prepared for merging with HEIMS data;

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = QI_GOS;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;

*saving excel names;
%let savename = QILT_GOS;
%let sheetname = GOS_RAW;

************************************************************;
%let QI_data = QI_GOS; 
************************************************************;

*saving directory;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\QILT\;


proc sort data=&indata out=GOS (drop=CollectionPeriod snapshotid id submissionid linkageid); by e306 chessn; run;

*loading files that has all the enrolment infomation here;
data COU_LOGIC(drop=first_metro first_regional first_remote first_SES_SA1 SES_SA1 PostalAddress_CountryName ResidentialAddress_CountryName);
set AITSL.CS_HE_COU_LOGIC_&d_type;
run;

*getting rec_e313 from there to add into QILT file;
proc sql;
create table rec_e313 as
select distinct e306, chessn, rec_e313
from COU_LOGIC;
quit;

proc sort data=GOS; by e306 chessn; run;
proc sort data=rec_e313; by e306 chessn rec_e313; run;

data GOS_with_rec_e313;
merge GOS(in=in1) rec_e313(in=in2);
by e306 chessn;
if in1;
run;

data NEW_GOS;
retain E306 rec_e313 chessn YEAR;
set GOS_with_rec_e313;
if rec_e313 ne '';
run;

* selecting _A and _B variables;
proc sql noprint;
select name into: Major_A separated by ' ' from dictionary.columns where libname='WORK' and memname='NEW_GOS' and name?'_A';
select name into: Major_B separated by ' ' from dictionary.columns where libname='WORK' and memname='NEW_GOS' and name?'_B';
quit;

%let VARS = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&Major_A)),%str(_A), %str()))));


%let Rename_A=;
%macro renaming;
%do i = 1 %to %sysfunc(countw(&Major_A));
%let Major = %scan(&Major_A, &i);
%let renaming = %scan(&VARS, &i);
%let Rename_Major = &Major=&renaming;
%let Rename_A= &Rename_A &Rename_Major;
%end;
%mend;
%renaming;

%let Rename_B=;
%macro renaming;
%do i = 1 %to %sysfunc(countw(&Major_B));
%let Major = %scan(&Major_B, &i);
%let renaming = %scan(&VARS, &i);
%let Rename_Major = &Major=&renaming;
%let Rename_B= &Rename_B &Rename_Major;
%end;
%mend;
%renaming;


*dropping and renaming;
data GOS_A (drop= &Major_B);
set NEW_GOS;
rename &Rename_A;
run;

data GOS_B (drop= &Major_A);
set NEW_GOS;
if ANALYSIS_B = 'NA' then delete;
rename &Rename_B;
run;

proc sort data=GOS_A; by e306 rec_e313 YEAR ANALYSIS; run;
proc sort data=GOS_B; by e306 rec_e313 YEAR ANALYSIS; run;


data Merged_GOS;
merge GOS_A GOS_B;
by e306 rec_e313 YEAR ANALYSIS;
CEQCODE = strip(put(input(CEQCODE,best6.),z6.));
ANZSIC = strip(put(input(ANZSIC,best4.),z4.));
if ANZSIC = '.' then ANZSIC = 'NA'; * putting back 'NA' into the data;

padding = '00';
substr(padding,3-length(FINDJOB)) = FINDJOB;
drop FINDJOB;
rename padding=FINDJOB;
run;


** flagging those that are "EDUCATION" to put as _A later on;
data flag_07;
set Merged_GOS;
if substr(CEQCODE,1,2) = '07' then FLAG_ED = 1;
if substr(CEQCODE,1,2) ne '07' then FLAG_ED = 2;
run;

proc sort data=flag_07; by e306 YEAR rec_e313 FLAG_ED; run;
data flag_07_last;
set flag_07;
by e306 YEAR rec_e313 FLAG_ED; 
if first.rec_e313 then PICK=1;
else PICK=2;
run;


%let Rename_A=;
%macro renaming;
%do i = 1 %to %sysfunc(countw(&Major_A));
%let Major = %scan(&Major_A, &i);
%let renaming = %scan(&VARS, &i);
%let Rename_Major = &Major=&renaming%nrstr(;) ;
%let Rename_A= &Rename_A &Rename_Major;
%end;
%mend;
%renaming;

%let Rename_B=;
%macro renaming;
%do i = 1 %to %sysfunc(countw(&Major_B));
%let Major = %scan(&Major_B, &i);
%let renaming = %scan(&VARS, &i);
%let Rename_Major = &Major=&renaming%nrstr(;) ;
%let Rename_B= &Rename_B &Rename_Major;
%end;
%mend;
%renaming;


*only getting data for "EDUCATION" field;
data GOS_07;
set flag_07_last;
if PICK=1 then do; &Rename_A; end;
if PICK=2 then do; &Rename_B; end;
drop &VARS;
run;


proc sort data=GOS_07; by e306 rec_e313 YEAR; run;
options missing= ' ';
data Compressed;
update GOS_07(obs=0) GOS_07;
by e306 rec_e313 YEAR;
drop FLAG_ED PICK;
run;
options missing= '.';


data Compressed;
set Compressed;
by e306 rec_e313 YEAR;
if last.rec_e313 then last_GOS_index=1;
run;

* formatting;
data QILT_A;
set Compressed;
length sal_mod $5;

* zeropadding salary;
length padding $7;
padding = '000000';
substr(padding,8-length(SALARYA)) = SALARYA;

drop SALARYA;
if find(padding,'NA') ne 0 then padding = 'NA';
rename padding=SALARYA;

	* Having Salary in brackets;
	SAL_temp = SALARYA;
	if find(SAL_temp,'NA') eq 1 then SAL_temp = '.';
	Sal_temp2 = input(SAL_temp,8.); 

	if Sal_temp2 = 0 then SAL_mod = '000K';
	if 1 =< Sal_temp2 =< 10000 then SAL_mod = '010K';
	if 10001 =< Sal_temp2 =< 20000 then SAL_mod = '020K';
	if 20001 =< Sal_temp2 =< 30000 then SAL_mod = '030K';
	if 30001 =< Sal_temp2 =< 40000 then SAL_mod = '040K';
	if 40001 =< Sal_temp2 =< 50000 then SAL_mod = '050K';
	if 50001 =< Sal_temp2 =< 60000 then SAL_mod = '060K';
	if 60001 =< Sal_temp2 =< 70000 then SAL_mod = '070K';
	if 70001 =< Sal_temp2 =< 80000 then SAL_mod = '080K';
	if 80001 =< Sal_temp2 =< 90000 then SAL_mod = '090K';
	if 90001 =< Sal_temp2 =< 100000 then SAL_mod = '100K';
	if 100001 =< Sal_temp2 =< 110000 then SAL_mod = '110K';
	if 110001 =< Sal_temp2 =< 120000 then SAL_mod = '120K';
	if Sal_temp2 => 120001 then SAL_mod = '120K+';

	if find(SAL_mod,' ') eq 1 then SAL_mod = 'NA';

SALARY = input(SALARYA,8.);
QGOS_AGE = input(E913,2.);
QGOS_YEAR = input(YEAR,4.);

drop sal_temp Sal_temp2;
run;



*merge here;
proc sort data=QILT_A; by ANZSIC;
proc sort data=AITSL.ANZSIC out=ANZSIC(drop=category_ori); by ANZSIC;

options mergenoby=warn msglevel=I;
data QILT_B ANZSIC_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge QILT_A(IN=In1)  ANZSIC(IN=In2);
by ANZSIC;
if In1=1 then output QILT_B; 
if In2=1 then output ANZSIC_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; 
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;


proc datasets library=work;
save QILT_B;
run;

data QILT_C;
set QILT_B;
if ANZSIC_DES='' then ANZSIC_DES='NA';
if CATEGORY='' then CATEGORY='NA';
if CATEGORY_N='' then CATEGORY_N='NA';
if CATEGORY_B='' then CATEGORY_B='NA';
run;


%let indata = QILT_C;


proc sql noprint;
select nvar into :nvars
from dictionary.tables
where libname='WORK' and memname='QILT_C';
quit;

* ========= Actual shortening starts here =============;
data size(keep=_name_ _length_ _format_);
set &indata end=_eof;
array _c[*] _character_;
array _s[&nvars] _temporary_;
do _i_ = 1 to dim(_c);
_s[_i_]= max(_s[_i_],length(_c[_i_]));
end;

if _eof then do _i_=1 to dim(_c);
length _name_ $32;
_name_=vname(_c[_i_]);
_length_=_s[_i_];
_format_=cat(_length_, '.');
output;
end;
run;

proc print;
run;
filename tempfile temp;
options missing= ' ';
data _null_;
file tempfile;
if 0 then set &indata;
if _n_ eq 1 then do;
put 'retain ' (_all_) (=) ';' @;
_file_ = translate(_file_,' ','=');
put;
end;
set size;
put 'Length ' _name_ '$' _length_ ';';
put 'Format ' _name_ '$' _format_ ';';
put 'Informat ' _name_ '$' _format_ ';';
run;
options missing= '.';

data outdata;
%include tempfile / source2;
set &indata;
run;


proc datasets library=work;
save outdata;
run;

data AITSL.CS_QGOS_PREP;
set outdata;
run;

