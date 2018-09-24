
t=0.01;
x=-1:0.05:1;
syms k
int((g(x,t,k)-g(-x,t,k)).*ff(k),-inf,inf)