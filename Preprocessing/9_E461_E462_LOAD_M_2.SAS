* This file loads Mined data from University Handbooks and use the information there to derive;
* information into the HEIMS LOAD file;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = LCE_E461E462; * Change this accordingly;
%let d_type = M; * data type == A mean as HEIMS (As is), M means Mined;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type._TEMP;

/* ============================================================================= */
/* =============================== Start Analysing ============================= */
/* ============================================================================= */

%let startyear = 2005;
%let thisyear = 2017;

***************** CHANGE THIS FOR DIFFERENT DETAILS *******************;
%let PRG_LVL = PRG_D_DES;
%let lvl_of_detail = M;
***********************************************************************;

data temp(drop=linkageid snapshotid collectionperiod id submissionid);
set &indata;
run;

*removing special char and space, and zeropadding;
data temp_2017;
set temp;
length padding $12;
padding = '0000000000';
e354=compress(e354,"~!@#$%^&*()_+-=\|/?.,><-+ ");
if e354 ne ' ' then substr(padding,13-length(e354)) = e354;
drop e354;
rename padding=e354;
run;


data Unit;
set AITSL.UNIT_DETAIL;
run;


proc sort data=temp_2017; by e306 E354; run;
proc sort data=Unit; by e306 E354; run;

*adding e354_details into load file ;
options mergenoby=warn msglevel=I;
data temp_2017_new Unit_new inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
		sysecho "merging temp_2017_new..";
merge temp_2017(IN=In1)  Unit(IN=In2);
by e306 E354;
if In1=1 then output temp_2017_new; * this is the file we want;
if In2=1 then output Unit_new;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2; 
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

* clearing workspace;
proc datasets library=work;
save temp_2017_new;
run;


**** here we further improve classification using mined data for 2017 -- e46x -> if use 'if referenceyear = '2017' then do' ***;
** For the report, it was only done for 2017, but it can be applied to all if the raw data get improved;
data replace_logic;
set temp_2017_new;
/*if referenceyear = '2017' then do;*/

if content ne '' then do; *adding content when EC PRI SEC into temp e464 so it can be put into e46x, unless e46x already has them;
if e46x not in ('070101','070103','070105','07010x') and e464 not in ('070101','070103','070105') and substr(content,1,2) = '07' then e464x=content;
end;

if pedagogy ne '' then do; *adding pedagogy when EC PRI SEC into temp e464 so it can be put into e46x, unless e46x already has them;
if e46x not in ('070101','070103','070105','07010x') and e464 not in ('070101','070103','070105') and substr(pedagogy,1,2) = '07' then e464x=pedagogy;
end;

/*end;*/
run;



data select_these(keep=e306 rec_e313 referenceyear  e461 e462 e464 e46x e464x content pedagogy Mode_YR);
set replace_logic;
if substr(e464x,1,2) = '07';
if e464x not in ('070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then e464x = '079999';
run;

proc sql;
create table U_select_these as
select distinct e306, rec_e313, referenceyear, e464x
from select_these;
quit;


proc sql noprint;
create table these as
select distinct e464x
from U_select_these
where e464x is not null;
quit;


data catting;
length new_e464x $7.;
set these;
new_e464x = cats('e',e464x);
run;


proc transpose data=catting out=cattingx(drop=_name_);
id new_e464x;
run;


data new_e464x_temps;
set U_select_these cattingx;
run;

proc sql noprint;
select * into: varnames separated by ' '
from catting;
select count(*) into: counting separated by ' '
from catting;
quit;



* allocating appropriate data;
data arraythis;*(drop=new_e46x);
set new_e464x_temps;
array x &varnames;
do over x;
if find(vname(x),e464x) ge 1 then x=1;
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



*if it's just one then have them as the new category -- now it's e46x_replace;
%macro logic_A;
data logic_A;
set compressed;
%do i = 1 %to %sysfunc(countw(&varnames));
%let varname = %scan(&varnames, &i);
if sum_range=1 and &varname=1 then e46x_replace=strip(tranwrd(vname(&varname),'e',''));
%end;
run;
%mend;
%logic_A;



%let dropvarnames = e070000 e070100 e070101 e070103 e070105 e070107 e070109 e070111 e070113 e070115 e070117 e079999;

*putting them into either EC PRI SEC if it's mixed with other category;
*also adding mixed category;
data logic_B(drop=&dropvarnames sum_range e464x);
set logic_A;
if sum_range not in (1,.) and e070103 eq . and e070105 eq . and e070101=1 then e46x_replace='070101'; *EC when others;
if sum_range not in (1,.) and e070101 eq . and e070105 eq . and e070103=1 then e46x_replace='070103'; *PRI when others;
if sum_range not in (1,.) and e070101 eq . and e070103 eq . and e070105=1 then e46x_replace='070105'; *SEC when others;

if e070101 eq 1 and e070103 eq 1 then e46x_replace='07010x'; *MIXED;
if e070101 eq 1 and e070105 eq 1 then e46x_replace='07010x'; *MIXED;
if e070103 eq 1 and e070105 eq 1 then e46x_replace='07010x'; *MIXED;

* Order: (1) 070115 (EALD), (2) 070113 (Special Ed), (3) 070107 (Teacher Librarianship), (4) 070109 (VET), (5) 070111 (Higher Ed),
(6) 070117 (Nursing -- not found);
*(1)*; if e46x_replace eq '' and e070115 = 1 then e46x_replace = '070115';
*(2)*; if e46x_replace eq '' and e070113 = 1 then e46x_replace = '070113';
*(3)*; if e46x_replace eq '' and e070107 = 1 then e46x_replace = '070107';
*(4)*; if e46x_replace eq '' and e070109 = 1 then e46x_replace = '070109';
*(5)*; if e46x_replace eq '' and e070111 = 1 then e46x_replace = '070111';
*(6)*; if e46x_replace eq '' and e070117 = 1 then e46x_replace = '070117';

if e46x_replace eq '' then e46x_replace=e464x; *if none of the above, then just use new_e46x;
run;


*merging with replace_logic and replacing e46x;
proc sort data=replace_logic; by e306 rec_e313 referenceyear;
data merging_all(Drop=e464x e46x_replace);
merge replace_logic logic_B;
by e306 rec_e313 referenceyear;
if e46x_replace ne '' then e46x = e46x_replace;
run;

* Undo-ing some data that classified into '070999' as what was before (usually not EC PRI SEC);
data UNDO_SOME;
set merging_all;
if e46x = '079999' and e46x_step2 ne '079999' then e46x = e46x_step2;
run;

data AITSL.LCE_E461E462_&d_type;
set UNDO_SOME;
run;





**** CHECKING FROM HERE ***************;

data CHECKING;
set AITSL.LCE_E461E462_M;
*standardising all the "general" into 079999;
if e46x not in  ('07010x','070101' '070103' '070105' '070107' '070109' '070111' '070113' '070115' '070117') then e46x = '079999';
run;

proc sql;
create table U_person as
select distinct e306, rec_e313, referenceyear,  e46x_ori, e46x_step1, e46x_step2, e46x
from CHECKING;
quit;

data CLASSING;
length CLASS CLASS_ori CLASS_step1 CLASS_step2 $3.;
set U_person;
if e46x='070101' then CLASS='EC';
if e46x='070103' then CLASS='PRI'; 
if e46x='070105' then CLASS='SEC';
if e46x='07010x' then CLASS='MIX';
if e46x not in ('070101','070103','070105','07010x') then CLASS='EO';

if e46x_ori='070101' then CLASS_ori='EC';
if e46x_ori='070103' then CLASS_ori='PRI'; 
if e46x_ori='070105' then CLASS_ori='SEC';
if e46x_ori='07010x' then CLASS_ori='MIX';
if e46x_ori not in ('070101','070103','070105','07010x') then CLASS_ori='EO';

if e46x_step1='070101' then CLASS_step1='EC';
if e46x_step1='070103' then CLASS_step1='PRI'; 
if e46x_step1='070105' then CLASS_step1='SEC';
if e46x_step1='07010x' then CLASS_step1='MIX';
if e46x_step1 not in ('070101','070103','070105','07010x') then CLASS_step1='EO';

if e46x_step2='070101' then CLASS_step2='EC';
if e46x_step2='070103' then CLASS_step2='PRI'; 
if e46x_step2='070105' then CLASS_step2='SEC';
if e46x_step2='07010x' then CLASS_step2='MIX';
if e46x_step2 not in ('070101','070103','070105','07010x') then CLASS_step2='EO';
run;


%let VARS = CLASS CLASS_ori CLASS_STEP1 CLASS_STEP2;

%macro dFOE;
	%do i=1 %to %sysfunc(countw(&VARS));
		%let VAR = %scan(&VARS,&i);

proc sql;
create table U_this as
select distinct referenceyear, &VAR, COUNT(*) as count
from CLASSING
group by referenceyear, &VAR;
quit;

proc transpose data=u_this out=out_this (drop=_name_);
by  referenceyear;
id &VAR;
var count;
run; 

data final_&VAR;
retain referenceyear EC PRI SEC MIX EO;
set out_this;
array change _numeric_;
do over change;
if change=. then change=0;
end;
run;

%end;
%mend;
%DFOE;

