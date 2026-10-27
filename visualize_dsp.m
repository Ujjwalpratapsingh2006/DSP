function visualize_dsp(data)
% VISUALIZE_DSP Generates publication-quality ECE DSP analysis plots
% =========================================================================
% ECE DSP Concepts Visualized:
%   - Time-Frequency Pitch Tracking & Quantization
%   - Power Spectral Density (PSD) & Denoising Efficiency
%   - Time-Domain Noise Residual Suppression (e[n] = x[n] - y[n])
%   - Digital Delay & Echo Impulse Dynamics
%   - Schroeder Room Impulse Response h[n] and Acoustic Decay
% =========================================================================

    fs = data.fs;
    t_audio = (0:length(data.x_raw) - 1) / fs;

    % =====================================================================
    % FIGURE 1: SMART AUTO-TUNE ANALYSIS
    % =====================================================================
    figure('Name', 'Auto-Tune Pitch Snapping & Time-Frequency Analysis', ...
           'Color', 'w', 'Position', [100, 100, 1000, 650]);

    % Subplot 1: Pitch Contour over Time (Wobbly vs Locked)
    subplot(2, 1, 1);
    plot(data.t_pitch, data.f0_raw, 'r.', 'LineWidth', 1.5, 'MarkerSize', 10); hold on;
    plot(data.t_pitch, data.f0_tuned, 'b-', 'LineWidth', 2.2);
    
    % Draw reference lines for standard musical notes
    ref_notes = [261.63, 329.63, 392.00, 440.00];
    ref_names = {'C4 (261.6 Hz)', 'E4 (329.6 Hz)', 'G4 (392.0 Hz)', 'A4 (440.0 Hz)'};
    for r = 1:length(ref_notes)
        yline(ref_notes(r), 'k--', ref_names{r}, 'LabelVerticalAlignment', 'bottom', ...
              'LabelHorizontalAlignment', 'left', 'Alpha', 0.5);
    end
    hold off;
    grid on;
    title('Auto-Tune Dynamic Pitch Tracking (Autocorrelation Peak vs 12-TET Scale)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Time (seconds)', 'FontSize', 10);
    ylabel('Fundamental Frequency f0 (Hz)', 'FontSize', 10);
    legend('Detected Raw Pitch (Off-Key / Vibrato)', 'Auto-Tuned Target Pitch (Quantized)', 'Location', 'northwest');
    ylim([220, 480]);

    % Subplot 2: Waveform Comparison (Input vs Tuned)
    subplot(2, 1, 2);
    plot(t_audio, data.x_raw, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.0); hold on;
    plot(t_audio, data.y_tuned, 'Color', [0.0 0.45 0.74], 'LineWidth', 1.2);
    hold off;
    grid on;
    title('Time-Domain Audio Waveform: Raw Vocal vs Pitch-Corrected Vocal', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Time (seconds)', 'FontSize', 10);
    ylabel('Normalized Amplitude', 'FontSize', 10);
    legend('Raw Input Signal', 'Auto-Tuned Signal', 'Location', 'northeast');
    xlim([0.2, min(4.0, max(t_audio))]);

    % =====================================================================
    % FIGURE 2: NOISE REDUCTION & RESIDUAL SUPPRESSION ANALYSIS
    % =====================================================================
    figure('Name', 'Spectral Denoising & Residual Analysis', ...
           'Color', 'w', 'Position', [150, 150, 1000, 650]);

    % Subplot 1: Power Spectral Density Before vs After Denoising
    subplot(2, 1, 1);
    plot(data.f_axis, data.psd_noisy, 'r-', 'LineWidth', 1.2); hold on;
    plot(data.f_axis, data.psd_clean, 'g-', 'LineWidth', 1.5);
    hold off;
    grid on;
    xlim([0, 12000]);
    title('Spectral Subtraction: Power Spectral Density (PSD) Comparison', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Frequency (Hz)', 'FontSize', 10);
    ylabel('Power / Frequency (dB/Hz)', 'FontSize', 10);
    legend('Noisy Input (Microphone Hiss + Noise)', 'Denoised Signal (Clean Vocal Floor)', 'Location', 'northeast');

    % Subplot 2: Time-Domain Noise Residual Suppression
    subplot(2, 1, 2);
    len_cmp = min(length(data.x_raw), length(data.y_denoised));
    t_cmp = (0:len_cmp - 1) / fs;
    noise_residual = data.x_raw(1:len_cmp) - data.y_denoised(1:len_cmp);
    plot(t_cmp, data.x_raw(1:len_cmp), 'Color', [0.75 0.75 0.75], 'LineWidth', 0.9); hold on;
    plot(t_cmp, data.y_denoised(1:len_cmp), 'Color', [0.15 0.65 0.35], 'LineWidth', 1.2);
    plot(t_cmp, noise_residual, 'Color', [0.85 0.25 0.25], 'LineWidth', 0.9);
    hold off;
    grid on;
    title('Time-Domain Noise Floor Suppression & Extracted Noise Residual e[n] = x[n] - y[n]', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Time (seconds)', 'FontSize', 10);
    ylabel('Amplitude', 'FontSize', 10);
    legend('Raw Noisy Input x[n]', 'Denoised Signal y[n]', 'Suppressed Noise Residual e[n]', 'Location', 'northeast');
    xlim([0.2, min(4.0, max(t_cmp))]);

    % =====================================================================
    % FIGURE 3: ECHO & SCHROEDER REVERB ACOUSTICS
    % =====================================================================
    figure('Name', 'Delay, Echo & Schroeder Reverb Acoustics', ...
           'Color', 'w', 'Position', [200, 200, 1000, 650]);

    % Subplot 1: Waveforms Comparison (Dry vs Echo vs Reverb)
    subplot(2, 1, 1);
    plot(t_audio, data.x_raw, 'k:', 'LineWidth', 0.8); hold on;
    plot(t_audio, data.y_echo, 'Color', [0.85 0.33 0.1], 'LineWidth', 1.1);
    plot(t_audio, data.y_reverb, 'Color', [0.47 0.67 0.19], 'LineWidth', 1.1);
    hold off;
    grid on;
    title('Time-Domain Spatial Effects: Dry Input vs Repeating Echo vs Reverb', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Time (seconds)', 'FontSize', 10);
    ylabel('Amplitude', 'FontSize', 10);
    legend('Dry Signal', 'Echo (Difference Equation y[n] = x[n] + g*y[n-D])', ...
           'Schroeder Reverb (4 Comb + 2 All-Pass)', 'Location', 'northeast');

    % Subplot 2: Schroeder Room Impulse Response h[n]
    subplot(2, 1, 2);
    t_h = (0:length(data.h_reverb) - 1) / fs;
    plot(t_h, data.h_reverb, 'Color', [0.1 0.3 0.6], 'LineWidth', 1.0);
    grid on;
    title('Schroeder Reverb Room Impulse Response h[n] (T60 Decay Profile)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('Time (seconds)', 'FontSize', 10);
    ylabel('Impulse Response Amplitude', 'FontSize', 10);
    xlim([0, 1.0]);

    drawnow;
    fprintf('[visualize_dsp] Successfully displayed all 3 analysis figures.\n');
end
