* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file will attemp to clean and standardise HEIMS enrolment file using basic probability;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = HE_ENR; * Change this accordingly;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;

/* ============================================================================= */
/* ======================= Start Modifying / Cleaning ========================== */
/* ============================================================================= */


* data into temp, e307 upcase;
* zero-padding e327 e369 e493;
* Converting ZZZZs into 'NULL' in CHESSN;

data temp (drop=id linkageid snapshotid submissionid);
set &indata;

e307 = upcase(e307);
length e327 $2; e327 = put(input(e327,best2.),z2.);
length e369 $3;
e369 = put(input(e369,best3.),z3.);
length e493 $6;
e493 = put(input(e493,best6.),z6.);
if find(chessn,'zzz','i') ne 0 or find(chessn,'nul','i') ne 0 then chessn='NULL';

run;


******************************************;
*** Process of harmonising student ID ****;
******************************************;

* e306 - 1019 (drop first 2 digits & last digit, adding '1' in front - data changed until 2006 (something must have happened in 2007));
data e313_fix;
set temp;
aa = find(e306,'1019') ne 0;
bb = find(referenceyear,'2005') ne 0;
cc = find(referenceyear,'2006') ne 0;
aabb = aa and bb;
aacc = aa and cc;
all = aabb or aacc;
len=length(e313);
if all = 1 then e313 = cat('1',substr(e313,3,length(e313)-3));
drop aa bb cc aabb aacc all len;
run;

* zeropadding everything in e313 by 10 zeros;
data e313_fix;
set e313_fix;
length padding $10;
padding = '0000000000';
substr(padding,11-length(e313)) = e313;
drop e313;
rename padding=e313;
run;

* fixing some other e313 issues;
data e313_fix;
set e313_fix;
if e306 = '4334' and substr(e313,1,4) = '2005' or
e306 = '4334' and substr(e313,1,4) = '2006' or
e306 = '4334' and substr(e313,1,4) = '2007' then
substr(e313,1,4) = '0000';

if e306 = '4334' and find(e313,'TCA')
and e313 = 'TCA1112894' then e313 ='0TCA112894';

* just getting rid of 0TCA as it causes a lot of trouble;
if e306 = '4334' and find(e313,'0TCA') then substr(e313,1,4) = '0000';
run;

*fixing some entry error (probably);
data e313_fix;
set e313_fix;
if e369 = '800' then e369 = '080';
run;

***********************;
******* weighted ******;
***********************;

* clearing workspace;
proc datasets library=WORK;
save e313_fix;
run;

* Trying a weighted fix. (1) How long has it been (e.g. 2005 will have lower % weight than 2016)
* and (2) How many times does it occur (e.g. YOB 1991 1991 1991 1992 -> 1991 will have higher % weight than 1992)

* This is Year differences - giving more weights to latest year (log10 to scale them evenly);

proc sort data= e313_fix; by e306 e313 chessn; run;


data weighted_fix;
set e313_fix; *counting_x_more;
by e306 e313 ; 

YearChange = log10(1/(collectionperiod - referenceyear)*100); *closest to collectionperiod gets more point (logged because it was weighing too much on the closest year);

if first.e313 then sumYC = 0;
sumYC + YearChange; *summing the year change (for scoring);

run;

* This step outputs the last value (sum of all) within e306 e313 and to do calculation later;
data weighted_fix;
do _n_ = 1 by 1 until(last.e313);
set weighted_fix(rename=(sumYC=lastYC));
by e306 e313;
end;
do _n_ = 1 to _n_;
set weighted_fix;
output;
end;
run;

* Calculates the percentage based on the sum --> 1st category;
data weighted_fix;
set weighted_fix;
percentYC = (YearChange/lastYC)*100;
run;

data clean_data;
set weighted_fix;
drop lastYC sumYC YearChange; *percentYC (keeping this for now);
run;



******************************************************;
********** Doing different variables here ************; 
******************************************************;


* clearing workspace;
proc datasets library=WORK;
save CLEAN_DATA e313_fix weighted_fix;
run;

* Processing order: YoB, e315 (gender - this will only be used for linking purposes), e316 (ATSI), e346 (country of birth);
%let vars = YoB e315 e316 e346;
%let k=%sysfunc(countw(&vars,' ')); *number of loop depending on var numbers above;

%macro macrothis; *macro for looping through;

%do i = 1 %to &k.;
%global e&i.;
%let e&i.=%scan(&vars,&i.,' ');

*variable names and save names;
%let insertvar = &e&i.; 
%let prefix = rec_;
%let savevar = &prefix&insertvar;


proc sql;
create table weighted_fix_temp as
select *, count(*) as count
from clean_data
group by e306,e313,&insertvar;
quit;

* Summing them as above;
data weighted_fix;
set weighted_fix_temp;
by e306 e313 ; 

if first.e313 then sumcount = 0;
sumcount + count;
run;

* Getting last value as above;
data weighted_fix;
do _n_ = 1 by 1 until(last.e313);
set weighted_fix(rename=(sumcount=lastSC));
by e306 e313;
end;
do _n_ = 1 to _n_;
set weighted_fix;
output;
end;
run;

* Calculating percentage as above --> 2nd category & makes decision score;
data weighted_fix;
set weighted_fix;
percentSC = (count/lastSC)*100;

if &insertvar = e315 and find(&insertvar,'x','i') ne 0 then percentYC = 0; *reducing chance for anyone with X (for linking purpose only);

decisionvar = (percentYC + percentSC) / 2; * 50-50 weight;
run;

proc sort data=weighted_fix out= weighted_fix_sort;
by e306 e313 decisionvar;
run;

data weighted_fix_sort;
do _n_ = 1 by 1 until(last.e313);
set weighted_fix_sort(rename=(&insertvar=&savevar));
by e306 e313 decisionvar;
end;
do _n_ = 1 to _n_;
set weighted_fix_sort;
output;
end;
run;

* clearing workspace;
proc datasets library=work;
save weighted_fix_sort e313_fix weighted_fix;
run;

data clean_data;
set weighted_fix_sort;
drop count decisionvar lastSC percentSC sumcount; *percentYC (keeping this for now);
run;

%end;
%mend;
%macrothis;


* clearing workspace;
proc datasets library=WORK;
save clean_data e313_fix;
run;


******************************************************;
****************** Doing CHESSN here *****************; 
******************************************************;

*variable names and save names;
%let insertvar = chessn; 
%let prefix = rec_;
%let savevar = &prefix&insertvar;


proc sql;
create table weighted_fix_temp as
select *, count(*) as count
from clean_data
group by e306,e313, rec_yob, &insertvar;
quit;

* Summing them as above;
data weighted_fix;
set weighted_fix_temp;
by e306 e313 rec_yob; 

if first.e313 then sumcount = 0;
sumcount + count;
run;

* Getting last value as above;
data weighted_fix;
do _n_ = 1 by 1 until(last.e313);
set weighted_fix(rename=(sumcount=lastSC));
by e306 e313 rec_yob;
end;
do _n_ = 1 to _n_;
set weighted_fix;
output;
end;
run;

* Calculating percentage as above --> 2nd category & makes decision score;
data weighted_fix;
set weighted_fix;
percentSC = (count/lastSC)*100;

if find(&insertvar,'nul','i') ne 0 then percentYC = 0 and percentSC = 0; *reducing chance for anyone with null (for chessn);

decisionvar = (percentYC + percentSC) / 2; * 50-50 weight;
run;

proc sort data=weighted_fix out= weighted_fix_sort;
by e306 e313 rec_yob decisionvar;
run;

data weighted_fix_sort;
do _n_ = 1 by 1 until(last.e313);
set weighted_fix_sort(rename=(&insertvar=&savevar));
by e306 e313 rec_yob decisionvar;
end;
do _n_ = 1 to _n_;
set weighted_fix_sort;
output;
end;
run;


* clearing workspace;
proc datasets library=work;
save weighted_fix_sort e313_fix weighted_fix;
run;

data clean_data;
set weighted_fix_sort;
drop count decisionvar lastSC percentSC sumcount; *percentYC (keeping this for now);
run;


* clearing workspace;
proc datasets library=WORK;
save clean_data e313_fix;
run;





******************************************************;
****************** Doing e313 here *******************; 
******************************************************;

proc sort data= clean_data; by e306 rec_chessn rec_yob e313; run;


*variable names and save names;
%let insertvar = e313; 
%let prefix = rec_;
%let savevar = &prefix&insertvar;

*e315 e316 e346;
proc sql;
create table weighted_fix_temp as
select *, count(*) as count
from clean_data
group by e306,rec_chessn, rec_yob, &insertvar;
quit;

* Summing them as above;
data weighted_fix;
set weighted_fix_temp;
by e306 rec_chessn rec_yob; 

if first.rec_chessn then sumcount = 0;
sumcount + count;
run;

* Getting last value as above;
data weighted_fix;
do _n_ = 1 by 1 until(last.rec_chessn);
set weighted_fix(rename=(sumcount=lastSC));
by e306 rec_chessn rec_yob;
end;
do _n_ = 1 to _n_;
set weighted_fix;
output;
end;
run;

* Calculating percentage as above --> 2nd category & makes decision score;
data weighted_fix;
set weighted_fix;
percentSC = (count/lastSC)*100;
decisionvar = (percentYC + percentSC) / 2; * 50-50 weight;
run;

proc sort data=weighted_fix out= weighted_fix_sort;
by e306 rec_chessn rec_yob  decisionvar;
run;

data weighted_fix_sort;
do _n_ = 1 by 1 until(last.rec_chessn);
set weighted_fix_sort(rename=(&insertvar=&savevar));
by e306 rec_chessn rec_yob  decisionvar;
end;
do _n_ = 1 to _n_;
set weighted_fix_sort;
output;
end;
run;



* clearing workspace;
proc datasets library=work;
save weighted_fix_sort e313_fix weighted_fix;
run;

data clean_data;
set weighted_fix_sort;
drop count decisionvar lastSC percentSC sumcount; *percentYC (keeping this for now);

* Making international have their own e313 as before;
if chessn = 'NULL' then rec_e313 = e313;

run;



* here we do removing double enrolments - flag;
proc sort data=clean_data; by e306 rec_e313 referenceyear e307; run;

data Denr;
set clean_data;
	if rec_e313 eq lag(rec_e313) and referenceyear = lag(referenceyear) then DoubleEnr = 1;
run;


proc sql;
create table u_denr as
select distinct e306, rec_e313
from Denr
where doubleEnr = 1;
quit;


*merging to flag the individual;
proc sort data=u_denr; by e306 rec_e313; run;
proc sort data=clean_data out=ENR; by e306 rec_e313; run;

options mergenoby=warn msglevel=I;
data u_denr_new ENR_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge u_denr(IN=In1)  ENR(IN=In2);
by e306 rec_e313;
if In1=1 then output u_denr_new; * this is the file we want;
if In2=1 then output ENR_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;



proc sort data=u_denr_new; by e306  rec_e313 comp_year ; run;

data denr_again;
set u_denr_new;
	if rec_e313 eq lag(rec_e313) and referenceyear = lag(referenceyear) then DoubleEnr = 1;
run;


data denr_A;
set denr_again;
set denr_again(firstobs=2 keep=DoubleEnr rename=(DoubleEnr=next_DE))
	denr_again(obs=1 drop=_all_); 
	next_DE = ifn(last.DoubleEnr, 1, next_DE);
	output;
run;

data denr_B;
set denr_A;
if next_de = 1 then doubleEnr = 1;
drop next_de;
run;




proc sort data= denr_b; by e306  rec_e313  e313 ReferenceYear e307; run;

data weighted_fix_1;
set denr_B; *counting_x_more;
by e306  rec_e313  e313 ReferenceYear; 
if first.rec_e313 then sums1 = 0;
sums1 + 1; *summing the year change (for scoring);
run;

data weighted_fix_2;
set weighted_fix_1;
by e306  rec_e313 e313 ReferenceYear; 
if first.e313 then sums2 = 0;
sums2 + 1;
run;


proc sort data= weighted_fix_2; by e306  rec_e313  e307 ReferenceYear ; run;
data weighted_fix_3;
set weighted_fix_2;
by e306  rec_e313 e307 ReferenceYear; 
if first.e307 then sums3 = 0;
sums3 + 1;
run;


proc sort data= weighted_fix_3; by e306  rec_e313  e313 ReferenceYear e307; run;
* for rec_e313;
data weighted_fix_1_A;
do _n_ = 1 by 1 until(last.rec_e313);
set weighted_fix_3(rename=(sums1=lasts1));
by e306  rec_e313  e313 ReferenceYear e307; 
end;
do _n_ = 1 to _n_;
set weighted_fix_3;
output;
end;
run;


proc sort data= weighted_fix_1_A; by e306  rec_e313  e313 ReferenceYear e307; run;

*for e313;
data weighted_fix_2_A;
do _n_ = 1 by 1 until(last.e313);
set weighted_fix_1_A(rename=(sums2=lasts2));
by e306  rec_e313  e313 ReferenceYear e307; 
end;
do _n_ = 1 to _n_;
set weighted_fix_1_A;
output;
end;
run;


proc sort data= weighted_fix_2_A; by e306  rec_e313  e307 ReferenceYear ; run;

*for e307;
data weighted_fix_3_A;
do _n_ = 1 by 1 until(last.e307);
set weighted_fix_2_A(rename=(sums3=lasts3));
by e306  rec_e313   e307 ReferenceYear ; 
end;
do _n_ = 1 to _n_;
set weighted_fix_2_A;
output;
end;
run;



* Calculates the percentage based on the sums and lasts -- using 3 different things here (rec_e313 e313 e307);
data weighted_fix_last ;
set weighted_fix_3_A;
percents = ((lasts2/lasts1 + lasts3/lasts1)/2)*100;
run;

proc sort data=weighted_fix_last(drop= lasts1 lasts2 lasts3 sums1 sums2 sums3) out= weighted_fix_sort;
by e306 rec_e313  descending doubleenr percents;
run;

* designating remove here;
data final;
set weighted_fix_sort;
by e306 rec_e313  descending doubleenr percents;
if first.rec_e313 then remove_Denr=1;
run;



*merging back;
proc sort data=clean_data; by e306 rec_e313 referenceyear; run;
proc sort data=final; by e306 rec_e313 referenceyear; run;


options mergenoby=warn msglevel=I;
data clean_data_new final_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge clean_data(IN=In1)  final(IN=In2);
by e306 rec_e313 referenceyear;
if In1=1 then output clean_data_new; * this is the file we want;
if In2=1 then output final_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; *we want to make sure NOmatch2 has no data;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;



* writing it into AITSL folder;
data AITSL.HE_ENR_MOD(drop=percentYC percents doubleEnr);
set clean_data_new;
run;






