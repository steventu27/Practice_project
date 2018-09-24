
% 另一 model
% data=csvread('/Users/Steven/Desktop/600155.csv',1,1);
% datasize=size(data);
% profit=zeros(datasize(1),1);
% totalprofit=zeros(datasize(1),1);
% k=0;
% n1=20;
% n2=2;
% status=0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MA_Bonding
clear
clc
data=csvread('/Users/Steven/Desktop/600155.csv',1,1);
datasize=size(data);
length=datasize(1);     %时间长度
close=data(:,4)';
open=data(:,1)'; 
HS=data(:,6)';
profit(1)=0;        %收益率
count(1)=0;         %计日器
epsilon1=0.05;
epsilon2=0.01;
money=1000000;
capital(1)=1000000;
position(1)=0;
sumprofit(1)=0;
sumHS(1)=data(1);
MA20=MA(close,20);
MA60=MA(close,60);
MA90=MA(close,90);
for i=1:length-1
    profit(i+1)=(close(i+1)-close(i))/close(i);
    if abs(profit(i+1)<=epsilon1)
        count(i+1)=count(i)+1;
        sumHS(i+1)=sumHS(i)+HS(i+1);
        
    else
        count(i+1)=0;
        sumHS(i+1)=0;
    end
    
   %         开仓 
    if count(i+1)>=45 ...
        && abs((MA20(i+1)-MA90(i+1))/MA60(i+1))<=epsilon2...
        && sumHS(i+1)>=0.8
        position(i+2)=floor(money/open(i+2));
    capital(i+1)=position(i+1)*close(i+1);
    sumprofit(i+1)=capital(i+1)-money;
    end
   %         平仓 
    if profit(i)<-0.05 || (sumprofit(i)-money)/money<-0.03 ...
            || (sumprofit(i)-money)/money> 0.1
        sumprofit(i+1)=position(i)*open(i+1)-money;
        position(i+2)=0;
    end
end 
% a=1:length;
% plot(a,sumprofit,'r')
% hold on;
b=1:length+1;
plot(b,position,'b')

