function xingqi=myfun(year,month,day)
dy=2*(year>=2000)-1;
y=2000:dy:year;
p=mod(y,400)==0 | mod(y,100)~=0 & mod(y,4)==0;
yue=[31 28+p(end) 31 30 31 30 31 31 30 31 30 31];
xingqi=mod(dy*sum(p((1:end-1)+(dy<0)))+365*(year-2000)+sum(yue(1:month-1))+day+5 ,7);
xingqi=xingqi+(xingqi==0)*7;
end