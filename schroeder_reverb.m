function [y_reverb, h_room, T60] = schroeder_reverb(x, fs, room_size_or_T60, wet_mix)
% SCHROEDER_REVERB Artificial Acoustic Reverberation using Comb & All-Pass IIR Networks
% =========================================================================
% ECE DSP Syllabus Concepts:
%   - Acoustic Room Modeling from Physical Dimensions:
%       Sabine's Reverberation Time Approximation: T60 proportional to Room Dimension L
%   - Feedback Comb Filters (FBCF) modeling acoustic room eigenmodes:
%       H_comb(z) = z^(-D) / (1 - g * z^(-D))
%   - Series All-Pass Filters (APF) creating high reflection density without color:
%       H_ap(z) = (-g + z^(-D)) / (1 - g * z^(-D)), where |H_ap(e^(jw))| = 1
%   - T60 Reverberation Time Decay Equation:
%       g = 10^(-3 * D / (T60 * fs))
%
% Inputs:
%   x                  : Mono input audio signal
%   fs                 : Sampling frequency in Hz (e.g., 44100)
%   room_size_or_T60   : If >= 3.0: Room dimension in METERS (e.g., 10m to 80m)
%                        If <  3.0: Direct T60 reverberation time in SECONDS (e.g., 1.8 s)
%                        Default: 25.0 meters (~1.75 s T60)
%   wet_mix            : Wet audio blend ratio (0 to 1, default: 0.38)
%
% Outputs:
%   y_reverb : Reverberated audio signal
%   h_room   : Synthetic room impulse response (for pole-zero & decay plots)
%   T60      : Calculated reverberation time in seconds
% =========================================================================

    % ---------------------------------------------------------------------
    % Block 1: Input Validation and Acoustic Parameter Scaling
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(room_size_or_T60), room_size_or_T60 = 25.0; end
    if nargin < 4 || isempty(wet_mix), wet_mix = 0.38; end

    x = x(:);
    N = length(x);

    % Map Room Size in meters to Sabine T60 decay time
    if room_size_or_T60 >= 3.0
        room_meters = room_size_or_T60;
        % Physical acoustic scaling: larger room volume -> longer T60 decay
        T60 = min(4.5, max(0.8, 0.045 * room_meters + 0.6));
        % Scale base comb delays proportionally to room size
        scale_factor = sqrt(room_meters / 25.0);
    else
        T60 = room_size_or_T60;
        scale_factor = 1.0;
    end

    % ---------------------------------------------------------------------
    % Block 2: Parallel Feedback Comb Filter Stage (Room Resonance Modes)
    % ---------------------------------------------------------------------
    % Base Schroeder delays (ms): 29.7, 37.1, 41.1, 43.7
    base_delays_ms = [29.7, 37.1, 41.1, 43.7] * scale_factor;
    D_comb = max(2, round((base_delays_ms / 1000) * fs));

    % Calculate feedback gain for each comb based on T60 decay formula:
    % g = 10^(-3 * D / (T60 * fs))
    g_comb = 10 .^ (-3 * D_comb ./ (T60 * fs));

    comb_sum = zeros(N, 1);

    for i = 1:4
        b_c = zeros(1, D_comb(i) + 1);
        b_c(D_comb(i) + 1) = 1;

        a_c = zeros(1, D_comb(i) + 1);
        a_c(1) = 1;
        a_c(D_comb(i) + 1) = -g_comb(i);

        comb_sum = comb_sum + filter(b_c, a_c, x);
    end

    comb_sum = comb_sum * 0.25;

    % ---------------------------------------------------------------------
    % Block 3: Series All-Pass Filter Stage (Phase Diffusion / Density)
    % ---------------------------------------------------------------------
    delay_ms_ap = [5.0, 1.7] * scale_factor;
    D_ap = max(2, round((delay_ms_ap / 1000) * fs));
    g_ap = [0.7, 0.7];

    ap_signal = comb_sum;

    for j = 1:2
        b_ap = zeros(1, D_ap(j) + 1);
        b_ap(1) = -g_ap(j);
        b_ap(D_ap(j) + 1) = 1;

        a_ap = zeros(1, D_ap(j) + 1);
        a_ap(1) = 1;
        a_ap(D_ap(j) + 1) = -g_ap(j);

        ap_signal = filter(b_ap, a_ap, ap_signal);
    end

    % ---------------------------------------------------------------------
    % Block 4: Wet / Dry Mixing & Output Normalization
    % ---------------------------------------------------------------------
    y_reverb = (1 - wet_mix) * x + wet_mix * ap_signal;

    max_amp = max(abs(y_reverb));
    if max_amp > 0.98
        y_reverb = (y_reverb / max_amp) * 0.95;
    end

    % ---------------------------------------------------------------------
    % Block 5: Synthetic Room Impulse Response Calculation
    % ---------------------------------------------------------------------
    impulse_len = min(round(fs * 1.5), 65536);
    unit_imp = zeros(impulse_len, 1);
    unit_imp(1) = 1;

    c_imp = zeros(impulse_len, 1);
    for i = 1:4
        b_c = zeros(1, D_comb(i) + 1);
        b_c(D_comb(i) + 1) = 1;
        a_c = zeros(1, D_comb(i) + 1);
        a_c(1) = 1;
        a_c(D_comb(i) + 1) = -g_comb(i);
        c_imp = c_imp + filter(b_c, a_c, unit_imp);
    end
    c_imp = c_imp * 0.25;

    for j = 1:2
        b_ap = zeros(1, D_ap(j) + 1);
        b_ap(1) = -g_ap(j);
        b_ap(D_ap(j) + 1) = 1;
        a_ap = zeros(1, D_ap(j) + 1);
        a_ap(1) = 1;
        a_ap(D_ap(j) + 1) = -g_ap(j);
        c_imp = filter(b_ap, a_ap, c_imp);
    end

    h_room = c_imp;
end
