function [] = amr(s)
%% 1 Precalculation
% 1.1 Global settings
city = 337;
year0 = 2020; % Set to 2020, DO NOT ALTER
year1 = 2060; % Before 2060
year = year1 - year0 + 1;
type = 6;
exr = 7.0467;
% 1.2 Data import
if ~exist('Parameters/Params.mat','file')
    DT = importdata("Parameters/BatParam.xlsx");
    BatComp = DT.data.BatComp;
    MatComp = DT.data.MatComp;
    % Supposing type4 Car 200 miles composition
    Car = 4;
    Bat = BatComp(25*Car - 24:25*Car - 5,:);
    BatT = Bat;
    BatT(2,:) = BatT(2,:)*372/175;
    BatT = BatT./sum(BatT,1);
    MatInt = Bat(2:20,:)'*MatComp(10:28,:) + Bat(1,:)'.*MatComp(1:8,:);
    MatInt = [MatInt;BatT(3:20,:)'*MatComp(11:28,:) + BatT(1,:)'.*MatComp(1:8,:) + BatT(2,:)'.*MatComp(9,:)];
    % Supposing LFP, LMO, NMC111, NMC532, NMC811, NCA as cathode types
    MatInt = MatInt([1,2,3,4,6,8,9],:);
    writematrix(MatInt',"Parameters/MatInt.csv");
    % ElePer in t/GWh, T means Titanium oxide anode instead of graphite, supposing all LTO batteries using LFP as cathode
    load("Parameters/Outflow.mat","Outflow");
    Den(1:6) = BatComp(25*Car - 4,[1,2,3,4,6,8]);
    Den = [Den,Den(1)/2];
    Outflow = Outflow(:,2020 - 2009:2060 - 2009,1:7)./reshape(Den,1,1,7)*1e6;
    DT = importdata("Parameters/GeoParam.xlsx");
    RowName = DT.textdata.EF(2:end,:);
    GeoParam = DT.data;
    GeoParam.EF = interp1([2020,2025,2030,2035,2040,2050,2060],GeoParam.EF(2:end,:)',2020:2060,"pchip")';
    DT = importdata("Parameters/PltParam.xlsx");
    PltParam = DT.data;
    DT = importdata("Parameters/ScenParam.xlsx");
    ScenParam = DT.data(:,1:end - 2);
    save("Parameters/Params.mat",'GeoParam','PltParam','RowName','Outflow','ScenParam');
else
    load("Parameters/Params.mat",'GeoParam','PltParam','RowName','Outflow','ScenParam');
end
disp("Parameters loaded successfully!")
% 1.3 Definition of parameters
fli = ScenParam(s,1); % Lithium discount factor
fni = ScenParam(s,2); % Nickel discount factor
fco = ScenParam(s,3); % Cobalt discount factor
ptp = ScenParam(s,4); % Tenary precursor price
plc = ScenParam(s,5); % Lithium carbonate price
pns = ScenParam(s,6); % Nickel sulphate price
pcs = ScenParam(s,7); % Cobalt sulphate price
cr2 = ScenParam(s,8); % Collection rate by 2035
lr = ScenParam(s,9:11); % Learning rate
fgd = ScenParam(s,12); % Grid decarbonization factor
Outflow = Outflow(1:city,year0 - 2019:year1 - 2019,1:type); % Retired battery volume
GeoParam.EF = GeoParam.EF(1:city,year0 - 2019:year1 - 2019); % Grid emission factor
pms = 5880; % Manganese sulphate price
labor0 = 1060; % Labor input
land0 = 500*2000/3; % Land consumption
elec0 = 12/7200; % Electricity capacity
gas0 = 2020000; % Gas consumption
water0 = [81540 60000 819500]; % Water consumption
s0 = 250; % Steam price
% 1.4 Learning curve, using different learning rate on different cathodes, based on cumulative amount of retired batteries
crmin = 0.20;
crmax = 1;
cr1 = 0.25;
t0 = 2020;
t1 = 2023;
t2 = 2035;
b = (log(-log((cr1 - crmin)/(crmax - crmin)))-log(-log((cr2 - crmin)/(crmax - crmin))))/(t2 - t1);
a = exp(log(-log((cr1 - crmin)/(crmax - crmin))) + b*(t1 - t0));
CR = @(t) crmin + (crmax - crmin).*exp(-a.*exp(-b.*(t - t0)));
SLIB = Outflow.*reshape(CR(year0:year1),1,year,1);
CLIB = cumsum(reshape(sum(SLIB,1),year,type));
CLIB = [CLIB(:,1),sum(CLIB(:,2:type),2)];
LR = @(lr) reshape([(CLIB(:,1)./CLIB(4,1)).^log2(1 - lr),(CLIB(:,2)./CLIB(4,2)).^log2(1 - lr).*ones(year,type - 1)],1,year,type);
% 1.5 Grid decarbonization scenarios
GD = @(t) (fgd - 1)/(2060 - 2020).*(t - 2020) + 1;
GeoParam.EF = GeoParam.EF.*GD(year0:year1);
%% 2 Fixed cost
% 2.1 ISBL
fer = 0.5;
fp = 0.6;
fi = 0.3;
fel = 0.2;
fc = 0.3;
fs = 0.2;
fl = 0.1;
fis = fer + fp + fi + fel + fc + fs + fl;
ISBL = reshape(PltParam.EqpParam(1:37,4)'*PltParam.EqpParam(1:37,6:5 + type),1,1,type).*ones(city,year,1)*fis/exr.*LR(lr(2));
% 2.2 OSBL
OSBL = reshape(PltParam.EqpParam(38:50,4)'*PltParam.EqpParam(38:50,6:5 + type),1,1,type).*ones(city,year,1)/exr.*LR(lr(2));
% 2.3 Design and engineering
fde = 0.25;
DE = (ISBL + OSBL)*fde;
% 2.4 Contingency
fx = 0.1;
X = (ISBL + OSBL)*fx;
% 2.5 Land
Land = reshape(land0*PltParam.EqpParam(48,6:5 + type),1,1,type).*reshape(GeoParam.Cost(:,2),city,1,1).*ones(1,year,1)/exr.*LR(lr(1));
fdr = 0.08;
life = 15;
DR = fdr*(1 + fdr)^life/((1 + fdr)^life-1);
PT = (ISBL + OSBL + DE + X)*DR;
LD = Land*fdr;
CI = PT/DR + LD/fdr;
%% 3 Variable cost of production
% 3.1 Batteries
BT = reshape([fli*plc/0.1872,fni*pns/0.220,fco*pcs/0.205]*PltParam.MatInt(1:3,1:type),1,1,type).*ones(city,year,1)/exr;
% 3.2 Raw materials
pin = PltParam.Input(:,2);
pin(1) = pcs/PltParam.Input(1,1);
pin(2) = pms/PltParam.Input(2,1);
RM = reshape(pin'*PltParam.Input(:,3:2 + type),1,1,type).*ones(city,year,1)/exr.*LR(lr(1));
% 3.3 Utilities
Elec = reshape(PltParam.EqpParam(:,5)'*PltParam.EqpParam(:,6:5 + type),1,1,type).*reshape(GeoParam.Cost(:,3) + elec0*GeoParam.Cost(:,4),city,1,1).*ones(1,year,1)/exr.*LR(lr(1));
Gas = reshape(gas0*PltParam.EqpParam(38,6:5 + type),1,1,type).*reshape(GeoParam.Cost(:,5),city,1,1).*ones(1,year,1)/exr.*LR(lr(1));
Water = reshape(water0(1)*PltParam.EqpParam(48,6:5 + type) + 0.6*(water0(2)*PltParam.EqpParam(44,6:5 + type) + water0(3)*PltParam.EqpParam(45,6:5 + type)),1,1,type).*reshape(GeoParam.Cost(:,6),city,1,1).*ones(1,year,1)/exr.*LR(lr(1));
Steam = reshape(s0*PltParam.Input(8,3:2 + type),1,1,type).*ones(city,year,1)/exr.*LR(lr(1));
UT = Elec + Gas + Water + Steam;
% 3.4 Effluent disposal
SW = reshape(PltParam.Output(16:17,1)'*PltParam.Output(16:17,2:1 + type),1,1,type).*ones(city,year,1)/exr.*LR(lr(1));
WW = Water*0.3;
WD = SW + WW;
%% 4 FCOP
% 4.1 Labor
fsm = 0.25;
foh = 0.5;
LB = reshape(labor0*PltParam.EqpParam(48,6:5 + type),1,1,type).*reshape(GeoParam.Cost(:,1),city,1,1)*(1+fsm)*(1+foh)/exr.*LR(lr(3));
% 4.2 Maintenance
fmt = 0.05;
MT = fmt*ISBL;
% 4.3 Insurance
fins = 0.01;
IS = fins*(ISBL + OSBL);
% 4.4 Corporate overhead charges
pout = PltParam.Output(1:15,1);
pout(1) = ptp;
pout(2) = pcs;
pout(3) = pms;
pout(4) = plc;
RV = reshape(pout'*PltParam.Output(1:15,2:1 + type),1,1,type).*ones(city,year,1)/exr;
frd = 0.05;
fgsa = 0.65;
RD = frd*RV.*LR(lr(1));
GA = fgsa*LB;
OH = RD + GA;
%% 5 Carbon emission
% 5.1 Process emissions
PC = (reshape(PltParam.EqpParam(1:37,5)'*PltParam.EqpParam(1:37,6:5 + type),1,1,type).*reshape(GeoParam.EF,city,year,1)/1e3 + reshape(gas0*PltParam.EqpParam(38,6:5 + type),1,1,type)*35.8*PltParam.GWP(14,4)/1e6 + reshape(PltParam.Input(8,3:2 + type),1,1,type)*165/1e3).*LR(lr(1));
% 5.2 Upstream material emissions
UM = (reshape(PltParam.GWP(18,1:5)*PltParam.GWP(1:13,1:5)'*PltParam.Input(:,3:2 + type),1,1,type).*ones(city,year,1)/1e3 + reshape(GeoParam.EF/3.6,city,year,1).*reshape(PltParam.GWP(1:13,6)'*PltParam.Input(:,3:2 + type),1,1,type)).*LR(lr(1));
% 5.3 Waste treatment emissions
WT = reshape(PltParam.EqpParam(38:50,5)'*PltParam.EqpParam(38:50,6:5 + type),1,1,type).*reshape(GeoParam.EF,city,year,1)/1e3.*LR(lr(1));
% 5.4 Primary source extraction emissions
PM = reshape(PltParam.GWP(18,1:5)*PltParam.GWP(14:17,1:5)'*PltParam.Output(1:4,2:1 + type),1,1,type).*ones(city,year,1)/1e3 + reshape(GeoParam.EF/3.6,city,year,1).*reshape(PltParam.GWP(14:17,6)'*PltParam.Output(1:4,2:1 + type),1,1,type);
DF = reshape(pout(1:4)'*PltParam.Output(1:4,2:1 + type),1,1,type)/exr./RV;
%% 6 Automotive material recycling
% 6.1 Recycling costs and GHG emissions
RC = PT + LD + RM + UT + WD + LB + MT + IS + RD + GA;
RE = PC + UM + WT;
if ~exist('Results','dir')
    mkdir('Results');
end
filepath = sprintf("Results/AMRS%d.mat",s);
save(filepath,'RC','CI','PT','LD','BT','RM','UT','WD','LB','MT','IS','OH','RD','GA','RV','RE','PC','UM','WT','PM','DF','-v7.3');
disp("Automotive material recycling modeled successfully!")
end