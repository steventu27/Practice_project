%% 简介：系统基于布林通道原理，是一个趋势追踪系统。
%  入场条件：
%    ROC大于0且价格突破布林带上轨就开多仓；
%    ROC小于0且价格跌破布林带下轨就开空仓；
%  关键参数：
%	 买卖滑点参数Slip
%	 布林带的周期数BollLength；
%    布林带标准差的倍数Offset;
%    ROC的周期数ROCLength；
%    跟踪止损算法的周期数ExitLength;


%% --提取数据--
% data=csvread('/Users/Steven/Desktop/IF888(1分钟).csv',1,0,[1 0 1000 7]);
% StockName = '600036.ss';
% StartDate = today-500;
% EndDate = today;
% Freq = 'd';
% [DataYahoo, Date_datenum, Head]=YahooData(StockName, StartDate, EndDate, Freq);

% data=YahooData('600036.ss', today-200, today,'d');
load data.mat
Date=datenum(data(:,1));                %日期时间
Open=cell2mat(data(:,2));               %开盘价
High=cell2mat(data(:,3));               %最高价
Low=cell2mat(data(:,4));                %最低价
Close=cell2mat(data(:,5));              %收盘价
Volume=cell2mat(data(:,6));             %成交量
OpenInterest=cell2mat(data(:,7));       %持仓量

% Date=datenum(data(:,1)); 
% Open=data(:,2);               %开盘价
% High=data(:,3);               %最高价
% Low=data(:,4);                %最低价
% Close=data(:,5);              %收盘价
% Volume=data(:,6);             %成交量
% OpenInterest=data(:,7);       %持仓量

%% --定义参数（常量）--

%策略参数
Slip=2;                                      %滑点
BollLength=50;                               %布林线长度
Offset=1.25;                                 %布林线标准差倍数
ROCLength=30;                                %ROC的周期数

%品种参数
MinMove=0.2;                                    %商品的最小变动量
PriceScale=1;                                 %商品的计数单位
TradingUnits=10;                              %交易单位
Lots=1;                                       %交易手数
MarginRatio=0.07;                             %保证金率
TradingCost=0.0003;                           %交易费用设为成交金额的万分之三
RiskLess=0.035;                               %无风险收益率(计算夏普比率时需要)

%% --定义变量--

%策略变量
UpperLine=zeros(length(data),1);               %上轨
LowerLine=zeros(length(data),1);               %下轨
MidLine=zeros(length(data),1);                 %中间线
Std=zeros(length(data),1);                     %标准差序列
RocValue=zeros(length(data),1);                %ROC值


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

%记录资产变化变量
LongMargin=zeros(length(data),1);              %多头保证金
ShortMargin=zeros(length(data),1);             %空头保证金
Cash=repmat(1e6,length(data),1);               %可用资金,初始资金为10W
DynamicEquity=repmat(1e6,length(data),1);      %动态权益,初始资金为10W
StaticEquity=repmat(1e6,length(data),1);       %静态权益,初始资金为10W

%% --计算布林带和ROC--
[UpperLine,MidLine,LowerLine]=BOLL(Close,BollLength,Offset,0);
RocValue=ROC(Close,ROCLength);

%% --策略仿真--

for i=BollLength:length(data)

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


    %开仓模块

    %开多头
    if MarketPosition~=1 && RocValue(i-1)>0 && High(i)>=UpperLine(i-1)   %用i-1,避免未来函数
        %平空开多
        if MarketPosition==-1
            MarketPosition=1;
            ShortMargin(i)=0;   %平空后空头保证金为0了
            MyEntryPrice(i)=UpperLine(i-1);
            if Open(i)>MyEntryPrice(i)    %考虑是否跳空
                MyEntryPrice(i)=Open(i);
            end
            MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格(也是平空仓的价格)
            ClosePosNum=ClosePosNum+1;
            ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
            CloseDate(ClosePosNum)=Date(i);%记录平仓时间
            OpenPosNum=OpenPosNum+1;
            OpenPosPrice(OpenPosNum)=MyEntryPrice(i);%记录开仓价格
            OpenDate(OpenPosNum)=Date(i);%记录开仓时间
            Type(OpenPosNum)=1;   %方向为多头
            StaticEquity(i)=StaticEquity(i-1)+(OpenPosPrice(OpenPosNum-1)-ClosePosPrice(ClosePosNum))...
                *TradingUnits*Lots-OpenPosPrice(OpenPosNum-1)*TradingUnits*Lots*TradingCost...
                -ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;%平空仓时的静态权益
            DynamicEquity(i)=StaticEquity(i)+(Close(i)-OpenPosPrice(OpenPosNum))*TradingUnits*Lots; %平空仓时的动态权益
        end
        %空仓开多
        if MarketPosition==0
            MarketPosition=1;
            MyEntryPrice(i)=UpperLine(i-1);
            if Open(i)>MyEntryPrice(i)    %考虑是否跳空
                MyEntryPrice(i)=Open(i);
            end
            MyEntryPrice(i)=MyEntryPrice(i)+Slip*MinMove*PriceScale;%建仓价格
            OpenPosNum=OpenPosNum+1;
            OpenPosPrice(OpenPosNum)=MyEntryPrice(i);%记录开仓价格
            OpenDate(OpenPosNum)=Date(i);%记录开仓时间
            Type(OpenPosNum)=1;   %方向为多头
            StaticEquity(i)=StaticEquity(i-1);
            DynamicEquity(i)=StaticEquity(i)+(Close(i)-OpenPosPrice(OpenPosNum))*TradingUnits*Lots;
        end
        LongMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;               %多头保证金
        Cash(i)=DynamicEquity(i)-LongMargin(i);
    end

    %开空头
    %平多开空
    if MarketPosition~=-1 && RocValue(i-1)<0 && Low(i)<=LowerLine(i-1)
        if MarketPosition==1
            MarketPosition=-1;
            LongMargin(i)=0;     %平多后多头保证金为0了
            MyEntryPrice(i)=LowerLine(i-1);
            if Open(i)<MyEntryPrice(i)
                MyEntryPrice(i)=Open(i);
            end
            MyEntryPrice(i)=MyEntryPrice(i)-Slip*MinMove*PriceScale;%建仓价格(也是平多仓的价格)
            ClosePosNum=ClosePosNum+1;
            ClosePosPrice(ClosePosNum)=MyEntryPrice(i);%记录平仓价格
            CloseDate(ClosePosNum)=Date(i);%记录平仓时间
            OpenPosNum=OpenPosNum+1;
            OpenPosPrice(OpenPosNum)=MyEntryPrice(i);%记录开仓价格
            OpenDate(OpenPosNum)=Date(i);%记录开仓时间
            Type(OpenPosNum)=-1;   %方向为空头
            StaticEquity(i)=StaticEquity(i-1)+(ClosePosPrice(ClosePosNum)-OpenPosPrice(OpenPosNum-1))...
                *TradingUnits*Lots-OpenPosPrice(OpenPosNum-1)*TradingUnits*Lots*TradingCost...
                -ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;%平多仓时的静态权益
            DynamicEquity(i)=StaticEquity(i)+(OpenPosPrice(OpenPosNum)-Close(i))*TradingUnits*Lots;%平空仓时的动态权益
        end
        %空仓开空
        if MarketPosition==0
            MarketPosition=-1;
            MyEntryPrice(i)=LowerLine(i-1);
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
        end
        ShortMargin(i)=Close(i)*Lots*TradingUnits*MarginRatio;
        Cash(i)=DynamicEquity(i)-ShortMargin(i);
    end

    %如果最后一个Bar有持仓，则以收盘价平掉
    if i==length(data)
        %平多
        if MarketPosition==1
            MarketPosition=0;
            LongMargin(i)=0;
            ClosePosNum=ClosePosNum+1;
            ClosePosPrice(ClosePosNum)=Close(i);%记录平仓价格
            CloseDate(ClosePosNum)=Date(i);%记录平仓时间
            StaticEquity(i)=StaticEquity(i-1)+(ClosePosPrice(ClosePosNum)-OpenPosPrice(OpenPosNum))...
                *TradingUnits*Lots-OpenPosPrice(OpenPosNum)*TradingUnits*Lots*TradingCost...
                -ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;%平多仓时的静态权益 
            DynamicEquity(i)=StaticEquity(i);%空仓时动态权益和静态权益相等
            Cash(i)=DynamicEquity(i); %空仓时可用资金等于动态权益
        end
        %平空
        if MarketPosition==-1
            MarketPosition=0;
            ShortMargin(i)=0;
            ClosePosNum=ClosePosNum+1;
            ClosePosPrice(ClosePosNum)=Close(i);
            CloseDate(ClosePosNum)=Date(i);
            StaticEquity(i)=StaticEquity(i-1)+(OpenPosPrice(OpenPosNum)-ClosePosPrice(ClosePosNum))...
                *TradingUnits*Lots-OpenPosPrice(OpenPosNum)*TradingUnits*Lots*TradingCost...
                -ClosePosPrice(ClosePosNum)*TradingUnits*Lots*TradingCost;%平空仓时的静态权益 
            DynamicEquity(i)=StaticEquity(i);%空仓时动态权益和静态权益相等
            Cash(i)=DynamicEquity(i); %空仓时可用资金等于动态权益
        end
    end
    pos(i)=MarketPosition;
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

%{
%日收益率
% Daily=Date(hour(Date)==9 & minute(Date)==0 & second(Date)==0);
% DailyEquity=DynamicEquity(hour(Date)==9 & minute(Date)==0 & second(Date)==0);
% DailyRet=tick2ret(DailyEquity);

DailyRet=tick2ret(DynamicEquity);
DailyRet=[0;DailyRet];

%周收益率
WeeklyNum=weeknum(Daily);     
Weekly=[Daily((WeeklyNum(1:end-1)-WeeklyNum(2:end))~=0);Daily(end)];
WeeklyEquity=[DailyEquity((WeeklyNum(1:end-1)-WeeklyNum(2:end))~=0);DailyEquity(end)];
WeeklyRet=tick2ret(WeeklyEquity);

%月收益率
MonthNum=month(Daily);
Monthly=[Daily((MonthNum(1:end-1)-MonthNum(2:end))~=0);Daily(end)];
MonthlyEquity=[DailyEquity((MonthNum(1:end-1)-MonthNum(2:end))~=0);DailyEquity(end)];
MonthlyRet=tick2ret(MonthlyEquity);

%年收益率
YearNum=year(Daily);
Yearly=[Daily((YearNum(1:end-1)-YearNum(2:end))~=0);Daily(end)];
YearlyEquity=[DailyEquity((YearNum(1:end-1)-YearNum(2:end))~=0);DailyEquity(end)];
YearlyRet=tick2ret(YearlyEquity);
%}


%{

%% 自动创建测试报告(输出到excel) 
%% 输出交易汇总
xlswrite('测试报告.xls',{'统计指标'},'交易汇总','A1');
xlswrite('测试报告.xls',{'全部交易'},'交易汇总','B1');
xlswrite('测试报告.xls',{'多头'},'交易汇总','C1');
xlswrite('测试报告.xls',{'空头'},'交易汇总','D1');

%净利润
ProfitTotal=sum(NetMargin);
ProfitLong=sum(NetMargin(Type==1));
ProfitShort=sum(NetMargin(Type==-1));
xlswrite('测试报告.xls',{'净利润'},'交易汇总','A2');
xlswrite('测试报告.xls',ProfitTotal,'交易汇总','B2');
xlswrite('测试报告.xls',ProfitLong,'交易汇总','C2');
xlswrite('测试报告.xls',ProfitShort,'交易汇总','D2');

%总盈利
WinTotal=sum(NetMargin(NetMargin>0));
ans=NetMargin(Type==1);
WinLong=sum(ans(ans>0));
ans=NetMargin(Type==-1);
WinShort=sum(ans(ans>0));
xlswrite('测试报告.xls',{'总盈利'},'交易汇总','A3');
xlswrite('测试报告.xls',WinTotal,'交易汇总','B3');
xlswrite('测试报告.xls',WinLong,'交易汇总','C3');
xlswrite('测试报告.xls',WinShort,'交易汇总','D3');

%总亏损
LoseTotal=sum(NetMargin(NetMargin<0));
ans=NetMargin(Type==1);
LoseLong=sum(ans(ans<0));
ans=NetMargin(Type==-1);
LoseShort=sum(ans(ans<0));
xlswrite('测试报告.xls',{'总亏损'},'交易汇总','A4');
xlswrite('测试报告.xls',LoseTotal,'交易汇总','B4');
xlswrite('测试报告.xls',LoseLong,'交易汇总','C4');
xlswrite('测试报告.xls',LoseShort,'交易汇总','D4');

%总盈利/总亏损
WinTotalDLoseTotal=abs(WinTotal/LoseTotal);
WinLongDLoseLong=abs(WinLong/LoseLong);
WinShortDLoseShort=abs(WinShort/LoseShort);
xlswrite('测试报告.xls',{'总盈利/总亏损'},'交易汇总','A5');
xlswrite('测试报告.xls',WinTotalDLoseTotal,'交易汇总','B5');
xlswrite('测试报告.xls',WinLongDLoseLong,'交易汇总','C5');
xlswrite('测试报告.xls',WinShortDLoseShort,'交易汇总','D5');

%交易手数
LotsTotal=length(Type(Type~=0))*Lots;
LotsLong=length(Type(Type==1))*Lots;
LotsShort=length(Type(Type==-1))*Lots;
xlswrite('测试报告.xls',{'交易手数'},'交易汇总','A7');
xlswrite('测试报告.xls',LotsTotal,'交易汇总','B7');
xlswrite('测试报告.xls',LotsLong,'交易汇总','C7');
xlswrite('测试报告.xls',LotsShort,'交易汇总','D7');

%盈利手数
LotsWinTotal=length(NetMargin(NetMargin>0))*Lots;
ans=NetMargin(Type==1);
LotsWinLong=length(ans(ans>0))*Lots;
ans=NetMargin(Type==-1);
LotsWinShort=length(ans(ans>0))*Lots;
xlswrite('测试报告.xls',{'盈利手数'},'交易汇总','A8');
xlswrite('测试报告.xls',LotsWinTotal,'交易汇总','B8');
xlswrite('测试报告.xls',LotsWinLong,'交易汇总','C8');
xlswrite('测试报告.xls',LotsWinShort,'交易汇总','D8');

%亏损手数
LotsLoseTotal=length(NetMargin(NetMargin<0))*Lots;
ans=NetMargin(Type==1);
LotsLoseLong=length(ans(ans<0))*Lots;
ans=NetMargin(Type==-1);
LotsLoseShort=length(ans(ans<0))*Lots;
xlswrite('测试报告.xls',{'亏损手数'},'交易汇总','A9');
xlswrite('测试报告.xls',LotsLoseTotal,'交易汇总','B9');
xlswrite('测试报告.xls',LotsLoseLong,'交易汇总','C9');
xlswrite('测试报告.xls',LotsLoseShort,'交易汇总','D9');

%持平手数
ans=NetMargin(Type==1);
LotsDrawLong=length(ans(ans==0))*Lots;
ans=NetMargin(Type==-1);
LotsDrawShort=length(ans(ans==0))*Lots;
LotsDrawTotal=LotsDrawLong+LotsDrawShort;
xlswrite('测试报告.xls',{'持平手数'},'交易汇总','A10');
xlswrite('测试报告.xls',LotsDrawTotal,'交易汇总','B10');
xlswrite('测试报告.xls',LotsDrawLong,'交易汇总','C10');
xlswrite('测试报告.xls',LotsDrawShort,'交易汇总','D10');

%盈利比率
LotsWinTotalDLotsTotal=LotsWinTotal/LotsTotal;
LotsWinLongDLotsLong=LotsWinLong/LotsLong;
LotsWinShortDLotsShort=LotsWinShort/LotsShort;
xlswrite('测试报告.xls',{'盈利比率'},'交易汇总','A11');
xlswrite('测试报告.xls',LotsWinTotalDLotsTotal,'交易汇总','B11');
xlswrite('测试报告.xls',LotsWinLongDLotsLong,'交易汇总','C11');
xlswrite('测试报告.xls',LotsWinShortDLotsShort,'交易汇总','D11');

%平均利润
xlswrite('测试报告.xls',{'平均利润(净利润/交易手数)'},'交易汇总','A13');
xlswrite('测试报告.xls',ProfitTotal/LotsTotal,'交易汇总','B13');
xlswrite('测试报告.xls',ProfitLong/LotsLong,'交易汇总','C13');
xlswrite('测试报告.xls',ProfitShort/LotsShort,'交易汇总','D13');

%平均盈利
xlswrite('测试报告.xls',{'平均盈利(总盈利金额/盈利交易手数)'},'交易汇总','A14');
xlswrite('测试报告.xls',WinTotal/LotsWinTotal,'交易汇总','B14');
xlswrite('测试报告.xls',WinLong/LotsWinLong,'交易汇总','C14');
xlswrite('测试报告.xls',WinShort/LotsWinShort,'交易汇总','D14');

%平均亏损
xlswrite('测试报告.xls',{'平均亏损(总亏损金额/亏损交易手数)'},'交易汇总','A15');
xlswrite('测试报告.xls',LoseTotal/LotsLoseTotal,'交易汇总','B15');
xlswrite('测试报告.xls',LoseLong/LotsLoseLong,'交易汇总','C15');
xlswrite('测试报告.xls',LoseShort/LotsLoseShort,'交易汇总','D15');

%平均盈利/平均亏损
xlswrite('测试报告.xls',{'平均盈利/平均亏损'},'交易汇总','A16');
xlswrite('测试报告.xls',abs((WinTotal/LotsWinTotal)/(LoseTotal/LotsLoseTotal)),'交易汇总','B16');
xlswrite('测试报告.xls',abs((WinLong/LotsWinLong)/(LoseLong/LotsLoseLong)),'交易汇总','C16');
xlswrite('测试报告.xls',abs((WinShort/LotsWinShort)/(LoseShort/LotsLoseShort)),'交易汇总','D16');

%最大盈利
MaxWinTotal=max(NetMargin(NetMargin>0));
ans=NetMargin(Type==1);
MaxWinLong=max(ans(ans>0));
ans=NetMargin(Type==-1);
MaxWinShort=max(ans(ans>0));
xlswrite('测试报告.xls',{'最大盈利'},'交易汇总','A18');
xlswrite('测试报告.xls',MaxWinTotal,'交易汇总','B18');
xlswrite('测试报告.xls',MaxWinLong,'交易汇总','C18');
xlswrite('测试报告.xls',MaxWinShort,'交易汇总','D18');

%最大亏损
MaxLoseTotal=min(NetMargin(NetMargin<0));
ans=NetMargin(Type==1);
MaxLoseLong=min(ans(ans<0));
ans=NetMargin(Type==-1);
MaxLoseShort=min(ans(ans<0));
xlswrite('测试报告.xls',{'最大亏损'},'交易汇总','A19');
xlswrite('测试报告.xls',MaxLoseTotal,'交易汇总','B19');
xlswrite('测试报告.xls',MaxLoseLong,'交易汇总','C19');
xlswrite('测试报告.xls',MaxLoseShort,'交易汇总','D19');

%最大盈利/总盈利
xlswrite('测试报告.xls',{'最大盈利/总盈利'},'交易汇总','A20');
xlswrite('测试报告.xls',MaxWinTotal/WinTotal,'交易汇总','B20');
xlswrite('测试报告.xls',MaxWinLong/WinLong,'交易汇总','C20');
xlswrite('测试报告.xls',MaxWinShort/WinShort,'交易汇总','D20');

%最大亏损/总亏损
xlswrite('测试报告.xls',{'最大亏损/总亏损'},'交易汇总','A21');
xlswrite('测试报告.xls',MaxLoseTotal/LoseTotal,'交易汇总','B21');
xlswrite('测试报告.xls',MaxLoseLong/LoseLong,'交易汇总','C21');
xlswrite('测试报告.xls',MaxLoseShort/LoseShort,'交易汇总','D21');

%净利润/最大亏损
xlswrite('测试报告.xls',{'净利润/最大亏损'},'交易汇总','A22');
xlswrite('测试报告.xls',ProfitTotal/MaxLoseTotal,'交易汇总','B22');
xlswrite('测试报告.xls',ProfitLong/MaxLoseLong,'交易汇总','C22');
xlswrite('测试报告.xls',ProfitShort/MaxLoseShort,'交易汇总','D22');

%最大使用资金
xlswrite('测试报告.xls',{'最大使用资金'},'交易汇总','A24');
xlswrite('测试报告.xls',max(max(LongMargin),max(ShortMargin)),'交易汇总','B24');
xlswrite('测试报告.xls',max(LongMargin),'交易汇总','C24');
xlswrite('测试报告.xls',max(ShortMargin),'交易汇总','D24');

%交易成本合计
CostTotal=sum(CostSeries);
ans=CostSeries(Type==1);
CostLong=sum(ans);
ans=CostSeries(Type==-1);
CostShort=sum(ans);
xlswrite('测试报告.xls',{'交易成本合计'},'交易汇总','A25');
xlswrite('测试报告.xls',CostTotal,'交易汇总','B25');
xlswrite('测试报告.xls',CostLong,'交易汇总','C25');
xlswrite('测试报告.xls',CostShort,'交易汇总','D25');

%测试时间范围
xlswrite('测试报告.xls',{'测试时间范围'},'交易汇总','F2');
xlswrite('测试报告.xls',cellstr(strcat(datestr(Date(1),'yyyy-mm-dd HH:MM:SS'),'-',datestr(Date(end),'yyyy-mm-dd HH:MM:SS'))),'交易汇总','G2');

%总交易时间
xlswrite('测试报告.xls',{'测试天数'},'交易汇总','F3');
xlswrite('测试报告.xls',round(Date(end)-Date(1)),'交易汇总','G3');

%持仓时间比例
xlswrite('测试报告.xls',{'持仓时间比例'},'交易汇总','F4');
xlswrite('测试报告.xls',length(pos(pos~=0))/length(data),'交易汇总','G4');

%持仓时间
xlswrite('测试报告.xls',{'持仓时间(天)'},'交易汇总','F5');
HoldingDays=round(round(Date(end)-Date(1))*(length(pos(pos~=0))/length(data)));%持仓时间
xlswrite('测试报告.xls',HoldingDays,'交易汇总','G5');

%收益率
xlswrite('测试报告.xls',{'收益率(%)'},'交易汇总','F7');
xlswrite('测试报告.xls',(DynamicEquity(end)-DynamicEquity(1))/DynamicEquity(1)*100,'交易汇总','G7');

%有效收益率
xlswrite('测试报告.xls',{'有效收益率(%)'},'交易汇总','F8');
TrueRatOfRet=(DynamicEquity(end)-DynamicEquity(1))/max(max(LongMargin),max(ShortMargin));
xlswrite('测试报告.xls',TrueRatOfRet*100,'交易汇总','G8');

%年度收益率(按365天算)
xlswrite('测试报告.xls',{'年化收益率(按365天算,%)'},'交易汇总','F9');
xlswrite('测试报告.xls',(1+TrueRatOfRet)^(1/(HoldingDays/365))*100,'交易汇总','G9');

%年度收益率(按240天算)
xlswrite('测试报告.xls',{'年度收益率(按240天算,%)'},'交易汇总','F10');
xlswrite('测试报告.xls',(1+TrueRatOfRet)^(1/(HoldingDays/240))*100,'交易汇总','G10');

% 年度收益率(按日算)
xlswrite('测试报告.xls',{'年度收益率(按日算,%)'},'交易汇总','F11');
xlswrite('测试报告.xls',mean(DailyRet)*365*100,'交易汇总','G11');

%年度收益率(按周算)
xlswrite('测试报告.xls',{'年度收益率(按周算,%)'},'交易汇总','F12');
xlswrite('测试报告.xls',mean(WeeklyRet)*52*100,'交易汇总','G12');

%年度收益率(按月算)
xlswrite('测试报告.xls',{'年度收益率(按月算,%)'},'交易汇总','F13');
xlswrite('测试报告.xls',mean(MonthlyRet)*12*100,'交易汇总','G13');

%夏普比率(按日算)
xlswrite('测试报告.xls',{'夏普比率(按日算,%)'},'交易汇总','F14');
xlswrite('测试报告.xls',(mean(DailyRet)*365-RiskLess)/(std(DailyRet)*sqrt(365)),'交易汇总','G14');

%夏普比率(按周算)
xlswrite('测试报告.xls',{'夏普比率(按周算,%)'},'交易汇总','F15');
xlswrite('测试报告.xls',(mean(WeeklyRet)*52-RiskLess)/(std(WeeklyRet)*sqrt(52)),'交易汇总','G15');

%夏普比率(按月算)
xlswrite('测试报告.xls',{'夏普比率(按月算,%)'},'交易汇总','F16');
xlswrite('测试报告.xls',(mean(MonthlyRet)*12-RiskLess)/(std(MonthlyRet)*sqrt(12)),'交易汇总','G16');

%最大回撤比例
xlswrite('测试报告.xls',{'最大回撤比例(%)'},'交易汇总','F17');
xlswrite('测试报告.xls',abs(min(BackRatio))*100,'交易汇总','G17');

%% 输出交易记录
xlswrite('测试报告.xls',{'#'},'交易记录','A1');
xlswrite('测试报告.xls',(1:RecLength)','交易记录','A2');
xlswrite('测试报告.xls',{'类型'},'交易记录','B1');
xlswrite('测试报告.xls',Type(1:RecLength),'交易记录','B2');
xlswrite('测试报告.xls',{'商品'},'交易记录','C1');
xlswrite('测试报告.xls',cellstr(repmat(commodity,RecLength,1)),'交易记录','C2');
xlswrite('测试报告.xls',{'周期'},'交易记录','D1');
xlswrite('测试报告.xls',cellstr(repmat(Freq,RecLength,1)),'交易记录','D2');
xlswrite('测试报告.xls',{'建仓时间'},'交易记录','E1');
xlswrite('测试报告.xls',cellstr(datestr(OpenDate(1:RecLength),'yyyy-mm-dd HH:MM:SS')),'交易记录','E2');
xlswrite('测试报告.xls',{'建仓价格'},'交易记录','F1');
xlswrite('测试报告.xls',OpenPosPrice(1:RecLength),'交易记录','F2');
xlswrite('测试报告.xls',{'平仓时间'},'交易记录','G1');
xlswrite('测试报告.xls',cellstr(datestr(CloseDate(1:RecLength),'yyyy-mm-dd HH:MM:SS')),'交易记录','G2');
xlswrite('测试报告.xls',{'平仓价格'},'交易记录','H1');
xlswrite('测试报告.xls',ClosePosPrice(1:RecLength),'交易记录','H2');
xlswrite('测试报告.xls',{'数量'},'交易记录','I1');
xlswrite('测试报告.xls',repmat(Lots,RecLength,1),'交易记录','I2');
xlswrite('测试报告.xls',{'交易成本'},'交易记录','J1');
xlswrite('测试报告.xls',CostSeries(1:RecLength),'交易记录','J2');
xlswrite('测试报告.xls',{'净利'},'交易记录','K1');
xlswrite('测试报告.xls',NetMargin(1:RecLength),'交易记录','K2');
xlswrite('测试报告.xls',{'累计净利'},'交易记录','L1');
xlswrite('测试报告.xls',CumNetMargin(1:RecLength),'交易记录','L2');
xlswrite('测试报告.xls',{'收益率'},'交易记录','M1');
xlswrite('测试报告.xls',RateOfReturn(1:RecLength),'交易记录','M2');
xlswrite('测试报告.xls',{'累计收益率'},'交易记录','N1');
xlswrite('测试报告.xls',CumRateOfReturn(1:RecLength),'交易记录','N2');

%% 输出资产变化
xlswrite('测试报告.xls',{'资产概要'},'资产变化','A1');
xlswrite('测试报告.xls',{'起初资产'},'资产变化','A2');
xlswrite('测试报告.xls',StaticEquity(1),'资产变化','A3');
xlswrite('测试报告.xls',{'期末资产'},'资产变化','B2');
xlswrite('测试报告.xls',StaticEquity(end),'资产变化','B3');
xlswrite('测试报告.xls',{'交易盈亏'},'资产变化','C2');
xlswrite('测试报告.xls',sum(NetMargin),'资产变化','C3');
xlswrite('测试报告.xls',{'最大资产'},'资产变化','D2');
xlswrite('测试报告.xls',max(DynamicEquity),'资产变化','D3'); %依据TB
xlswrite('测试报告.xls',{'最小资产'},'资产变化','E2');
xlswrite('测试报告.xls',min(DynamicEquity),'资产变化','E3');
xlswrite('测试报告.xls',{'交易成本合计'},'资产变化','F2');
xlswrite('测试报告.xls',sum(CostSeries),'资产变化','F3');
xlswrite('测试报告.xls',{'资产变化明细'},'资产变化','A5');
xlswrite('测试报告.xls',{'Bar#'},'资产变化','A6');
xlswrite('测试报告.xls',(1:length(data))','资产变化','A7');
xlswrite('测试报告.xls',{'时间'},'资产变化','B6');
xlswrite('测试报告.xls',cellstr(datestr(Date,'yyyy-mm-dd HH:MM:SS')),'资产变化','B7');
xlswrite('测试报告.xls',{'多头保证金'},'资产变化','C6');
xlswrite('测试报告.xls',LongMargin,'资产变化','C7');
xlswrite('测试报告.xls',{'空头保证金'},'资产变化','D6');
xlswrite('测试报告.xls',ShortMargin,'资产变化','D7');
xlswrite('测试报告.xls',{'可用资金'},'资产变化','E6');
xlswrite('测试报告.xls',Cash,'资产变化','E7');
xlswrite('测试报告.xls',{'动态权益'},'资产变化','F6');
xlswrite('测试报告.xls',DynamicEquity,'资产变化','F7');
xlswrite('测试报告.xls',{'静态权益'},'资产变化','G6');
xlswrite('测试报告.xls',StaticEquity,'资产变化','G7');

%}

%% --图表分析--
%画出布林带(部分)
figure(1);
candle(High(end-150:end),Low(end-150:end),Open(end-150:end),Close(end-150:end),'r');
hold on;
plot([MidLine(end-150:end)],'k');
plot([UpperLine(end-150:end)],'g');
plot([LowerLine(end-150:end)],'g');
title('布林带(仅部分)');
saveas(gcf,'1.布林带(仅部分).png');
close all;

scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
candle(High,Low,Close,Open,'r');
hold on;
plot([MidLine(end-50:end)],'k');
plot([UpperLine(end-50:end)],'g');
plot([LowerLine(end-50:end)],'g');
xlim( [0 length(Open)+1] );
title(StockName);

%交易盈亏曲线及累计成本
figure(2);
subplot(2,1,1);
area(1:RecLength,CumNetMargin(1:RecLength),'FaceColor','g');
axis([1 RecLength min(CumNetMargin(1:RecLength)) max(CumNetMargin(1:RecLength))]);
xlabel('交易次数');
ylabel('交易盈亏(元)');
title('交易盈亏曲线');

subplot(2,1,2);
plot(CumNetMargin(1:RecLength),'r','LineWidth',2);
hold on;
plot(cumsum(CostSeries(1:RecLength)),'b','LineWidth',2);
axis([1 RecLength min(CumNetMargin(1:RecLength)) max(CumNetMargin(1:RecLength))]);
xlabel('交易次数');
ylabel('交易盈亏及成本(元)');
legend('交易盈亏','累计成本','Location','NorthWest');
hold off;
saveas(gcf,'2.交易盈亏曲线.png');

%交易盈亏分布图
figure(3)
subplot(2,1,1);
ans=NetMargin(1:RecLength);%正收益和负收益用不同的颜色表示
ans(ans<0)=0;
plot(ans,'r.');
hold on;
ans=NetMargin(1:RecLength);
ans(ans>0)=0;
plot(ans,'b.');
xlabel('盈亏(元)');
ylabel('交易次数');
title('交易盈亏分布图');

subplot(2,1,2);
hist(NetMargin(1:RecLength),50);
h = findobj(gca,'Type','patch');
set(h,'FaceColor','r','EdgeColor','w')
xlabel('频率');
ylabel('盈亏分组');
saveas(gcf,'3.交易盈亏分布图.png');


%权益曲线
figure(4)
plot(Date,DynamicEquity,'r','LineWidth',2);
hold on;
area(Date,DynamicEquity,'FaceColor','g');
datetick('x',29);
axis([Date(1) Date(end) min(DynamicEquity) max(DynamicEquity)]);
xlabel('时间');
ylabel('动态权益(元)');
title('权益曲线图');
hold off;
saveas(gcf,'4.权益曲线图.png');


%仓位及回测比例
figure(5);
subplot(2,1,1);
plot(Date,pos,'g');
datetick('x',29);
axis([Date(1) Date(end) min(pos) max(pos)]);
xlabel('时间');
ylabel('仓位');
title('仓位状态(1-多头 0-不持仓 -1-空头)');

subplot(2,1,2);
plot(Date,BackRatio,'b');
datetick('x',29);
axis([Date(1) Date(end) min(BackRatio) max(BackRatio)]);
xlabel('时间');
ylabel('回撤比例');
title(strcat('回撤比例（初始资金为：',num2str(DynamicEquity(1)),'，开仓比例：',num2str(max(max(LongMargin),max(ShortMargin))/DynamicEquity(1)*100),'%',...
    '，保证金比例：',num2str(MarginRatio*100),'%）'));
saveas(gcf,'5.仓位及回测比例.png');


%多空对比
figure(6)
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
saveas(gcf,'6.多空对比饼图.png');
%}


%% 收益多周期统计
figure(7);
subplot(2,2,1);
% bar(Daily(2:end),DailyRet,'r','EdgeColor','r');
bar(1:length(DailyRet),DailyRet,'r','EdgeColor','r');
datetick('x',29);
axis([min(Daily(2:end)) max(Daily(2:end)) min(DailyRet) max(DailyRet)]);
xlabel('时间');
ylabel('日收益率');

subplot(2,2,2);
bar(Weekly(2:end),WeeklyRet,'r','EdgeColor','r');
datetick('x',29);
axis([min(Weekly(2:end)) max(Weekly(2:end)) min(WeeklyRet) max(WeeklyRet)]);
xlabel('时间');
ylabel('周收益率');

subplot(2,2,3);
bar(Monthly(2:end),MonthlyRet,'r','EdgeColor','r');
datetick('x',28);
axis([min(Monthly(2:end)) max(Monthly(2:end)) min(MonthlyRet) max(MonthlyRet)]);
xlabel('时间');
ylabel('月收益率');

subplot(2,2,4);
bar(Yearly(2:end),YearlyRet,'r','EdgeColor','r');
datetick('x',10);
axis([min(Yearly(2:end)) max(Yearly(2:end)) min(YearlyRet) max(YearlyRet)]);
xlabel('时间');
ylabel('年收益率');
saveas(gcf,'7.收益多周期统计.png');
close all;
%}