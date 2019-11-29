* this file is used to make the file size smaller;

/*   START OF NODE: Shortening_script_v3   */

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

/* Finding max length of all character variables & shortening (takes long) */

* Assigning script/macro variables;

* ============== Just change these ==================;
%let LIB = AITSL; * Probably don't need to for now;
%let MEM = HEIMS_ENROLMENT; * Change this accordingly;
* HEIMS_ENROLMENT // HEIMS_COURSE // HEIMS_LOAD //;
* QILT_ESS // QILT_GOS // QILT_SES;
* ===================================================;

%let separator = .;
%let indata = &LIB&separator&MEM;

* making saving name -> %let outname = XX_XXX using LIB (first 2 letter), '_' and MEM (first 3 letter);
* This may require modification based on the Given name of the file;
data savevar;
savename = cat(substr(scan(%tslit(&MEM),1,"_"),1,2), '_' , substr(scan(%tslit(&MEM),2,"_"),1,3));
run;
proc sql noprint;
select savename into: outname from savevar;
quit;

* Assigning save name (&outname) in AITSL;
%let savedata = &LIB&separator&outname;

options fullstimer; * timer option;

* Counting number of variables (columns) and putting into nvars;
proc sql;
select nvar into :nvars
from dictionary.tables
where libname=%tslit(&LIB) and memname=%tslit(&MEM);
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

*looking at contents of changed vs before;
proc contents varnum;
run;
proc contents data=&indata varnum;
run;


* Saving adjusted data into AITSL folder;
data &savedata;
set outdata;
run;
