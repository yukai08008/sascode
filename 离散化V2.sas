/*data test;*/
/*set wz.erp;*/
/*target=dft;*/
/*p_net_fractn_house_loan_b=cs_p_net_fractn_house_loan_burde;*/
/*c_p_net_fractn_house_loan_b=  c_p_net_fractn_house_loan_burden*/
/*;*/
/*;*/
/*drop appid appid1 address dtapp dtrel var106 dft:*/
/*c_p_net_fractn_house_loan_burden*/
/*cs_p_net_fractn_house_loan_burde*/
/*;*/
/*run;*/

%macro dischar(ins,var);
proc means data=&ins(where=(&var gt 0)) noprint;
var &var;
output out=tem 
p10(&var)=p10
p25(&var)=p25
p50(&var)=p50
p75(&var)=p75
p90(&var)=p90;
run;
data _null_;
set tem;
call symput('p10',p10);
call symput('p25',p25);
call symput('p50',p50);
call symput('p75',p75);
call symput('p90',p90);
run;
data &ins;
length %sysfunc(cats(&var,_c)) $ 10;
set &ins;
select;
when(&var le -1000) %sysfunc(cats(&var,_c))='c0';
when(-1000 lt &var lt 0 ) %sysfunc(cats(&var,_c))=cats('c',&var);
when(&var le &p10) %sysfunc(cats(&var,_c))='c1';
when(&p10 lt &var le &p25) %sysfunc(cats(&var,_c))='c2';
when(&p25 lt &var le &p50) %sysfunc(cats(&var,_c))='c3';
when(&p50 lt &var le &p75) %sysfunc(cats(&var,_c))='c4';
when(&p75 lt &var le &p90) %sysfunc(cats(&var,_c))='c5';
when(&var gt &p90) %sysfunc(cats(&var,_c))='c6';
otherwise %sysfunc(cats(&var,_c))='c7';
end;
drop &var;
run;
%mend;

/*缺失值也被当做一个水平*/
%macro woe(ins,tar);
proc sql noprint;
select count(*) into :vnum
from sashelp.vcolumn
where libname='WORK' and memname=upper("&ins")
and name ne "&tar";

select name into :var1-:%sysfunc(cats(var,&vnum))
from sashelp.vcolumn
where libname='WORK' and memname=upper("&ins")
and name ne "&tar"
;
quit;

data woe_res;
length var $ 50 lev $ 10;
var='';
lev='';
n=.;
n1=.;
n0=.;
p1=.;
p0=.;
cump1=.;
cump0=.;
woe=.;
chi=.;
iv=.;
ps=.;
stop;
run;
%do i=1 %to &vnum;
/*计算频数*/
ods output CrossTabFreqs=temf;
proc freq data=&ins ;
tables &tar*&&var&i/out=tem1 expected;
run;
/*temf做处理*/
data temf;
set temf;
if _type_=11;
run;
%sort(temf,&&var&i);
proc transpose data=temf out=temf1 prefix=e;
by &&var&i;
id &tar;
var expected;
run;
data temf2;
length var $ 50 lev $ 10;
set temf1;
var="&&var&i";
lev=left(&&var&i)||'';
keep var lev e0 e1;
run;

/*排序*/
proc sort data=tem1;
by &&var&i;
run;
/*按变量转置*/
proc transpose data=tem1 out=tem2 prefix=n;
by &&var&i;
id &tar;
var count;
run;
proc sql noprint;
select sum(n0),sum(n1),sum(n0)+sum(n1) into :sum0,:sum1,:sumn
from tem2;
quit;
data tem2;
length var $ 50 lev $ 10;
retain &&var&i n n1 n0;
set tem2;
n=sum(n0,n1);
/*保证正例和负例的可计算性*/
if n1 le 0 then n1=1;
if n0 le 0 then n0=1;
p1=n1/&sum1;
p0=n0/&sum0;
cump1+p1;
cump0+p0;
var="&&var&i";
lev=left(&&var&i)||'';
woe=log(p1/p0);
iv=(p1-p0)*woe;
ps=(n/&sumn)**2;
drop _name_ _label_ &&var&i ;
run;
%mer1(tem2,temf2,var,lev,tem3)
data tem3;
set tem3;
chi=(n1-e1)**2/e1+(n0-e0)**2/e0;
drop e0 e1;
run;
proc append base=woe_res data=tem3 force;
run;
%end;
proc sql;
select var,sum(chi) as chisq,sum(iv) as var_iv,1-sum(ps) as gini from woe_res
group by var
;
quit;
%mend;

/*离散化对数值型变量水平超过10的进行离散*/
/*按百分位离散，另外负数作为独立水平保留*/
/*先取出符合要求的变量*/
%macro dproc(ins,tar,nlev=10);
ods output nlevels=nlev;
proc freq data=&ins nlevels;
tables _all_/noprint;
run;
data nlev;
set nlev;
name=tablevar;
run;
proc sql ;
create table va as 
select name,type from sashelp.vcolumn
where libname="WORK" and memname=upper("&ins");
quit;
%mer(nlev,va,name,nlev1)
data nlev2;
set nlev1;
if type eq 'num' and nlevels gt &nlev;
run;
proc sql noprint;
select count(*) into :dnum 
from nlev2 ;
select name into :dvar1-:%sysfunc(cats(dvar,&dnum))
from nlev2;
quit;
%do i=1 %to &dnum;
%dischar(&ins,&&dvar&i)
%end;
%woe(&ins,&tar)
%mend;



%dproc(pay1,target,nlev=15);
