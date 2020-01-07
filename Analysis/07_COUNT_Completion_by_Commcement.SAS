* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file loads CS_ENR_COU_ALL data from Preprocessing steps;
* This is done at National level and each state level, and breaks down into different field of education (dFOE) and Undergrad/Postgrad;
* It will export summarised data into excel. Several standardising processes have been incorporated to make the output neater;

* Counting Completion by Commencement (for example, how many completed in 2010 who started in 2007);


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;

%let lvls = EC PRI SEC MIX EO;
%let THIS_STATE = UNI_STATE; ** CHANGE THIS FOR STATE -- HOME_STATE UNI_STATE **;
%let CLASS = CLASS_COU; ** using COU data for completion;
%let TYPE = UNI_TYPE; ** this is for further Provider Type breakdown;

%let savedir = \\vault2\tdrive\ATWD\AITSL\ATWD_OUTPUT\FINAL\COHORT\DUR\&THIS_STATE\;
options dlcreatedir;
libname newdir "&savedir";

%let savedir1 = &savedir\OVERALL\;
libname newdir "&savedir1";

%let savedir2 = &savedir\TYPE\;
libname newdir "&savedir2";
libname newdir clear;

*loading data;
DATA COMBINE(keep=e306 e306_type UNI_TYPE rec_e313 COU G_LEVEL &CLASS FYS_COU LYC_COU HOME_STATE UNI_STATE);
set aitsl.CS_ENR_COU_ALL_&d_type;
if last_index_cou = 1;
run;

***** Here we include those that has START and COMP only **************************;
* This is because some commencements are missing (also completions but we don't know);

data COMBINE_FINAL;
set COMBINE ;
if FYS_COU ne . then START=1;
if LYC_COU ne . then COMP=1;
if START and COMP then START_COMP=1; * only getting those that has both start & completion;

*getting rid of those that have no data in both START and COMP;
array x START COMP START_COMP;
if sum (of x[*]) = . then delete;
run;


********************************** To see how many people each year has No Start but has Completion ***************************;
data No_Start_but_Yes_Comp;
set COMBINE_FINAL;
if START = . and COMP = 1;
run;

proc summary data=No_Start_but_Yes_Comp nway missing;
class LYC_COU;
var COMP;
output out=outdata(drop=_type_ _FREQ_) sum=;
run;

%let savename = Yes_Comp_but_No_Start.XLSX;
libname outdata XLSX "&savedir&savename";

data outdata.Yes_Comp_No_Start;
set outdata;
run;

libname outdata clear;
********************************************************************************************************************************;


** getting states;
proc sql noprint;
select distinct &THIS_STATE into: STATES separated by ' '
from COMBINE_FINAL;
quit;


********************************************** For Standardised output *****************************************;
*to not get empty/missing data under a column;
proc sql noprint;
create table U_START_COMP as
select distinct FYS_COU, LYC_COU
from COMBINE_FINAL
where START_COMP = 1;
quit;

*** For unique START_COMP and TYPE ***;
proc sql noprint;
create table U_TYPE as
select distinct UNI_TYPE
from COMBINE_FINAL
where START_COMP = 1;
quit;

proc sql;
create table U_SC_TYPE as select U_START_COMP.FYS_COU, U_START_COMP.LYC_COU, U_TYPE.UNI_TYPE
from U_START_COMP, U_TYPE;
quit;

proc sort data=U_SC_TYPE; by FYS_COU LYC_COU U_TYPE; run;

*** for unique START + TYPE ***;
proc sql noprint;
create table U_START as
select distinct FYS_COU
from COMBINE_FINAL
where FYS_COU ne .;
quit;

proc sql;
create table U_START_TYPE as select U_START.FYS_COU, U_TYPE.UNI_TYPE
from U_START, U_TYPE;
quit;
*********************************************************************************************************************;



************************************************************************************************************;
***** COMBINED DATA **************;
data AUS_ALL AUS_UG AUS_PG;
set COMBINE_FINAL;
output AUS_ALL;
if G_LEVEL = 'UG' then output AUS_UG;
if G_LEVEL = 'PG' then output AUS_PG;
run;

* making state breakdown data;
%macro STATE_DATAS;
%do i=1 %to %sysfunc(countw(&STATES));
%let STATE = %scan(&STATES,&i);

data &STATE._ALL; 
set AUS_ALL;
if &THIS_STATE = "&STATE" then output &STATE._ALL;
run;

data &STATE._UG; 
set AUS_UG;
if &THIS_STATE = "&STATE" then output &STATE._UG;
run;

data &STATE._PG; 
set AUS_PG;
if &THIS_STATE = "&STATE" then output &STATE._PG;
run;

%end;
%mend;
%STATE_DATAS;


proc sql noprint;
select distinct memname into: ALL_DATAS separated by ' ' from dictionary.columns where libname = "WORK" and memname?'_ALL';
select distinct memname into: UG_DATAS separated by ' ' from dictionary.columns where libname = "WORK" and memname?'_UG';
select distinct memname into: PG_DATAS separated by ' ' from dictionary.columns where libname = "WORK" and memname?'_PG';
quit;
************************************************************************************************************;


**********************************************************************************************;
************************* Using below subset datasets from here ******************************;
**********************************************************************************************;

***************************** OVERALL ****************************;
%let choose = ALL_DATAS UG_DATAS PG_DATAS;
%let choose_name = %sysfunc(compbl(%sysfunc(tranwrd(%sysfunc(compbl(&choose)),%str(_DATAS), %str()))));

%macro START_COMP;

	%do i=1 %to %sysfunc(countw(&choose));
		%let chosen = %scan(&choose,&i);
		%let chosen_name = %scan(&choose_name,&i);
			%let datas = &chosen;

		%do k=1 %to %sysfunc(countw(&&&DATAS));
			%let data = %scan(&&&DATAS,&k);

proc sort data= &data out=out_this; by FYS_COU LYC_COU;
data START_COMP_A;
set out_this;
if START_COMP=. then delete;
run;

proc summary data=START_COMP_A nway missing;
class FYS_COU LYC_COU;
var START_COMP;
output out=START_COMP_B(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_START_COMP(in=in1) START_COMP_B(in=in2);
by FYS_COU LYC_COU;
if in1;
run;

data standardise;
retain START_COMP;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc transpose data=standardise out=START_COMP_C (drop=_NAME_) prefix=Y;
by FYS_COU;
var START_COMP;
run;	

data START_A;
set OUT_THIS;
if START=. then delete;
run;

proc summary data=START_A nway missing;
class FYS_COU;
var START;
output out=START_B(drop=_type_ _FREQ_) sum=;
run;

data Merged;
merge START_COMP_C START_B;
by FYS_COU;
run;

%let savename1 = COMBINE_DUR_&chosen_name..XLSX;
libname COMBINE XLSX "&savedir1&savename1";

data COMBINE.&data;
set Merged;
run;

%end;
%end;
%mend;
%START_COMP;

libname COMBINE clear;
************************************************************************************************************;



************************************** HEP_TYPE BREAK DOWN *************************************;
** type of education provider **;

%macro START_COMP;

	%do i=1 %to %sysfunc(countw(&choose));
		%let chosen = %scan(&choose,&i);
		%let chosen_name = %scan(&choose_name,&i);
			%let datas = &chosen;

		%do k=1 %to %sysfunc(countw(&&&DATAS));
			%let data = %scan(&&&DATAS,&k);

proc sort data= &data out=out_this; by FYS_COU LYC_COU &TYPE;
data START_COMP_A;
set out_this;
if START_COMP=. then delete;
run;

proc summary data=START_COMP_A nway missing;
class FYS_COU LYC_COU &TYPE;
var START_COMP;
output out=START_COMP_B(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_SC_TYPE(in=in1) START_COMP_B(in=in2);
by FYS_COU LYC_COU &TYPE;
if in1;
run;

data standardise;
retain START_COMP;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &TYPE FYS_COU ; run;
proc transpose data=standardise out=START_COMP_C (drop=_NAME_) prefix=Y;
by &TYPE FYS_COU;
var START_COMP;
run;

data START_A;
set OUT_THIS;
if START=. then delete;
run;

proc summary data=START_A nway missing;
class &TYPE FYS_COU ;
var START;
output out=START_B(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_START_TYPE(in=in1) START_B(in=in2);
by &TYPE FYS_COU ;
if in1;
run;

data standardise;
retain START;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

data Merged;
merge START_COMP_C standardise;
by &TYPE FYS_COU ;
run;

%let savename1 = TYPE_DUR_&chosen_name..XLSX;
libname TYPE XLSX "&savedir2&savename1";

data TYPE.&data;
set Merged;
run;

proc datasets library=work nolist;
delete &data; 
run;

%end;
%end;
%mend;
%START_COMP;

libname TYPE clear;
************************************************************************************************************;



************************************************************************************************************;
***** dFOE BREAKDOWN **************;
%macro LVLS;

%do a=1 %to %sysfunc(countw(&lvls));
%let lvl = %scan(&lvls,&a);

data AUS_ALL AUS_UG AUS_PG;
set COMBINE_FINAL;
if "&lvl" = &CLASS;
output AUS_ALL;
if G_LEVEL = 'UG' then output AUS_UG;
if G_LEVEL = 'PG' then output AUS_PG;
run;

	%do b=1 %to %sysfunc(countw(&STATES));
	%let STATE = %scan(&STATES,&b);
	data &STATE._ALL; 
	set AUS_ALL;
	if &THIS_STATE = "&STATE" then output &STATE._ALL;
	run;

	data &STATE._UG; 
	set AUS_UG;
	if &THIS_STATE = "&STATE" then output &STATE._UG;
	run;

	data &STATE._PG; 
	set AUS_PG;
	if &THIS_STATE = "&STATE" then output &STATE._PG;
	run;
	%end;


		%do c=1 %to %sysfunc(countw(&choose));
		%let chosen = %scan(&choose,&c);
		%let chosen_name = %scan(&choose_name,&c);
			%let datas = &chosen;

		%do d=1 %to %sysfunc(countw(&&&DATAS));
			%let data = %scan(&&&DATAS,&d);

proc sort data= &data out=out_this; by FYS_COU LYC_COU;
data START_COMP_A;
set out_this;
if START_COMP=. then delete;
run;

proc summary data=START_COMP_A nway missing;
class FYS_COU LYC_COU;
var START_COMP;
output out=START_COMP_B(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_START_COMP(in=in1) START_COMP_B(in=in2);
by FYS_COU LYC_COU;
if in1;
run;

data standardise;
retain START_COMP;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc transpose data=standardise out=START_COMP_C (drop=_NAME_) prefix=Y;
by FYS_COU;
var START_COMP;
run;	

data START_A;
set OUT_THIS;
if START=. then delete;
run;

proc summary data=START_A nway missing;
class FYS_COU;
var START;
output out=START_B(drop=_type_ _FREQ_) sum=;
run;

data Merged;
merge START_COMP_C START_B;
by FYS_COU;
run;

%let savename1 = &lvl._DUR_&chosen_name..XLSX;
libname &lvl XLSX "&savedir1&savename1";

data &lvl..&data;
set Merged;
run;

		%end;
	%end;


************************** TYPE **************************************;

	%do i=1 %to %sysfunc(countw(&choose));
		%let chosen = %scan(&choose,&i);
		%let chosen_name = %scan(&choose_name,&i);
			%let datas = &chosen;

		%do j=1 %to %sysfunc(countw(&&&DATAS));
			%let data = %scan(&&&DATAS,&j);

proc sort data= &data out=out_this; by FYS_COU LYC_COU &TYPE;
data START_COMP_A;
set out_this;
if START_COMP=. then delete;
run;

proc summary data=START_COMP_A nway missing;
class FYS_COU LYC_COU &TYPE;
var START_COMP;
output out=START_COMP_B(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_SC_TYPE(in=in1) START_COMP_B(in=in2);
by FYS_COU LYC_COU &TYPE;
if in1;
run;

data standardise;
retain START_COMP;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

proc sort data=standardise; by &TYPE FYS_COU ; run;
proc transpose data=standardise out=START_COMP_C (drop=_NAME_) prefix=Y;
by &TYPE FYS_COU;
var START_COMP;
run;

data START_A;
set OUT_THIS;
if START=. then delete;
run;

proc summary data=START_A nway missing;
class &TYPE FYS_COU ;
var START;
output out=START_B(drop=_type_ _FREQ_) sum=;
run;

data standardise;
merge U_START_TYPE(in=in1) START_B(in=in2);
by &TYPE FYS_COU ;
if in1;
run;

data standardise;
retain START;
set standardise;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

data Merged;
merge START_COMP_C standardise;
by &TYPE FYS_COU ;
run;

%let savename1 = TYPE_&lvl._DUR_&chosen_name..XLSX;
libname TYPE XLSX "&savedir2&savename1";

data TYPE.&data;
set Merged;
run;

proc datasets library=work nolist;
delete &data; 
run;

%end;
%end;

libname &lvl clear;

%end;
%mend;
%LVLS;

libname TYPE clear;
