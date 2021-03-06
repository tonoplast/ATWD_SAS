* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_HE_LOAD_PRGC data from step 17, which was summarised by YEAR, and summarise it by Course (COU);


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_HE_LOAD_PRGC; * Change this accordingly;
%let d_type = M;
%let lvl_of_detail = D;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type._&lvl_of_detail._YR;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */

%let startyear = 2005;
%let thisyear = 2017;

* loading file;
data temp;
set &indata;
run;


*****************************************************************************************;
** BY COU **;
proc sort data=temp; by e306 rec_e313 COU referenceyear;

proc sql noprint;
select name into: VARS separated by ' '
from dictionary.columns
where libname='WORK' and type = 'num' and memname='TEMP' and not name?'COU';
quit;

%let VARS_COU = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&VARS)),%str( ), %str(_COU )))))_COU;

* getting sum for each COU -- here is the summarising part;
DATA SUBJ_COU;
set temp;
by e306 rec_e313 COU referenceyear;
ARRAY x &VARS;
ARRAY y &VARS_COU;

do over x;
if first.COU then y = 0;
y + x;
if y = 0 then y = .;
end;
drop &VARS;
if last.cou;
run;


* Saving;
DATA AITSL.CS_HE_LOAD_PRGC_&d_type._&lvl_of_detail._COU;
set SUBJ_COU;
run;


