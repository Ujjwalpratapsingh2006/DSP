function [y_echo, h_impulse, delay_sec, D] = delay_echo(x, fs, room_size_or_delay, feedback_gain, wet_dry_mix)
% DELAY_ECHO Implements Digital Echo from Room Physical Dimensions / Difference Equations
% =========================================================================
% ECE DSP & Acoustic Physics Concepts:
%   - Acoustic Reflection Delay from Room Size (Meters):
%       Round-trip distance d = 2 * L (meters)
%       Propagation delay: tau = (2 * L) / c, where c = 343 m/s (speed of sound in air)
%   - Discrete Sample Delay:
%       D = round(tau * fs)
%   - Time-Domain Discrete Difference Equation:
%       y[n] = x[n] + g * y[n - D]
%   - Z-Transform Transfer Function:
%       H(z) = Y(z) / X(z) = 1 / (1 - g * z^(-D))
%   - Filter Stability Criterion:
%       BIBO stable if and only if |g| < 1 (poles on circle of radius |g|^(1/D) < 1).
%
% Inputs:
%   x                   : Input audio vector (mono)
%   fs                  : Sampling frequency in Hz (e.g., 44100)
%   room_size_or_delay  : If >= 1.0: Room dimension in METERS (e.g., 5m, 15m, 25m, 50m)
%                         If <  1.0: Delay time directly in SECONDS (e.g., 0.25 s)
%                         Default: 25.0 meters (~145.8 ms delay)
%   feedback_gain       : Feedback multiplier g (0 to 0.85, default: auto-calculated or 0.48)
%   wet_dry_mix         : Wet ratio (0 = dry, 1 = 100% echo, default: 0.42)
%
% Outputs:
%   y_echo    : Output audio with room-dimension echo effect
%   h_impulse : Filter impulse response for visualization
%   delay_sec : Calculated delay time in seconds
%   D         : Discrete delay sample count
% =========================================================================

    % ---------------------------------------------------------------------
    % Block 1: Input Validation and Acoustic Parameter Calculation
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(room_size_or_delay), room_size_or_delay = 25.0; end
    if nargin < 4 || isempty(feedback_gain), feedback_gain = []; end
    if nargin < 5 || isempty(wet_dry_mix), wet_dry_mix = 0.42; end

    x = x(:);
    N = length(x);
    c_sound = 343.0; % Speed of sound in air at 20 deg C (m/s)

    % Determine if input is room size in meters or delay in seconds
    if room_size_or_delay >= 1.0
        % Room size provided in meters (e.g., 5m bedroom to 80m cathedral)
        room_meters = room_size_or_delay;
        % Round-trip wall reflection: distance = 2 * room_meters
        delay_sec = (2.0 * room_meters) / c_sound;
        
        % Auto-scale feedback gain with room size if not explicitly set
        if isempty(feedback_gain)
            % Larger rooms have slightly longer acoustic persistence
            feedback_gain = min(0.75, max(0.35, 0.38 + 0.003 * room_meters));
        end
    else
        % Delay directly provided in seconds (< 1.0)
        delay_sec = room_size_or_delay;
        room_meters = (delay_sec * c_sound) / 2.0;
        if isempty(feedback_gain)
            feedback_gain = 0.48;
        end
    end

    % Convert delay time to discrete sample count D
    D = max(1, round(delay_sec * fs));

    % Stability check: Feedback gain must be strictly less than 1.0
    if abs(feedback_gain) >= 0.95
        warning('Feedback gain |g| >= 0.95 risks instability! Clamping to 0.85.');
        feedback_gain = 0.85;
    end

    % ---------------------------------------------------------------------
    % Block 2: Z-Transform Filter Coefficient Formulation
    % ---------------------------------------------------------------------
    % Difference equation: y[n] - g * y[n - D] = x[n]
    % Numerator polynomial b(z):   b_0 = 1, b_1..b_D = 0
    % Denominator polynomial a(z): a_0 = 1, a_1..a_{D-1} = 0, a_D = -g
    b = zeros(1, D + 1);
    b(1) = 1;

    a = zeros(1, D + 1);
    a(1) = 1;
    a(D + 1) = -feedback_gain;

    % ---------------------------------------------------------------------
    % Block 3: IIR Filtering Execution
    % ---------------------------------------------------------------------
    % Compute delayed/feedback echo stream
    y_wet = filter(b, a, x);

    % ---------------------------------------------------------------------
    % Block 4: Wet / Dry Blending & Normalization
    % ---------------------------------------------------------------------
    y_echo = (1 - wet_dry_mix) * x + wet_dry_mix * y_wet;

    % Normalize to prevent digital saturation
    max_amp = max(abs(y_echo));
    if max_amp > 0.98
        y_echo = (y_echo / max_amp) * 0.95;
    end

    % ---------------------------------------------------------------------
    % Block 5: Impulse Response Calculation (for Viva & Plotting)
    % ---------------------------------------------------------------------
    impulse_len = min(round(fs * 2.0), max(4096, 5 * D));
    unit_impulse = zeros(impulse_len, 1);
    unit_impulse(1) = 1;
    h_impulse = filter(b, a, unit_impulse);
end
