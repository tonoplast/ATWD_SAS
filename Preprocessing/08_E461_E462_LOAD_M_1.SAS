* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file uses discipline information and course name to derive detailed field of education (dFOE);
* that had not already been assigned. Similar to LOAD_A script, it will also summarise Mode of study;
* It creates LOAD_M file to be used for analysis. This file is part 1;

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
%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */


* adding curriculum information based on discipline code (e464);
data temp(drop=linkageid snapshotid collectionperiod id submissionid);
set &indata;
if e464 = '070301' then CURR = 1;
if e464 = '070303' then CURR = 2;
if CURR = . then CURR = 9;
run;


* having e307 here is important because it will need to merge all denr flags in load file, not just the first one;
proc sort data=temp; by e306 e313 referenceyear e307; run;
proc sort data=AITSL.HE_ENR_MOD(keep=e306 e313 referenceyear rec_e313 e307 remove_denr) out=ENR; by e306 e313 referenceyear e307; run;

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



* here we remove those that were removed in enrolment file - double enrolment;
data temp_new (drop=remove_denr);
set temp_new;
if rec_e313 ne ' ';
if remove_denr ne 1;
if referenceyear = '2017' then EXT_YEAR = referenceyear;
run;

*merging with COURSE file;
proc sort data=temp_new out=temp; by e306 e307 referenceyear; run;
proc sort data=AITSL.HE_COU_MOD out=COU(drop=linkageid snapshotid collectionperiod id submissionid
Trading_Name e306_name e306_abbrev_name e306_eff_from_date e306_eff_to_date e310_des new_e310_des e312 state e306_type HEP_TYPE e350); by e306 e307 referenceyear; run;

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


data tempx (keep= e306 rec_e313 referenceyear e461 e462 e464 e329);
set temp_new;
run;

data temp_e308(keep=e306 rec_e313 e308 referenceyear);
set temp_new;
run;


**************************************************** Summarising Mode of Study by Year ***************************************;
data e329_temp(keep=e306 rec_e313 referenceyear Mode_Int Mode_Ext Mode_Mix);
set tempx;
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
data e461_e462_combination(drop= e461x e462x e329);
set tempx; *temp_new;

if e461 in ('070101','070103','070105') then e461x=e461;
if e462 in ('070101','070103','070105') then e462x=e462;

if e461x = '' then e46x_ori = e462;
if e462x = '' then e46x_ori = e461;
if e461x ne '' and e462x ne '' and e461x ne e462x then e46x_ori = '07010x';
if e461x = e462x then e46x_ori = e461;

if e461 = '070100' and e462 in ('070107' '070109' '070111' '070113' '070115' '070117') then e46x_ori = e462;

run;


* if e46x_ori is not one of the list and found in e464 with conditions;
data e46x_temps(drop=e46x_i e308 e461 e462 e464);
set e461_e462_combination;
new_e46x=e46x_ori;
e46x_i = '070101 070103 070105 07010x';
if not find(e46x_i, e46x_ori) ge 1 and find(e46x_i, e464) ge 1 then new_e46x=e464;
if new_e46x in ('070100','070199','') and not find(e46x_i, e46x_ori) ge 1 and substr(e464,1,2) eq '07' then new_e46x=e464;
run;


*standardising all the "general" into 079999;
data e46x_temps;
set e46x_temps;
* if substr(new_e46x,1,2) eq '07' (Not doing this and putting 100101 into general Ed;
if new_e46x not in ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then
new_e46x = '079999';
run;


* getting unique ones to make it a little faster;
proc sql;
create table e46x_temps_2 as
select distinct *
from e46x_temps;
quit;


proc sql noprint;
create table these as
select distinct new_e46x
from e46x_temps_2
where new_e46x is not null;
quit;


data catting;
length new_e46x $7.;
set these;
new_e46x = cats('e',new_e46x);
run;


proc transpose data=catting out=cattingx(drop=_name_);
id new_e46x;
run;


data new_e46x_temps;
set e46x_temps_2 cattingx;
run;

proc sql noprint;
select * into: varnames separated by ' '
from catting;
select count(*) into: counting separated by ' '
from catting;
quit;


* allocating appropriate data;
data arraythis(drop=new_e46x);
set new_e46x_temps;
array x &varnames;
do over x;
if find(vname(x),new_e46x) ge 1 then x=1;
end;
run;

proc sort data=arraythis out=logics; by e306 rec_e313 referenceyear; run;

*compressing;
options missing= ' ';
data compressed;
update logics(obs=0) logics;
by e306 rec_e313 referenceyear;
run;
options missing= '.';


*getting sum;
data compressed;
set compressed;
array x &varnames;
sum_range = sum(of &varnames);
run;


*if it's just one then have them as the new category -- now it's e46x;
%macro logic_A;
data logic_A;
set compressed;
%do i = 1 %to %sysfunc(countw(&varnames));
%let varname = %scan(&varnames, &i);
if sum_range=1 and &varname=1 then e46x=strip(tranwrd(vname(&varname),'e',''));
%end;
run;
%mend;
%logic_A;


%let dropvarnames = e070000 e070100 e070101 e070103 e070105 e070107 e070109 e070111 e070113 e070115 e070117 e079999 e07010x;


*putting them into either EC PRI SEC if it's mixed with other category;
*also adding mixed category;
data logic_B(drop=&dropvarnames sum_range);
set logic_A;
if sum_range not in (1,.) and e070103 eq . and e070105 eq . and e070101=1 then e46x='070101'; *EC when others;
if sum_range not in (1,.) and e070101 eq . and e070105 eq . and e070103=1 then e46x='070103'; *PRI when others;
if sum_range not in (1,.) and e070101 eq . and e070103 eq . and e070105=1 then e46x='070105'; *SEC when others;

if e070101 eq 1 and e070103 eq 1 then e46x='07010x'; *MIXED;
if e070101 eq 1 and e070105 eq 1 then e46x='07010x'; *MIXED;
if e070103 eq 1 and e070105 eq 1 then e46x='07010x'; *MIXED;

* Order: (1) 070115 (EALD), (2) 070113 (Special Ed), (3) 070107 (Teacher Librarianship), (4) 070109 (VET), (5) 070111 (Higher Ed),
(6) 070117 (Nursing -- not found);
*(1)*; if e46x eq '' and e070115 = 1 then e46x = '070115';
*(2)*; if e46x eq '' and e070113 = 1 then e46x = '070113';
*(3)*; if e46x eq '' and e070107 = 1 then e46x = '070107';
*(4)*; if e46x eq '' and e070109 = 1 then e46x = '070109';
*(5)*; if e46x eq '' and e070111 = 1 then e46x = '070111';
*(6)*; if e46x eq '' and e070117 = 1 then e46x = '070117';
run;


*merging with e461_e462_combination;
proc sort data=e461_e462_combination; by e306 rec_e313 referenceyear;
proc sort data=temp_e308; by e306 rec_e313 referenceyear; 
data merging_all;
merge e461_e462_combination logic_B temp_e308;
by e306 rec_e313 referenceyear;
run;


* Using some characters to filter into dFOE for those that had not been assigned;
data final_data(keep=e306 rec_e313 referenceyear e46x_ori e46x e46x_step1 Mode_YR MAJOR CURR);
set merging_all;
e46x_step1=e46x;
if e46x not in ('070101','070103','070105','07010x') then do;
if prxmatch('m/EARLY|CHILD/oi',e308) > 0 then EC=1;
if prxmatch('m/PRI|R-7/oi',e308) > 0 then PRI=1;
if prxmatch('m/SEC/oi',e308) > 0 then SEC=1;
if prxmatch('m/MID|MYS|M,PR|M,SEC|K-10|K-12|P-10|P-12|1-10/oi',e308) > 0 then MID=1;
sum_range = sum(of EC PRI SEC MID);
if sum_range = 1 and EC=1 then e46x = '070101';
if sum_range = 1 and PRI=1 then e46x = '070103';
if sum_range = 1 and SEC=1 then e46x = '070105';
if MID=1 then e46x = '07010x';
if sum_range not in (1,.) then e46x = '07010x';
end;
run;

*merging with load file;
proc sort data=temp_new; by e306 rec_e313 referenceyear;

data save_this;
merge temp_new final_data e329;
by e306 rec_e313 referenceyear;
e46x_step2 = e46x;

*standardising all the "general" into 079999;
if e46x_ori not in  ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then e46x_ori = '079999';
if e46x_step1 not in  ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then e46x_step1 = '079999';
if e46x_step2 not in  ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then e46x_step2 = '079999';
if e46x not in  ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then e46x = '079999';
run;


data AITSL.LCE_E461E462_&d_type._TEMP;
set save_this;
run;

