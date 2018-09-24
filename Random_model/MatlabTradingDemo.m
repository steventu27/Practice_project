% MATLAB�������ײ��Է���һ���򵥾��߽���ϵͳ

%% ��չ����ռ䡢�����
clear;
clc;
format compact;
%% ���������� : ��ָ����IF888 2011��ȫ�����
load IF888-2011.mat
IFdata = IF888(:,2);

%% ѡ�����5�վ��ߡ�����20�վ���
ShortLen = 5;
LongLen = 20;
[MA5, MA20] = movavg(IFdata, ShortLen, LongLen);
MA5(1:ShortLen-1) = IFdata(1:ShortLen-1);
MA20(1:LongLen-1) = IFdata(1:LongLen-1);

scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
plot(IFdata,'b','LineStyle','-','LineWidth',1.5);
hold on;
plot(MA5,'r','LineStyle','--','LineWidth',1.5);
plot(MA20,'k','LineStyle','-.','LineWidth',1.5);
grid on;
legend('IF888','MA5','MA20','Location','Best');
title('����ײ�Իز���','FontWeight', 'Bold');
hold on;
%% ���׹�̷���

% ��λ Pos = 1 ��ͷ1��; Pos = 0 �ղ�; Pos = -1 ��ͷһ��
Pos = zeros(length(IFdata),1);
% ��ʼ�ʽ�
InitialE = 50e4;
% �������¼
ReturnD = zeros(length(IFdata),1);
% ��ָ����
scale = 300;

for t = LongLen:length(IFdata)
    
    % �����ź� : 5�վ����ϴ�20�վ���
    SignalBuy = MA5(t)>MA5(t-1) && MA5(t)>MA20(t) && MA5(t-1)>MA20(t-1) && MA5(t-2)<=MA20(t-2);
    % �����ź� : 5�վ�������20�վ���
    SignalSell = MA5(t)<MA5(t-1) && MA5(t)<MA20(t) && MA5(t-1)<MA20(t-1) && MA5(t-2)>=MA20(t-2);
    
    % ��������
    if SignalBuy == 1
        % �ղֿ���ͷ1��
        if Pos(t-1) == 0
            Pos(t) = 1;
            text(t,IFdata(t),' \leftarrow����1��','FontSize',8);
            plot(t,IFdata(t),'ro','markersize',8);
            continue;
        end
        % ƽ��ͷ����ͷ1��
        if Pos(t-1) == -1
            Pos(t) = 1;
            ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
            text(t,IFdata(t),' \leftarrowƽ�տ���1��','FontSize',8);
            plot(t,IFdata(t),'ro','markersize',8);           
            continue;
        end
    end
    
    % ��������
    if SignalSell == 1
        % �ղֿ���ͷ1��
        if Pos(t-1) == 0
            Pos(t) = -1;
            text(t,IFdata(t),' \leftarrow����1��','FontSize',8);
            plot(t,IFdata(t),'rd','markersize',8);
            continue;
        end
        % ƽ��ͷ����ͷ1��
        if Pos(t-1) == 1
            Pos(t) = -1;
            ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
            text(t,IFdata(t),' \leftarrowƽ�࿪��1��','FontSize',8);
            plot(t,IFdata(t),'rd','markersize',8);
            continue;
        end
    end
    
    % ÿ��ӯ������
    if Pos(t-1) == 1
        Pos(t) = 1;
        ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
    end
    if Pos(t-1) == -1
        Pos(t) = -1;
        ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
    end
    if Pos(t-1) == 0
        Pos(t) = 0;
        ReturnD(t) = 0;
    end    
    
    % ���һ������������гֲ֣�����ƽ��
    if t == length(IFdata) && Pos(t-1) ~= 0
        if Pos(t-1) == 1
            Pos(t) = 0;
            ReturnD(t) = (IFdata(t)-IFdata(t-1))*scale;
            text(t,IFdata(t),' \leftarrowƽ��1��','FontSize',8);
            plot(t,IFdata(t),'rd','markersize',8);
        end
        if Pos(t-1) == -1
            Pos(t) = 0;
            ReturnD(t) = (IFdata(t-1)-IFdata(t))*scale;
            text(t,IFdata(t),' \leftarrowƽ��1��','FontSize',8);
            plot(t,IFdata(t),'ro','markersize',8);
        end
    end
    
end
%% �ۼ�����
ReturnCum = cumsum(ReturnD);
ReturnCum = ReturnCum + InitialE;
%% �������س�
MaxDrawD = zeros(length(IFdata),1);
for t = LongLen:length(IFdata)
    C = max( ReturnCum(1:t) );
    if C == ReturnCum(t)
        MaxDrawD(t) = 0;
    else
        MaxDrawD(t) = (ReturnCum(t)-C)/C;
    end
end
MaxDrawD = abs(MaxDrawD);
%% ͼ��չʾ
scrsz = get(0,'ScreenSize');
figure('Position',[scrsz(3)*1/4 scrsz(4)*1/6 scrsz(3)*4/5 scrsz(4)]*3/4);
subplot(3,1,1);
plot(ReturnCum);
grid on;
axis tight;
title('��������','FontWeight', 'Bold');

subplot(3,1,2);
plot(Pos,'LineWidth',1.8);
grid on;
axis tight;
title('��λ','FontWeight', 'Bold');

subplot(3,1,3);
plot(MaxDrawD);
grid on;
axis tight;
title(['���س�����ʼ�ʽ�',num2str(InitialE/1e4),'��'],'FontWeight', 'Bold');
saveas(gcf,'ͼ��չʾ')
