close all
clear
clc

amr(1);
load("Parameters/Params.mat");
City = RowName(:,1);
Year = {'Y2020','Y2025','Y2030','Y2035','Y2040','Y2045','Y2050','Y2055','Y2060'};
Type = {'LFP','LMO','NCM-L','NCM-M','NCM-H','NCA'};
CompC = {'ALL','Plant','Land','Labor','Maintenance','Insurance','R&D','G&A','Raw materials','Utilities','Waste disposal'};
CompE = {'ALL','Processing','Upstream materials','Waste treatment'};
LabelC = {'Recycling cost','USD/t'};
LabelE = {'Recycling GHG emissions','t CO2-eq/t'};
load("Results/AMRS1.mat");
HeadC = ['Region','Batt-chem','Rec-com','Indicator','Unit',Year];
HeadE = ['Region','Batt-chem','Rec-pro','Indicator','Unit',Year];
[I,J,K] = ndgrid(1:numel(City),1:numel(Type),1:numel(CompC));
List = [City(I(:)),Type(J(:))',CompC(K(:))'];
LabelC = repmat(LabelC,length(I(:)),1);
Cost = cat(4,RC,PT,LD,LB,MT,IS,RD,GA,RM,UT,WD); 
Cost = reshape(permute(Cost(:,1:5:41,:,:),[1 3 4 2]),[],9);
writecell([HeadC;List,LabelC,num2cell(Cost)],"Results/Automotive_Material_Recycling_China.xlsx",'Sheet','Cost');
[I,J,K] = ndgrid(1:numel(City),1:numel(Type),1:numel(CompE));
List = [RowName(I(:)),Type(J(:))',CompE(K(:))'];
LabelE = repmat(LabelE,length(I(:)),1);
Emis = cat(4,RE,PC,UM,WT);
Emis = reshape(permute(Emis(:,1:5:41,:,:),[1 3 4 2]),[],9);
writecell([HeadE;List,LabelE,num2cell(Emis)],"Results/Automotive_Material_Recycling_China.xlsx",'Sheet','GHG');