clear all; close all; clc;
addpath(genpath(pwd));
user = 'puti';
projectName = 'Localizer';
bidsDir = '/Users/pw1246/mnt/CBIUserData/rokerslab/CueIntegration';
%bidsDir = '/Users/pw1246/Desktop/MRI/CueIntegration';
serverDir = '/Volumes/Vision/MRI/Decoding';
githubDir = '/Users/pw1246/Documents/GitHub';
codeDir = pwd;
addpath(genpath(fullfile(githubDir, 'wpToolbox')));
setup_user(user,projectName,bidsDir,githubDir);

subj = 'sub-0201';
ses = 'ses-01';
space = 'fsnative';
run = 1;
% load data
tic
datafiles = load_data(bidsDir,'mt',space,'.mgh',subj,ses,run) ;
toc 
load dms
matrices{1} = (dms{1});  

%%
% myresults = GLMdenoisedata(matrices,datafiles,1,1);
 myresults = GLMestimatemodel(matrices,datafiles,1,1,'assume',[],0);
 
%%

setenv('SUBJECTS_DIR',[bidsDir '/derivatives/freesurfer'])

conditions = {'central_moving';'central_stationary';'left_moving';'left_stationary';'right_moving';'right_stationary'}

resultsdir = sprintf('%s/derivatives/GLMdenoise/%s/%s/',bidsDir,subj,ses)
mkdir(resultsdir)
fspth = fullfile(bidsDir, 'derivatives', 'freesurfer', [subj]);
lcurv = read_curv(fullfile(fspth, 'surf', 'lh.curv'));
rcurv = read_curv(fullfile(fspth, 'surf', 'rh.curv'));
mgz = MRIread(fullfile(fspth, 'mri', 'orig.mgz'));
leftidx  = 1:numel(lcurv);
rightidx = (1:numel(rcurv))+numel(lcurv);
%

% findnan = isnan(myresults.modelmd{2}(:));
% myresults.modelmd{2}(findnan) = 0;

assert(isequal(numel(lcurv) + numel(rcurv), numel(myresults.R2)), ...
        'The number of vertices in the aprf results and the l&r curv files do not match;');


for b = 1 : size(myresults.modelmd{2},2)
    
mgz.vol = myresults.modelmd{2}(leftidx,b);
MRIwrite(mgz, fullfile(resultsdir, sprintf('lh.run_%s_%s_%s.mgz',num2str(run),space,conditions{b})));
mgz.vol = myresults.modelmd{2}(rightidx,b);
MRIwrite(mgz, fullfile(resultsdir, sprintf('rh.run_%s_%s_%s.mgz',num2str(run),space,conditions{b})));
end

% findnan = isnan(myresults.R2(:));
% myresults.R2(findnan)= 0;
mgz.vol = double(myresults.R2(leftidx,:));
MRIwrite(mgz, fullfile(resultsdir, sprintf('lh.run_%s_%s_%s.mgz',num2str(run),space,'vexpl_glm')));
mgz.vol = double(myresults.R2(rightidx,:));
MRIwrite(mgz, fullfile(resultsdir, sprintf('rh.run_%s_%s_%s.mgz',num2str(run),space,'vexpl_glm')));


mgz.vol = double(myresults.R2(leftidx,:))>10;
MRIwrite(mgz, fullfile(resultsdir, sprintf('lh.run_%s_%s_%s.mgz',num2str(run),space,'vexpl_mask')));
mgz.vol = double(myresults.R2(rightidx,:))>10;
MRIwrite(mgz, fullfile(resultsdir, sprintf('rh.run_%s_%s_%s.mgz',num2str(run),space,'vexpl_mask')));


pairs =[[1 2];[3 4];[5 6]]


C = [1 -1]'

betas = myresults.modelmd{2};
for p = 1 : size(pairs,1)
    
motion = nanmean(betas(:,[pairs(p,1)]),2);
stationary = nanmean(betas(:,[pairs(p,2)]),2);    
contrast = (C' * [motion stationary]')';

mgz.vol = double(contrast(leftidx,:));
MRIwrite(mgz, fullfile(resultsdir, sprintf('lh.run_%s_%s_vs_%s.mgz',num2str(run),conditions{pairs(p,1)},conditions{pairs(p,2)})))
mgz.vol = double(contrast(rightidx,:));
MRIwrite(mgz, fullfile(resultsdir, sprintf('rh.run_%s_%s_vs_%s.mgz',num2str(run),conditions{pairs(p,1)},conditions{pairs(p,2)})))
end

%%
%%
close all
figure(1);clf
bins = 0:1:100;
datatoplot = myresults.R2 ;
cmap0 = cmaplookup(bins,min(bins),max(bins),[],hot);

datatoplot(datatoplot==0) = 0;
datatoplot(isnan(datatoplot)) = 0;

[rawimg,Lookup,rgbimg] = cvnlookup(subj,1,datatoplot,[min(bins) max(bins)],cmap0,0,[],0,{'roiname',{'MT_exvivo'},'roicolor',{'w'},'drawrpoinames',0,'roiwidth',{5},'fontsize',20});

color = [0.5];
[r,c,t] = size(rgbimg);
[i j] = find(all(rgbimg == repmat(color,r,c,3),3));

for ii = 1: length(i)
    rgbimg(i(ii),j(ii),:) = ones(1,3);
end

a = imagesc(rgbimg); axis image tight;
axis off
hold on
% subplot(2,1,2)
plot(0,0);
colormap(cmap0);
hcb=colorbar('SouthOutside');
hcb.Ticks = [0:0.25:1];
% hcb.TickLabels = {'}
hcb.FontSize = 25
hcb.Label.String = 'R2%'
hcb.TickLength = 0.001;

title(subj)

%%
figure(2); clf
betas = myresults.modelmd{2};

motion = nanmean(betas(:,[3]),2);
stationary = nanmean(betas(:,[4]),2);

C = [1 -1]'
contrast = C' * [motion stationary]';

alltcs = nanmean(cat(3,datafiles{:}),3);
predttcs = dms{1} * myresults.modelmd{2}';


% pvals = 1-tcdf(tmp.vol(:),length(subjects)-1);
mymask = double(myresults.R2>5);



datatoplot = contrast' .* double(mymask);

datatoplot(datatoplot==0) = -50;
datatoplot(isnan(datatoplot)) = -50;



bins = -0.5:0.01:0.5
cmap0 = cmaplookup(bins,min(bins),max(bins),[],(cmapsign4));
[rawimg,Lookup,rgbimg] = cvnlookup(subj,1,datatoplot,[min(bins) max(bins)],cmap0,min(bins),[],0,{'roiname',{'MT_exvivo'},'roicolor',{'w'},'drawrpoinames',0,'roiwidth',{5},'fontsize',20});

color = [0.5];
[r,c,t] = size(rgbimg);
[i j] = find(all(rgbimg == repmat(color,r,c,3),3));

for ii = 1: length(i)
    rgbimg(i(ii),j(ii),:) = ones(1,3);
end

a = imagesc(rgbimg); axis image tight;

    
set(gcf,'Position',[ 277         119        1141         898])
axis off
hold on
% subplot(2,1,2)
plot(0,0);
colormap(cmap0);
hcb=colorbar('SouthOutside');
hcb.Ticks = [0 1];
hcb.TickLabels = {'-0.5';'0.5'}
hcb.FontSize = 25
hcb.Label.String = 'Moving dots vs. stationary'
hcb.TickLength = 0.001;





%%
figure(3);clf
mymask = double(myresults.R2>70);
sum(mymask)

tcs = nanmean(cat(3,datafiles{:}),3);
ObsResp = nanmean(tcs(logical(mymask),:),1);
dc = nanmean(ObsResp)
ObsResp = 100 * (ObsResp - dc) / dc;

plot(ObsResp)
% tcs
hold on

stem(dms{1}(:,1))

legend({'Average timecourse from 100 most responsible voxels in MT';'Centrally moving dots predictior'})
legend box off
ylabel('%BOLD')
xlabel('TRs')
set(gca,'Fontsize',25)




