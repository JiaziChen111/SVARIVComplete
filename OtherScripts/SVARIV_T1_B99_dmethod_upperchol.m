%% This script file implements standard SVAR-IV inference for the case
%  in which we have two instrumental variables for two different shocks,
%  each of which is allowed to be correlated with both IVs.
% This version: July 25th, 2017
% Comment: We have tested this script on a Macbook Pro 
%         @2.4 GHz Intel Core i7 (8 GB 1600 MHz DDR3)
%         Running Matlab R2016b.
%         This script runs in about 10 seconds.
 
clear; clc;
 
cd ..
 
main_d = pwd;
 
cd(main_d);
 
disp('This script reports confidence intervals for IRFs estimated using the SVAR-IV bootstrap type approach')
 
disp('(created by Karel Mertens and Jose Luis Montiel Olea)')
 
disp('-')
 
disp('This version: July 2017')
 
disp('-')
 
disp('(We would like to thank Qifan Han and Jianing Zhai for excellent research assistance)')
 
%% 1) Set number of VAR Lags, Newey West lags and confidence level.
 
disp('-')
 
disp('1) The first section defines the number of VAR Lags, Newey West lags and confidence level that will be used for SVAR-IV.')
 
p = 2; 
 
confidence = .90;
 
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
                                        
    data.Var3_Controls2                 = -log(1-data.Var3_Controls2);
                                        % Transformation of the AMTR
                                        
    [data.Var3_Controls3,~,~]           = xlsread('DATA_Mertens2015',...
                                          'LOG AVG INCOME', 'H6:H64');
                                        % Bottom99% AVG INCOME                                                                            
                                        
    data.Var3_Controls                  = [data.Var3_Controls1,...
                                           data.Var3_Controls2,...
                                           data.Var3_Controls3];
                                        
    [data.Var4_ExtIV,~,~]               = xlsread('DATA_Mertens2015',...
                                          'PROXIES (Table 3)','D6:D64');
                                        % Top 1% instrument
                                      
    [data.aux,~,~]                      = xlsread('DATA_Mertens2015',...
                                          'PROXIES (Table 3)','I6:I64');
                                        % Bottom 99% instrument
    
    data.Var4_ExtIV                     = [data.Var4_ExtIV , data.aux]; 
    
    data                                = rmfield(data,'aux');
                                      
cd ..

cd .. 
 
%% 3) Least-squares, reduced-form estimation
 
disp('-')
 
disp('3) The third section estimates the reduced-form VAR parameters');
 
disp('(output saved in "RForm" structure)')
 
addpath(strcat(main_d,'/functions/RForm'));
 
SVARinp.ydata    = ...
    [-log(1-data.Var1_AMTR), data.Var3_Controls2, ...
    data.Var2_LogIncome, data.Var3_Controls3, ...
    data.Var3_Controls1];
 
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
 
%b) Estimation of Gammahat (n times k)
 
RForm.Gamma      = RForm.eta*SVARinp.Z(p+1:end,:)./(size(RForm.eta,2)); 
%(We need to take the instrument starting at period (p+1), because
%we there are no reduced-form errors for the first p entries of Y.)
 
%c) Add initial conditions and the external IV to the RForm structure
    
RForm.Y0         = SVARinp.ydata(1:p,:);
    
RForm.externalIV = SVARinp.Z(p+1:end,:);
    
RForm.n          = SVARinp.n;
    
%d) Definitions for next section
 
    n            = RForm.n;
    
    k            = size(SVARinp.Z,2);
    
    T            = (size(RForm.eta,2));
    
    d            = ((n^2)*p)+(n*k);     %This is the size of (vec(A)',vec(Gamma)')'
    
    dall         = d+ (n*(n+1))/2;    %This is the size of (vec(A)',vech(Sigma), vec(Gamma)')'
    
display(strcat('(total number of parameters estimated:',num2str(d),'; sample size:',num2str(T),')'));
 
%% 4) Estimation of the asymptotic variance of A,Gamma
 
disp('-')
 
disp('4) The fourth section estimates the asymptotic covariance matrix of the reduced-form VAR parameters');
 
disp('(output saved in "RForm" structure)')
 
%a) Covariance matrix for vec(A,Gammahat). Used
%to conduct frequentist inference about the IRFs. 
 
[RForm.WHatall,RForm.WHat,RForm.V] = ...
    CovAhat_Sigmahat_Gamma(p,RForm.X,SVARinp.Z(p+1:end,:),RForm.eta,8);                
 
%NOTES:
%The matrix RForm.WHatall is the covariance matrix of 
% vec(Ahat)',vech(Sigmahat)',vec(Gamma)')'
 
%The matrix RForm.WHat is the covariance matrix of only
% vec(Ahat)',vec(Gamma)')' 
 
% The latter is all we need to conduct inference about the IRFs,
% but the former is needed to conduct inference about FEVDs. 

%% 5) Point estimator for the IRFs with respect to the first shock
%  (Upper Cholesky Identification)

%Set-up the inputs 
 
norm   =  1;  %Variable in which the shock will be imposed
 
scale      = -1;  %Scale of the shock
 
horizons   =  6;  %Number of horizons for the IRFs

disp('-')

disp('5) This section reports points estimators based on a "lower Cholesky" identification scheme.')

addpath(strcat(main_d,'/functions/StructuralIRF'));

addpath(strcat(main_d,'/functions/StructuralIRF/2instruments'));

[InferenceMSW.IRFSVARIV, InferenceMSW.dIRFdmu] = IRFSVARIV_2inst_j(RForm.AL,RForm.Sigma,RForm.Gamma,...
                      horizons,scale,norm,@upperchol_id_minusj);
                  
%% 6) Delta-Method Standard Errors

disp('-')

disp('6) This section conducts "standard" delta-method inference based on a "lower Cholesky" identification scheme.')

InferenceMSW.dmethod = zeros(size(InferenceMSW.IRFSVARIV));

for h   = 1:horizons+1
    
    for i_var = 1:n
        
        InferenceMSW.dmethod(i_var,h) = (InferenceMSW.dIRFdmu(:,i_var,h)'...
                                        *RForm.WHatall...
                                        *InferenceMSW.dIRFdmu(:,i_var,h)./T).^.5;                                                
    end
    
end

%% 7) Bootstrap comparison

%Set-up the inputs for the MSW function
 
norm   =  1;  %Variable used for normalization
 
scale      = -1;  %Scale of the shock
 
horizons   =  6;  %Number of horizons for the IRFs

NB         = 1000;

NWlags = 0; 

seed   = load(strcat(main_d,'/seed/seedMay12.mat')); 
    
seed   = seed.seed;

disp('-')

disp('7) This section samples from the asy dist of the reduced-form parameters to conduct "standard" inference.')

disp('Standard inference based on sampling from the asy. dist. takes only:')  

addpath(strcat(main_d,'/functions/StructuralIRF/2instruments'));

f     = @(AL,Sigma,Gamma,hori,x,nvar)...
        IRFSVARIV_2inst_j(AL,Sigma,Gamma,horizons,scale,norm,@upperchol_id_minusj);

tic;

addpath(strcat(main_d,'/functions/Inference'));

addpath(strcat(main_d,'/functions/AuxFunctions'));

[InferenceMSW.IRFs,InferenceMSW.bootsIRFs] = ...
                  Gasydistboots(seed, NB, n, p, norm, scale, horizons, confidence, T,...
                  f, RForm.AL, RForm.Sigma, RForm.Gamma, RForm.V,...
                  RForm.WHatall, SVARinp, NWlags);              

toc;

%% 8) Plot Results

disp('-')

disp('8) This section plots the CIs based on MSW bootstrap-type procedure')
 
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

%plots.index     = [1,2,3,4,10,11];

plots.index     = [1,3,5,6,2,4];
 
plots.order     = [1,3,5,6,2,4];
 
caux            = norminv(1-((1-confidence)/2),0,1);
 
for iplot = 1:6
    
    subplot(3,2,plots.order(1,iplot));
    
    plot(0:1:horizons,InferenceMSW.IRFSVARIV(plots.index(1,iplot),:,end),'b'); hold on
    
    %[~,~] = jbfill(0:1:hori,InferenceMSW.bootsIRFs(plots.index(1,iplot),:,2),...
        %InferenceMSW.bootsIRFs(plots.index(1,iplot),:,1),[204/255 204/255 204/255],...
        %[204/255 204/255 204/255],0,0.5); hold on
    
    g1    =  plot(0:1:horizons,InferenceMSW.bootsIRFs(plots.index(1,iplot),:,2),':b'); hold on
    
    dmub  =  InferenceMSW.IRFSVARIV(plots.index(1,iplot),:) + ...
             (caux*InferenceMSW.dmethod(plots.index(1,iplot),:)); 
    
    lmub  =  InferenceMSW.IRFSVARIV(plots.index(1,iplot),:) - ...
             (caux*InferenceMSW.dmethod(plots.index(1,iplot),:)); 
    
    h1 = plot(0:1:horizons,dmub,'--b'); hold on
    
    g2    =  plot(0:1:horizons,InferenceMSW.bootsIRFs(plots.index(1,iplot),:,1),':b'); hold on
    
    h2 = plot(0:1:horizons,lmub,'--b'); hold on
    
    clear dmub lmub   
    
    h3 = plot([0 5],[0 0],'black'); hold off
    
    xlabel('Year')
    
    title(plots.name(iplot,:));
    
    if iplot == 1
        
        legend('SVAR-IV Estimator',...
            strcat('MSWBoots C.I (',num2str(100*confidence),'%)'),...
            strcat('Delta Method C.I (',num2str(100*confidence),'%)'));
        
        set(get(get(g2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        legend boxoff
        
        legend('location','southeast')
     
    end
    
    axis(plots.axis(iplot,:))
    
end

%% 9) Point estimator for the IRFs with respect to the second shock
%  (Lower Cholesky Identification)

disp('-')

disp('9) This section reports points estimators for the IRFs of the second shock based on a "lower Cholesky" identification scheme.')

[InferenceMSW.IRFSVARIV2, InferenceMSW.dIRFdmu2] = IRFSVARIV_2inst_j(RForm.AL,RForm.Sigma,RForm.Gamma,...
                      horizons,scale,2,@upperchol_id);

%% 10) Delta-method standard errors for the second shock IRFs

disp('-')

disp('10) This section conducts "standard" delta-method inference for the responses to the second shock based on a "lower Cholesky" identification scheme.')

InferenceMSW.dmethod2 = zeros(size(InferenceMSW.IRFSVARIV2));

for h   = 1:horizons+1
    
    for i_var = 1:n
        
        InferenceMSW.dmethod2(i_var,h) = (InferenceMSW.dIRFdmu2(:,i_var,h)'...
                                        *RForm.WHatall...
                                        *InferenceMSW.dIRFdmu2(:,i_var,h)./T).^.5;                                                
    end
    
end

%% 11) Bootstrap comparison

disp('-')

disp('11) This section samples from the asy dist of the reduced-form parameters to conduct "standard" inference on the second shock.')

disp('Standard inference based on sampling from the asy. dist. takes only:')  

addpath(strcat(main_d,'/functions/StructuralIRF'));

f     = @(AL,Sigma,Gamma,hori,x,nvar)...
        IRFSVARIV_2inst_j(AL,Sigma,Gamma,hori,x,nvar,@upperchol_id);

tic;

[InferenceMSW.IRFs2,InferenceMSW.bootsIRFs2] = ...
                  Gasydistboots(seed, 1000, n, p, 2, scale, horizons, confidence, T,...
                  RForm.AL(:),RForm.V*RForm.Sigma(:),RForm.Gamma(:),...
                  RForm.WHatall,f);              

toc;

%% 12) Plot Results

disp('-')

disp('12) This section plots the CIs based on MSW bootstrap-type procedure')
 
addpath(strcat(main_d,'/functions/figuresfun'));
 
figure(2)

for iplot = 1:6
    
    subplot(3,2,plots.order(1,iplot));
    
    plot(0:1:horizons,InferenceMSW.IRFSVARIV2(plots.index(1,iplot),:,end),'b'); hold on
    
    %[~,~] = jbfill(0:1:hori,InferenceMSW.bootsIRFs(plots.index(1,iplot),:,2),...
        %InferenceMSW.bootsIRFs(plots.index(1,iplot),:,1),[204/255 204/255 204/255],...
        %[204/255 204/255 204/255],0,0.5); hold on
    
    g1    =  plot(0:1:horizons,InferenceMSW.bootsIRFs2(plots.index(1,iplot),:,2),':b'); hold on
    
    dmub  =  InferenceMSW.IRFSVARIV2(plots.index(1,iplot),:) + ...
             (caux*InferenceMSW.dmethod2(plots.index(1,iplot),:)); 
    
    lmub  =  InferenceMSW.IRFSVARIV2(plots.index(1,iplot),:) - ...
             (caux*InferenceMSW.dmethod2(plots.index(1,iplot),:)); 
    
    h1 = plot(0:1:horizons,dmub,'--b'); hold on
    
    g2    =  plot(0:1:horizons,InferenceMSW.bootsIRFs2(plots.index(1,iplot),:,1),':b'); hold on
    
    h2 = plot(0:1:horizons,lmub,'--b'); hold on
    
    clear dmub lmub   
    
    h3 = plot([0 5],[0 0],'black'); hold off
    
    xlabel('Year')
    
    title(plots.name(iplot,:));
    
    if iplot == 1
        
        legend('SVAR-IV Estimator',...
            strcat('MSWBoots C.I (',num2str(100*confidence),'%)'),...
            strcat('Delta Method C.I (',num2str(100*confidence),'%)'));
        
        set(get(get(g2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        set(get(get(h3,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        legend boxoff
        
        legend('location','southeast')
     
    end
    
    axis(plots.axis(iplot,:))
    
end

%% 13) Save the output and plots in ./Output/Mat and ./Output/Figs
 
disp('-')
 
disp('13) The final section saves the .mat files and figures in the Output folder')
 
%Check if the Output File exists, and if not create one.
 
if exist('Output','dir')==0
    
    mkdir('Output')
        
end
 
if exist('Output/Mat','dir')==0
    
    mkdir('Output/Mat')
        
end
 
if exist('Output/Figs','dir')==0
    
    mkdir('Output/Figs')
        
end
 
cd(strcat(main_d,'/Output/Mat'));
 
output_label = strcat('_p=',num2str(p),'_Top1Bottom99_2inst_upper',...
               num2str(100*confidence));
 
save(strcat('IRF_SVAR',output_label,'.mat'),...
     'InferenceMSW','RForm','SVARinp');
 
figure(1)
 
cd(strcat(main_d,'/Output/Figs'));
 
print(gcf,'-depsc2',strcat('IRF_SVAR_Top1',output_label,'.eps'));
 

figure(2)
  
print(gcf,'-depsc2',strcat('IRF_SVAR_Bottom99',output_label,'.eps'));
 
cd(main_d);
 
clear plots output_label main_d labelstrs dtype