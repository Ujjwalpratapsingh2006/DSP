function [y_eq, H_mag_dB, f_grid] = parametric_eq(x, fs, gains_dB)
% PARAMETRIC_EQ 5-Band Studio Equalizer using Cascaded Second-Order IIR Biquad Filters
% =========================================================================
% ECE DSP Syllabus Concepts:
%   - Second-Order Digital IIR Filter (Biquad) Formulation:
%       H(z) = (b0 + b1*z^(-1) + b2*z^(-2)) / (1 + a1*z^(-1) + a2*z^(-2))
%   - Bilinear Transform & Analog-to-Digital Frequency Prewarping
%   - Cascaded Filter Topologies: H_total(z) = H1(z) * H2(z) * ... * H5(z)
%   - Frequency Response Analysis: H(e^(jw)) over logarithmic audio spectrum
%
% Inputs:
%   x        : Mono audio vector
%   fs       : Sampling frequency in Hz
%   gains_dB : 5-element vector of gains in dB:
%              [LowShelf(100Hz), LowMid(400Hz), Mid(1200Hz), HighMid(3200Hz), HighShelf(8000Hz)]
%              Default: [2.0, -1.0, 2.5, 3.0, 1.5] (Vocal clarity preset)
%
% Outputs:
%   y_eq     : Equalized audio signal
%   H_mag_dB : Total composite frequency response magnitude in dB
%   f_grid   : Frequency axis from 20 Hz to fs/2 in Hz (for plotting)
% =========================================================================

    % ---------------------------------------------------------------------
    % Block 1: Input Validation and Filter Specifications
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(gains_dB)
        % Default preset: Vocal Presence & Polish
        gains_dB = [2.0, -1.5, 2.0, 3.5, 2.0];
    end

    x = x(:);
    
    % Center / Cutoff frequencies for the 5 audio bands (Hz)
    fc = [100, 400, 1200, 3200, 8000];
    % Quality factors (Q)
    Q  = [0.707, 1.2, 1.4, 1.2, 0.707];

    % ---------------------------------------------------------------------
    % Block 2: Frequency Grid for Composite Response Evaluation
    % ---------------------------------------------------------------------
    n_points = 2048;
    f_grid = logspace(log10(20), log10(fs / 2), n_points);
    H_total = ones(1, n_points);

    y_filtered = x;

    % ---------------------------------------------------------------------
    % Block 3: Biquad Coefficient Computation & Cascaded Filtering
    % ---------------------------------------------------------------------
    for k = 1:5
        G = gains_dB(k);
        A = 10^(G / 40); % Voltage gain factor
        w0 = 2 * pi * fc(k) / fs;
        alpha = sin(w0) / (2 * Q(k));
        cos_w0 = cos(w0);

        switch k
            case 1
                % Band 1: Low-Shelf Filter
                b0 =    A * ( (A+1) - (A-1)*cos_w0 + 2*sqrt(A)*alpha );
                b1 =  2*A * ( (A-1) - (A+1)*cos_w0 );
                b2 =    A * ( (A+1) - (A-1)*cos_w0 - 2*sqrt(A)*alpha );
                a0 =          (A+1) + (A-1)*cos_w0 + 2*sqrt(A)*alpha;
                a1 =   -2 * ( (A-1) + (A+1)*cos_w0 );
                a2 =          (A+1) + (A-1)*cos_w0 - 2*sqrt(A)*alpha;

            case 5
                % Band 5: High-Shelf Filter
                b0 =    A * ( (A+1) + (A-1)*cos_w0 + 2*sqrt(A)*alpha );
                b1 = -2*A * ( (A-1) + (A+1)*cos_w0 );
                b2 =    A * ( (A+1) + (A-1)*cos_w0 - 2*sqrt(A)*alpha );
                a0 =          (A+1) - (A-1)*cos_w0 + 2*sqrt(A)*alpha;
                a1 =    2 * ( (A-1) - (A+1)*cos_w0 );
                a2 =          (A+1) - (A-1)*cos_w0 - 2*sqrt(A)*alpha;

            otherwise
                % Bands 2, 3, 4: Peaking Parametric EQ
                b0 = 1 + alpha * A;
                b1 = -2 * cos_w0;
                b2 = 1 - alpha * A;
                a0 = 1 + alpha / A;
                a1 = -2 * cos_w0;
                a2 = 1 - alpha / A;
        end

        % Normalize by a0 to obtain standard digital filter form
        b = [b0, b1, b2] / a0;
        a = [a0, a1, a2] / a0;

        % Apply IIR filter stage
        y_filtered = filter(b, a, y_filtered);

        % Calculate complex frequency response H_k(w) of current stage
        H_k = freqz(b, a, f_grid, fs);
        H_total = H_total .* H_k(:).';
    end

    % ---------------------------------------------------------------------
    % Block 4: Composite Magnitude in Decibels & Output Limiting
    % ---------------------------------------------------------------------
    H_mag_dB = 20 * log10(abs(H_total));
    y_eq = y_filtered;

    % Normalize to prevent digital clipping
    max_val = max(abs(y_eq));
    if max_val > 0.98
        y_eq = (y_eq / max_val) * 0.95;
    end
end
