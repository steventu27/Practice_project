%%此程序用来计算MACD指标并对其有效性进行回测检验
 
%% 计算相关指标(这里也可编一个函数)，第一天初始化：DIFF=DEA=MACD=0,EMAshort=EMAlong=第一天的收盘价
%虽然matlab有自带的函数macd()，它貌似只能计算默认长度的平滑移动平均，还是自己算理解更深刻
stk_clpr=csvread('/Users/Steven/Desktop/600155.csv',1,0);
clpr=stk_clpr(:,5);%提取收盘价
date=stk_clpr(:,1);%提取日期
%定义计算长度
shortPeriod=12;%定义收盘价短期（快速）平滑移动平均计算长度
longPeriod=26;%定义收盘价长期（慢速）平滑移动平均计算长度
DEAPeriod=9;%定义diff线平滑移动平均计算长度
%建立占位矩阵，提高程序运行效率
EMAshort=zeros(length(clpr),1);
EMAlong=zeros(length(clpr),1);
DIFF=zeros(length(clpr),1);
DEA=zeros(length(clpr),1);
MACD=zeros(length(clpr),1);
%用循环语句计算各个指标（这里用向量不管用）
EMAshort(1)=clpr(1);%初始化EMAshort第一值
EMAlong(1)=clpr(1);%初始化EMAlong第一个值
DEA(1)=0;%初始化第一值
DIFF(1)=0;
MACD(1)=0;
for t=2:length(clpr);
    %计算短期和长期EMA
    EMAshort(t)=clpr(t)*(2/(shortPeriod+1))+EMAshort(t-1)*((shortPeriod-1)/(shortPeriod+1));
    EMAlong(t)=clpr(t)*(2/(longPeriod+1))+EMAlong(t-1)*((longPeriod-1)/(longPeriod+1));
    %计算DIFF
    DIFF(t)=EMAshort(t)-EMAlong(t);
    %计算DEA
    DEA(t)=DIFF(t)*(2/(DEAPeriod+1))+DEA(t-1)*((DEAPeriod-1)/(DEAPeriod+1));
    %计算MACD
    MACD(t)=2*(DIFF(t)-DEA(t));
end
%画出行情序列图和各指标变化图
figure(1);
subplot(3,1,1);
plot(date,clpr,'r');
datetick('x','yyyymmdd');
xlabel('Date');
ylabel('Close Price');
title('Time Series of Stock');
grid on;
subplot(3,1,2);
plot(date,DIFF,'g',date,DEA,'b');
datetick('x','yyyymmdd');
legend('DIFF','DEA');
xlabel('Date');
ylabel('DIFF and DEA');
title('The DIFF and DEA of Stock');
grid on;
subplot(3,1,3);
plot(date,MACD,'r');
datetick('x','yyyymmdd');
xlabel('Date');
ylabel('MACD');
title('The MACD of Stock');
grid on;
%% 策略回测仿真
%%一个最简单的策略：1)DIFF向上突破MACD且连续三天处于MACD之上，则为买入信号；２)DIFF向下穿过MACD且连续三天处于MACD之下，则为卖出信号
%初始资金10000元
initial=10000;
%定义仓位：1表示多头，0表示空仓
pos=zeros(length(clpr),1);
%定义收益序列
Return=zeros(length(clpr),1);
figure(2);
plot(date,clpr,'r');
datetick('x','yyyymmdd');
xlabel('Date');
ylabel('Close Price');
title('Time Series of Stock');
grid on;
hold on;
%策略计算
for t=5:length(clpr)
    %定义买卖信号
    signalBuy=(DIFF(t)>MACD(t) && DIFF(t-1)>MACD(t-1) && DIFF(t-2)>MACD(t-2) && DIFF(t-3)<MACD(t-3) && DIFF(t-4)<MACD(t-4));
    signalSell=(DIFF(t)<MACD(t) && DIFF(t-1)<MACD(t-1) && DIFF(t-2)<MACD(t-2) && DIFF(t-3)>MACD(t-3) && DIFF(t-4)>MACD(t-4));
    %如果是买入信号且为空仓，则买入
    if (signalBuy==1 && pos(t-1)==0)
        pos(t)=1;
        text(date(t),clpr(t),'\leftarrow买');
        plot(date(t),clpr(t),'go');

    %如果是卖出信号且为多仓，则卖出
    elseif (signalSell==1 && pos(t-1)==1)
        pos(t)=0;
        text(date(t),clpr(t),'\leftarrow卖');
        plot(date(t),clpr(t),'bo');

    %其它情况一律不进行任何操作
    else    pos(t)=pos(t-1);
    end
end
%计算资金变化情况，交易成本假设为单边千分之三
Return(1)=initial;
for t=2:length(clpr)
    %空仓且没有买入信号
    if pos(t)==0 && pos(t-1)==0
        Return(t)=Return(t-1);
        continue;
    end
    %买入
    if pos(t)==1 && pos(t-1)==0
        Return(t)=Return(t-1)*(1-0.003);
        continue;
    end
    %持仓并且无卖出信号
    if pos(t)==1 && pos(t-1)==1
        Return(t)=Return(t-1)*(clpr(t)/clpr(t-1));
        continue;
    end
    %卖出
    if pos(t)==0 && pos(t-1)==1
        Return(t)=Return(t-1)*(clpr(t)/clpr(t-1))*(1-0.003);
        continue;
    end
end
%% 模型评价：收益率，夏普比率，绝对收益率，最大回撤等一些列指标，这里只画资金变化曲线
%画出资金变化曲线
hold off;
figure(3);
plot(date,Return,'r');
datetick('x','yyyymmdd');
xlabel('Date');
ylabel('Your Money');
title('The Return of Stock');
%画出持仓情况
figure(4);
plot(date,pos,'b');
datetick('x','yyyymmdd');
xlabel('Date');
ylabel('The state of your account');
