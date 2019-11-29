* Uploading Uni information here;

libname AITSL base "\\vault2\tdrive\ATWD\AITSL\HEIMS";

/* Clean workdir */
proc datasets library=WORK kill; run; quit;

**************************************;
***** this is for importing data *****;
**************************************;

* LOAD FILE HERE - UNI_INFO *;

data UNI;
set A_HIGHER_EDUCATION_AND_VET_PROVI;
e306_name = upcase(e306_name);
HEP_type = upcase(HEP_type);
Trading_Name = upcase(Trading_Name);
run;

data AITSL.UNI_INFO;
set UNI;
run;
