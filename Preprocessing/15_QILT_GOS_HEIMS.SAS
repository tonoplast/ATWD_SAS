* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file is used to merge QILT GOS data with Enrolment data;
* We are using the latest GOS (if someone has taken more than 1);



libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_QGOS_PREP; * Change this accordingly;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */

%let startyear = 2005;
%let thisyear = 2017;
%let ext_year = 2017;
%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;
%let glvls = UG PG; 


data QGOS(drop=chessn GOSIDZ GOSID_A ANZSIC_DES CATEGORY_N CATEGORY_B CATEGORY_NEW);
set &indata;
run;

* selecting _B variables for deletion;
proc sql noprint;
select name into: Major_B separated by ' ' from dictionary.columns where libname='WORK' and memname='QGOS' and name?'_B';
quit;

** only selecting last GOS data and single (EDUCATION) data;
data QGOS_A;
set QGOS;
if last_GOS_index=1;
drop &MAJOR_B E913;
QGOS=1;
run;


* loading HEIMS file -- only getting last person data;
data ENR;
set AITSL.CS_ENR_COU_ALL_&d_type;
if last_index_person = 1;
run;


proc sort data=QGOS_A; by e306 rec_e313; run;
proc sort data=ENR; by e306 rec_e313; run;

data merging;
merge ENR (in=in1) QGOS_A (in=in2);
by e306 rec_e313;
if in1;
run;


* adding variables to track if they work at the same state as residence / university;
data merging_all;
set merging;

*1=same 2=diff 3=home 4=work 5=both dunno;
if emp_state ne '.' and home_state = emp_state then same_state_HJ = 1; *same job state as home state;
if emp_state ne '.' and home_state ne emp_state then same_state_HJ = 2; *diff job state from home state;
if home_state not in ('NULL') and emp_state = 'NA' then same_state_HJ = 3; *home state only;
if home_state in ('NULL') and emp_state ne 'NA' then same_state_HJ = 4; *work state only;
if home_state in ('NULL') and emp_state eq 'NA' then same_state_HJ = 5; *dunno both;

*1=same 2=diff 3=UNI 4=work 5=both dunno;
if emp_state ne '.' and UNI_STATE = emp_state then same_state_UJ = 1; *same job state as UNI state;
if emp_state ne '.' and UNI_STATE ne emp_state then same_state_UJ = 2; *diff job state from home state;
if UNI_STATE not in ('MUL') and emp_state = 'NA' then same_state_UJ = 3; *UNI state only;
if UNI_STATE in ('MUL') and emp_state ne 'NA' then same_state_UJ = 4; *work state only;
if UNI_STATE in ('MUL') and emp_state eq 'NA' then same_state_UJ = 5; *dunno both;

if QGOS = . then QGOS = 2;
run;


data AITSL.CS_HEIMS_QGOS_&d_type;
set merging_all;
run;

