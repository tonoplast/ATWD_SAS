* This file loads Data extracted from University handbooks and standardise variables;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

**************************************;
***** this is for importing data ***** Unit details by mining;
**************************************;

* LOAD FILE HERE *;

data Unit_details(drop=credits);
set COURSECODECOMBINEDLIST_MINE;
run;

data Unit_upcased;
set unit_details;
array charvar _character_;
do i=1 to dim(charvar); drop i;
charvar(i) = upcase(charvar(i));
end;
run;

proc freq data=Unit_upcased; tables literacy numeracy prof_pract; run;

data Unit_ED;
set unit_upcased;
If find(literacy,"Y") ge 1 then literacy = "YES";
If find(numeracy,"Y") ge 1 then numeracy = "YES";
If find(prof_pract,"Y") ge 1 then Prof_Pract = "YES";
run;

proc freq data=Unit_ED; tables literacy numeracy prof_pract; run;


proc sort data=unit_ed; by e306 e354; run;
data single dup;
set Unit_ED;
by e306 e354;
if first.e354 and last.e354 then output single;
else output dup;
run;


proc sort data=Unit_upcased; by e354; run;

*removing special char and space, and zeropadding;
data UNIT_more_A;
set Unit_ED;
length padding $12;
padding = '0000000000';
e354=compress(e354,"~!@#$%^&*()_+-=\|/?.,><-+ ");

if e354 ne ' ' then substr(padding,13-length(e354)) = e354;
drop e354;
rename padding=e354;
run;


** fixing e464 codes here;

*removing special char and space, and zeropadding;
data UNIT_more_B;
set UNIT_more_A;
length padding1 $6 padding2 $6;
padding1 = '000000'; padding2 = '000000';

Content=compress(Content,"~!@#$%^&*()_+-=\|/?.,><-+ ");
if content ne ' ' then substr(padding1,7-length(Content)) = Content;

Pedagogy=compress(Pedagogy,"~!@#$%^&*()_+-=\|/?.,><-+ ");
if Pedagogy ne ' ' then substr(padding2,7-length(Pedagogy)) = Pedagogy;

if padding1 = '000000' then padding1 = ' ';
if padding2 = '000000' then padding2 = ' ';

drop Content Pedagogy;
rename padding1=Content padding2=Pedagogy;
run;


proc sql;
create table Content as select distinct content as e461 from UNIT_more_B where content ne '';
create table Pedagogy as select distinct Pedagogy as e461 from UNIT_more_B where Pedagogy ne '';
quit;

data ContPeda;
merge content pedagogy;
by e461;
contpeda=1;
run;

proc sort data=contpeda; by e461; run;
proc sort data=aitsl.ASCED_STRUCTURES out=ASCED; by e461; run;

data Merge_check;
merge ASCED(in=in1) contpeda(in=in2);
by e461;
if not in1;
run;


* Fixing some errors manually;
data UNIT_more_C;
set UNIT_more_B;
if pedagogy = '070200' then pedagogy = '079999';
if Content = '070200' then Content = '079999';

if pedagogy = '070201' then pedagogy = '079999';
if Content = '070201' then Content = '079999';

if pedagogy = '070305' then pedagogy = '070301';
if Content = '070305' then Content = '070301';

if pedagogy = '070999' then pedagogy = '079999';
if Content = '070999' then Content = '079999';
run;


* Saving;
proc sort data=UNIT_more_C; by e306 e354; run;
data AITSL.unit_detail;
set UNIT_more_C;
run;



** This is for ANZSIC file uploading **;
/*libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";*/
/**/
/*/** anzsic here;*/*/
/*data anzsic;*/
/*set anzsic;*/
/*anzsic_des = upcase(anzsic_des);*/
/*/*category = upcase(category);*/*/
/*run;*/
/**/
/*proc sort data=anzsic; */
/*by ANZSIC; */
/*run;*/
/**/
/*data aitsl.anzsic;*/
/*set anzsic;*/
/*run;*/
