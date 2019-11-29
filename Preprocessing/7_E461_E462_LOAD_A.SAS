* This file is for comparison later on (orignal HEIMS data vs Extracted data from Handbook), but it is not strictly necessary;
* It uses HEIMS Load to derive detailed field of education (dFOE) by each year and;
* summarise Mode of study by each year;
* _A means as is (original HEIMS data) and _M means Mined (Extracted data from Handbook);

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = HE_LOA_MOD; * Change this accordingly;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;
%let d_type = A; * data type == A mean as HEIMS (As is), M means Mined;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */


data temp(drop=linkageid snapshotid collectionperiod id submissionid);
set &indata;
run;

* having e307 here is important because it will need to merge all denr flags in load file, not just the first one;
proc sort data=temp; by e306 e313 referenceyear e307; run;
proc sort data=AITSL.HE_ENR_MOD(keep=e306 e313 referenceyear rec_e313 e307 comp_year e922 remove_denr) out=ENR; by e306 e313 referenceyear e307; run;

*adding cleaned rec_e313 into load file ;
options mergenoby=warn msglevel=I;
data temp_new ENR_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge temp(IN=In1)  ENR(IN=In2);
by e306 e313 referenceyear e307;
if In1=1 then output temp_new; * this is the file we want;
if In2=1 then output ENR_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

* clearing workspace;
proc datasets library=work;
save temp_new;
run;


* here we remove those that were removed in enrolment file - double enrolment and only take 2017;
data temp_new (drop=remove_denr);
set temp_new;
if rec_e313 ne ' ';
if remove_denr ne 1;
if referenceyear = '2017' then EXT_YEAR = referenceyear;

length padding $12;
padding = '0000000000';
e354=compress(e354,"~!@#$%^&*()_+-=\|/?.,><-+ ");
if e354 ne ' ' then substr(padding,13-length(e354)) = e354;
drop e354;
rename padding=e354;
run;



*merging with COURSE file;
proc sort data=temp_new out=temp; by e306 e307 referenceyear; run;
proc sort data=AITSL.HE_COU_MOD out=COU(drop=linkageid snapshotid collectionperiod id submissionid); by e306 e307 referenceyear; run;

*adding e461 e462 into load file ;
options mergenoby=warn msglevel=I;
data temp_new COU_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge temp(IN=In1)  COU(IN=In2);
by e306 e307 referenceyear;
if In1=1 then output temp_new; * this is the file we want;
if In2=1 then output COU_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

* clearing workspace;
proc datasets library=work;
save temp_new;
run;


**************************************************** Summarising Mode of Study by Year ***************************************;
data e329_temp(keep=e306 rec_e313 referenceyear Mode_Int Mode_Ext Mode_Mix);
set temp_new;
if e329 = 1 then Mode_Int = 1;
if e329 = 2 then Mode_Ext = 1;
if e329 = 3 then Mode_Mix = 1;
run;


* creating temp file to compress;
proc sort data=e329_temp;
by e306 rec_e313 referenceyear; 
run;

*compressing by course;
options missing= ' ';
data e329_compressed;
		sysecho "Compressing..";
update e329_temp(obs=0) e329_temp;
by e306 rec_e313 referenceyear; 
run;
options missing= '.';

data e329(drop=Mode_Int Mode_Ext Mode_Mix sum_range);
set e329_compressed;
sum_range = sum(of Mode_Int Mode_Ext Mode_Mix);

if Mode_Int = 1 and sum_range=1 then Mode_YR = 1;
if Mode_Ext = 1 and sum_range=1 then Mode_YR = 2;
if Mode_YR = . then Mode_YR = 3;
run;

********************************************************************************************************;



** making e46x as one field for ec pri sec ***;

* combining e461 and e462 into one;
data e461_e462_combination(drop= e461x e462x);
set temp_new; *temp_new;

if e461 in ('070101','070103','070105') then e461x=e461;
if e462 in ('070101','070103','070105') then e462x=e462;

if e461x = '' then e46x = e462;
if e462x = '' then e46x = e461;
if e461x ne '' and e462x ne '' and e461x ne e462x then e46x = '07010x';
if e461x = e462x then e46x = e461;

if e461 = '070100' and e462 in ('070107' '070109' '070111' '070113' '070115' '070117') then e46x = e462;
run;


*standardising all the "general" into 079999;
data e46x_temps;
set e461_e462_combination;
* if substr(new_e46x,1,2) eq '07' (Not doing this and putting 100101 into general Ed;
if e46x not in  ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then
e46x = '079999';
run;

proc sort data=e46x_temps; by e306  rec_e313 referenceyear;

data merged;
merge e46x_temps e329;
by e306 rec_e313 referenceyear;
run;


data AITSL.LCE_E461E462_&d_type;
set merged;
run;
