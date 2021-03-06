% % created on 2017-12-19
% % Goal: do STA analysis for various cells
close all;
clc;clear;
set(0,'DefaultFigureWindowStyle','docked');

base_dir = 'C:\RathbunLab';

save_fig = 0;

exp_dict =  T02_datalist();
for exp_id = exp_dict.keys()
    exp_id = char(exp_id);
    exp_data_dir = fullfile(base_dir,'Data\',exp_id,'\');
    for cell_id = exp_dict(exp_id)
        cell_id = char(cell_id);
        work_dir = fullfile(base_dir,'results\T02_corrected\',exp_id,'\',cell_id,'\');
        config_file = fullfile(exp_data_dir,'analysis_config.ini');
        
        if ~exist(work_dir,'dir'), mkdir(work_dir); end
        exp_ps = ini2struct(config_file);
        
        exp_ps.exp_id = exp_id;
        exp_ps.cell_id = cell_id;
        exp_ps.work_dir = work_dir;
        exp_ps.data_dir = exp_data_dir;
        
        exp_ps.single_pulse_activation_correction = 1; % overwrite the single pulse correction
        
        [STA_ps, exp_ps] = STA_computation(exp_ps);
        
        %% extract the kernel
        sta_d1_idx = STA_ps.D_ps.D1_idx;
        sta_d2_idx = STA_ps.D_ps.D2_idx;
        
        crop2_idx = length(STA_ps.STA);%the mid point can happen to not cross the exact zero point and that would be because we dont have samples there
        
        if ~isnan(STA_ps.D_ps.D2_cross_ids(1)) && STA_ps.D_ps.D2_issig
            crop1_idx = (STA_ps.D_ps.D2_cross_ids(1));
        elseif ~isnan(STA_ps.D_ps.D1_cross_ids(1))&& STA_ps.D_ps.D1_issig
            crop1_idx = (STA_ps.D_ps.D1_cross_ids(1));
        elseif ~isnan(STA_ps.D_ps.D2_finsig_ids(1)) && STA_ps.D_ps.D2_issig
            crop1_idx = (STA_ps.D_ps.D2_finsig_ids(1));
        elseif ~isnan(STA_ps.D_ps.D1_finsig_ids(1))&& STA_ps.D_ps.D1_issig
            crop1_idx = (STA_ps.D_ps.D1_finsig_ids(1));
        else
            crop1_idx = 1;
            display('Warning! No significant D2/D1 or no crossing were found! using the initial point of the STA.');
        end
        
        estim_meanline = exp_ps.estim_mean * ones(1,length(STA_ps.STA));
        
        kernel = STA_ps.STA(crop1_idx:crop2_idx);
        kernel_t = STA_ps.STA_t(crop1_idx:crop2_idx);
        
        Kw = length(kernel);
        
        %% Figure 1xx - STA PLots
        figIdx = 1;
        figure();
        
        subplot(4,1,[1,2]);
        plot(STA_ps.STA_t,STA_ps.STA, 'b', 'LineWidth',2);hold on;
        plot(STA_ps.STA_t(sta_d1_idx,1),STA_ps.STA(sta_d1_idx,1),'r*');
        plot(STA_ps.STA_t(sta_d2_idx,1),STA_ps.STA(sta_d2_idx,1),'r*');
        plot(vertcat(STA_ps.STA_t(end),STA_ps.postSTA_t),vertcat(STA_ps.STA(end),STA_ps.postSTA), 'b', 'LineWidth',2);
        
        plot(kernel_t,kernel,'r-','LineWidth',2);
        
        plt_ylim = [-1200, -400];
        yaxis_line = zeros(length(plt_ylim(1):100:plt_ylim(2)));
        
        plot(yaxis_line, plt_ylim(1):100:plt_ylim(2), 'k');
        plot(STA_ps.STA_t, estim_meanline, 'k');
        
        ylim([plt_ylim(1) plt_ylim(2)]);
        title(sprintf('STA plot for %s_[%s]',exp_ps.exp_id,exp_ps.cell_id), 'Interpreter', 'none');
        
        subplot(413);plot(kernel_t, kernel,'b'); title('STA Crop, a.k.a Kernel');
        
        sta_sta_xcorr_full = (1/exp_ps.stimFreq)*custom_xcorr(kernel,kernel,'full');
        
        subplot(414);plot(1:length(sta_sta_xcorr_full), sta_sta_xcorr_full,'k-');title('Padded XCorrelation of Kernel with itset');
        
        saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Rest of the figures
        
        estim_amps = exp_ps.tData.estim_amps;
        estim_ts = exp_ps.tData.estim_ts;
        estim_spts = exp_ps.tData.estim_spts;
        
        estim_inds = 1:length(estim_amps); % stimulus sample indices used for plotting
        
        fig_basename = sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id);
        
        %% Figure 2xx - The Stimulus and the Generator Signal
        figIdx = 2;
        figure();
        
        estim_amps_norm = (estim_amps - exp_ps.estim_mean) / exp_ps.estim_std;
        kernel_norm = (kernel - exp_ps.estim_mean) / exp_ps.estim_std;
        
        genSig_vals = (1/exp_ps.stimFreq)*custom_xcorr(estim_amps_norm,kernel_norm);
        genSig_inds = (Kw:length(genSig_vals)+Kw-1)';
        genSig_ts = estim_ts(genSig_inds); %  We assign the timestamp corresponding to the end point of the xcorrel window to that genSig value
        
        ax1 = subplot(211);plot(estim_ts, estim_amps_norm, 'b');
        ax2 = subplot(212);plot(genSig_ts, genSig_vals,'b');
        linkaxes([ax1,ax2],'x');
        xlim([0,genSig_ts(end)]);
        
        figTitle = sprintf('%s [%s]\nThe normlzd Stmuli and the Gen Signal computed for normlzd Stim/Kernel',strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'));
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Figure 3xx - Extracting Spike associated stimuli
        % Extract the values in the stimuli and the generator signal that caused a
        % spike. This would be a window of stimuli that immediately precede a spike
        % or the single generator signal value before that spike
        figIdx = 3;
        figure();
        
        speriod = 1/exp_ps.stimFreq;%sampling period
        pre_spike_sample = 16;% for 25 Hz, samples are 0.04 s far.
        
        spike_estim_vals = interp1(estim_ts,estim_amps_norm,estim_spts); % the values of the stimulus at the spike timepoints used for plotting
        sp_assoc_stimuli = NaN(size(estim_amps_norm));%spike associated stimuli
        sp_assoc_stimuli_weighted = [];
        for spike_t = estim_spts'
            idx_tochange = ((estim_ts>=(spike_t-pre_spike_sample*speriod))&(estim_ts<spike_t));
            sp_assoc_stimuli(idx_tochange) = estim_amps_norm(idx_tochange);
            sp_assoc_stimuli_weighted = vertcat(sp_assoc_stimuli_weighted, estim_amps_norm(idx_tochange));
        end
        
        ax1 = subplot(211);plot(estim_ts, estim_amps_norm,'y');hold on;
        plot(estim_ts, estim_amps_norm,'k.');hold on;
        plot(estim_spts, spike_estim_vals,'r.');hold on;
        plot(estim_ts, sp_assoc_stimuli,'b*');hold on;
        
        xlabel('t');ylabel('Norm Val (mV)');
        xlim([0,max(estim_ts)]);
        
        % In the first subplot the yellow line shows the stimuli variations,
        % the black dots mark the sample points in the stimuli (might be overlayed by blue stars)
        % the red dots show the time point that a spike occured
        % the blue-stared values are the ones included as the spike associated stimuli
        % note that in the variable sp_assoc_stimuli all the indices corresponding to black dots are NaN and indices correponding to blue stars are genSig
        
        spike_genSig_vals = interp1(genSig_ts,genSig_vals,estim_spts);
        sp_assoc_genSig = NaN(size(genSig_vals));%spike associated generator signal
        sp_assoc_genSig_weighted = [];
        for spike_t = estim_spts'
            idx_tochange = ((genSig_ts>=(spike_t-speriod))&(genSig_ts<spike_t));
            sp_assoc_genSig(idx_tochange) = genSig_vals(idx_tochange);
            sp_assoc_genSig_weighted = vertcat(sp_assoc_genSig_weighted, genSig_vals(idx_tochange)); % to be used in the next figures
        end
        %sp_assoc_genSig_weighted has the value of the genSig multiple
        %times. The count is set by the number of spikes happeing in
        %the time-window associated with that generator signal value
        
        ax2 = subplot(212);plot(genSig_ts, genSig_vals,'y');hold on;
        plot(genSig_ts, genSig_vals,'k.');hold on;
        plot(estim_spts, spike_genSig_vals,'r.');hold on;
        plot(genSig_ts, sp_assoc_genSig,'b*');hold on;
        
        xlabel('t');ylabel('Norm Val (mV)');
        xlim([0,max(estim_ts)]);
        
        linkaxes([ax1,ax2],'x')
        
        figTitle = sprintf('%s [%s]\nExtracting the spike associated stimuli/generator signal',strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'));
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Figure 4xx - Overlay a histogram of spike-associated generator signals.
        figIdx = 4;
        figure();
        
        [estim_binCounts,estim_binEdges] = histcounts(estim_amps_norm);
        estim_binCenters = (estim_binEdges(1:end-1) + estim_binEdges(2:end))/2;
        
        [genSig_binCounts,genSig_binEdges] = histcounts(genSig_vals);
        genSig_binCenters = (genSig_binEdges(1:end-1) + genSig_binEdges(2:end))/2;
        
        ax1 = subplot(321);bar(estim_binCenters, estim_binCounts,'histc');title('Normlzd Stimuli');
        ax2 = subplot(322);bar(genSig_binCenters, genSig_binCounts,'histc');title('Generator Signal');
        
        [sp_assoc_stimuli_binCounts,~] = histcounts(sp_assoc_stimuli, estim_binEdges);
        ax3 = subplot(323);bar(estim_binCenters, sp_assoc_stimuli_binCounts,'histc');title('Spike Associated & Normlzd Stimuli');
        
        [sp_assoc_stimuli_binCounts_weighted,~] = histcounts(sp_assoc_stimuli_weighted, estim_binEdges);
        ax5 = subplot(325);bar(estim_binCenters, sp_assoc_stimuli_binCounts_weighted,'histc');title('Spike Associated & Weighted & Normlzd Stimuli');
        
        [sp_assoc_genSig_binCounts,~] = histcounts(sp_assoc_genSig, genSig_binEdges);
        ax4 = subplot(324);bar(genSig_binCenters, sp_assoc_genSig_binCounts,'histc');title('Spike Associated Gnerator Signal');
        
        [sp_assoc_genSig_binCounts_weighted,~] = histcounts(sp_assoc_genSig_weighted, genSig_binEdges);
        ax6 = subplot(326);bar(genSig_binCenters, sp_assoc_genSig_binCounts_weighted,'histc');title('Spike Associated & Weighted Gnerator Signal');
        
        linkaxes([ax1,ax3, ax5],'x');
        linkaxes([ax2,ax4, ax6],'x');
        
        figTitle = sprintf('%s [%s]\nOverlay a histogram of spike-associated generator signals.',strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'));
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Figure 5xx - Stimuli segment waveform of "nWavefs" largest spike associated generator signal values
        figIdx = 5;
        nWavefs = 100;
        [~,genSig_Ids] = maxk(sp_assoc_genSig,nWavefs);
        figure(); hold on;
        for genSig_Idx = genSig_Ids'
            estim_excerpt = estim_amps_norm(genSig_Idx:(genSig_Idx+Kw-1),1);
            plot(kernel_t,estim_excerpt,'k');hold on;
        end
        
        exact_overlap = (sum(diff(estim_amps_norm(genSig_Ids,1))==0)/nWavefs)*100;
        
        xlabel('t');
        figTitle = sprintf('%s [%s]\nStimuli excerpts of %d largest spike associated generator signal values\n%.1f %% Overlaps in the Waveforms'...
            ,strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'),nWavefs, exact_overlap);
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Figure 6xx - Spike rate vs. the generator signal
        % We would like to count the number of spikes corresponding to each value of the
        % generator signal. For this we first assign a generator signal value to
        % each spike time stamp. We then bin those spike_genSig_vals and count the
        % number of times a value falls within each bin and visualize it as a histogram.
        figIdx = 6;
        figure();
        
        FRgenSig = sp_assoc_genSig_binCounts_weighted ./ genSig_binCounts; % divide each bin by the number of generator signals there
        FRgenSig = FRgenSig .* exp_ps.stimFreq; % divide again by the sampling time to get the number of spikes per second (Hz)
        
        FRgenSig(isnan(FRgenSig)) = 0;
        
        %         p = polyfit(genSig_binCenters,FRgenSig,2);
        %         t2 = min(genSig_binCenters):0.001:max(genSig_binCenters);
        %         y2 = polyval(p,t2);
        %
        %         plot(t2,y2, 'b'); hold on;
        plot(genSig_binCenters,FRgenSig, 'b');hold on;
        plot(genSig_binCenters,FRgenSig, 'k.');
        
        xlabel('Gen. Sig Value');
        ylabel('Spikes Rate (Hz)');
        
        figTitle = sprintf('%s [%s]\nSpike rate vs. the generator signal amplitude',strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'));
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Figure 7xx - PCA on spike associated stimuli waveforms
        % ToDo: consider unifying the procedure to compute spike
        % associated generator signal with spike associated stimuli waveforms
        figIdx = 7;
        
        raw_stim_ensem = exp_ps.tData.raw_stim_ensem(:,crop1_idx:crop2_idx);
        spike_assoc_ensemble = exp_ps.tData.spike_assoc_ensemble(:,crop1_idx:crop2_idx);
        
        nPCs = 2;
        [PCs, var_perserved ] = custom_pca(spike_assoc_ensemble,nPCs);
        
        prj_estim_amps_excerpts = raw_stim_ensem * PCs;
        prj_sp_assoc_estim_excerpts = spike_assoc_ensemble * PCs;
        
        figure();
        subplot(3,2,[1,4]);plot(prj_estim_amps_excerpts(:,1),prj_estim_amps_excerpts(:,2),'b.');hold on;
        plot(prj_sp_assoc_estim_excerpts(:,1),prj_sp_assoc_estim_excerpts(:,2),'r*');
        xlabel('PC1'); ylabel('PC2');
        
        subplot(3,2,5);plot(kernel_t,PCs(:,1));title('PC1');
        subplot(3,2,6);plot(kernel_t,PCs(:,2));title('PC2');
        
        figTitle = sprintf('%s [%s]\nProjection of the stimuli segments (var preseved %.2f %%).',strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'),var_perserved*100);
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
        %% Figure 8xx - STC: PCA on mean STA subtracted spike associated ensemble
        figIdx = 8;
        
        nsp = exp_ps.nspikes;
        spike_assoc_ensemble_spcount = exp_ps.tData.spike_assoc_ensemble_spcount;
        
        STC = spike_assoc_ensemble'*(spike_assoc_ensemble.*repmat(spike_assoc_ensemble_spcount,1,Kw))/(nsp-1) - kernel*kernel'*nsp/(nsp-1);
        [U, S, ~] = svd(STC); %eigenvectors sorted based on magnitude of eigen values
        STC_PCs = U(:,1:nPCs);

        prj2_estim_amps_excerpts = raw_stim_ensem * STC_PCs;
        prj2_sp_assoc_estim_excerpts = spike_assoc_ensemble * STC_PCs;
        
        figure();
        subplot(3,2,[1,4]);plot(prj2_estim_amps_excerpts(:,1),prj2_estim_amps_excerpts(:,2),'b.');hold on;
        plot(prj2_sp_assoc_estim_excerpts(:,1),prj2_sp_assoc_estim_excerpts(:,2),'r*');
        xlabel('PC1'); ylabel('PC2');
        
        subplot(3,2,5);plot(kernel_t,STC_PCs(:,1));title('STC-PC1');
        subplot(3,2,6);plot(kernel_t,STC_PCs(:,2));title('STC-PC2');
        
        figTitle = sprintf('%s [%s]\nProjection of the stimuli based on STC.',strrep(exp_ps.exp_id,'_','.'),strrep(exp_ps.cell_id,'_','-'));
        suptitle(figTitle);
        saveas(gcf, [exp_ps.work_dir, fig_basename, sprintf('_F%.2d.%s',figIdx,'jpeg')]);
        if save_fig; saveas(gcf, [exp_ps.work_dir, sprintf('%s_[%s]',exp_ps.exp_id,exp_ps.cell_id), sprintf('_F%.2d.%s',figIdx,'fig')]);end
        
    end
end