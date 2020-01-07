* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_ENR_COU_ALL data from Preprocessing steps, and summarises data by demographics;
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;
* This is done to count students who study in and out of state;

* This will do all data type (Commencement, Completion and Enrolment);


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;

* check this later;
options dlcreatedir;
%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\DEMOGRAPHIC\;
libname newdir "&savedir";


%let STATES = ACT NSW NT QLD SA TAS VIC WA NULL;

%let YRs =  SS_YR REF_YR CC_YR;
%let CLASSES = CLASS_YR CLASS_COU CLASS_COU; 
%let files =  START ENR COMP;

*loading data;
DATA COMBINE_FINAL(KEEP= &STATES G_LEVEL &CLASSES &YRs);
set aitsl.CS_ENR_COU_ALL_&d_type;
run;


%macro IN_OUT;

%do i=1 %to %sysfunc(countw(&YRs));
	%let YR = %scan(&YRs,&i);
	%let file = %scan(&files,&i);
	%let CLASS = %scan(&CLASSES,&i);

* save directory
options dlcreatedir;
%let savedir1 = &savedir\&file\;
libname newdir "&savedir1";

%let savedir1 = &savedir\&file\IO_STATE\;
libname newdir "&savedir1";


* OVERALL (maybe for Gephi?);
proc sort data=COMBINE_FINAL out=OVERALL; by &YR &STATES; run;

data OVERALL;
set OVERALL;
if &YR ne .;
run;

proc summary data=OVERALL nway missing;
by &YR &STATES;
output out=OUT_THIS(drop=_type_ rename=(_freq_=FREQ));
run;

%let savename = IO_State.xlsx;
libname HU XLSX "&savedir&savename";
data HU.&file;
set OUT_THIS;
run;


* Subsetting data;
		%do j=1 %to %sysfunc(countw(&STATES));
			%let STATE = %scan(&STATES,&j);

data ALL UG PG EC PRI SEC MIX EO EC_UG PRI_UG SEC_UG MIX_UG EO_UG EC_PG PRI_PG SEC_PG MIX_PG EO_PG;
set COMBINE_FINAL;
if &YR ne .;
if &STATE ne .;
output ALL;
if G_LEVEL = 'UG' then output UG;
if G_LEVEL = 'PG' then output PG;

if &CLASS = 'EC' then output EC;
if &CLASS = 'PRI' then output PRI;
if &CLASS = 'SEC' then output SEC;
if &CLASS = 'MIX' then output MIX;
if &CLASS = 'EO' then output EO;

if G_LEVEL = 'UG' and &CLASS = 'EC' then output EC_UG;
if G_LEVEL = 'UG' and &CLASS = 'PRI' then output PRI_UG;
if G_LEVEL = 'UG' and &CLASS = 'SEC' then output SEC_UG;
if G_LEVEL = 'UG' and &CLASS = 'MIX' then output MIX_UG;
if G_LEVEL = 'UG' and &CLASS = 'EO' then output EO_UG;

if G_LEVEL = 'PG' and &CLASS = 'EC' then output EC_PG;
if G_LEVEL = 'PG' and &CLASS = 'PRI' then output PRI_PG;
if G_LEVEL = 'PG' and &CLASS = 'SEC' then output SEC_PG;
if G_LEVEL = 'PG' and &CLASS = 'MIX' then output MIX_PG;
if G_LEVEL = 'PG' and &CLASS = 'EO' then output EO_PG;
run;

*to not get empty/missing data under a column -- for OVERALL;
proc sql noprint;
create table U_VARS_1A as
select distinct &YR
from COMBINE_FINAL
where &YR ne .;
quit;


* Looping through subset data;
	%let datas = ALL UG PG EC PRI SEC MIX EO EC_UG PRI_UG SEC_UG MIX_UG EO_UG EC_PG PRI_PG SEC_PG MIX_PG EO_PG;

	%do k=1 %to %sysfunc(countw(&datas));
		%let data = %scan(&datas,&k);

proc sort data=&data out=DATA_A; by &YR &STATE; run;
proc summary data=DATA_A nway missing;
by &YR &STATE;
VAR &STATE;
output out=DATA_B(drop=_type_ rename=(_freq_=FREQ)) N=;
run;

proc sql noprint;
create table U_VARS_2 as
select distinct &STATE
from COMBINE_FINAL
where &STATE ne .;
quit;

proc sql;
create table U_VARS as select U_VARS_1A.&YR, U_VARS_2.&STATE
from U_VARS_1A, U_VARS_2;
quit;

proc sort data=U_VARS; by &YR &STATE; run;
data standardise;
merge U_VARS(in=in1) DATA_B(in=in2);
by &YR &STATE; 
if in1;
run;

data standardise;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &YR; run;
proc transpose data=standardise out=FINAL_DATA (drop=_NAME_) prefix=v;
by &YR ;
id &state;
run;


%let savename = IO_State_&state._&file..xlsx;
libname HU XLSX "&savedir1&savename";
data HU.&data;
set FINAL_DATA;
run;

		%end;
	%end;
%end;

%mend;
%IN_OUT;

libname HU clear;
libname newdir clear;
