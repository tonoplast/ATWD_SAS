* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file is for additional logic added to HEIMS Enrolment data. This is not crucial, and can be omitted;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = HE_ENR_MOD; * Change this accordingly;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;

/* ============================================================================= */
/* =============================== Flagging Chessn ============================= */
/* ============================================================================= */


* This script will flag chessns that are in multiple institution;
* Unfortunately it is only doable for non-null chessns (non international and full paying);

data temp;
set &indata;
run;

*sorting by chessn & others;
proc sort data=temp; by chessn e306 ReferenceYear e313; run;

* counting by chessn and by e306 to see the differences;
data counting;
set temp;
by chessn e306 ReferenceYear;

	if first.chessn then count_chessn=1;
	else count_chessn+1;

	if first.e306 then count_e306=1;
	else count_e306+1;
run;

* flagging chessn count that is different from e306 --> students possibly studying elsewhere;
data test;
set counting;
if count_chessn ne count_e306;
flag_chessn = 'flag';
run;

* not including null because it is pointless;
proc sql;
create table flags as
select distinct chessn, flag_chessn
from test
where CHESSN not in ('NULL')
;
quit;


* Merging it to enrolment file;
proc sql;
create table Enr_order as
select *
from temp
order by chessn;
quit;

* sorting flag table;
proc sql;
create table flags_order as
select *
from flags
order by chessn;
quit;

*merging here;
options mergenoby=warn msglevel=I;
data Enr_order_new flags_order_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge Enr_order(IN=In1)  flags_order(IN=In2);
by chessn;
if In1=1 then output Enr_order_new; * this is the file we want;
if In2=1 then output flags_order_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1; *we want to make sure NOmatch1 has no data;
if (In1=1 and In2=0) then output NOmatch2; 
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;



* clearing workspace;
proc datasets library=work;
save Enr_order_new;
run;

*doing this again when rec_chessn to make sure (same procedure);

proc sort data=Enr_order_new; by rec_chessn e306 ReferenceYear e313; run;


data counting;
set Enr_order_new;
by rec_chessn e306 ReferenceYear;

	if first.rec_chessn then count_rec_chessn=1;
	else count_rec_chessn+1;

	if first.e306 then count_e306=1;
	else count_e306+1;
run;

data test;
set counting;
if count_rec_chessn ne count_e306;
flag_rec_chessn = 'flag';
run;


proc sql;
create table flags as
select distinct rec_chessn, flag_rec_chessn
from test
where rec_CHESSN not in ('NULL')
;
quit;

proc sql;
create table Enr_order as
select *
from Enr_order_new
order by rec_chessn;
quit;


proc sql;
create table flags_order as
select *
from flags
order by rec_chessn;
quit;


*merging here;
options mergenoby=warn msglevel=I;
data Enr_order_new_2 flags_order_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge Enr_order(IN=In1)  flags_order(IN=In2);
by rec_chessn;
if In1=1 then output Enr_order_new_2; * this is the file we want;
if In2=1 then output flags_order_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1; *we want to make sure NOmatch1 has no data;
if (In1=1 and In2=0) then output NOmatch2; 
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

* don't need to worry about whether it's just chessn or rec_chessn, so I am combining it into flag_chessn here;
data all_flag(drop=flag_rec_chessn);
set enr_order_new_2;
if flag_chessn ne flag_rec_chessn then flag_chessn = flag_rec_chessn;
run;

data temp;
set all_flag;
run;

** decided to remove certain steps here -- commented out and not used **;

* writing it into AITSL folder;
data AITSL.HE_ENR_MOD;
set temp;
run;

