* Author: Sung Wook Chung (AITSL), 2019
* sungwookaitsl@gmail.com / sungwook.chung@aitsl.edu.au

* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY, without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.

* This file merges HEIMS Enrolment file with Course file, and adds / modifies variables for;
* reporting purposes. Main take away from here is that it'll have variables that determines;
* how data is cut for dFOE (e.g. by Year, or by Course, or by Person);


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;


%let thisyear = 2017;
%let d_type = M; ** can use A here for _A data, for comparing between _A and _M by course level;
options missing= '.';

proc sort data=AITSL.HE_ENR_MOD out=ENRx; by e306 rec_e313 referenceyear; run;

*** used this in the tech report ***;
data FIX_e922_B;
set aitsl.fix_start_year ;
run;
************************************;

* here we remove those that were removed in enrolment file - double enrolment;
* also remove completion year and commencement (e922) and add above into this file;
data ENR (drop=comp_year e922);
set ENRx;
if rec_e313 ne ' ';
if remove_denr ne 1;

* getting max value for these to determine where to put them;
array x{*} metro regional remote;
max = max(of x[*]);
if metro = max then region = input('METRO',$8.);
if regional = max then region = input('REGIONAL',$8.);
if remote = max then region = input('REMOTE',$8.);
if max = . then region = input('NULL',$8.);

* some rules to place them into one category if same value;
if max ne . and metro = max and metro = regional then region = 'METRO';
if max ne . and metro = max and metro = remote then region = 'METRO';
if max ne . and regional = max and regional = remote then region = 'REGIONAL';


	* empty rows replaced with 'z' here;
	if SES_PC = ' ' then SES_PC = 'z';

	e386_mod = input(substr(e386,1,1),1.); * simplifying disabilities (99 - no answer, 1 - yes , 2 - no);
	if e386_mod = 0 then e386_mod = 99;

	HOME_PC = addressofpermhomeres_postcode;
	HOME_STATE = residentialaddress_state;
	POSTAL_PC = postaladdress_postcode;
	POSTAL_STATE = postaladdress_statecode;
	
drop remove_denr metro regional remote addressofpermhomeres_postcode residentialaddress_state 
postaladdress_postcode postaladdress_statecode e386 max;
run;


proc sql noprint;
select distinct referenceyear into: LastYear 
from ENR
having referenceyear=max(referenceyear);
quit;

proc sort data=FIX_e922_B(keep=e306 rec_e313 referenceyear e922 comp_year ori_e922  ori_comp_year) out=FIX; by e306 rec_e313 referenceyear; run;

data merging(drop=Id snapshotID submissionID LinkageID);
merge ENR(in=in1) FIX(in=in2);
by e306 rec_e313 referenceyear;
run;


* clearing workspace;
proc datasets library=work;
save merging;
run;

* geting load file and replacing into e46x;
proc sql;
create table U_LOA as
select distinct e306,rec_e313,referenceyear,e46x,e461,e462,mode_yr
from aitsl.LCE_e461e462_&d_type;
quit;


* clearing workspace;
proc datasets library=work;
save merging U_LOA;
run;

proc sort data=merging; by e306 rec_e313 referenceyear; run;
proc sort data=U_LOA; by e306 rec_e313 referenceyear; run;

data merging_all;
merge merging(in=in1) U_LOA(in=in2);
by e306 rec_e313 referenceyear;
run;


Data A;
set merging_all;*(keep=e306 rec_e313 referenceyear comp_year e922);

* adding number of Major here;
if e462 = '000000' then MAJOR = 1; else MAJOR = 2;

length countx_mod $2;
by e306 rec_e313  referenceyear ; 

	* counting if starting;
	if first.rec_e313 then count=0;
	if e922 = '1' then count=1;
	else if e922 = '2' then do; 
	if count then count +1;
	end;
	
	*counting each year enrolled (all year here);
	if first.rec_e313 then countx=1;
	else countx +1;

	* counting potentially by course - whether drop or not;
	if first.rec_e313 then count1=0;
	if first.rec_e313 and e922='2' then count1=1;
	if e922 = '1' then count1+1;
	
	if count1=2 then x=1; * for fixing comp;

	countx_mod = put(countx,z2.);

	*adding rules;
	if e922 = 1 then START='SS'; * commencement;
	if first.rec_e313 and count=0 then OONS='XX'; * appear out of nowhere;
	if comp_year ne '.' then COMP='CC'; * completion;

run;




proc sort data=A; by e306 rec_e313 count1 referenceyear; run;

data A_1;
set A;
by e306 rec_e313 count1 referenceyear; 
if last.count1 and comp_year eq '.' and referenceyear ne &lastyear then DROP='DD'; *dropped out;
run;


* adding A B C D E etc by count1 (number of courses);
data NumbLet;
do count1 = 1 to 26; *number of alphabets for each course;
COU = collate(64 + count1, 64 + count1);
output;
end;
run;
proc sort data=A_1; by count1; run;
data merging_A;
merge A_1(in=in1) NumbLet(in=in2);
by count1;
if in1;
run;


proc sort data=merging_A; by e306 rec_e313 descending referenceyear; 

* last year Course used to keep those that are still enrolled and did not complete won't be flagged as drop below;
data A_COU;
set merging_A;
by e306 rec_e313 descending referenceyear; 
if first.rec_e313 then LCOU = COU;
else LCOU = coalescec(LCOU,COU); retain LCOU; 
run;


*flagging all record with x=1 here into fix_comp_1 in case we need it (not used here);
proc sort data=A_COU; by e306 rec_e313 descending x ; run;
data A_A;
set A_COU;
by e306 rec_e313 descending x;
retain fix_comp_1;
if first.rec_e313 then fix_comp_1=.;
if x ne . then fix_comp_1=x;
drop x;
run;



proc sort data=A_A; by e306 rec_e313 referenceyear; 
* first year appearing;
data B;
set A_A;
by e306 rec_e313 referenceyear; 
if first.rec_e313 then FYA = input(referenceyear,4.);
else FYA = coalesce(FYA,input(referenceyear,4.)); retain FYA; 
run;

* last year appearing;
proc sort data=B; by e306 rec_e313 descending referenceyear; run;
data B2;
set B;
by e306 rec_e313 descending referenceyear; 
if first.rec_e313 then LYA = input(referenceyear,4.);
else LYA = coalesce(LYA,input(referenceyear,4.)); retain LYA; 
run;


** this was added for retention use (potentially) 17 June 2019 - I've been meaning to add this anyway;
* it is for each course durations;
proc sort data=B2; by e306 rec_e313 cou referenceyear; run;
data C1;
set B2;
by e306 rec_e313 cou referenceyear;
if first.cou then cnt_ea_cou=0;
cnt_ea_cou+1;
cou_ea = cats(cou,put(cnt_ea_cou,z2.));
drop cnt_ea_cou;
run;


* making logic for FullTime PartTime and MixType -- this was removed and added below with COU GLVL and Person;
proc sort data=C1; by e306 cou rec_e313 referenceyear; run;

Data C2;
set C1;
by e306 cou rec_e313 referenceyear; 


* adding part time full time and giving a number;
if e330 = 1 then FPM = 1; if e330=2 then FPM=0.5; * for calculation of types- 1 is fulltime 0.5 is part time;
if first.rec_e313 then FPM_CAL = 0;
FPM_CAL + FPM;
if last.rec_e313 then SUM_FPT = FPM_CAL;

** this was added because of empty field later, which is the start. I decided to add so that we can see what they started with;
if SUM_FPT = . then do;
if e330 = 1 then SUM_FPT = 1; if e330=2 then SUM_FPT=0.5;
end;

drop count countx  FPM FPM_CAL;* count_T count_FT last_count_T last_count_FT;
run;


* clearing workspace;
proc datasets library=work;
save merging_all C2;
run;


** saving distinct COU into COUs ***;
proc sql noprint;
select distinct COU into: cou_lists separated by ' '
from C2;
quit;


** adding course information here **;
proc sort data=aitsl.he_cou_mod out=COU(keep=e306 referenceyear e306_name_abbrev e307 e308 e310 new_e310_des STATE e350 e312); by e306 referenceyear e307; run;
proc sort data=C2; by e306 referenceyear e307; run;

data C2_New;
merge C2(in=in1) COU(in=in2);
by  e306 referenceyear e307;
if in1;
run;


* just catagorising into Undergrade (UG) or postgrade (PG) here;
data C3;
format G_LEVEL GLVL_YR $3.;
set C2_New;
if E310 in (08,09,10,13,20,21,22) then do;
G_LEVEL = "UG"; GLVL_YR = "UG"; end;
else if E310 in (04,06,07,11,12,14) then do;
G_LEVEL = "PG"; GLVL_YR = "PG"; end; * "PGC"; *no research so just coursework; 

rename new_e310_des = e310_des;
run;


* having last course counts (how many courses a person has taken) and who is still enrolled;
proc sort data=C3; by e306 rec_e313 cou referenceyear; run;
data C4;*(keep=e306 rec_e313 cou referenceyear count1 COU_CNT SE sen start comp drop FYS LYC comp_year e922);
set C3;
by e306 rec_e313 cou referenceyear;
if last.rec_e313 then COU_CNT = count1;
if COU_CNT ne '.' and COMP ne 'CC' and referenceyear eq &LastYear then SE = COU; *still enrolled;
run;

proc sort data=C4; by e306 descending comp rec_e313 referenceyear; run;

data C5;* (drop=e922 e330);
set C4;
by e306 descending comp rec_e313 referenceyear;
if last.rec_e313 and COMP ne ' ' then LC = COU; *last completed;
run;


proc datasets library=work nolist;
save C5;
run;


proc sort data=C5; by e306 rec_e313 referenceyear COU; run;

* getting classification for COURSE LEVEL (A,B,C,D,E) -- Doing by Year first (YR) ;
data D;
length CLASS_YR $3.;
set C5;
if e46x='070101' then do; CLASS_YR='EC'; EC=1; end;
if e46x='070103' then do; CLASS_YR='PRI'; PRI=1; end;
if e46x='070105' then do; CLASS_YR='SEC'; SEC=1; end;
if e46x='07010x' then do; CLASS_YR='MIX'; MIX=1; end;
if e46x not in ('070101','070103','070105','07010x') then do;  CLASS_YR='EO'; EO=1; end;

* this is for Full-time and part-time;
if e330=1 then FT=1;
if e330=2 then PT=1;

* this is for Mode of attendance;
if Mode_YR = 1 then Mode_Int =1;
if Mode_YR = 2 then Mode_Ext =1;
if Mode_Yr = 3 then Mode_Mix = 1;

* this is for Graduate Level;
if GLVL_YR = 'UG' then UG=1;
if GLVL_YR = 'PG' then PG=1;

* to be used for COMP_COU;
if comp_year ne '.' then ref_comp_year = referenceyear;

* FT PT -- converting into new thing;
FTPT_YR = input(e330,1.);
drop e330;
run;


** adding comp_cou here for prioritising those that completed over having done for classification -- only for G_level and Person;
proc sort data=D; by e306 cou rec_e313 descending ref_comp_year descending referenceyear; run; 
Data D1;
set D;
by e306 cou rec_e313 descending ref_comp_year descending referenceyear; 
if first.rec_e313 then COMP_COU=ref_comp_year;
else COMP_COU= coalescec(COMP_COU,ref_comp_year); retain COMP_COU;
drop ref_comp_year;
run;


** adding GLVL details by start and end;
proc sort data=D1; by e306 cou rec_e313 referenceyear GLVL_YR; run; 
Data D1_x;
set D1;
by e306 cou rec_e313 referenceyear GLVL_YR;
if first.rec_e313 then FIRST_GLVL=GLVL_YR;
else FIRST_GLVL= coalescec(FIRST_GLVL,GLVL_YR); retain FIRST_GLVL;
run;

proc sort data=D1_x; by e306 cou rec_e313 descending referenceyear GLVL_YR; run; 
Data D1_y;
set D1_x;
by e306 cou rec_e313 descending referenceyear GLVL_YR;
if first.rec_e313 then LAST_GLVL=GLVL_YR;
else LAST_GLVL= coalescec(LAST_GLVL,GLVL_YR); retain LAST_GLVL;
run;

data D1_z(drop=FIRST_GLVL LAST_GLVL);
set D1_y;
GLVL_COU_ORD = cats(substr(FIRST_GLVL,1,1),substr(LAST_GLVL,1,1));
run;


* creating temp file to compress;
proc sort data=D1_z out=D1_A(keep=e306 rec_e313 COU EC PRI SEC MIX EO COMP_COU FT PT Mode_Int Mode_Ext Mode_Mix UG PG);
by e306 rec_e313 COU; 
run;

*compressing by course;
options missing= ' ';
data D1_compressed;
		sysecho "Compressing..";
update D1_A(obs=0) D1_A;
by e306 rec_e313 COU;
run;
options missing= '.';


***********************************************************************************************;
%let classes = EC PRI SEC EO MIX;
%let classes_x = %sysfunc(tranwrd(%sysfunc(compbl(&classes)),%str( ), %str(_x )))_x;
%let comp_classes = COMP_%sysfunc(tranwrd(%sysfunc(compbl(&classes)),%str( ), %str( COMP_)));

%let FTPT = FT PT MT;

%let Mode = Mode_Int Mode_Ext Mode_Mix;

%let GLVL = UG PG;
***********************************************************************************************;

data D1_B(drop=comp_cou &classes sum_range FT PT &mode sum_mode &GLVL sum_glvl);
length CLASS_COU $3.;
set D1_compressed;

*adding completion logic;
sum_range=sum(of &classes);

if EC=1 and sum_range=1 then CLASS_COU='EC';
if PRI=1 and sum_range=1 then CLASS_COU='PRI';
if SEC=1 and sum_range=1 then CLASS_COU='SEC';
if EO=1 and sum_range=1 then CLASS_COU='EO';
if MIX=1 and sum_range=1 then CLASS_COU='MIX';

if sum_range=2 and EO=1 and EC=1 then CLASS_COU='EC';
if sum_range=2 and EO=1 and PRI=1 then CLASS_COU='PRI';
if sum_range=2 and EO=1 and SEC=1 then CLASS_COU='SEC';
if sum_range=2 and EO=1 and MIX=1 then CLASS_COU='MIX';

if sum_range=2 and EO ne 1 then CLASS_COU='MIX';

if sum_range=>3 then CLASS_COU='MIX';

*for FT_PT_MT;
if FT=1 and PT ne 1 then FTPT_COU = 1;
if FT ne 1 and PT=1 then FTPT_COU = 2;
if FT=1 and PT=1 then FTPT_COU = 3;

*for Mode;
sum_mode=sum(of &mode);
if Mode_Int=1 and sum_mode = 1 then Mode_COU = 1;
if Mode_Ext=1 and sum_mode = 1 then Mode_COU = 2;
if Mode_COU = . then Mode_COU = 3;

*for GLVL;
sum_glvl=sum(of &GLVL);
if UG=1 and sum_glvl = 1 then GLVL_COU = 'UG';
if PG=1 and sum_glvl = 1 then GLVL_COU = 'PG';
if UG and PG then GLVL_COU = 'XG';
run;


proc sort data=D1; by e306 rec_e313 cou; run;
proc sort data=D1_z; by e306 rec_e313 referenceyear cou; run;
data merging_D;
merge D1_z(in=in1) D1_B(in=in2);
by e306 rec_e313 cou;
run;

data E;
retain e306 rec_e313 referenceyear COU CLASS_COU CLASS_YR G_LEVEL GLVL_COU GLVL_COU_ORD GLVL_YR COMP_COU FTPT_COU FTPT_YR Mode_COU;
set merging_D;
run;

proc datasets library=work nolist;
save D E;
run;


* getting classsification for UG/PG G_level -- order is very important here;
proc sort data=E; by e306 G_LEVEL rec_e313 descending COU descending referenceyear descending COMP_COU; run; 

DATA E1(keep=e306 G_LEVEL rec_e313 COMP_C &classes &comp_classes FT PT &mode);
SET E;
** replacing with completion logic;
if EC=1 and COMP_COU ne '.' then COMP_EC=1; 
if PRI=1 and COMP_COU ne '.' then COMP_PRI=1; 
if SEC=1 and COMP_COU ne '.' then COMP_SEC=1; 
if EO=1 and COMP_COU ne '.' then COMP_EO=1; 
if MIX=1 and COMP_COU ne '.' then COMP_MIX=1; 

run;


options missing= ' ';
data E_compressed;
		sysecho "Compressing..";
update E1(obs=0) E1;
by e306 G_LEVEL rec_e313;
run;
options missing= '.';


data E_A;
length CLASS_GLVL CLASS_GLVL_x $3;
set E_compressed;
sum_range=sum(of &classes);

if EC=1 and sum_range=1 then CLASS_GLVL='EC';
if PRI=1 and sum_range=1 then CLASS_GLVL='PRI';
if SEC=1 and sum_range=1 then CLASS_GLVL='SEC';
if EO=1 and sum_range=1 then CLASS_GLVL='EO';
if MIX=1 and sum_range=1 then CLASS_GLVL='MIX';

if sum_range=2 and EO=1 and EC=1 then CLASS_GLVL='EC';
if sum_range=2 and EO=1 and PRI=1 then CLASS_GLVL='PRI';
if sum_range=2 and EO=1 and SEC=1 then CLASS_GLVL='SEC';
if sum_range=2 and EO=1 and MIX=1 then CLASS_GLVL='MIX';

if sum_range=2 and EO ne 1 then CLASS_GLVL='MIX';
if sum_range=>3 then CLASS_GLVL='MIX';

EC_x = (EC + COMP_EC)/2;
PRI_x = (PRI + COMP_PRI)/2;
SEC_x = (SEC + COMP_SEC)/2;
EO_x = (EO + COMP_EO)/2;
MIX_x = (MIX + COMP_MIX)/2;

sum_x=sum(of &classes_x);

*replacing with completed classification here;

if EC_x=1 and sum_x=1 then CLASS_GLVL_x='EC';
if PRI_x=1 and sum_x=1 then CLASS_GLVL_x='PRI';
if SEC_x=1 and sum_x=1 then CLASS_GLVL_x='SEC';
if EO_x=1 and sum_x=1 then CLASS_GLVL_x='EO';
if MIX_x=1 and sum_x=1 then CLASS_GLVL_x='MIX';

if sum_x=2 and EO_x=1 and EC_x=1 then CLASS_GLVL_x='EC';
if sum_x=2 and EO_x=1 and PRI_x=1 then CLASS_GLVL_x='PRI';
if sum_x=2 and EO_x=1 and SEC_x=1 then CLASS_GLVL_x='SEC';
if sum_x=2 and EO_x=1 and MIX_x=1 then CLASS_GLVL_x='MIX';

if sum_x=2 and EO_x ne 1 then CLASS_GLVL_x='MIX';
if sum_x=>3 then CLASS_GLVL_x='MIX';

if CLASS_GLVL_x ne '' then CLASS_GLVL = CLASS_GLVL_x;

*for FT_PT_MT;
if FT=1 and PT ne 1 then FTPT_GLVL = 1;
if FT ne 1 and PT=1 then FTPT_GLVL = 2;
if FT=1 and PT=1 then FTPT_GLVL = 3;


*for Mode;
sum_mode=sum(of &mode);
if Mode_Int=1 and sum_mode = 1 then Mode_GLVL = 1;
if Mode_Ext=1 and sum_mode = 1 then Mode_GLVL = 2;
if Mode_GLVL = . then Mode_GLVL = 3;

keep e306 G_LEVEL rec_e313 CLASS_GLVL FTPT_GLVL Mode_GLVL;
run;


data merging_E;
merge E(in=in1) E_A(in=in2);
by e306 G_LEVEL rec_e313;
run;

data F;
retain e306 rec_e313 referenceyear COU CLASS_GLVL CLASS_COU CLASS_YR 
G_LEVEL GLVL_COU GLVL_COU_ORD GLVL_YR COMP_COU FTPT_GLVL FTPT_COU FTPT_YR Mode_GLVL Mode_COU;
set merging_E;
run;

proc datasets library=work nolist;
save D E F;
run;


* getting classsification for Person;
proc sort data=F; by e306 rec_e313 descending COU descending referenceyear descending COMP_COU; run; 


DATA F1(keep=e306 rec_e313 COMP_C &classes &comp_classes FT PT &mode UG PG &GLVL);
SET F;
** replacing with completion logic;
if EC=1 and COMP_COU ne '.' then COMP_EC=1; 
if PRI=1 and COMP_COU ne '.' then COMP_PRI=1; 
if SEC=1 and COMP_COU ne '.' then COMP_SEC=1; 
if EO=1 and COMP_COU ne '.' then COMP_EO=1; 
if MIX=1 and COMP_COU ne '.' then COMP_MIX=1; 
run;


options missing= ' ';
data F_compressed;
		sysecho "Compressing..";
update F1(obs=0) F1;
by e306 rec_e313;
run;
options missing= '.';


data F_A;
length CLASS_PERSON CLASS_PERSON_x $3;
set F_compressed;
sum_range=sum(of &classes);

if EC=1 and sum_range=1 then CLASS_PERSON='EC';
if PRI=1 and sum_range=1 then CLASS_PERSON='PRI';
if SEC=1 and sum_range=1 then CLASS_PERSON='SEC';
if EO=1 and sum_range=1 then CLASS_PERSON='EO';
if MIX=1 and sum_range=1 then CLASS_PERSON='MIX';

if sum_range=2 and EO=1 and EC=1 then CLASS_PERSON='EC';
if sum_range=2 and EO=1 and PRI=1 then CLASS_PERSON='PRI';
if sum_range=2 and EO=1 and SEC=1 then CLASS_PERSON='SEC';
if sum_range=2 and EO=1 and MIX=1 then CLASS_PERSON='MIX';

if sum_range=2 and EO ne 1 then CLASS_PERSON='MIX';
if sum_range=>3 then CLASS_PERSON='MIX';

EC_x = (EC + COMP_EC)/2;
PRI_x = (PRI + COMP_PRI)/2;
SEC_x = (SEC + COMP_SEC)/2;
EO_x = (EO + COMP_EO)/2;
MIX_x = (MIX + COMP_MIX)/2;

sum_x=sum(of &classes_x);

*replacing with completed classification here;

if EC_x=1 and sum_x=1 then CLASS_PERSON_x='EC';
if PRI_x=1 and sum_x=1 then CLASS_PERSON_x='PRI';
if SEC_x=1 and sum_x=1 then CLASS_PERSON_x='SEC';
if EO_x=1 and sum_x=1 then CLASS_PERSON_x='EO';
if MIX_x=1 and sum_x=1 then CLASS_PERSON_x='MIX';

if sum_x=2 and EO_x=1 and EC_x=1 then CLASS_PERSON_x='EC';
if sum_x=2 and EO_x=1 and PRI_x=1 then CLASS_PERSON_x='PRI';
if sum_x=2 and EO_x=1 and SEC_x=1 then CLASS_PERSON_x='SEC';
if sum_x=2 and EO_x=1 and MIX_x=1 then CLASS_PERSON_x='MIX';

if sum_x=2 and EO_x ne 1 then CLASS_PERSON_x='MIX';
if sum_x=>3 then CLASS_PERSON_x='MIX';

if CLASS_PERSON_x ne '' then CLASS_PERSON = CLASS_PERSON_x;

*for FT_PT_MT;
if FT=1 and PT ne 1 then FTPT_PERSON = 1;
if FT ne 1 and PT=1 then FTPT_PERSON = 2;
if FT=1 and PT=1 then FTPT_PERSON = 3;

*for Mode;
sum_mode=sum(of &mode);
if Mode_Int=1 and sum_mode = 1 then Mode_PERSON = 1;
if Mode_Ext=1 and sum_mode = 1 then Mode_PERSON = 2;
if Mode_PERSON = . then Mode_PERSON = 3;

*for G_LEVEL;
sum_glvl=sum(of &GLVL);
if UG=1 and sum_glvl = 1 then GLVL_PERSON = 'UG';
if PG=1 and sum_glvl = 1 then GLVL_PERSON = 'PG';
if UG and PG then GLVL_PERSON = 'XG';

keep e306 rec_e313 CLASS_PERSON GLVL_PERSON FTPT_PERSON Mode_PERSON;
run;


data merging_F;
merge F(in=in1) F_A(in=in2);
by e306 rec_e313;
run;


data G;
retain e306 rec_e313 referenceyear COU CLASS_PERSON CLASS_GLVL CLASS_COU CLASS_YR 
G_LEVEL GLVL_PERSON GLVL_COU GLVL_COU_ORD GLVL_YR 
FTPT_PERSON FTPT_GLVL FTPT_COU FTPT_YR Mode_PERSON Mode_GLVL Mode_COU Mode_YR COMP_COU;
set merging_F;
drop count1 fix_comp_1 FT PT MODE_INT MODE_EXT MODE_MIX UG PG ;
run;



proc sort data=G; by e306 rec_e313 referenceyear;

****************************** shortening file ****************************************;
%let indata = G;

* Counting number of variables (columns) and putting into nvars;
proc sql noprint;
select nvar into :nvars
from dictionary.tables
where libname="WORK" and memname="G";
quit;

* ========= Actual shortening starts here =============;
data size(keep=_name_ _length_ _format_);
set &indata end=_eof;
array _c[*] _character_;
array _s[&nvars] _temporary_;
do _i_ = 1 to dim(_c);
_s[_i_]= max(_s[_i_],length(_c[_i_]));
end;

if _eof then do _i_=1 to dim(_c);
length _name_ $32;
_name_=vname(_c[_i_]);
_length_=_s[_i_];
_format_=cat(_length_, '.');
output;
end;
run;

proc print;
run;
filename tempfile temp;
options missing= ' ';
data _null_;
file tempfile;
if 0 then set &indata;
if _n_ eq 1 then do;
put 'retain ' (_all_) (=) ';' @;
_file_ = translate(_file_,' ','=');
put;
end;
set size;
put 'Length ' _name_ '$' _length_ ';';
put 'Format ' _name_ '$' _format_ ';';
put 'Informat ' _name_ '$' _format_ ';';
run;
options missing= '.';



data outdata;
%include tempfile / source2;
set &indata;
run;
* =====================================================;

* saving;
data AITSL.CS_HE_COU_LOGIC_&d_type;
set outdata;
run;
