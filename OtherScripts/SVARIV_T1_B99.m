%% This script file implements standard and weak-IV robust SVAR-IV inference.
% This version: July 11th, 2017
% Comment: We have tested this script on a Macbook Pro 
%         @2.4 GHz Intel Core i7 (8 GB 1600 MHz DDR3)
%         Running Matlab R2016b.
%         This script runs in about 10 seconds.
 
clear; clc;
 
cd ..

main_d = pwd;
 
cd(main_d);
 
disp('This script reports confidence intervals for IRFs estimated using the SVAR-IV approach')
 
disp('(created by Karel Mertens and Jose Luis Montiel Olea)')
 
disp('-')
 
disp('This version: July 2017')
 
disp('-')
 
disp('(We would like to thank Qifan Han and Jianing Zhai for excellent research assistance)')
 
%% 1) Set number of VAR Lags, Newey West lags and confidence level.
 
disp('-')
 
disp('1) The first section defines the number of VAR Lags, Newey West lags and confidence level that will be used for SVAR-IV.')
 
p = 2; 
 
confidence = .68;
 
%% 2) Load data (saved in structure "data")
 
disp('-')
 
disp('2) The second section loads the data and saves it in the "data" structure')
 
cd(strcat(main_d,'/Data/Tax'));
 
    [data.years, ~, ~]                  = xlsread('DATA_Mertens2015',... 
                                          'AMTR (Figure 1)', 'A6:A64');
 
    [data.Var1_AMTR, ~, ~]              = xlsread('DATA_Mertens2015',...
                                          'AMTR (Figure 1)', 'D6:D64');
                                      
    [data.Var2_LogIncome,~,~]           = xlsread('DATA_Mertens2015',...
                                          'LOG AVG INCOME', 'C6:C64');
    
    [data.Var3_Controls1,~,~]           = xlsread('DATA_Mertens2015', ...
                                           'CONTROLS','B6:H64');
                                        % LOG RGDP, UNRATE, INFLATION, FFR
                                        % LOG GOV, LOG RSTPRICES, DLOGRDEBT                                   
                                         
    [data.Var3_Controls2,~,~]           = xlsread('DATA_Mertens2015',...
                                          'AMTR (Figure 1)', 'I6:I64');
                                        % Bottom99% AMTR
                                        
    [data.Var3_Controls3,~,~]           = xlsread('DATA_Mertens2015',...
                                          'LOG AVG INCOME', 'H6:H64');
                                        % Bottom99% AVG INCOME                                                                            
                                        
    data.Var3_Controls                  = [data.Var3_Controls1,...
                                           data.Var3_Controls2,...
                                           data.Var3_Controls3];
                                        
    [data.Var4_ExtIV,~,~]               = xlsread('DATA_Mertens2015',...
                                          'PROXIES (Table 3)','D6:D64');
                                      
cd ..

cd .. 
 
%% 3) Least-squares, reduced-form estimation
 
disp('-')
 
disp('3) The third section estimates the reduced-form VAR parameters');
 
disp('(output saved in "RForm" structure)')
 
addpath(strcat(main_d,'/functions/RForm'));
 
SVARinp.ydata    = ...
    [-log(1-data.Var1_AMTR),data.Var2_LogIncome,data.Var3_Controls];
 
SVARinp.Z        = data.Var4_ExtIV;
 
SVARinp.n        = size(SVARinp.ydata,2);
 
RForm.p          = p; %RForm.p is the number of lags in the model
 
 
%a) Estimation of (AL, Sigma) and the reduced-form innovations
 
[RForm.mu, ...
 RForm.AL, ...
 RForm.Sigma,...
 RForm.eta,...
 RForm.X,...
 RForm.Y]        = RForm_VAR(SVARinp.ydata,p);
 
%b) Estimation of Gammahat (n times 1)
 
RForm.Gamma      = RForm.eta*SVARinp.Z(p+1:end,1)/(size(RForm.eta,2)); 
%(We need to take the instrument starting at period (p+1), because
%we there are no reduced-form errors for the first p entries of Y.)
 
%c) Add initial conditions and the external IV to the RForm structure
    
RForm.Y0         = SVARinp.ydata(1:p,:);
    
RForm.externalIV = SVARinp.Z(p+1:end,1);
    
RForm.n          = SVARinp.n;
    
%d) Definitions for next section
 
    n            = RForm.n;
    
    T            = (size(RForm.eta,2));
    
    d            = ((n^2)*p)+(n);     %This is the size of (vec(A)',Gamma')'
    
    dall         = d+ (n*(n+1))/2;    %This is the size of (vec(A)',vech(Sigma), Gamma')'
    
display(strcat('(total number of parameters estimated:',num2str(d),'; sample size:',num2str(T),')'));
 
%% 4) Estimation of the asymptotic variance of A,Gamma
 
disp('-')
 
disp('4) The fourth section estimates the asymptotic covariance matrix of the reduced-form VAR parameters');
 
disp('(output saved in "RForm" structure)')
 
%a) Covariance matrix for vec(A,Gammahat). Used
%to conduct frequentist inference about the IRFs. 
 
[RForm.WHatall,RForm.WHat,RForm.V] = ...
    CovAhat_Sigmahat_Gamma(p,RForm.X,SVARinp.Z(p+1:end,1),RForm.eta,8);                
 
%NOTES:
%The matrix RForm.WHatall is the covariance matrix of 
% vec(Ahat)',vech(Sigmahat)',Gamma')'
 
%The matrix RForm.WHat is the covariance matrix of only
% vec(Ahat)',Gamma')' 
 
% The latter is all we need to conduct inference about the IRFs,
% but the former is needed to conduct inference about FEVDs. 
 
%% 5) Compute standard and weak-IV robust confidence set suggested in MSW
 
disp('-')
 
disp('5) The fifth section reports standard and weak-IV robust confidence sets ');
 
disp('(output saved in the "Inference.MSW" structure)')
 
%Set-up the inputs for the MSW function
 
norm   =  1;  %Variable used for normalization
 
scale      = -1;  %Scale of the shock
 
horizons   =  6;  %Number of horizons for the IRFs
 
%Apply the MSW function
 
tic;
 
addpath(strcat(main_d,'/functions'));
 
[InferenceMSW,Plugin,Chol] = MSWfunction(confidence,norm,scale,horizons,RForm,1);
 
disp('The MSW routine takes only:')
 
toc;
 
%Report the estimated shock:
    
epsilonhat=Plugin.epsilonhat;
 
epsilonhatstd=Plugin.epsilonhatstd;
 
%% 6) Plot Results
 
addpath(strcat(main_d,'/functions/figuresfun'));
 
figure(1)
 
plots.name(1,:) = {'Log(1/1-AMTR) Top 1%'};
 
plots.name(2,:) = {'Log Income Top 1%'};
 
plots.name(3,:) = {'Log Real GDP'};
 
plots.name(4,:) = {'Unemployment Rate'};

plots.name(5,:) = {'Log(1/1-AMTR) Bottom 99%'};

plots.name(6,:) = {'Log Income Bottom 99%'};
 
plots.axis(1,:) = [0 5 -1.4 .6];
 
plots.axis(2,:) = [0 5 -.5 2.5];
 
plots.axis(3,:) = [0 5 -.4 1.6];
 
plots.axis(4,:) = [0 5 -.7 .3];

plots.axis(5,:) = [0 5 -1.4 .6];
 
plots.axis(6,:) = [0 5 -.5 2.5];

plots.index     = [1,2,3,4,10,11];
 
plots.order     = [1,3,5,6,2,4];
 
caux            = norminv(1-((1-confidence)/2),0,1);
 
for iplot = 1:6
    
    subplot(3,2,plots.order(1,iplot));
    
    plot(0:1:horizons,Plugin.IRF(plots.index(1,iplot),:),'b'); hold on
    
    [~,~] = jbfill(0:1:horizons,InferenceMSW.MSWubound(plots.index(1,iplot),:),...
        InferenceMSW.MSWlbound(plots.index(1,iplot),:),[204/255 204/255 204/255],...
        [204/255 204/255 204/255],0,0.5); hold on
    
    dmub  =  Plugin.IRF(plots.index(1,iplot),:) + ...
            (caux*Plugin.IRFstderror(plots.index(1,iplot),:));
    
    lmub  =  Plugin.IRF(plots.index(1,iplot),:) - ...
        (caux*Plugin.IRFstderror(plots.index(1,iplot),:));
    
    h1 = plot(0:1:horizons,dmub,'--b'); hold on
    
    h2 = plot(0:1:horizons,lmub,'--b'); hold on
    
    clear dmub lmub
    
    h3 = plot([0 5],[0 0],'black'); hold off
    
    xlabel('Year')
    
    title(plots.name(iplot,:));
    
    if iplot == 1
        
        legend('SVAR-IV Estimator',strcat('MSW C.I (',num2str(100*confidence),'%)'),...
            'D-Method C.I.')
        
        set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        legend boxoff
        
        legend('location','southeast')
     
    end
    
    axis(plots.axis(iplot,:))
    
end
 
%% 7) Save the output and plots in ./Output/Mat and ./Output/Figs
 
disp('-')
 
disp('7) The final section saves the .mat files and figures in the Output folder')
 
%Check if the Output File exists, and if not create one.
 
OutputExtraMat = strcat(main_d, '/OutputExtra/Mat');

        if exist(OutputExtraMat,'dir')==0

            mkdir(OutputExtraMat)

        end
        
OutputExtraFigs = strcat(main_d, '/OutputExtra/Figs');

        if exist(OutputExtraFigs,'dir')==0

            mkdir(OutputExtraFigs)

        end
 
cd(strcat(main_d,'/OutputExtra/Mat'));
 
output_label = strcat('_p=',num2str(p),'_Top1Bottom99_',...
               num2str(100*confidence));
 
save(strcat('IRF_SVAR',output_label,'.mat'),...
     'InferenceMSW','Plugin','RForm','SVARinp');
 
figure(1)
 
cd(strcat(main_d,'/OutputExtra/Figs'));
 
print(gcf,'-depsc2',strcat('IRF_SVAR',output_label,'.eps'));
 
cd(main_d);
 
clear plots output_label main_d labelstrs dtype

