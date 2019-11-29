** This file will do a basic cleaning of the data;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = HE_LOA; * Change this accordingly;
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


* data into temp, zero-padding e464;
* removing decimal for e339 & upcase e307;
* changing e358 to ReferenceYear - This was wrong title (e358 is census year in Data);
data temp;
set &savedata;
length e464 $6;
e464 = put(input(e464,best6.),z6.);
e339 = compress(e339,'.');
e307 = upcase(e307);
ReferenceYear = e358;

drop e358;
run;


******************************************;
*** Process of harmonising student ID ****;
******************************************;

* e306 - 1019 (drop first 2 digits & last digit, adding '1' in front - data changed until 2006 (something must have happened in 2007));
data e313_fix;
set temp;
aa = find(e306,'1019') ne 0;
bb = find(referenceyear,'2005') ne 0;
cc = find(referenceyear,'2006') ne 0;
aabb = aa and bb;
aacc = aa and cc;
all = aabb or aacc;
len=length(e313);
if all = 1 then e313 = cat('1',substr(e313,3,length(e313)-3));
drop aa bb cc dd aabb aacc all len;
run;



* zeropadding everything by 10 zeros;
data e313_fix;
set e313_fix;
length padding $10;
padding = '0000000000';
substr(padding,11-length(e313)) = e313;
drop e313;
rename padding=e313;
run;

* fixing some other e313 issues;
data e313_fix;
set e313_fix;
if e306 = '4334' and substr(e313,1,4) = '2005' or
e306 = '4334' and substr(e313,1,4) = '2006' or
e306 = '4334' and substr(e313,1,4) = '2007' then
substr(e313,1,4) = '0000';

if e306 = '4334' and find(e313,'TCA')
and e313 = 'TCA1112894' then e313 ='0TCA112894';

* just getting rid of 0TCA as it causes a lot of trouble;
if e306 = '4334' and find(e313,'0TCA') then substr(e313,1,4) = '0000';
run;


* writing it into AITSL folder;
data AITSL.HE_LOA_MOD;
set e313_fix;
run;
