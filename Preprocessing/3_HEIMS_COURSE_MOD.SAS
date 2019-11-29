* This file does basic cleaning for HEIMS Course data;

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = HE_COU; * Change this accordingly;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;

* making saving name -> %let outname = XX_XXX using  LIB (first 2 letter), '_' and MEM (first 3 letter);
* This may require modification based on the Given name of the file;
data savevar;
savename = cat(substr(scan(%tslit(&MEM),1,"_"),1,2), '_' , substr(scan(%tslit(&MEM),2,"_"),1,3));
run;
proc sql noprint;
select savename into: outname from savevar;
quit;

* Assigning save name (&outname) in AITSL;
%let savedata = &LIB&separator&outname;


/* ============================================================================= */
/* ============================ Start Analysis ================================= */
/* ============================================================================= */


* data into temp, zero-padding e310 e461 e462 & removing decimal for e350, upcasing e307 & e308;
* fixing e350 problem (80 means 8 years, and the course is advanced diploma, so it must be 08);
data temp;
set &savedata;
length e461 e462 $6 e310 $2;
e461 = put(input(e461,best6.),z6.);
e462 = put(input(e462,best6.),z6.);
e310 = put(input(e310,best2.),z2.);
e350 = compress(e350,'.');
e307 = upcase(e307);
e308 = upcase(e308);
if e350 eq '80' then e350= tranwrd(e350,"80","08"); ** some odd case here;
run;

* Here just added one row of data into HE_COU_MOD file for e307 887 in 2005 that is missing (using 2006 but all are the same);
data fix_uow;
set temp; 
if e307 ='887' and referenceyear = '2006';
linkageid = 'THISIS-MADEUP-BECAUSE-ITWAS-MISSING';
id = 19999;
referenceyear = '2005';
run;

* merging the made-up data and saving;
data temp;
set temp 
	fix_uow;
run;

* Swapping e461 <-> e462 for double major if '07' (i.e. education) is in e462. Also if both are '07' then smallest first;
data temp (drop=e461_temp e462_temp Ticker);
set temp;

if e462 ne '000000' and substr(e461,1,2) ne '07' then Ticker = 1;
if e462 ne '000000' and substr(e461,1,2) eq '07' and substr(e462,1,2) eq '07' and e461 > e462 then Ticker = 1;

if ticker = 1 then do 
e461_temp = e462;
e462_temp = e461;
end;

if ticker = 1 then do
e461 = e461_temp;
e462 = e462_temp;
end;
run;


* Adding more things ( provider decodes here );
/* Loading education provider decodes*/

*merging here;
data uni_info;
set AITSL.UNI_INFO;
run;

proc sort data=uni_info; by e306; run;
proc sort data=temp; by e306; run;

options mergenoby=warn msglevel=I;
data temp_new uni_info_more inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge temp(IN=In1)  uni_info(IN=In2);
by e306;
if In1=1 then output temp_new;
if In2=1 then output uni_info_more;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;


* e310 information added here;
data E310;
set AITSL.E310;
run;

* Just shortening the variable;
data E310(rename=(new_e310_des=e310_des));
set E310;
if findw(e310_des,'HIGHER DOCTORATE') then new_e310_des = 'HIDOC';
if findw(e310_des,'DOCTORATE BY RESEARCH') then new_e310_des = 'DR';
if find(e310_des,'POSTGRADUATE QUALIFYING OR PRELIMINARY') then new_e310_des = 'PGQ';
if findw(e310_des,'DOCTORATE BY COURSEWORK') then new_e310_des = 'DC';
if findw(e310_des,'MASTERS (EXTENDED)') then new_e310_des = 'ME';
if findw(e310_des,'OTHER UNDERGRADUATE AWARD COURSE') then new_e310_des = 'OUAC';
if findw(e310_des,'CROSS INSTITUTIONAL PROGRAM FOR UNDERGRADUATE COURSES AT HOME HIGHER EDUCATION PROVIDER') then new_e310_des = 'CIPU';
if findw(e310_des,'NON-AWARD COURSE (INCLUDING BRIDGING FOR OVERSEAS TRAINED PROFESSIONALS)') then new_e310_des = 'NAC';
if findw(e310_des,'OPEN UNIVERSITIES AUSTRALIA UNDERGRADUATE STUDIES') then new_e310_des = 'OUAUS';
if findw(e310_des,'OPEN UNIVERSITIES AUSTRALIA POSTGRADUATE STUDIES') then new_e310_des = 'OUAPS';
if findw(e310_des,'ASSOCIATE DEGREE') ne 0 then new_e310_des = "ASSDEG";
if findw(e310_des,'DIPLOMA') ne 0 then new_e310_des = "DIP";
if findw(e310_des,'ADVANCED DIPLOMA') ne 0 then new_e310_des = "ADVDIP";
if findw(e310_des,'BACHELORS GRADUATE ENTRY') ne 0 then new_e310_des = "BGE";
if findw(e310_des,'BACHELORS HONOURS') ne 0 then new_e310_des = "BHONS";
if findw(e310_des,'BACHELORS PASS') ne 0 then new_e310_des = "BPASS";
if findw(e310_des,'GRADUATE CERTIFICATE') ne 0 then new_e310_des = "GCERT";
if findw(e310_des,'GRADUATE DIPLOMA/POSTGRADUATE DIPLOMA (PASS OR HONOURS) INVOLVING NEW ACADEMIC, PROFESSIONAL OR VOCATIONAL AREA') ne 0 then new_e310_des = "GDA";
if findw(e310_des,'GRADUATE DIPLOMA/POSTGRADUATE DIPLOMA (PASS OR HONOURS) EXTENDING SKILLS AND KNOWLEDGE IN A PROFESSIONAL AREA PREVIOUSLY STUDIED') ne 0 then new_e310_des = "GDB";
if findw(e310_des,'MASTERS (COURSEWORK)') ne 0 then new_e310_des = "MC";
if findw(e310_des,'MASTERS (RESEARCH)') ne 0 then new_e310_des = "MR";
if findw(e310_des,'CROSS INSTITUTIONAL PROGRAM FOR POSTGRADUATE COURSES AT HOME HIGHER EDUCATION PROVIDER') ne 0 then new_e310_des = "CIPP";
if findw(e310_des,'ENABLING COURSE') ne 0 then new_e310_des = "EACOU";
run;


proc sort data=E310; by e310; run;
proc sort data=temp_new; by e310; run;

options mergenoby=warn msglevel=I;
data temp_new_2 e310_more inBOTH 
	NOmatch1 NOmatch2 allRECS NOmatch;
merge temp_new(IN=In1)  e310(IN=In2);
by e310;
if In1=1 then output temp_new_2;
if In2=1 then output e310_more;
if (In1=1 and In2=1) then output inBoth;
if (In1=0 and In2=1) then output NOmatch1;
if (In1=1 and In2=0) then output NOmatch2;
if (in1=1 or In2=1) then output allRECS;
if (In1+In2) = 1	then output NOmatch;
run;

* clearing workspace;
proc datasets library=work;
save TEMP temp_new_2;
run;


*Saving;
data AITSL.HE_COU_MOD;
set temp_new_2;
run;
