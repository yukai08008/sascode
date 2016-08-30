proc sql noprint;
create table name as 
select name from sashelp.vcolumn
where libname="WORK" and memname="PAY";
quit;
data name;
set name;
clength=length(name);
run;
proc print data=name;
where clength gt 30;
run;
/*well*/
