%% Turtle.M
% 海龟交易法则
% 主要包括：
%     ? 市场----买卖什么，根据SVR强弱觉得买卖优先顺序
% 　　? 头寸规模----买卖多少，根据ATR以及不对称相关性风险矩阵进行寸风险管理
% 　　? 入市----何时买卖，根据突破信号辨别方法，辨别真假信号，并受账户资金水平限制其头寸，这里没有考虑到快速变化行情的滑点。
% 　　? 止损----何时退出亏损的头寸，根据ATR和固定损失水平设定。这里没有考虑到快速变化行情的滑点。
% 　　? 离市----何时退出赢利的头寸，根据特定参数回归。
% 　　? 策略----如何买卖，此处只考虑了4种策略，但如何更细致的执行改策略我们没有考虑到。如：如何利用其他指标辅助，如何优化组合资产配置等。

% 说明： 
% 为了明晰化思路，一些循环被拆成若干个子循环，影响了速度，但不妨碍我们学习和分析。
% 为了更为精确的服务高频数据，这里设定所得数据为1分钟数据。所以，这里特别要注意的是，程序目前只能处理同样交易时间的市场品种。
% 那么，郑州和大连(9:00-10:15 10:30-11:30 1:30-3:00)，上海(9:00-10：15 10：30-11：30 1：30-2：10  2：20-3：00)，证券市场(9:30-11:30 1:00-3:00)就被割裂开来了。
% 因为无法控制非对称时间窗口内的风险，策略和程序暂时不向此扩展和修改。不过，如果用天数据，则不存在任何问题了。

% 讨论：
% 这里我没有写出强弱讨论程序，因为我觉得我的思路还不完全清晰。我的初步想法是，根据相关性水平，如果上涨相关性水平高情形下，
% 如果上涨击穿压力线，则买入最强的SVR，卖出最弱的；理论根据是journal of Finance 2002, Andrew , and

%%  Controls %
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
Freq= 1;           % 市场交易长度（分钟）：大连、郑州=225 ，上海=215， 证券=240
STRATEGY=1;          % 选择的交易策略,1 策略1；2 策略2； 3 强弱套利； d
EMA=20;              % 计算指数平均的周期数 d
Repeat=1;            % 多久时间重新算一次ATR D
Margin=ones(1,12);           % 所交易品种的保证金率 1×i , i 资产数量，股票为1
Size=100*ones(1,12);            % 所交易品种的合约规模 1×i, 股票为100,铜为5；etc。
Account=[100000000];          % 初始账户资金 D
Str1_in=20;          % 策略一进场周期参数 d
Str2_in=55;          % 策略二进场周期参数 d
Str1_out=10;         % 策略一出场周期参数 d
Str2_out=20;         % 策略二出场周期参数 d

P_RSV= 50*Freq;      % 相对强弱指标
CorrAdj=50*Freq;     % 市场相关性调查时间窗口长度，考虑到市场相关性的不对称性，买入考察下跌相关性，卖出考虑上涨相关性
CorrLev=[0.3 0.7];   % 相关性水平识别，高于它为高度相关性市场，低于它为低度相关市场。 1×2
PosLim=[4 6 8 10 12];  % 分别为单市场、高度相关、一般相关、低度相关、单向交易持仓限制 1×5
HoldingPosition=[];  % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,,开仓时间） 4×（5×i)
LastPL=[];           % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
Balance=[];          % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度

%% 数据初始化及参数设计

data=csvread('IF888_1分钟.csv');

[m n]=size(data);
Q=1;
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
    
    O=data(1:Freq:Days*Freq,3);
    H=data(1:Freq:Days*Freq,4);
    L=data(1:Freq:Days*Freq,5);
    C=data(1:Freq:Days*Freq,6);
    V=data(1:Freq:Days*Freq,7);
    PDC=[C(1);C(1:end-1,:)];

    for j=1:Repeat:Days
        if j==1
            TR=max([H(j)-L(j) ,H(j)-PDC(j),PDC(j)-L(j)]);
            NMatrix(j,1)=TR;
        elseif j<EMA && j>1
            TR=max([H(j)-L(j) ,H(j)-PDC(j),PDC(j)-L(j)]);
            NMatrix(j,1)=((j-1)*NMatrix(j-1,1)+TR)/j;
        else
            TR=max([H(j)-L(j) ,H(j)-PDC(j),PDC(j)-L(j)]);
            NMatrix(j,1)=((EMA-1)*NMatrix(j-1,1)+TR)/EMA;
        end
    end


% save ATR NMatrix
DailyData=data(1:Freq:Days*Freq,:);

%{
 价值量波动性=N×每点价值量
按照我们所称的单位（Units）建立头寸。单位重新计算，使1N代表帐户净值的1%。
因为海龟把单位用作头寸规模的量度基础，还因为那些单位已经过波动性风险调整，所以，单位既是头寸风险的量度标准，又是头寸整个投资组合的量度标准。
单位=帐户的1%/(N×每点价值量)
%}

HoldingPosition=zeros(4,5*Q);  % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,开仓时间） 4×（5×i)
LastPL=[0, 0, 0, 0, 0];        % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
Balance=repmat([Account ,0],m,1);          % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度

%% 交易策略正式开始测试：
% 首先运算出辅助指标——RSV
RSV=50*ones(m,Q);
for i=1:Q
    O=data(:,i*5-4);H=data(:,i*5-3);L=data(:,i*5-2);C=data(:,i*5-1);
    RSV(:,i)=rsv(H,L,C,P_RSV);
end

PLI=zeros(3,Q);% 上一次开仓价位、方向、以及盈利与否示性指标，确认短期开仓信号要用到。

    for j=max([Str1_in,Str2_in,Str1_out,Str2_out,P_RSV/Freq,CorrAdj/Freq])*Freq+1:Days*Freq
        Today=ceil(j/Freq); % 现在所处的交易日，向上取整

        % 系统一----以20日突破为基础的偏短线系统

        %{
        1,海龟的止损
　　有了止损并不意味着海龟总是让经纪人设置实际的止损指令。
　　因为海龟持有如此大量的头寸，所以，我们不想因为让经纪人设置止损指令而泄露我们的头寸或我们的交易策略。
    相反，我们被鼓励设定某个价位，一旦达到该价位，我们就会使用限价指令或市价指令退出头寸。
        2,离开市场
    系统一离市对于多头头寸为10日最低价，对于空头头寸为10日最高价。如果价格波动与头寸背离至10日突破，头寸中的所有单位都会退出。
        %}
        newlip=[0, 0, 0, inf,0]; % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】
        MarketValue=0; % 市值水平。

        for i=1:Q
            O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);C=data(j,i*5-1);
            QuitL=min(DailyData(Today-Str1_out:Today-1,i*5-2));
            QuitH=max(DailyData(Today-Str1_out:Today-1,i*5-3));
            %             HoldingPosition=zeros(4,5*Q);  % 持仓，针对每一个品种，描述出其（开仓价格，持仓量，开仓方向，预设止损值,开仓时间） 4×（5×i)
            if any(HoldingPosition(:,i*5-4)) % 表示有档位的持仓非空
                ii=find(HoldingPosition(:,i*5-3)~=0);
                for k=1:ii
                    if HoldingPosition(k,i*5-2)==1  % 多头
                        if L<=HoldingPosition(k,i*5-1) % 止损触发
                            %                             LastPL=[0, 0, 0, 0, 1];        % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
                            %                             Balance=[Account ,0];          % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度

                            newlip(1,1)=newlip(1,1)+(HoldingPosition(k,i*5-1)-HoldingPosition(k,i*5-4))*HoldingPosition(k,i*5-3); % 盈亏
                            newlip(1,2)=newlip(1,2)-HoldingPosition(k,i*5-3); % 多头减少量
                            newlip(1,3)=newlip(1,3)+0;
                            newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                            newlip(1,5)=max([newlip(1,5),j]);
                            

                            HoldingPosition(k,i*5-4:i*5)=zeros(1,5);  % 还原仓位
                            PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                            PLI(2,i)=1;  % 方向
                            PLI(3,i)=-1; % 亏损与否
                        elseif L<=QuitL                % 退出触发
                            newlip(1,1)=newlip(1,1)+(HoldingPosition(k,i*5-1)-QuitL)*HoldingPosition(k,i*5-3); % 盈亏
                            newlip(1,2)=newlip(1,2)-HoldingPosition(k,i*5-3); % 多头减少量
                            newlip(1,3)=newlip(1,3)+0;
                            newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                            newlip(1,5)=max([newlip(1,5),j]);

                            HoldingPosition(k,i*5-4:i*5)=zeros(1,5);  % 还原仓位

                            PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                            PLI(2,i)=1;  % 方向
                            if (HoldingPosition(k,i*5-1)-QuitL)*HoldingPosition(k,i*5-3)<0
                                PLI(3,i)=-1; % 亏损
                            else
                                PLI(3,i)=1;  % 盈利
                            end

                        else
                        end

                    elseif  HoldingPosition(k,i*5-2)==-1     %空头
                        if H>=HoldingPosition(k,i*5-1) % 止损触发
                            %                             LastPL=[0, 0, 0, 0, 1];        % 平仓记录，【盈利状况 多头水平 空头水平 开仓时间 平仓时间】 K*(5×i),k交易次数
                            %                             Balance=[Account ,0];          % 账户可用资金 账户交易资产现值 m*(2*i)，m时间长度

                            newlip(1,1)=newlip(1,1) -(HoldingPosition(k,i*5-1)-HoldingPosition(k,i*5-4))*HoldingPosition(k,i*5-3); % 盈亏
                            newlip(1,2)=newlip(1,2)+0;
                            newlip(1,3)=newlip(1,3)-HoldingPosition(k,i*5-3);% 空头减少量
                            newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                            newlip(1,5)=max([newlip(1,5),j]);

                            HoldingPosition(k,i*5-4:i*5)=zeros(1,5);  % 还原仓位
                            PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                            PLI(2,i)=-1;  % 方向
                            PLI(3,i)=-1;  % 亏损与否
                        elseif H>=QuitH                % 退出触发
                            newlip(1,1)=newlip(1,1) -(HoldingPosition(k,i*5-1)-QuitH)*HoldingPosition(k,i*5-3); % 盈亏
                            newlip(1,2)=newlip(1,2)+0;
                            newlip(1,3)=newlip(1,3)-HoldingPosition(k,i*5-3);% 空头减少量
                            newlip(1,4)=min([newlip(1,4),HoldingPosition(k,i*5)]);
                            newlip(1,5)=max([newlip(1,5),j]);

                            HoldingPosition(k,i*5-4:i*5)=zeros(1,5);  % 还原仓位

                            PLI(1,i)=HoldingPosition(k,i*5-4);% 开仓价位
                            PLI(2,i)=-1;  % 方向
                            if -(HoldingPosition(k,i*5-1)-QuitH)*HoldingPosition(k,i*5-3)<0
                                PLI(3,i)=-1; % 亏损
                            else
                                PLI(3,i)=1;  % 盈利
                            end
                        else
                        end
                    else
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
        %%
        % 开仓信号产生和确认以及加仓信号的确认
        %{
      如果上次突破已导致赢利的交易，系统一的突破入市信号就会被忽视。注意：为了检验这个问题，上次突破被视为某种商品上最近一次的突破，
      而不管对那次突破是否实际被接受，或者因这项法则而被忽略。如果有赢利的10日离市之前，突破日之后的价格与头寸方向相反波动了2N，
      那么，这一突破就会被视为失败的突破。
　　  上次突破的方向与这项法则无关。因此，亏损的多头突破或亏损的空头突破将使随后新的突破被视为有效的突破，而不管它的方向如何（即多头或空头）。

      然而，如果系统一的入市突破由于以前的交易已经取得赢利而被忽略，还可以在55日突破时入市，以避免错过主要的波动。
      这种55日突破被视为自动保险突破点（Failsafe Breakout point）。

      多品种组合时，开仓顺序按照相对强弱指标排序进行对比。做多时，买强；做空时，卖弱。
        %}

        RSV_j=RSV(j,:);
        [s sr]= sort(RSV_j,'descend'); % 获得从大到小排序。
        [s2 sr2]= sort(RSV_j);           % 获得从小到大排序。

        % 率先对仓位和风险水平做一个核算。
        % 风险水平，根据相关性水平进行那个核算。
        % 首先要把价格序列转换成收益率。
        MCorr=[]; % 下相关和 上相关
        
        % 为了能够分析一个品种，我们这里需要增加一次判断样本量，否则，相关矩阵运算会出错。
        if Q>1
            for i=1:Q-1
                for k=i+1
                    Ci=data(j-CorrAdj:j,i*5-1); Ck=data(j-CorrAdj:j,k*5-1);
                    ri=diff(log(Ci)); rk=diff(log(Ck));
                    [corrxy] = exceedence_corr(ri,rk,0,0); % 均值左右的相关性<0 ;>0
                    MCorr=[MCorr,corrxy];
                end
            end
            MCorr=mean(MCorr,2);
            
            
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
        else
            CB=PosLim(1,1);
            CS=PosLim(1,1);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % 再统计现在剩余的盘口数
        %{
最大头寸限制为：
　　级别        类型            最大单位
　　1        单一市场           4个单位
　　2      高度相关市场         6个单位
    3      一般相关度市场       8个单位
　　4      低度相关市场         10个单位
　　5   单向交易—多头或空头    12个单位
如果止损风险容度为2N，对单向交易而言，一次性系统承担的最大风险为-24%
        %}
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
        PB=min([CB+SQ-BQ PosLim(1,5)-BQ]) ;  % permit buy,相关性风险下可以允许少部分对冲，但总单向持仓不能找过一个限度。
        PS=min([CS+BQ-SQ PosLim(1,5)-SQ]) ;  % permit sell

        for ll=1:Q
            if PB>0 % 有剩余头寸
                i=sr(ll); % 首先从RSV最大的开始
                O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);
                EnterL=min(DailyData(Today-Str1_in:Today-1,i*5-2));
                EnterH=max(DailyData(Today-Str1_in:Today-1,i*5-3));
                N= NMatrix(Today-1,i);
                ValuePerPoint=N*Size(i)/Margin(i); % 一手波动全部损失所值价值
                VN= fix(0.01*sum(Balance(j-1,:))/ValuePerPoint); % 每个标准风险单位
                PriceVN_B=VN*H*Margin(i)*Size(i); % 做多每组所需资金
                if H>=EnterH
                    if PLI(2,i)==-1 || PLI(3,i)==-1 || PLI(2,i)==1 && PLI(1,i)-EnterL>=2*N || H>= max(DailyData(Today-Str2_in:Today-1,i*5-3))
                        % 上次交易为做空 或上次交易亏损 或 上次交易也是做多，不过开仓位置与这一次最低点没有超过2N
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
                        elseif  HoldingPosition(1,i*5-3)~=0 && HoldingPosition(2,i*5-3)==0 && H>=HoldingPosition(1,i*5-4)+0.5*N
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
                        elseif  HoldingPosition(2,i*5-3)~=0 && HoldingPosition(3,i*5-3)==0 && H>=HoldingPosition(2,i*5-4)+0.5*N
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
                        elseif  HoldingPosition(3,i*5-3)~=0 && HoldingPosition(4,i*5-3)==0 && H>=HoldingPosition(3,i*5-4)+0.5*N
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
                        else
                        end
                    end
                else
                end
            end

            if  PS>0
                i=sr2(ll); % 首先从RSV最小的开始
                O=data(j,i*5-4);H=data(j,i*5-3);L=data(j,i*5-2);C=data(j,i*5-1);
                EnterL=min(DailyData(Today-Str1_in:Today-1,i*5-2));
                EnterH=max(DailyData(Today-Str1_in:Today-1,i*5-3));
                N= NMatrix(Today-1,i);
                ValuePerPoint=N*Size(i)/Margin(i); % 一手波动全部损失所值价值
                VN= fix(0.01*sum(Balance(j-1,:))/ValuePerPoint); % 每个标准风险单位
                PriceVN_S=VN*L*Margin(i)*Size(i); % 做多每组所需资金
                if L<=EnterL
                    if PLI(2,i)==1 || PLI(3,i)==-1 || PLI(2,i)==-1 && EnterH -PLI(1,i)>=2*N || L<=min(DailyData(Today-Str2_in:Today-1,i*5-2));
                        % 上次交易为做多 或上次交易亏损 或 上次交易也是做空，不过开仓位置与这一次最高点没有超过2N
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
                        elseif  HoldingPosition(1,i*5-3)~=0 && HoldingPosition(2,i*5-3)==0 && L<=HoldingPosition(1,i*5-4)-0.5*N
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
                        elseif  HoldingPosition(2,i*5-3)~=0 && HoldingPosition(3,i*5-3)==0 && L<=HoldingPosition(2,i*5-4)-0.5*N
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
                        elseif  HoldingPosition(3,i*5-3)~=0 && HoldingPosition(4,i*5-3)==0 && L<=HoldingPosition(3,i*5-4)-0.5*N
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
                        else
                        end
                    end
                else
                end
            end
        end
    end
    sign=unique(LastPL(2:end,4:5));
    save sign.mat sign
    
    

    
    
