function [y_tuned, t_pitch, f0_raw, f0_tuned] = autotune(x, fs, scale_mode, correction_speed)
% AUTOTUNE Smart Musical Pitch Correction using Autocorrelation & Harmonic Resynthesis
% =========================================================================
% ECE DSP Syllabus Concepts:
%   - Frame-by-Frame Short-Time Fourier / Overlap-Add Processing
%   - Distant Musical Frequency Quantization (Pentatonic / Major Triad Grid)
%   - Fundamental Pitch Estimation via Autocorrelation: r_xx[k]
%   - Sinusoidal Harmonic Modeling & Pitch Resynthesis (McAulay-Quatieri)
%   - Continuous Inter-Frame Phase Accumulation
%
% Inputs:
%   x                : Input audio signal (mono vector)
%   fs               : Sampling rate in Hz (e.g., 44100)
%   scale_mode       : 'pentatonic' (default, wide gaps ~40-90Hz),
%                      'major_triad' (widest gaps ~70-130Hz),
%                      'C_major' (diatonic scale), or 'chromatic'
%   correction_speed : 0 (natural) to 1 (full robotic snap, default: 0.95)
%
% Outputs:
%   y_tuned  : Pitch-corrected output audio
%   t_pitch  : Time vector for pitch contour plots
%   f0_raw   : Detected raw fundamental frequency contour (Hz)
%   f0_tuned : Target corrected musical pitch contour (Hz)
% =========================================================================

    % ---------------------------------------------------------------------
    % Block 1: Input Validation and Parameter Configuration
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(scale_mode), scale_mode = 'pentatonic'; end
    if nargin < 4 || isempty(correction_speed), correction_speed = 0.95; end

    x = x(:);
    total_samples = length(x);

    % Analysis frame: 40 ms window with 75% overlap (hop = 10 ms)
    frame_len = round(0.040 * fs);
    if mod(frame_len, 2) ~= 0, frame_len = frame_len + 1; end
    hop_size = round(frame_len / 4);

    win = hann(frame_len, 'periodic');
    win_sum_norm = sum(win) / 2;

    num_frames = floor((total_samples - frame_len) / hop_size) + 1;

    t_pitch = zeros(num_frames, 1);
    f0_raw = zeros(num_frames, 1);
    f0_tuned = zeros(num_frames, 1);

    % Overlap-Add accumulation buffers
    y_accum = zeros(total_samples + frame_len, 1);
    win_accum = zeros(total_samples + frame_len, 1);

    % ---------------------------------------------------------------------
    % Block 2: Musical Reference Frequencies (Widely Spaced for Dramatic Snapping)
    % ---------------------------------------------------------------------
    % Formula: f(n) = 440 * 2^((n - 69) / 12), where n is MIDI note number
    midi_all = (36:84)'; % C2 (65.4 Hz) to C6 (1046.5 Hz)
    freq_all = 440 * (2 .^ ((midi_all - 69) / 12));
    note_classes = mod(midi_all, 12); % 0=C, 1=C#, 2=D, 3=D#, 4=E, 5=F, 6=F#, 7=G, 8=G#, 9=A, 10=A#, 11=B

    switch lower(scale_mode)
        case 'major_triad'
            % C, E, G only: extremely wide spacing (4 to 7 semitones = ~70 to 130 Hz apart!)
            mask = ismember(note_classes, [0, 4, 7]);
            allowed_freqs = freq_all(mask);

        case 'pentatonic'
            % C, D, E, G, A: widely spaced notes (2 to 3 semitones = ~35 to 85 Hz apart!)
            % Maximum audible Auto-Tune stairstep effect without sounding dissonant
            mask = ismember(note_classes, [0, 2, 4, 7, 9]);
            allowed_freqs = freq_all(mask);

        case 'c_major'
            % C, D, E, F, G, A, B: standard diatonic major scale
            mask = ismember(note_classes, [0, 2, 4, 5, 7, 9, 11]);
            allowed_freqs = freq_all(mask);

        otherwise
            % Chromatic: all 12 semitones
            allowed_freqs = freq_all;
    end

    % ---------------------------------------------------------------------
    % Block 3: Harmonic Resynthesis Setup & Continuous Phase State
    % ---------------------------------------------------------------------
    max_harmonics = 8;
    phase_accum = zeros(max_harmonics, 1);
    n_fft = 2^nextpow2(frame_len * 2);

    t_frame = (0:frame_len - 1)' / fs;

    % ---------------------------------------------------------------------
    % Block 4: Frame-by-Frame Pitch Tracking & Correction Loop
    % ---------------------------------------------------------------------
    for m = 1:num_frames
        idx_start = (m - 1) * hop_size + 1;
        idx_end = idx_start + frame_len - 1;

        current_frame = x(idx_start:idx_end);
        t_center = (idx_start + frame_len / 2) / fs;
        t_pitch(m) = t_center;

        % Step 1: Detect fundamental pitch f0 using Normalized Autocorrelation
        [f0, is_voiced] = pitch_detect(current_frame, fs, 80, 700);

        if is_voiced && f0 > 80 && f0 < 700
            f0_raw(m) = f0;

            % Step 2: Snap to the closest widely-spaced reference frequency
            [~, closest_idx] = min(abs(allowed_freqs - f0));
            target_f = allowed_freqs(closest_idx);

            % Blend between raw and target according to correction_speed
            effective_target = (1 - correction_speed) * f0 + correction_speed * target_f;
            f0_tuned(m) = effective_target;

            % Step 3: Spectral Analysis (FFT) to extract vocal formant magnitudes
            X_fft = fft(current_frame .* win, n_fft);
            half_len = n_fft / 2 + 1;
            mag_spec = abs(X_fft(1:half_len)) / win_sum_norm;
            f_axis = (0:half_len - 1)' * (fs / n_fft);

            % Step 4: Sinusoidal Harmonic Resynthesis at Target Frequency
            tuned_harmonics = zeros(frame_len, 1);
            num_h = min(max_harmonics, floor((fs / 2 - 100) / effective_target));

            for h = 1:num_h
                f_h_target = h * effective_target;
                f_h_orig = h * f0;

                % Formant amplitude from vocal spectrum
                if f_h_orig < fs / 2
                    [~, bin_idx] = min(abs(f_axis - f_h_orig));
                    A_h = mag_spec(bin_idx);
                else
                    A_h = 0;
                end

                % Synthesize sinusoid with continuous inter-frame phase
                phi_0 = phase_accum(h);
                inst_phase = 2 * pi * f_h_target * t_frame + phi_0;
                tuned_harmonics = tuned_harmonics + A_h * sin(inst_phase);

                % Advance phase accumulator
                phase_accum(h) = mod(phi_0 + 2 * pi * f_h_target * (hop_size / fs), 2 * pi);
            end

            windowed_grain = tuned_harmonics .* win;
        else
            % Unvoiced / Silence: Preserve consonants and noise as-is
            f0_raw(m) = NaN;
            f0_tuned(m) = NaN;
            windowed_grain = current_frame .* win;
        end

        % Overlap-Add accumulation
        y_accum(idx_start:idx_end) = y_accum(idx_start:idx_end) + windowed_grain;
        win_accum(idx_start:idx_end) = win_accum(idx_start:idx_end) + win;
    end

    % ---------------------------------------------------------------------
    % Block 5: Window Normalization & Output Scaling
    % ---------------------------------------------------------------------
    valid_mask = win_accum > 1e-4;
    y_accum(valid_mask) = y_accum(valid_mask) ./ win_accum(valid_mask);

    y_tuned = y_accum(1:total_samples);

    % Peak normalization
    max_amp = max(abs(y_tuned));
    if max_amp > 0.01
        y_tuned = (y_tuned / max_amp) * 0.90;
    end
end
