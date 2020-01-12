# SAS codes used for ATWD pipeline report (2019)

This repository is for SAS codes that were used to preprocess and analyse the Australian Teacher Workforce Data for 2017 records, 
specifically for the ATWD pipeline report.

The anaysis was conducted via a secure remote access (AIHW), and therefore it is unlikely that anyone would be able to reproduce the analysis, unless they have the access to the unit record data. However, this repository was created for transparency reasons.

Start with "Preprocessing" and move onto "Analysis" folder. Each code is numbered, so following in order will get the output required.

## Built with
* [SAS Enterprise Guide 7.1](https://documentation.sas.com/?docsetId=whatsdiff&docsetTarget=n1af4n56n0r8gvn1kt0j8iagcc86.htm&docsetVersion=9.4&locale=en) - The code is based on.

These codes are unlikely to go through further improvement as the remote access server has transitioned from AIHW to AWS.
Both are based in Australia.

Future codes will be written in "R", and will be maintained throughout the project.
For any data that were saved using SAS, it can be converted into CSV using the code in the main folder.
The reason for the conversion is that a nunber of raw data in SAS format are too large (larger than the memory can handle; 5 GB - 91 GB).
These converted files then can be loaded into R. 


If you have any question, please contact me at : 

sungwookaitsl@gmail.com

Thank you, and have a good day.

Regards,

Sung
