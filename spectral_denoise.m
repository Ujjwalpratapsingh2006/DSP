function [y_clean, psd_noisy, psd_clean, f_axis] = spectral_denoise(x, fs, alpha_sub, beta_floor)
% SPECTRAL_DENOISE Audio Noise Reduction using STFT Spectral Subtraction
% =========================================================================
% ECE DSP Syllabus Concepts:
%   - Short-Time Fourier Transform (STFT) Analysis & Synthesis
%   - Power Spectral Density (PSD) Estimation
%   - Non-Stationary Signal Processing with Windowing (Hann window)
%   - Spectral Subtraction Rule:
%       |Y(f)|^2 = max( |X(f)|^2 - alpha * |N(f)|^2 ,  beta * |X(f)|^2 )
%   - Phase Preservation: Y(f) = |Y(f)| * exp(j * angle(X(f)))
%   - Overlap-Add (OLA) Synthesis
%
% Inputs:
%   x          : Noisy mono audio signal
%   fs         : Sampling rate in Hz
%   alpha_sub  : Over-subtraction factor (1.0 to 3.0, default: 2.0)
%   beta_floor : Spectral floor factor to eliminate musical noise (default: 0.02)
%
% Outputs:
%   y_clean   : Denoised output audio signal
%   psd_noisy : Average power spectral density of noisy input (for plotting)
%   psd_clean : Average power spectral density of cleaned output (for plotting)
%   f_axis    : Frequency vector corresponding to PSD points (Hz)
% =========================================================================

    % ---------------------------------------------------------------------
    % Block 1: Input Setup & Window Configuration
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(alpha_sub), alpha_sub = 2.0; end
    if nargin < 4 || isempty(beta_floor), beta_floor = 0.02; end

    x = x(:);
    total_len = length(x);

    % Frame size: 25 ms (~1024 samples at 44.1 kHz)
    n_fft = 1024;
    hop = n_fft / 2; % 50% overlap for perfect reconstruction with Hann
    win = hann(n_fft, 'periodic');

    % Number of analysis frames
    num_frames = floor((total_len - n_fft) / hop) + 1;

    % ---------------------------------------------------------------------
    % Block 2: Noise Power Spectrum Estimation
    % ---------------------------------------------------------------------
    % Assume the first 8-10 frames (approx 100-150 ms) contain background noise
    num_noise_frames = min(10, max(2, floor(num_frames * 0.08)));
    noise_power_accum = zeros(n_fft, 1);

    for m = 1:num_noise_frames
        idx = (m - 1) * hop + 1;
        frame = x(idx:idx + n_fft - 1) .* win;
        noise_power_accum = noise_power_accum + abs(fft(frame, n_fft)).^2;
    end
    noise_psd = noise_power_accum / num_noise_frames;

    % ---------------------------------------------------------------------
    % Block 3: STFT Spectral Subtraction Loop
    % ---------------------------------------------------------------------
    y_accum = zeros(total_len + n_fft, 1);
    win_sum = zeros(total_len + n_fft, 1);

    psd_noisy_accum = zeros(n_fft / 2 + 1, 1);
    psd_clean_accum = zeros(n_fft / 2 + 1, 1);

    for m = 1:num_frames
        idx = (m - 1) * hop + 1;
        frame = x(idx:idx + n_fft - 1) .* win;

        % Compute complex discrete Fourier spectrum
        X_complex = fft(frame, n_fft);
        mag_sq = abs(X_complex).^2;
        phase = angle(X_complex);

        % Spectral Subtraction formula with spectral floor
        subtracted_mag_sq = mag_sq - alpha_sub * noise_psd;
        floor_mag_sq = beta_floor * mag_sq;
        clean_mag_sq = max(subtracted_mag_sq, floor_mag_sq);
        clean_mag = sqrt(clean_mag_sq);

        % Recombine cleaned magnitude with original phase spectrum
        Y_complex = clean_mag .* exp(1j * phase);

        % Inverse FFT to reconstruct time-domain frame
        reconstructed_frame = real(ifft(Y_complex, n_fft)) .* win;

        % Overlap-Add accumulation
        y_accum(idx:idx + n_fft - 1) = y_accum(idx:idx + n_fft - 1) + reconstructed_frame;
        win_sum(idx:idx + n_fft - 1) = win_sum(idx:idx + n_fft - 1) + win.^2;

        % Log half-spectrum for plotting
        half_idx = 1:(n_fft / 2 + 1);
        psd_noisy_accum = psd_noisy_accum + mag_sq(half_idx);
        psd_clean_accum = psd_clean_accum + clean_mag_sq(half_idx);
    end

    % ---------------------------------------------------------------------
    % Block 4: Overlap-Add Normalization & Output Scaling
    % ---------------------------------------------------------------------
    valid_mask = win_sum > 1e-4;
    y_accum(valid_mask) = y_accum(valid_mask) ./ win_sum(valid_mask);

    % Trim to exact input length
    y_clean = y_accum(1:total_len);

    % Prevent digital clipping
    max_val = max(abs(y_clean));
    if max_val > 0.98
        y_clean = (y_clean / max_val) * 0.95;
    end

    % ---------------------------------------------------------------------
    % Block 5: Power Spectral Density (PSD) Averages for Visualization
    % ---------------------------------------------------------------------
    psd_noisy = 10 * log10(psd_noisy_accum / num_frames + 1e-12);
    psd_clean = 10 * log10(psd_clean_accum / num_frames + 1e-12);
    f_axis = linspace(0, fs / 2, n_fft / 2 + 1)';
end
