clear
clc
global EMA;
global Repeat
global Margin;
global Size;
global Account;
global Str1
global Str2
global CorrLev
global PosLim
global Freq
Freq= 240; % 市场交易长度（分钟）：大连、郑州=225 ，上海=215， 证券=240
STRATEGY=2; % 选择的交易策略,1 策略1；2 策略2； 3 强弱套利；
EMA=20; % 计算指数平均的周期数
Repeat=1; % 多久时间重新算一次ATR D
Margin=[0.05 0.05 0.07 1]; % 所交易品种的保证金率 1×i , i 资产数量，股票为1
Size= [5 5 8 1]; % 所交易品种的合约规模 1×i, 股票为1
Account=[100000000]; % 初始账户资金 D
Str1_in=20; % 策略一进场周期参数
Str2_in=55; % 策略二进场周期参数
Str1_out=10; % 策略一出场周期参数
Str2_out=20; % 策略二出场周期参数

P_RSV= 30*Freq; % 相对强弱指标
CorrAdj=30*Freq; % 市场相关性调查时间窗口长度，考虑到市场相关性的不对称性，买入考察下跌相关性，卖出考虑上涨相关性
CorrLev=[0.3 0.7]; % 相关性水平识别，高于它为高度相关性市场，低于它为低度相关市场。 1×2
PosLim=[4 6 8 10 12]; % 分别为单市场、高度相关、一般相关、低度相关、单向交易持仓限制 1×5
HoldingPosition=[]; % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间） 4×（5×i)
LastPL=[]; % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
Balance=[]; % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度
% Load your own data? into matrix "dat"

%% 数据初始化及参数设计
load data;
%{
海龟们用于确定能够参与交易的期货品种的主要标准就是构成市场基础的流动性。
每一个品种，我们要求具有以下几个指标：开、高 、低、收、量
%}

[m n]=size(data);
if round(n/5)~=n/5 || (m/Freq)<=max([Str1 Str2 20]) || length(Margin)~=length(Size) || length(Margin)~=n/5
    error('你输入的数据格式不满足我们的要求，请重新核对数据质量')
end

Q=n/5;
Days=fix(m/Freq);

%{
N就是TR（True Range，实际范围）的20日指数移动平均，现在更普遍地称之为ATR。
N表示单个交易日某个特定市场所造成的价格波动的平均范围。
N同样用构成合约基础的点（points）进行度量。
　　每日实际范围的计算：
　　TR（实际范围）=max(H-L,H-PDC,PDC-L)
　　式中：
　　H-当日最高价
　　L-当日最低价
　　PDC-前个交易日的收盘价
　　用下面的公式计算N：
　　N=(19×PDN+TR)/20
　　式中：
　　PDN-前个交易日的N值
　　TR-当日的实际范围
　　因为这个公式要用到前个交易日的N值，所以，你必须从实际范围的20日简单平均开始计算初始值。
%}

% 需要多久计算一次N值和单位大小？一般为一个星期一次，我这里用每天。

NMatrix=zeros(Days,Q);
for i=1:Q
    O=data(1:Freq:Days*Freq,i*5-4);H=data(1:Freq:Days*Freq,i*5-3);L=data(1:Freq:Days*Freq,i*5-2);C=data(1:Freq:Days*Freq,i*5-1);
    V=data(1:Freq:Days*Freq,i*5);PDC=[0;C(1:end-1,:)];
    
    % 画出蜡烛图走势
    cndl(O,H,L,C);
    title('Figure 蜡烛图 ');
    ylabel('价格水平');
    xlabel('观察样本');
    grid on;
    saveas(gcf,strcat('Candle_',num2str(i),'.eps'),'psc2');
    
    for j=1:Repeat:Days
        if j==1
            TR=max([H(j)-L(j)]);
            NMatrix(i,j)=TR;
        elseif j<EMA && j>1
            TR=max([H(j)-L(j) ,H(j)-PDC(j),PDC(j)-L(j)]);
            NMatrix(i,j)=((j-1)*NMatrix(i,j-1)+TR)/j;
        else
            TR=max([H(j)-L(j) ,H(j)-PDC(j),PDC(j)-L(j)]);
            NMatrix(i,j)=((EMA-1)*NMatrix(i,j-1)+TR)/EMA;
        end
    end
end

DailyData=data(1:Freq:Days*Freq,:);

%{
价值量波动性=N×每点价值量
按照我们所称的单位（Units）建立头寸。单位重新计算，使1N代表帐户净值的1%。
因为海龟把单位用作头寸规模的量度基础，还因为那些单位已经过波动性风险调整，所以，单位既是头寸风险的量度标准，又是头寸整个投资组合的量度标准。
单位=帐户的1%/(N×每点价值量)
%}

VN=zeros(Days,Q); %波动单位价值量,及其单位

% 说明，此段被省略是因为在后面给出了更为精确的风险资金算法
% for i=1:Q
% for j=1:Days
% % 调整交易规模，海龟不使用以起始净值为基础的、连续结算的标准帐户进行交易。我们假设账户每季度调整一次。盈利入金，亏损出金。注意，此处
% % 不精确，没有考虑P&L对资金的影响。
% ValuePerPoint=N(i,j)*Size(i)/Margin(i); % 一手波动全部损失所值价值
% VN(i,j)=fix((0.01*Account)/ValuePerPoint); % 用账户的1%来覆盖风险波动值，交易手数向下取整
% end
% end


HoldingPosition=zeros(4,5*Q); % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,开仓时间） 4×（5×i)
LastPL=[0, 0, 0, 0, 1]; % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
Balance=repmat([Account ,0],m,1); % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度
%% 交易策略正式开始测试：
% 首先运算出辅助指标??RSV
RSV=50*ones(m,Q);
for i=1:Q
    O=data(:,i*5-4);H=data(:,i*5-3);L=data(:,i*5-2);C=data(:,i*5-1);
    RSV(:,i)=rsv(H,L,C,P_RSV);
end

PLI=[ DailyData(1,1:5:end);zeros(2,Q)];% 上一次开仓价位、方向、以及盈利与否示性指标，确认短期开仓信号要用到。

for j=max([Str1_in,Str2_in,P_RSV/Freq])*Freq+1:Days*Freq
    Today=fix(j/Freq)+1; % 现在所处的交易日
    
    % 系统2----以50日突破为基础的偏短线系统
    
    newlip=[0, 0, 0, inf,0]; % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】
    MarketValue=0; % 市值水平。
    
    for i=1:Q
        O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);C=data(j,i*5-1);
        QuitL=min(DailyData(Today-Str2_out:Today-1,i*5-2));
        QuitH=max(DailyData(Today-Str2_out:Today-1,i*5-3));
        HoldingPosition=zeros(4,5*Q); % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,开仓时间） 4×（5×i)
        if any(HoldingPosition(:,i*5-4)) % 表示有档位的持仓非空
            ii=find(HoldingPosition(:,i*5-3)~=0);
            for k=1:ii
                if HoldingPosition(k,i*5-2)==1  % 多头
                    if L<=HoldingPosition(k,i*5-1) % 止损触发
                        % LastPL=[0, 0, 0, 0, 1]; % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
                        % Balance=[Account ,0]; % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度
                        
                        newlip(1,1)=newlip(1,1)+(HoldingPosition(k,i*5-1)-HoldingPosition(k,i*5-4))*HoldingPosition(k,i*5-3); % 盈亏
                        newlip(1,2)=newlip(1,2)-HoldingPosition(k,i*5-3); % 多头减少量
                        newlip(1,3)=newlip(1,3)+0;
                        newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                        newlip(1,5)=max([newlip(1,5),j]);
                        
                        HoldingPosition(k,:)=zeros(1,5); % 还原仓位
                        PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                        PLI(2,i)=1; % 方向
                        PLI(3,i)=-1; % 亏损与否
                    elseif L<=QuitL % 退出触发
                        newlip(1,1)=newlip(1,1)+(HoldingPosition(k,i*5-1)-QuitL)*HoldingPosition(k,i*5-3); % 盈亏
                        newlip(1,2)=newlip(1,2)-HoldingPosition(k,i*5-3); % 多头减少量
                        newlip(1,3)=newlip(1,3)+0;
                        newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                        newlip(1,5)=max([newlip(1,5),j]);
                        
                        HoldingPosition(k,:)=zeros(1,5); % 还原仓位
                        
                        PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                        PLI(2,i)=1; % 方向
                        if (HoldingPosition(k,i*5-1)-QuitL)*HoldingPosition(k,i*5-3)<0
                            PLI(3,i)=-1; % 亏损
                        else
                            PLI(3,i)=1; % 盈利
                        end
                    end
                    
                elseif HoldingPosition(k,i*5-2)==-1 %空头
                    if H>=HoldingPosition(k,i*5-1) % 止损触发
                        %?LastPL=[0, 0, 0, 0, 1]; % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
                        %?Balance=[Account ,0]; % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度
                        
                        newlip(1,1)=newlip(1,1) -(HoldingPosition(k,i*5-1)-HoldingPosition(k,i*5-4))*HoldingPosition(k,i*5-3); % 盈亏
                        newlip(1,2)=newlip(1,2)+0;
                        newlip(1,3)=newlip(1,3)-HoldingPosition(k,i*5-3);% 空头减少量
                        newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                        newlip(1,5)=max([newlip(1,5),j]);
                        
                        HoldingPosition(k,:)=zeros(1,5); % 还原仓位
                        PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                        PLI(2,i)=-1; % 方向
                        PLI(3,i)=-1; % 亏损与否
                    elseif H>=QuitH % 退出触发
                        newlip(1,1)=newlip(1,1) -(HoldingPosition(k,i*5-1)-QuitH)*HoldingPosition(k,i*5-3); % 盈亏
                        newlip(1,2)=newlip(1,2)+0;
                        newlip(1,3)=newlip(1,3)-HoldingPosition(k,i*5-3);% 空头减少量
                        newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                        newlip(1,5)=max([newlip(1,5),j]);
                        
                        HoldingPosition(k,:)=zeros(1,5); % 还原仓位
                        
                        PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                        PLI(2,i)=-1; % 方向
                        if -(HoldingPosition(k,i*5-1)-QuitH)*HoldingPosition(k,i*5-3)<0
                            PLI(3,i)=-1; % 亏损
                        else
                            PLI(3,i)=1; % 盈利
                        end
                    end
                end
            end
        end

    % 更新平仓历史记录
    if newlip(1,1)~=0
        LastPL=[LastPL;newlip];
    end
    
    for i=1:Q
        O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);C=data(j,i*5-1);
        MarketValue=MarketValue+sum(HoldingPosition(:,i*5-3)*C);
    end
    
    % 更新账户损益信息
    Balance(j,:)=[Balance(j-1,1)+newlip(1,1), MarketValue];
    
    RSV_j=RSV(j,:);
    [s sr]= sort(RSV_j,'descend'); % 获得从大到小排序。
    [s2 sr2]= sort(RSV_j); % 获得从小到大排序。
    
    % 率先对仓位和风险水平做一个核算。
    % 风险水平，根据相关性水平进行那个核算。
    % 首先要把价格序列转换成收益率。
    MCorr=[0;0]; % 下相关和 上相关
    for i=1:Q
        for k=i+1
            Ci=data(j-CorrAdj:j,i*5-1); Ck=data(j-CorrAdj:j,k*5-1);
            ri=price2ret(Ci); rk=price2ret(Ck);
            [corrxy] = exceedence_corr(ri,rk,0,0); % 均值左右的相关性<0 ;>0
            MCorr=MCorr+corrxy;
        end
    end
    MCorr=MCorr/(i*(i-1)/2);
    
    % 做多风险控制，观察下跌相关性风险
    if MCorr(1,1)<= CorrLev(1,1)
        CB=PosLim(1,4);
    elseif MCorr(1,1)>= CorrLev(1,2)
        CB=PosLim(1,2);
    else
        CB=PosLim(1,3);
    end
    
    % 做空风险控制，观察上涨相关性风险
    if MCorr(2,1)<= CorrLev(1,1)
        CS=PosLim(1,4);
    elseif MCorr(2,1)>= CorrLev(1,2)
        CS=PosLim(1,2);
    else
        CS=PosLim(1,3);
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 再统计现在剩余的盘口数
    BQ=0; % 买单位数 buy quantity
    SQ=0; % 卖单位数
    for i=1:Q
        for k=1:4
            if HoldingPosition(k,i*5-3)~=0 && HoldingPosition(k,i*5-2)==1
                BQ=BQ+1;
            end
            if HoldingPosition(k,i*5-3)~=0 && HoldingPosition(k,i*5-2)==-1
                SQ=SQ+1;
            end
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 根据风险控制概念，现在还可以做多和做空的单位数分别为：
    PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ; % permit buy,相关性风险下可以允许少部分对冲，但总单向持仓不能找过一个限度。
    PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ; % permit sell
    
    for ll=1:Q
        if PB>0 % 有剩余头寸
            i=sr(ll); % 首先从RSV最大的开始
            O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);
            EnterL=min(DailyData(Today-Str2_in:Today-1,i*5-2));
            EnterH=max(DailyData(Today-Str2_in:Today-1,i*5-3));
            N= NMatrix(Today-1,i);
            ValuePerPoint=N*Size(i)/Margin(i); % 一手波动全部损失所值价值
            VN= fix(0.01*sum(Balance(j-1,:))/ValuePerPoint); % 每个标准风险单位
            PriceVN_B=VN*H*Margin(i)*Size(i); % 做多每组所需资金
            if H>=EnterH
                if HoldingPosition(1,i*5-3)==0
                    % 虚位以待！
                    if Balance(j-1,1)>PriceVN_B
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(1,i*5-4)=(EnterH);
                        HoldingPosition(1,i*5-3)=(VN);
                        HoldingPosition(1,i*5-2)=(1);
                        HoldingPosition(1,i*5-1)=(EnterH-2*N); %% 注：预设2倍止损！
                        HoldingPosition(1,i*5)=(j);
                        
                        HoldingPosition(2:4,i*5-4:i*5)=zeros;
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_B; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_B;
                        
                        BQ=BQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                    
                    %{
 为了保证全部头寸的风险最小，如果另外增加单位，前面单位的止损就提高1/2N。
 这一般意味着全部头寸的止损将被设置在踞最近增加的单位的2N处。

 然而，在后面单位因市场波动太快造成“打滑（skid）”或者因开盘跳空而以较大的间隔设置的情况下，止损就有所不同。
                    %}
                elseif HoldingPosition(1,i*5-3)~=0 && HoldingPosition(2,i*5-3)==0 && H>=HoldingPosition(1,i*5-4)+0.5*N
                    if Balance(j-1,1)>PriceVN_B
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(2,i*5-4)=(HoldingPosition(1,i*5-4)+0.5*N);
                        HoldingPosition(2,i*5-3)=(VN);
                        HoldingPosition(2,i*5-2)=(1);
                        HoldingPosition(2,i*5-1)=(HoldingPosition(2,i*5-4)-2*N); %% 注：预设2倍止损！
                        HoldingPosition(2,i*5)=(j);
                        
                        HoldingPosition(1,i*5-1)=(HoldingPosition(1,i*5-4)-2*N+0.5*N); %% 止损水平提高
                        HoldingPosition(3:4,i*5-4:i*5)=zeros;
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_B; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_B;
                        
                        BQ=BQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                elseif HoldingPosition(2,i*5-3)~=0 && HoldingPosition(3,i*5-3)==0 && H>=HoldingPosition(2,i*5-4)+0.5*N
                    if Balance(j-1,1)>PriceVN_B
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(3,i*5-4)=(HoldingPosition(2,i*5-4)+0.5*N);
                        HoldingPosition(3,i*5-3)=(VN);
                        HoldingPosition(3,i*5-2)=(1);
                        HoldingPosition(3,i*5-1)=(HoldingPosition(3,i*5-4)-2*N); %% 注：预设2倍止损！
                        HoldingPosition(3,i*5)=(j);
                        
                        HoldingPosition(1,i*5-1)=(HoldingPosition(1,i*5-4)-2*N+N); %% 止损水平提高
                        HoldingPosition(2,i*5-1)=(HoldingPosition(2,i*5-4)-2*N+0.5*N); %% 止损水平提高
                        HoldingPosition(4,i*5-4:i*5)=zeros;
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_B; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_B;
                        
                        BQ=BQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                elseif HoldingPosition(3,i*5-3)~=0 && HoldingPosition(4,i*5-3)==0 && H>=HoldingPosition(3,i*5-4)+0.5*N
                    if Balance(j-1,1)>PriceVN_B
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(4,i*5-4)=(HoldingPosition(3,i*5-4)+0.5*N);
                        HoldingPosition(4,i*5-3)=(VN);
                        HoldingPosition(4,i*5-2)=(1);
                        HoldingPosition(4,i*5-1)=(HoldingPosition(4,i*5-4)-2*N); %% 注：预设2倍止损！
                        HoldingPosition(4,i*5)=(j);
                        
                        HoldingPosition(1,i*5-1)=(HoldingPosition(1,i*5-4)-2*N+1.5*N); %% 止损水平提高
                        HoldingPosition(2,i*5-1)=(HoldingPosition(2,i*5-4)-2*N+1*N); %% 止损水平提高
                        HoldingPosition(3,i*5-1)=(HoldingPosition(3,i*5-4)-2*N+0.5*N); %% 止损水平提高
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_B; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_B;
                        
                        BQ=BQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                end
            end
        end
        
        
        if PS>0
            i=sr2(ll); % 首先从RSV最小的开始
            O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);C=data(j,i*5-1);
            EnterL=min(DailyData(Today-Str2_in:Today-1,i*5-2));
            EnterH=max(DailyData(Today-Str2_in:Today-1,i*5-3));
            N= NMatrix(Today-1,i);
            ValuePerPoint=N*Size(i)/Margin(i); % 一手波动全部损失所值价值
            VN= fix(0.01*sum(Balance(j-1,:))/ValuePerPoint); % 每个标准风险单位
            PriceVN_S=VN*L*Margin(i)*Size(i); % 做多每组所需资金
            if L<=EnterL
                if HoldingPosition(1,i*5-3)==0
                    % 虚位以待！
                    if Balance(j-1,1)>PriceVN_S
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(1,i*5-4)=(EnterL);
                        HoldingPosition(1,i*5-3)=(VN);
                        HoldingPosition(1,i*5-2)=(-1);
                        HoldingPosition(1,i*5-1)=(EnterL+2*N); %% 注：预设2倍止损！
                        HoldingPosition(1,i*5)=(j);
                        
                        HoldingPosition(2:4,i*5-4:i*5)=zeros;
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_S; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_S;
                        
                        SQ=SQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                    
                    %{
 为了保证全部头寸的风险最小，如果另外增加单位，前面单位的止损就提高1/2N。
 这一般意味着全部头寸的止损将被设置在踞最近增加的单位的2N处。
 然而，在后面单位因市场波动太快造成“打滑（skid）”或者因开盘跳空而以较大的间隔设置的情况下，止损就有所不同。
                    %}
                elseif HoldingPosition(1,i*5-3)~=0 && HoldingPosition(2,i*5-3)==0 && L<=HoldingPosition(1,i*5-4)-0.5*N
                    if Balance(j-1,1)>PriceVN_S
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(2,i*5-4)=(HoldingPosition(1,i*5-4)-0.5*N);
                        HoldingPosition(2,i*5-3)=(VN);
                        HoldingPosition(2,i*5-2)=(-1);
                        HoldingPosition(2,i*5-1)=(HoldingPosition(2,i*5-4)+2*N); %% 注：预设2倍止损！
                        HoldingPosition(2,i*5)=(j);
                        
                        HoldingPosition(1,i*5-1)=(HoldingPosition(1,i*5-4)+2*N-0.5*N); %% 止损水平提高
                        HoldingPosition(3:4,i*5-4:i*5)=zeros;
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_S; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_S;
                        
                        SQ=SQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                elseif HoldingPosition(2,i*5-3)~=0 && HoldingPosition(3,i*5-3)==0 && L<=HoldingPosition(2,i*5-4)-0.5*N
                    if Balance(j-1,1)>PriceVN_S
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(3,i*5-4)=(HoldingPosition(2,i*5-4)-0.5*N);
                        HoldingPosition(3,i*5-3)=(VN);
                        HoldingPosition(3,i*5-2)=(-1);
                        HoldingPosition(3,i*5-1)=(HoldingPosition(3,i*5-4)+2*N); %% 注：预设2倍止损！
                        HoldingPosition(3,i*5)=(j);
                        
                        HoldingPosition(1,i*5-1)=(HoldingPosition(1,i*5-4)+2*N-N); %% 止损水平提高
                        HoldingPosition(2,i*5-1)=(HoldingPosition(2,i*5-4)+2*N-0.5*N); %% 止损水平提高
                        HoldingPosition(4,i*5-4:i*5)=zeros;
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_S; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_S;
                        
                        SQ=SQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                elseif HoldingPosition(3,i*5-3)~=0 && HoldingPosition(4,i*5-3)==0 && L<=HoldingPosition(3,i*5-4)-0.5*N
                    if Balance(j-1,1)>PriceVN_S
                        % % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间）
                        % 4×（5×i)
                        HoldingPosition(4,i*5-4)=(HoldingPosition(3,i*5-4)-0.5*N);
                        HoldingPosition(4,i*5-3)=(VN);
                        HoldingPosition(4,i*5-2)=(-1);
                        HoldingPosition(4,i*5-1)=(HoldingPosition(4,i*5-4)-2*N); %% 注：预设2倍止损！
                        HoldingPosition(4,i*5)=(j);
                        
                        HoldingPosition(1,i*5-1)=(HoldingPosition(1,i*5-4)+2*N-1.5*N); %% 止损水平提高
                        HoldingPosition(2,i*5-1)=(HoldingPosition(2,i*5-4)+2*N-1*N); %% 止损水平提高
                        HoldingPosition(3,i*5-1)=(HoldingPosition(3,i*5-4)+2*N-0.5*N); %% 止损水平提高
                        
                        Balance(j,1)=Balance(j-1,1)-PriceVN_S; % 资金账户划转
                        Balance(j,2)=Balance(j-1,2)+PriceVN_S;
                        
                        SQ=SQ+1; % 可买卖单位调整
                        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;
                        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;
                    end
                end
            end
        end
    end
    end
end







% out=fopen('turtle','at');
%  fprintf(out,'********************最终交易结果***********************\n');
%  fprintf(out,'最终仓位持有情况? \n');
%  for i=1:Q
%  fprintf(out,'交易资产：?? %u\n',i);
%  fprintf(out,'开仓价格 持仓量 开仓方向 止损价位 开仓时间\n');
%  for k=1:4
%  fprintf(out,'%u?? %u?? %u %u %u\n',HoldingPosition(k,i*5-4),...
%  HoldingPosition(k,i*5-3),HoldingPosition(k,i*5-2),HoldingPosition(k,i*5-1),HoldingPosition(k,i*5-0));
%  end
%  fprintf(out,'\n');
%  end
%  fprintf(out,'期间共计交易次数? %u\n', size(LastPL,1)-1);
%  fprintf(out,'期间共计总计盈亏? %u\n', sum(LastPL(:,1)));
%  fprintf(out,'最后所持有的现金? %u\n', Balance(end,1));
%  fprintf(out,'最后所持有的市值? %u\n', Balance(end,2));
%  fclose(out);
%
%  plot(LastPL(:,1))
%  title('Figure 交易盈亏');
%  ylabel('每次交易盈亏水平');
%  xlabel('交易次数');
%  grid on;
%  saveas(gcf,strcat('P&L_',num2str(i),'.eps'),'psc2');
%
%  plot(Balance)
%  title('Figure 账户平衡表');
%  ylabel('每次交易导致的账面水平变动');
%  xlabel('每期观察');
%  grid on;
%  saveas(gcf,strcat('Balance_',num2str(i),'.eps'),'psc2');
%
%  save STRATEGY1 LastPL Balance HoldingPosition
% end
