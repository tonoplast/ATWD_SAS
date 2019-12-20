* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This step is also not crucial. It is to view how individuals transitioned throughout their course;
* both at Course and Individual level;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = CS_HE_COU_LOGIC; * Change this accordingly;
%let d_type = M;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM._&d_type;

%let startyear = 2005;
%let thisyear = 2017;

data temp;
set &indata;
run;


**********************************************************************************************************************;
**** doing enrolment information here; 

proc sort data=temp; by e306 rec_e313 e313 rec_chessn chessn COU referenceyear; run;

proc transpose data=temp out=T_C (drop= _name_) prefix= E;
by e306 rec_e313 e313 rec_chessn chessn COU referenceyear;
var cou_ea countx_mod OONS START COMP DROP;
id referenceyear ;
run;


proc sql noprint;
select distinct referenceyear into: Years seprated by ' ' from T_C;
select distinct min(referenceyear) into: MinYear from T_C;
select distinct max(referenceyear) into: MaxYear from T_C;
quit;

%let EYears = E%sysfunc(tranwrd(%sysfunc(compbl(&Years)),%str( ), %str( E)));
%let PCEYears = PCE_%sysfunc(tranwrd(%sysfunc(compbl(&Years)),%str( ), %str( PCE_)));
%let PPEYears = PPE_%sysfunc(tranwrd(%sysfunc(compbl(&Years)),%str( ), %str( PPE_)));

data T_C_1;
retain e306 rec_e313 e313 rec_chessn chessn COU referenceyear &EYears;
set T_C;
run;


* (1) letter = courses (e.g. A = first appearing course, B = 2nd, C= 3rd and so on);
* (2) digit = year of appearance in sequence (01,02,03,04,05) - enrolled
* (3) letters -> SS = started, CC = completed, XX = out of nowhwere, DD = did not complete, TT - transitioned without completion;
* For example, A/01/SS means first course, started, 1st year. A/02 means 2nd year enrolled, so something was there before.
* B/04/CC means 2nd Course (like bachelor then master for example), completed on 4th year;
* added count for each course, after Cou letter (A01/01/CC);


proc sort data=T_C_1; by e306 COU rec_e313 referenceyear; run;

options missing= ' ';
	data T_C_2;
	do until(last.rec_e313);
	set T_C_1;
	by e306 COU rec_e313;
	
	array x $12. &PCEYears;
	array y $12. &EYears;

	do over x;
	x = catx('_',x,y);
	end;
	end;

	drop referenceyear &EYears;
run;
options missing= '.';



proc sort data=T_C_1; by e306 rec_e313 referenceyear; run;

options missing= ' ';
	data T_C_3;
	do until(last.rec_e313);
	set T_C_1;
	by e306 rec_e313;
	
	array x $12. &PPEYears;
	array y $12. &EYears;

	do over x;
	x = catx('_',x,y);
	end;
	end;

	drop referenceyear &EYears COU;
run;
options missing= '.';


proc sort data=T_C_2; by e306 rec_e313 COU; run;
proc sort data=T_C_3; by e306 rec_e313; run;

data merged_E;
merge T_C_2 (in=in1) T_C_3 (in=in2);
by e306 rec_e313;
run;



**********************************************************************************************************************;
*********** doing by years for GLVL and CLASS here ***********************************;

proc transpose data=temp out=T_CG (drop= _name_) prefix= CG;
by e306 rec_e313 e313 rec_chessn chessn COU referenceyear;
var CLASS_YR GLVL_YR;
id referenceyear ;
run;

%let CGYears = CG%sysfunc(tranwrd(%sysfunc(compbl(&Years)),%str( ), %str( CG)));
%let PCCGYears = PCCG_%sysfunc(tranwrd(%sysfunc(compbl(&Years)),%str( ), %str( PCCG_)));
%let PPCGYears = PPCG_%sysfunc(tranwrd(%sysfunc(compbl(&Years)),%str( ), %str( PPCG_)));

data T_CG_1;
retain e306 rec_e313 e313 rec_chessn chessn COU referenceyear &CGYears;
set T_CG;
run;


proc sort data=T_CG_1; by e306 COU rec_e313 referenceyear; run;
options missing= ' ';
	data T_CG_2;
	do until(last.rec_e313);
	set T_CG_1;
	by e306 COU rec_e313;
	
	array x $12. &PCCGYears;
	array y $12. &CGYears;

	do over x;
	x = catx('_',x,y);
	end;
	end;

	drop referenceyear &CGYears;
run;
options missing= '.';


proc sort data=T_CG_1; by e306 rec_e313 referenceyear; run;
options missing= ' ';
	data T_CG_3;
	do until(last.rec_e313);
	set T_CG_1;
	by e306 rec_e313;
	
	array x $12. &PPCGYears;
	array y $12. &CGYears;

	do over x;
	x = catx('_',x,y);
	end;
	end;

	drop referenceyear &CGYears COU;
run;
options missing= '.';

proc sort data=T_CG_2; by e306 rec_e313 COU; run;
proc sort data=T_CG_3; by e306 rec_e313; run;

data merged_CG;
merge T_CG_2 (in=in1) T_CG_3 (in=in2);
by e306 rec_e313;
run;





**********************************************************************************************************************;
***************** doing by course for GLVL and CLASS **********************;

proc sql noprint;
select distinct COU into: COU seprated by ' ' from temp;
quit;

%let temp_COU = temp_%sysfunc(tranwrd(%sysfunc(compbl(&COU)),%str( ), %str( temp_)));
%let PCCG_COU = PCCG_%sysfunc(tranwrd(%sysfunc(compbl(&COU)),%str( ), %str( PCCG_)));
%let PPCG_COU = PPCG_%sysfunc(tranwrd(%sysfunc(compbl(&COU)),%str( ), %str( PPCG_)));

proc sql;
create table U_temp as
select distinct e306, rec_e313, COU, CLASS_COU, GLVL_COU
from temp;
quit; 


proc transpose data=U_temp out=CG_COU (drop= _name_) prefix=temp_;
by e306 rec_e313 COU;
var CLASS_COU GLVL_COU;
id COU ;
run;


proc sort data=CG_COU; by e306 COU rec_e313; run;
options missing= ' ';
	data CG_COU_2;
	do until(last.rec_e313);
	set CG_COU;
	by e306 COU rec_e313;
	
	array x $12. &PCCG_COU;
	array y $12. &temp_COU;

	do over x;
	x = catx('_',x,y);
	end;
	end;

	drop &temp_COU;
run;
options missing= '.';



proc sort data=CG_COU; by e306 rec_e313; run;
options missing= ' ';
	data CG_COU_3;
	do until(last.rec_e313);
	set CG_COU;
	by e306 rec_e313;
	
	array x $12. &PPCG_COU;
	array y $12. &temp_COU;

	do over x;
	x = catx('_',x,y);
	end;
	end;

	drop &temp_COU COU;
run;
options missing= '.';

proc sort data=CG_COU_2; by e306 rec_e313 COU; run;
proc sort data=CG_COU_3; by e306 rec_e313; run;

data merged_CG_COU;
merge CG_COU_2 (in=in1) CG_COU_3 (in=in2);
by e306 rec_e313;
run;


**********************************************************************************************************************;
*** This was for Graduate level but decided not to include ***;
/** last G_LEVEL for course;*/
/*proc sort data=temp out=temp_glvl(keep=e306 COU rec_e313 referenceyear G_LEVEL); by e306 COU rec_e313 referenceyear G_LEVEL;*/
/*data Last_G_LEVEL (drop=referenceyear G_LEVEL);*/
/*set temp_glvl;*/
/*by e306 COU rec_e313 referenceyear G_LEVEL;*/
/*if last.rec_e313 then do;*/
/*LAST_GLVL_COU = G_LEVEL;*/
/*output; end;*/
/*run;*/
/**/
/** last G_LEVEL for Person;*/
/*proc sort data=temp out=temp_glvl(keep=e306 rec_e313 referenceyear G_LEVEL); by e306 rec_e313 referenceyear G_LEVEL;*/
/*data Last_G_LEVEL_PERSON(drop=referenceyear G_LEVEL);*/
/*set temp_glvl;*/
/*by e306 rec_e313 referenceyear G_LEVEL;*/
/*if last.rec_e313 then do;*/
/*LAST_GLVL_PERSON = G_LEVEL;*/
/*output; end;*/
/*run;*/
/**/
/**/
/*proc sort data=Last_G_LEVEL; by e306 rec_e313 COU; run;*/
/**/
/*data LAST_PERSON_COU;*/
/*merge Last_G_LEVEL (in=in1) Last_G_LEVEL_PERSON(in=in2);*/
/*by e306 rec_e313;*/
/*run;*/
**********************************************************************************************************************;

proc sql;
create table GLVL_COU_ORD as
select distinct e306, rec_e313, COU, GLVL_COU_ORD
from temp;
quit;

data ENR_COMPRESSED(keep=e306 rec_e313 COU last_course_index last_course_index_glvl CLASS_PERSON CLASS_COU_2 G_LEVEL_2);
set aitsl.CS_ENR_COU_COMPRESSED_&d_type;
run;

data MERGE_ALL;
merge ENR_COMPRESSED GLVL_COU_ORD MERGED_CG_COU MERGED_CG MERGED_E;
by e306 rec_e313 COU;
run;

data merged;
retain e306 rec_e313 e313 rec_chessn chessn COU LAST_GLVL_COU LAST_GLVL_PERSON;
set merge_all;
run;

* Saving;
data AITSL.CS_YEAR_COMPRESSED_&d_type;
set merged;
run;

