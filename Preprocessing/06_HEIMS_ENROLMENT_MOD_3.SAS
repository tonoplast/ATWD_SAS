* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file attemps to fix missing / misplaced commencements in HEIMS Enrolment data;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let thisyear = 2017;
%let d_type = M;
options missing= '.';

proc sort data=AITSL.HE_ENR_MOD(keep=e306 e307 rec_e313  referenceyear comp_year e922 e313 e330 remove_denr) out=ENR; by e306 rec_e313 referenceyear; run;

* here we remove those that were removed in enrolment file - double enrolment;
data ENR;
set ENR;
if rec_e313 ne ' ';
if remove_denr ne 1;
drop remove_denr;
run;

proc sql noprint;
select distinct referenceyear into: LastYear 
from ENR
having referenceyear=max(referenceyear);
quit;

*adding Graduate level information here (STUDY TYPE CODE);
proc sort data=ENR; by e306 referenceyear e307; run;
proc sort data=aitsl.he_cou_mod out=COU(keep=e306 referenceyear e307 e310); by e306 referenceyear e307; run;

data ENR_NEW;
merge ENR(in=in1) COU(in=in2);
by  e306 referenceyear e307;
if in1;
run;

* just catagorising into Undergrade (UG) or postgrade (PG) here;
data ENR;
format GLVL_YR $3.;
set ENR_NEW;
if E310 in (08,09,10,13,20,21,22) then GLVL_YR = "UG";
else if E310 in (04,06,07,11,12,14) then GLVL_YR = "PG";
run;


*hashing by e307;
proc sort data=ENR; by e306 rec_e313 ReferenceYear e307; run;

data hashing_1(drop=rc _:);
declare hash h();
h.definekey("rec_e313","e307");
h.definedata("e307_order");
h.definedone();
_want=0;

do until(last.rec_e313);
set ENR;
by e306 rec_e313 ReferenceYear;
if h.find() ne 0 then do;
	_want+1;
	e307_order=_want;
	rc=h.add();
end;
output;
end;
run;


proc sort data=hashing_1; by e306 rec_e313 referenceyear e307; run;
data hashing_x;
set hashing_1;
by e306 rec_e313 referenceyear e307;
if first.rec_e313 then e307_RY_order=1;
if rec_e313=lag(rec_e313) and e307 ne lag(e307) then e307_RY_order+1;
if e307_RY_order ne e307_order then e307_diff=1;
run; 


proc sort data=hashing_x; by e306 rec_e313 referenceyear; run;
data hashing_A;
set hashing_x;
by e306 rec_e313 referenceyear;
if first.rec_e313 then record_count=0;
record_count+1;
run; 

*filling down record_count of the biggest number;
proc sort data=hashing_A; by e306 rec_e313 descending record_count; run;
data hashing_B;
set hashing_A;
retain temp;
by e306 rec_e313 descending record_count;
if first.rec_e313 then last_record_count=record_count;
if first.rec_e313 then temp=.;
if last_record_count ne . then temp=last_record_count;
else if last_record_count=. then last_record_count=temp;
drop temp;
run;


*counting how many starts per person;
proc sort data=hashing_B; by e306 rec_e313 e922 referenceyear; run;
data logic_A;
set hashing_B;
by e306 rec_e313 e922 referenceyear;
if first.rec_e313 then count_e922=0;
if e922=1 then count_e922+1;
run;

*filling down count_e922 of the biggest number;
proc sort data=logic_A; by e306 rec_e313 descending count_e922 descending referenceyear; run;
data logic_B;
set logic_A;
retain temp;
by e306 rec_e313 descending count_e922 descending referenceyear;
if first.rec_e313 then last_count_e922=count_e922;

if first.rec_e313 then temp=.;
if last_count_e922 ne . then temp=last_count_e922;
else if last_count_e922=. then last_count_e922=temp;
drop temp;
run;

*finding first e922 regardless;
proc sort data=logic_B; by e306 rec_e313 referenceyear; run;
data logic_C;
set logic_B;
by e306 rec_e313 referenceyear;
retain temp;
if first.rec_e313 then first_e922=e922;

if first.rec_e313 then temp=.;
if first_e922 ne . then temp=first_e922;
else if first_e922=. then first_e922=temp;
drop temp;
run;


*counting how many completions per person;
proc sort data=logic_C; by e306 rec_e313 comp_year; run;
data logic_D;
set logic_C;
by e306 rec_e313 comp_year;
if first.rec_e313 then count_comp=0;
if comp_year ne '.' then count_comp+1;
run;

*filling down the biggest number for count_comp;
proc sort data=logic_D; by e306 rec_e313 descending count_comp; run;
data logic_E;
set logic_D;
retain temp;
by e306 rec_e313 descending count_comp;
if first.rec_e313 then last_count_comp=count_comp;

if first.rec_e313 then temp=.;
if last_count_comp ne . then temp=last_count_comp;
else if last_count_comp=. then last_count_comp=temp;
drop temp;
run;


*finding last comp_year regardless;
proc sort data=logic_E; by e306 rec_e313 descending referenceyear; run;
data logic_F;
set logic_E;
by e306 rec_e313 descending referenceyear;
retain temp;
if first.rec_e313 and comp_year ne '.' then last_comp_year=input(comp_year,4.);
if first.rec_e313 then temp=.;
if last_comp_year ne . then temp=last_comp_year;
else if last_comp_year=. then last_comp_year=temp;
drop temp;
run;


* some logic to keep good ones;
proc sort data=logic_F; by e306 rec_e313 referenceyear; run;
data logic_G;
set logic_F;
ori_e922 = e922;
*first appear has start and last appear has end and it's just one of each;
if last_count_comp=1 and last_count_e922=1 and first_e922=1 and last_comp_year ne . then KEEP=1;
*first appear has no start but last appear has end and it's just one of each;
if last_count_comp=1 and last_count_e922=0 and first_e922=2 and last_comp_year ne . then KEEP=1;
*first appear has start but last appear has no end and it's just one of each;
if last_count_comp=0 and last_count_e922=1 and first_e922=1 and last_comp_year=. then KEEP=1;
*if no start and no completion then no problem;
if last_count_e922=0 and last_count_comp=0 then KEEP=1;
*if no completion then no problem;
if last_count_comp=0 then KEEP=1; 
*if only one record then it's all good;
if last_record_count=1 then KEEP=1;

run;

* Counting by courses;
proc sort data=logic_G; by e306 rec_e313  referenceyear ; run;

data FIX_COMP_A;
set LOGIC_G;
by e306 rec_e313 referenceyear;
	* counting potentially by course - whether drop or not;
	if first.rec_e313 then count=0;
	if first.rec_e313 and e922='2' then count=1;
	if e922 = '1' then count+1;
	if count=2 then x=1; * for fixing comp;
run;


*flagging all record with x=1 here;
proc sort data=FIX_COMP_A; by e306 rec_e313 descending x ; run;
data FIX_COMP_B;
set FIX_COMP_A;
by e306 rec_e313 descending x;
retain fix_comp_1;
if first.rec_e313 then fix_comp_1=.;
if x ne . then fix_comp_1=x;
drop x;
run;


* fixing completion year when it is in other places;
proc sort data=FIX_COMP_B; by e306 rec_e313 count e922 referenceyear ; run;

data FIX_COMP_C;
set FIX_COMP_B;
by e306 rec_e313 count e922 referenceyear;
ori_comp_year = comp_year;
* (1) number of start must be the same as number of start (2) for more than 2 courses;
if last_count_e922 = last_count_comp and last_count_comp ge 2 then do; 
if last.count then new_comp_year = referenceyear;
if new_comp_year ='' then new_comp_year='.';
comp_year = new_comp_year;
end;
drop new_comp_year;
run;



************************ this was used to count how many N *********************************;
/*data checks;*/
/*set fix_comp_c;*/
/*if comp_year ne ori_comp_year;*/
/*run;*/
/**/
/*proc sql;*/
/*create table number as*/
/*select distinct e306, rec_e313*/
/*from checks;*/
/*quit;*/
********************************************************************************************;


** here we fix e922 ***;

************************************ ;
** must do fill down using KEEP=1 ** ;
************************************ ;

data FIX_e922_A;
set FIX_COMP_C;
*if embedded honours then make it continue (e922 is not 1 anymore) and flag them;
if keep ne 1 and e307='HEDK070100' and last_count_e922=2 and e922=1 then do;
e922=2;Emb_Hons=1; keep=1; end;
run;




* giving a start after completion date;
data FIX_e922_B(drop=fixing fixing_a);
length fixing fixing_A $1.;
set FIX_e922_A;
if keep ne 1 then do;
if comp_year ne '.' and referenceyear ne '.' then fixing=1;
fixing_A=lag(fixing);
if record_count=1 then fixing_A='';
if fixing_A eq '1' then e922 = fixing_A;
end;
run;

proc datasets library=work;
save FIX_e922_B;
run;

*** used this in the tech report ***;
data aitsl.fix_start_year;
set FIX_e922_B;
run;
************************************;
