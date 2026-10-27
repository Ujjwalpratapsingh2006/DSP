function [f0, is_voiced] = pitch_detect(frame, fs, f_min, f_max)
% PITCH_DETECT Detects fundamental frequency (f0) of an audio frame
% =========================================================================
% ECE DSP Syllabus Concepts:
%   - Time-Domain Autocorrelation Sequence: r_xx[k] = sum(x[n] * x[n+k])
%   - Zero-Lag Energy Normalization
%   - FFT-based Fast Autocorrelation (Wiener-Khinchin): R = ifft(|fft(x)|^2)
%   - Sub-sample Parabolic Peak Interpolation
%
% Inputs:
%   frame  : Vector of audio samples for a short window (e.g., 20-40 ms)
%   fs     : Sampling frequency in Hz (e.g., 44100 Hz)
%   f_min  : Minimum expected pitch in Hz (default: 80 Hz for human vocal)
%   f_max  : Maximum expected pitch in Hz (default: 500 Hz for human vocal)
%
% Outputs:
%   f0        : Estimated fundamental frequency in Hz (0 if unvoiced/silent)
%   is_voiced : Logical flag (true if speech/vocal detected, false if silence)
% =========================================================================

    % ---------------------------------------------------------------------
    % Block 1: Input Validation and Parameter Defaults
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(f_min), f_min = 80; end
    if nargin < 4 || isempty(f_max), f_max = 500; end

    frame = frame(:) - mean(frame);
    N = length(frame);

    % Energy check for silence threshold (quiet frames are unvoiced)
    frame_energy = sum(frame.^2) / N;
    if frame_energy < 3e-4
        f0 = 0;
        is_voiced = false;
        return;
    end

    % ---------------------------------------------------------------------
    % Block 2: Normalized Autocorrelation via FFT (Wiener-Khinchin Theorem)
    % ---------------------------------------------------------------------
    n_fft = 2^nextpow2(2 * N);
    X = fft(frame, n_fft);
    power_spectrum = abs(X).^2;
    r_xx = real(ifft(power_spectrum));
    r_xx = r_xx(1:N);
    
    if r_xx(1) > 0
        r_norm = r_xx / r_xx(1);
    else
        f0 = 0;
        is_voiced = false;
        return;
    end

    % ---------------------------------------------------------------------
    % Block 3: Search Lag Bounds for Human Pitch Range (f = fs / k)
    % ---------------------------------------------------------------------
    lag_min = max(2, round(fs / f_max));
    lag_max = min(N - 1, round(fs / f_min));

    if lag_min >= lag_max
        f0 = 0;
        is_voiced = false;
        return;
    end

    search_region = r_norm(lag_min:lag_max);
    [peak_val, peak_idx] = max(search_region);
    best_lag = lag_min + peak_idx - 1;

    % ---------------------------------------------------------------------
    % Block 4: Voicing Decision & Sub-Sample Parabolic Interpolation
    % ---------------------------------------------------------------------
    % Threshold of 0.28 reliably tracks singing with vibrato and background noise
    voicing_threshold = 0.28;

    if peak_val >= voicing_threshold && best_lag > 1 && best_lag < N
        alpha = r_norm(best_lag - 1);
        beta  = r_norm(best_lag);
        gamma = r_norm(best_lag + 1);
        
        denom = 2 * (alpha - 2 * beta + gamma);
        if abs(denom) > 1e-12
            delta = (alpha - gamma) / denom;
            refined_lag = best_lag + delta;
        else
            refined_lag = best_lag;
        end
        
        f0 = fs / refined_lag;
        is_voiced = true;
    else
        f0 = 0;
        is_voiced = false;
    end
end
