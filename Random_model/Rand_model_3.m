clear
clc
%% --提取数据--
commodity = 'IF888';
Freq = 'M1';
data=csvread('IF888_1分钟.csv');
date=data(:,1);
date1=unique(date);
for i=1:length(date)
    for j=1:length(date1)
        if date(i)==date1(j)
            date(i)=j;
            break;
        end
    end
end
data(:,1)=date;

Date=data(:,1);               %日期索引
Time=data(:,2);               %时间索引
Open=data(:,3);
Close=data(:,6);

%% --定义参数（常量）--

%策略参数
Slip=2;                                      %滑点
Daymin=270;

%品种参数
MinMove=0.2;                                  %商品的最小变动量
PriceScale=10;                                 %商品的计数单位
TradingUnits=1;                              %交易单位
Lots=1;                                       %交易手数
MarginRatio=0.07;                             %保证金率
TradingCost=0.0003;                           %交易费用设为成交金额的万分之三
RiskLess=0.035;                               %无风险收益率(计算夏普比率时需要)
a=30;
b=0.05;
c=10;
k=1.5;

%% --定义变量--

%策略变量

%交易记录变量
MyEntryPrice=zeros(length(data),1);            %买卖价格
MarketPosition=0;                              %仓位状态，-1表示持有空头，0表示无持仓，1表示持有多头
pos=zeros(length(data),1);                     %记录仓位情况，-1表示持有空头，0表示无持仓，1表示持有多头
Type=zeros(length(data),1);                    %买卖类型，1标示多头，-1标示空头
OpenPosPrice=zeros(length(data),1);            %记录建仓价格
ClosePosPrice=zeros(length(data),1);           %记录平仓价格
OpenPosNum=0;                                  %建仓价格序号
ClosePosNum=0;                                 %平仓价格序号
OpenDate=zeros(length(data),1);                %建仓时间
CloseDate=zeros(length(data),1);               %平仓时间
NetMargin=zeros(length(data),1);               %净利
CumNetMargin=zeros(length(data),1);            %累计净利
RateOfReturn=zeros(length(data),1);            %收益率
CumRateOfReturn=zeros(length(data),1);         %累计收益率
CostSeries=zeros(length(data),1);              %记录交易成本
BackRatio=zeros(length(data),1);               %记录回测比例
gap0=zeros(length(data),1); 

%记录资产变化变量
LongMargin=zeros(length(data),1);              %多头保证金
ShortMargin=zeros(length(data),1);             %空头保证金
Cash=repmat(1e6,length(data),1);               %可用资金,初始资金为100W
DynamicEquity=repmat(1e6,length(data),1);      %动态权益,初始资金为100W
StaticEquity=repmat(1e6,length(data),1);       %静态权益,初始资金为100W

%% --策略仿真--
for i=2:length(Date)
    if MarketPosition==0
        LongMargin(i)=0;                            %多头保证金
        ShortMargin(i)=0;                           %空头保证金
        StaticEquity(i)=StaticEquity(i-1);          %静态权益
        DynamicEquity(i)=StaticEquity(i);           %动态权益
        Cash(i)=DynamicEquity(i);                   %可用资金
    end
    if MarketPosition==1
        LongMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;
        StaticEquity(i)=StaticEquity(i-1);
        DynamicEquity(i)=StaticEquity(i)+(Close(i)-OpenPosPrice(OpenPosNum))*TradingUnits*Lots;
        Cash(i)=DynamicEquity(i)-LongMargin(i);
    end
    if MarketPosition==-1
        ShortMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;
        StaticEquity(i)=StaticEquity(i-1);
        DynamicEquity(i)=StaticEquity(i)+(OpenPosPrice(OpenPosNum)-Close(i))*TradingUnits*Lots;
        Cash(i)=DynamicEquity(i)-ShortMargin(i);
    end
    
    
    for j=1:length(date1)
        if Date(i)==j
            MyEntryPrice(i-1)=Close(find(Date==j,1));
            if mod(i,Daymin)==a
                if rand>=0.5               %开多
                    MarketPosition=1;
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格
                    OpenPosNum=OpenPosNum+1;
                    OpenPosPrice(OpenPosNum)=MyEntryPrice(i);%记录开仓价格
                    OpenDate(OpenPosNum)=Date(i);%记录开仓时间
                    Type(OpenPosNum)=1;   %方向为多头
                    StaticEquity(i)=StaticEquity(i-1);
                    DynamicEquity(i)=StaticEquity(i)+(Close(i)-OpenPosPrice(OpenPosNum))*TradingUnits*Lots;
                    LongMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;               %多头保证金
                    Cash(i)=DynamicEquity(i)-LongMargin(i);
                else                %开空
                    MarketPosition=-1;
                    MyEntryPrice(i)=Close(i);
                    if Open(i)<MyEntryPrice(i)
                        MyEntryPrice(i)=Open(i);
                    end
                    MyEntryPrice(i)=MyEntryPrice(i)-Slip*MinMove*PriceScale;
                    OpenPosNum=OpenPosNum+1;
                    OpenPosPrice(OpenPosNum)=MyEntryPrice(i);
                    OpenDate(OpenPosNum)=Date(i);%记录开仓时间
                    Type(OpenPosNum)=-1;   %方向为空头
                    StaticEquity(i)=StaticEquity(i-1);
                    DynamicEquity(i)=StaticEquity(i)+(OpenPosPrice(OpenPosNum)-Close(i))*TradingUnits*Lots;
                    ShortMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;
                    Cash(i)=DynamicEquity(i)-ShortMargin(i);
                end
            end
            
            if mod(i,Daymin)==gap0(i)+c
                if rand>=0.5               %开多
                    MarketPosition=1;
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格
                    OpenPosNum=OpenPosNum+1;
                    OpenPosPrice(OpenPosNum)=MyEntryPrice(i);%记录开仓价格
                    OpenDate(OpenPosNum)=Date(i);%记录开仓时间
                    Type(OpenPosNum)=1;   %方向为多头
                    StaticEquity(i)=StaticEquity(i-1);
                    DynamicEquity(i)=StaticEquity(i)+(Close(i)-OpenPosPrice(OpenPosNum))*TradingUnits*Lots;
                    LongMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;               %多头保证金
                    Cash(i)=DynamicEquity(i)-LongMargin(i);
                else                %开空
                    MarketPosition=-1;
                    MyEntryPrice(i)=Close(i);
                    if Open(i)<MyEntryPrice(i)
                        MyEntryPrice(i)=Open(i);
                    end
                    MyEntryPrice(i)=MyEntryPrice(i)-Slip*MinMove*PriceScale;
                    OpenPosNum=OpenPosNum+1;
                    OpenPosPrice(OpenPosNum)=MyEntryPrice(i);
                    OpenDate(OpenPosNum)=Date(i);%记录开仓时间
                    Type(OpenPosNum)=-1;   %方向为空头
                    StaticEquity(i)=StaticEquity(i-1);
                    DynamicEquity(i)=StaticEquity(i)+(OpenPosPrice(OpenPosNum)-Close(i))*TradingUnits*Lots;
                    ShortMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;
                    Cash(i)=DynamicEquity(i)-ShortMargin(i);
                end
            end
            
            if Close(i)>=MyEntryPrice(i-1)*(1+k*b)
                if MarketPosition==1            %平多
                    MarketPosition=-1;
                    LongMargin(i)=0;     %平多后多头保证金为0了
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)-Slip*MinMove*PriceScale;%建仓价格(也是平多仓的价格)
                    ClosePosNum=ClosePosNum+1;
                    ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
                    CloseDate(ClosePosNum)=Date(i);%记录平仓时间
                    gap0(i)=i;
                end
            elseif Close(i)<MyEntryPrice(i-1)*(1-b)
                if MarketPosition==1            %平多
                    MarketPosition=-1;
                    LongMargin(i)=0;     %平多后多头保证金为0了
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)-Slip*MinMove*PriceScale;%建仓价格(也是平多仓的价格)
                    ClosePosNum=ClosePosNum+1;
                    ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
                    CloseDate(ClosePosNum)=Date(i);%记录平仓时间
                    gap0(i)=i;
                end
            elseif Close(i)>=MyEntryPrice(i-1)*(1-k*b)
                if MarketPosition==-1           %平空
                    MarketPosition=1;
                    ShortMargin(i)=0;   %平空后空头保证金为0了
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格(也是平空仓的价格)
                    ClosePosNum=ClosePosNum+1;
                    ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
                    CloseDate(ClosePosNum)=Date(i);%记录平仓时间
                    gap0(i)=i;
                end
            elseif Close(i)<MyEntryPrice(i-1)*(1+b)
                if MarketPosition==-1           %平空
                    MarketPosition=1;
                    ShortMargin(i)=0;   %平空后空头保证金为0了
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格(也是平空仓的价格)
                    ClosePosNum=ClosePosNum+1;
                    ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
                    CloseDate(ClosePosNum)=Date(i);%记录平仓时间
                    gap0(i)=i;
                end
            end
   
            if mod(i,Daymin)==Daymin-15
                if MarketPosition==-1           %平空
                    MarketPosition=1;
                    ShortMargin(i)=0;   %平空后空头保证金为0了
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格(也是平空仓的价格)
                    ClosePosNum=ClosePosNum+1;
                    ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
                    CloseDate(ClosePosNum)=Date(i);%记录平仓时间
                end
                if MarketPosition==1            %平多
                    MarketPosition=-1;
                    LongMargin(i)=0;     %平多后多头保证金为0了
                    MyEntryPrice(i)=Close(i);
                    MyEntryPrice(i)=MyEntryPrice(i)-Slip*MinMove*PriceScale;%建仓价格(也是平多仓的价格)
                    ClosePosNum=ClosePosNum+1;
                    ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
                    CloseDate(ClosePosNum)=Date(i);%记录平仓时间
                end
                break;
            end
        end
    end
end
%% -绩效计算--

RecLength=ClosePosNum;%记录交易长度

%净利润和收益率
for i=1:RecLength

    %交易成本(建仓+平仓)
    CostSeries(i)=OpenPosPrice(i)*TradingUnits*Lots*TradingCost+ClosePosPrice(i)*TradingUnits*Lots*TradingCost;

    %净利润
    %多头建仓时
    if Type(i)==1
        NetMargin(i)=(ClosePosPrice(i)-OpenPosPrice(i))*TradingUnits*Lots-CostSeries(i);
    end
    %空头建仓时
    if Type(i)==-1
        NetMargin(i)=(OpenPosPrice(i)-ClosePosPrice(i))*TradingUnits*Lots-CostSeries(i);
    end
    %收益率
    RateOfReturn(i)=NetMargin(i)/(OpenPosPrice(i)*TradingUnits*Lots*MarginRatio);
end

%累计净利
CumNetMargin=cumsum(NetMargin);

%累计收益率
CumRateOfReturn=cumsum(RateOfReturn);

%回撤比例
for i=1:length(data)
    c=max(DynamicEquity(1:i));
    if c==DynamicEquity(i)
        BackRatio(i)=0;
    else
        BackRatio(i)=(DynamicEquity(i)-c)/c;
    end
end

%交易手数
LotsTotal=length(Type(Type~=0))*Lots;
LotsLong=length(Type(Type==1))*Lots;
LotsShort=length(Type(Type==-1))*Lots;

%总盈利
WinTotal=sum(NetMargin(NetMargin>0));
ans=NetMargin(Type==1);
WinLong=sum(ans(ans>0));
ans=NetMargin(Type==-1);
WinShort=sum(ans(ans>0));

%总亏损
LoseTotal=sum(NetMargin(NetMargin<0));
ans=NetMargin(Type==1);
LoseLong=sum(ans(ans<0));
ans=NetMargin(Type==-1);
LoseShort=sum(ans(ans<0));

%总盈利/总亏损
WinTotalDLoseTotal=abs(WinTotal/LoseTotal);
WinLongDLoseLong=abs(WinLong/LoseLong);
WinShortDLoseShort=abs(WinShort/LoseShort);

%盈利手数
LotsWinTotal=length(NetMargin(NetMargin>0))*Lots;
ans=NetMargin(Type==1);
LotsWinLong=length(ans(ans>0))*Lots;
ans=NetMargin(Type==-1);
LotsWinShort=length(ans(ans>0))*Lots;

%亏损手数
LotsLoseTotal=length(NetMargin(NetMargin<0))*Lots;
ans=NetMargin(Type==1);
LotsLoseLong=length(ans(ans<0))*Lots;
ans=NetMargin(Type==-1);
LotsLoseShort=length(ans(ans<0))*Lots;

%持平手数
ans=NetMargin(Type==1);
LotsDrawLong=length(ans(ans==0))*Lots;
ans=NetMargin(Type==-1);
LotsDrawShort=length(ans(ans==0))*Lots;
LotsDrawTotal=LotsDrawLong+LotsDrawShort;

%盈利比率
LotsWinTotalDLotsTotal=LotsWinTotal/LotsTotal;
LotsWinLongDLotsLong=LotsWinLong/LotsLong;
LotsWinShortDLotsShort=LotsWinShort/LotsShort;


%% --图表分析--

%权益曲线
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
plot(Date,DynamicEquity,'r','LineWidth',2);
hold on;
axis([Date(1) Date(end) min(DynamicEquity) max(DynamicEquity)]);
xlabel('时间');
ylabel('动态权益(元)');
title('权益曲线图');


%多空对比
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(2,2,1);
pie3([LotsWinLong LotsLoseLong],[1 0],{strcat('多头盈利手数:',num2str(LotsWinLong),'手，','占比:',num2str(LotsWinLong/(LotsWinLong+LotsLoseLong)*100),'%')...
    ,strcat('多头亏损手数:',num2str(LotsLoseLong),'手，','占比:',num2str(LotsLoseLong/(LotsWinLong+LotsLoseLong)*100),'%')});

subplot(2,2,2);
pie3([WinLong abs(LoseLong)],[1 0],{strcat('多头总盈利:',num2str(WinLong),'元，','占比:',num2str(WinLong/(WinLong+abs(LoseLong))*100),'%')...
    ,strcat('多头总亏损:',num2str(abs(LoseLong)),'元，','占比:',num2str(abs(LoseLong)/(WinLong+abs(LoseLong))*100),'%')});

subplot(2,2,3);
pie3([LotsWinShort LotsLoseShort],[1 0],{strcat('空头盈利手数:',num2str(LotsWinShort),'手，','占比:',num2str(LotsWinShort/(LotsWinShort+LotsLoseShort)*100),'%')...
    ,strcat('空头亏损手数:',num2str(LotsLoseShort),'手，','占比:',num2str(LotsLoseShort/(LotsWinShort+LotsLoseShort)*100),'%')});

subplot(2,2,4);
pie3([WinShort abs(LoseShort)],[1 0],{strcat('空头总盈利:',num2str(WinShort),'元，','占比:',num2str(WinShort/(WinShort+abs(LoseShort))*100),'%')...
    ,strcat('空头总亏损:',num2str(abs(LoseShort)),'元，','占比:',num2str(abs(LoseShort)/(WinShort+abs(LoseShort))*100),'%')});
