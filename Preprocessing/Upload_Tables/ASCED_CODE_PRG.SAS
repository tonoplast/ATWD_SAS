* This file is to import excel file (modified ASCED code) and shorten the size of the file;


libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

**************************************;
***** this is for importing data ***** ASCED modified for reproting;
**************************************;

** Import excel table here **;

data ASCED_MOD_2;
set ASCED_Reporting_Codes_mine;
run;


%let indata = ASCED_MOD_2;

proc sql;
select nvar into :nvars
from dictionary.tables
where libname='WORK' and memname='ASCED_MOD_2';
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



data AITSL.ASCED_PRG;
set outdata;
run;
