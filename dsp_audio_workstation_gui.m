function dsp_audio_workstation_gui()
% DSP_AUDIO_WORKSTATION_GUI Interactive MATLAB GUI for ECE DSP Audio Lab Project
% =========================================================================
% Features:
%   - Interactive Physical Room Size Input (meters):
%       Calculates acoustic round-trip echo delay: tau = (2 * L) / 343 (s)
%       and scales Schroeder room reverberation T60 decay
%   - 4 Dedicated Built-in Test Audios:
%       1. Original 4-Note Melody -> The classic continuous sung melody (C4->E4->G4->A4)
%       2. Vocal Glide            -> Tests Stairstep Auto-Tune Pitch Quantization
%       3. Vocal Staccato         -> Tests Echo repeats vs Reverb decay + Note Snapping
%       4. Percussive Pluck       -> Tests Delay taps vs Cathedral Room Ambiance
%   - Selectable Musical Reference Spacing (Pentatonic, Triad, C Major, Chromatic)
%   - Upload custom .wav audio
%   - Dedicated interactive playback for ALL DSP stages
%   - Embedded 3-Tab DSP Visualizer (Pitch contour, PSD/EQ, Reverb Impulse)
% =========================================================================

    % ---------------------------------------------------------------------
    % State Variables
    % ---------------------------------------------------------------------
    app_data.fs = 44100;
    app_data.room_size_m = 25.0; % Default: 25 meters (145.8 ms delay)
    app_data.x_raw = [];
    app_data.y_tuned = [];
    app_data.y_echo = [];
    app_data.y_reverb = [];
    app_data.y_denoised = [];
    app_data.y_eq = [];
    app_data.y_master = [];
    app_data.t_pitch = [];
    app_data.f0_raw = [];
    app_data.f0_tuned = [];
    app_data.psd_noisy = [];
    app_data.psd_clean = [];
    app_data.f_axis = [];
    app_data.H_eq_dB = [];
    app_data.f_eq_grid = [];
    app_data.h_reverb = [];
    app_data.player = [];
    app_data.filename = 'None loaded';

    % ---------------------------------------------------------------------
    % Main Window Creation (uifigure for desktop & MATLAB Online)
    % ---------------------------------------------------------------------
    fig = uifigure('Name', 'ECE DSP Audio Workstation Studio', ...
                    'Position', [50, 30, 1240, 770], ...
                    'Color', [0.12, 0.14, 0.18]);

    % ---------------------------------------------------------------------
    % Left Panel: Control Center & Playback Station
    % ---------------------------------------------------------------------
    ctrl_panel = uipanel(fig, 'Position', [15, 12, 365, 745], ...
                         'BackgroundColor', [0.16, 0.18, 0.23], ...
                         'ForegroundColor', [0.95, 0.95, 0.95], ...
                         'Title', 'CONTROL CENTER & PLAYBACK', ...
                         'FontWeight', 'bold', 'FontSize', 12);

    % Title Banner
    uilabel(ctrl_panel, 'Position', [15, 685, 335, 28], ...
            'Text', 'DSP Audio Workstation', ...
            'FontColor', [0.35, 0.75, 1.0], 'FontSize', 16, 'FontWeight', 'bold');
    uilabel(ctrl_panel, 'Position', [15, 668, 335, 18], ...
            'Text', 'ECE Lab: Auto-Tune, Echo, Reverb, Denoise & EQ', ...
            'FontColor', [0.70, 0.75, 0.80], 'FontSize', 10);

    % SECTION 1: Audio Selection (4 Test Audios + Upload)
    uipanel(ctrl_panel, 'Position', [10, 485, 345, 175], ...
            'BackgroundColor', [0.20, 0.23, 0.29], ...
            'ForegroundColor', [0.85, 0.85, 0.85], ...
            'Title', '1. Audio Source (4 Test Presets or Upload)', 'FontSize', 10, 'FontWeight', 'bold');

    btn_orig = uibutton(ctrl_panel, 'push', 'Position', [18, 608, 155, 28], ...
                        'Text', '🎵 1. Original Melody', ...
                        'BackgroundColor', [0.65, 0.40, 0.15], 'FontColor', 'w', 'FontSize', 9, ...
                        'ButtonPushedFcn', @(~,~) load_test('melody'));

    btn_test1 = uibutton(ctrl_panel, 'push', 'Position', [180, 608, 165, 28], ...
                         'Text', '🎤 2. Vocal Glide', ...
                         'BackgroundColor', [0.22, 0.52, 0.38], 'FontColor', 'w', 'FontSize', 9, ...
                         'ButtonPushedFcn', @(~,~) load_test('glide'));

    btn_test2 = uibutton(ctrl_panel, 'push', 'Position', [18, 574, 155, 28], ...
                         'Text', '🗣 3. Vocal Staccato', ...
                         'BackgroundColor', [0.25, 0.45, 0.65], 'FontColor', 'w', 'FontSize', 9, ...
                         'ButtonPushedFcn', @(~,~) load_test('staccato'));

    btn_test3 = uibutton(ctrl_panel, 'push', 'Position', [180, 574, 165, 28], ...
                         'Text', '🔔 4. Pluck Melody', ...
                         'BackgroundColor', [0.55, 0.35, 0.55], 'FontColor', 'w', 'FontSize', 9, ...
                         'ButtonPushedFcn', @(~,~) load_test('percussive'));

    btn_upload = uibutton(ctrl_panel, 'push', 'Position', [18, 540, 327, 28], ...
                          'Text', '📁 Upload Custom .WAV File', ...
                          'BackgroundColor', [0.35, 0.38, 0.45], 'FontColor', 'w', 'FontSize', 10, ...
                          'ButtonPushedFcn', @on_upload);

    lbl_file_info = uilabel(ctrl_panel, 'Position', [18, 488, 327, 48], ...
                            'Text', 'Loaded: Test 1 (Original 4-Note Melody) - The classic sung song melody (C4->E4->G4->A4).', ...
                            'FontColor', [0.75, 0.85, 0.95], 'FontSize', 9, 'WordWrap', 'on');

    % SECTION 2: DSP Parameters (Scale Grid & Room Size Field)
    uipanel(ctrl_panel, 'Position', [10, 320, 345, 160], ...
            'BackgroundColor', [0.20, 0.23, 0.29], ...
            'ForegroundColor', [0.85, 0.85, 0.85], ...
            'Title', '2. DSP Parameters & Room Acoustics', 'FontSize', 10, 'FontWeight', 'bold');

    % Auto-Tune Scale Selection
    uilabel(ctrl_panel, 'Position', [18, 428, 110, 22], ...
            'Text', 'Auto-Tune Grid:', 'FontColor', [0.85, 0.85, 0.85], 'FontSize', 10);

    drop_scale = uidropdown(ctrl_panel, 'Position', [125, 428, 220, 24], ...
                            'Items', {'Pentatonic (Distant ~40-85Hz)', ...
                                      'Major Triad (Widest ~70-130Hz)', ...
                                      'C Major Scale', ...
                                      'Chromatic (All 12 Semitones)'}, ...
                            'Value', 'Pentatonic (Distant ~40-85Hz)', ...
                            'BackgroundColor', [0.28, 0.31, 0.38], 'FontColor', 'w');

    % Room Size Input Field
    uilabel(ctrl_panel, 'Position', [18, 395, 115, 22], ...
            'Text', 'Room Size (m):', 'FontColor', [0.85, 0.85, 0.85], 'FontSize', 10, 'FontWeight', 'bold');

    num_room_size = uieditfield(ctrl_panel, 'numeric', 'Position', [125, 395, 75, 24], ...
                                'Value', 25.0, 'Limits', [2.0, 100.0], ...
                                'RoundFractionalValues', 'off', ...
                                'BackgroundColor', [0.28, 0.31, 0.38], 'FontColor', 'w', ...
                                'ValueChangedFcn', @on_room_size_change);

    lbl_acoustic_info = uilabel(ctrl_panel, 'Position', [205, 393, 140, 26], ...
                               'Text', 'Delay: 145.8 ms', ...
                               'FontColor', [0.35, 0.85, 0.65], 'FontSize', 10, 'FontWeight', 'bold');

    lbl_physics_eq = uilabel(ctrl_panel, 'Position', [18, 368, 327, 22], ...
                             'Text', 'Acoustic equation: Delay tau = (2 * RoomSize) / 343 m/s', ...
                             'FontColor', [0.65, 0.70, 0.75], 'FontSize', 8);

    btn_process = uibutton(ctrl_panel, 'push', 'Position', [18, 328, 327, 36], ...
                           'Text', '⚡ PROCESS ALL DSP STAGES', ...
                           'BackgroundColor', [0.88, 0.45, 0.10], ...
                           'FontColor', 'w', 'FontWeight', 'bold', 'FontSize', 11, ...
                           'ButtonPushedFcn', @on_process);

    % SECTION 3: Playback Controls for Every Stage
    play_panel = uipanel(ctrl_panel, 'Position', [10, 42, 345, 272], ...
                         'BackgroundColor', [0.20, 0.23, 0.29], ...
                         'ForegroundColor', [0.85, 0.85, 0.85], ...
                         'Title', '3. Stage-by-Stage Audio Playback', 'FontSize', 10, 'FontWeight', 'bold');

    btn_play_raw = uibutton(play_panel, 'push', 'Position', [15, 212, 315, 28], ...
                           'Text', '▶  Play Raw Input Audio', ...
                           'BackgroundColor', [0.35, 0.38, 0.45], 'FontColor', 'w', ...
                           'ButtonPushedFcn', @(~,~) play_stage('raw'));

    btn_play_tune = uibutton(play_panel, 'push', 'Position', [15, 178, 315, 28], ...
                            'Text', '▶  Stage 1: Auto-Tuned Vocals', ...
                            'BackgroundColor', [0.18, 0.48, 0.72], 'FontColor', 'w', ...
                            'ButtonPushedFcn', @(~,~) play_stage('tuned'));

    btn_play_echo = uibutton(play_panel, 'push', 'Position', [15, 144, 315, 28], ...
                            'Text', '▶  Stage 2: Digital Echo', ...
                            'BackgroundColor', [0.65, 0.35, 0.18], 'FontColor', 'w', ...
                            'ButtonPushedFcn', @(~,~) play_stage('echo'));

    btn_play_reverb = uibutton(play_panel, 'push', 'Position', [15, 110, 315, 28], ...
                              'Text', '▶  Stage 3: Schroeder Reverb', ...
                              'BackgroundColor', [0.55, 0.25, 0.55], 'FontColor', 'w', ...
                              'ButtonPushedFcn', @(~,~) play_stage('reverb'));

    btn_play_denoise = uibutton(play_panel, 'push', 'Position', [15, 76, 315, 28], ...
                               'Text', '▶  Stage 4: Spectral Denoised Audio', ...
                               'BackgroundColor', [0.20, 0.55, 0.40], 'FontColor', 'w', ...
                               'ButtonPushedFcn', @(~,~) play_stage('denoised'));

    btn_play_master = uibutton(play_panel, 'push', 'Position', [15, 40, 315, 30], ...
                              'Text', '🌟  Stage 5: FINAL STUDIO MASTER', ...
                              'BackgroundColor', [0.75, 0.55, 0.10], 'FontColor', 'w', 'FontWeight', 'bold', ...
                              'ButtonPushedFcn', @(~,~) play_stage('master'));

    btn_stop = uibutton(play_panel, 'push', 'Position', [15, 6, 315, 28], ...
                       'Text', '⏹  STOP AUDIO PLAYBACK', ...
                       'BackgroundColor', [0.75, 0.20, 0.20], 'FontColor', 'w', 'FontWeight', 'bold', ...
                       'ButtonPushedFcn', @(~,~) stop_audio());

    % Status Bar
    lbl_status = uilabel(ctrl_panel, 'Position', [10, 8, 345, 26], ...
                         'Text', 'Status: Ready. Click "PROCESS ALL DSP STAGES".', ...
                         'FontColor', [0.95, 0.85, 0.35], 'FontSize', 10, 'FontWeight', 'bold');

    % ---------------------------------------------------------------------
    % Right Panel: Tabbed Interactive DSP Visualizations
    % ---------------------------------------------------------------------
    tab_group = uitabgroup(fig, 'Position', [390, 12, 835, 745]);

    % TAB 1: Auto-Tune Pitch Tracking
    tab_tune = uitab(tab_group, 'Title', 'Auto-Tune & Pitch Tracking');
    ax_pitch = uiaxes(tab_tune, 'Position', [50, 375, 755, 325], ...
                      'Color', [0.16, 0.18, 0.23], 'XColor', 'w', 'YColor', 'w');
    title(ax_pitch, 'Dynamic Pitch Tracking (Raw Input vs Quantized Reference Notes)', 'Color', 'w');
    xlabel(ax_pitch, 'Time (seconds)', 'Color', 'w');
    ylabel(ax_pitch, 'Frequency f0 (Hz)', 'Color', 'w');
    grid(ax_pitch, 'on');

    ax_wave = uiaxes(tab_tune, 'Position', [50, 45, 755, 285], ...
                     'Color', [0.16, 0.18, 0.23], 'XColor', 'w', 'YColor', 'w');
    title(ax_wave, 'Time-Domain Waveforms: Raw Input vs Auto-Tuned Audio', 'Color', 'w');
    xlabel(ax_wave, 'Time (seconds)', 'Color', 'w');
    ylabel(ax_wave, 'Amplitude', 'Color', 'w');
    grid(ax_wave, 'on');

    % TAB 2: Spectral Denoising & Residual Noise Analysis
    tab_denoise = uitab(tab_group, 'Title', 'Spectral Denoising');
    ax_psd = uiaxes(tab_denoise, 'Position', [50, 375, 755, 325], ...
                    'Color', [0.16, 0.18, 0.23], 'XColor', 'w', 'YColor', 'w');
    title(ax_psd, 'STFT Spectral Subtraction: Power Spectral Density (PSD) Comparison', 'Color', 'w');
    xlabel(ax_psd, 'Frequency (Hz)', 'Color', 'w');
    ylabel(ax_psd, 'Power / Frequency (dB/Hz)', 'Color', 'w');
    grid(ax_psd, 'on');

    ax_residual = uiaxes(tab_denoise, 'Position', [50, 45, 755, 285], ...
                         'Color', [0.16, 0.18, 0.23], 'XColor', 'w', 'YColor', 'w');
    title(ax_residual, 'Time-Domain Noise Residual Analysis (Noisy Input vs Clean vs Removed Noise Floor)', 'Color', 'w');
    xlabel(ax_residual, 'Time (seconds)', 'Color', 'w');
    ylabel(ax_residual, 'Amplitude', 'Color', 'w');
    grid(ax_residual, 'on');

    % TAB 3: Echo & Schroeder Reverb
    tab_acoustics = uitab(tab_group, 'Title', 'Echo & Schroeder Reverb');
    ax_spatial = uiaxes(tab_acoustics, 'Position', [50, 375, 755, 325], ...
                        'Color', [0.16, 0.18, 0.23], 'XColor', 'w', 'YColor', 'w');
    title(ax_spatial, 'Time-Domain Comparison: Dry Input vs Room Echo vs Schroeder Reverb', 'Color', 'w');
    xlabel(ax_spatial, 'Time (seconds)', 'Color', 'w');
    ylabel(ax_spatial, 'Amplitude', 'Color', 'w');
    grid(ax_spatial, 'on');

    ax_impulse = uiaxes(tab_acoustics, 'Position', [50, 45, 755, 285], ...
                        'Color', [0.16, 0.18, 0.23], 'XColor', 'w', 'YColor', 'w');
    title(ax_impulse, 'Room Impulse Response h[n] (Acoustic Decay Profile)', 'Color', 'w');
    xlabel(ax_impulse, 'Time (seconds)', 'Color', 'w');
    ylabel(ax_impulse, 'Impulse Response Amplitude', 'Color', 'w');
    grid(ax_impulse, 'on');

    % Initialize by loading the Original Melody on startup
    load_test('melody');

    % =====================================================================
    % CALLBACK FUNCTIONS
    % =====================================================================

    % 1. Room Size Input Changed
    function on_room_size_change(~, ~)
        val = num_room_size.Value;
        if isnan(val) || val < 2.0
            val = 2.0;
            num_room_size.Value = val;
        end
        app_data.room_size_m = val;
        % Calculate physical delay: tau = 2L / 343
        tau_ms = (2.0 * val / 343.0) * 1000.0;
        lbl_acoustic_info.Text = sprintf('Delay: %.1f ms', tau_ms);
        lbl_status.Text = sprintf('Status: Room size set to %.1f m (Delay: %.1f ms). Click PROCESS.', val, tau_ms);
    end

    % 2. Load Predefined Dedicated Test Audios
    function load_test(type)
        stop_audio();
        lbl_status.Text = sprintf('Status: Loading test "%s" ...', type);
        drawnow;

        switch lower(type)
            case {'melody', 'original_melody', '4'}
                fn = 'test_original_melody.wav';
                desc = 'Test 1 (Original Melody): The first 4-note sung song phrase (C4->E4->G4->A4) with natural vocal formants & vibrato.';
            case {'glide', '1'}
                fn = 'test_1_vocal_glide.wav';
                desc = 'Test 2 (Vocal Glide): Gliding pitch with vibrato. Demonstrates Stairstep Auto-Tune quantization.';
            case {'staccato', '2'}
                fn = 'test_2_vocal_staccato.wav';
                desc = 'Test 3 (Vocal Staccato): Vowel bursts + silence gaps. Compares Echo (repeats) vs Reverb (hall decay).';
            case {'percussive', '3'}
                fn = 'test_3_percussive_melody.wav';
                desc = 'Test 4 (Pluck Melody): Sharp acoustic attack plucks. Demonstrates delay taps vs room wash.';
        end

        if ~exist(fn, 'file')
            [x_gen, fs_gen] = generate_test_audio(type, fn);
        else
            [x_gen, fs_gen] = audioread(fn);
        end

        if size(x_gen, 2) > 1, x_gen = mean(x_gen, 2); end
        app_data.fs = fs_gen;
        app_data.x_raw = (x_gen(:) / max(abs(x_gen(:)))) * 0.90;
        app_data.filename = fn;

        lbl_file_info.Text = sprintf('Loaded: %s (%.2f s)', desc, length(app_data.x_raw)/app_data.fs);
        lbl_status.Text = 'Status: Audio loaded. Click "PROCESS ALL DSP STAGES".';
    end

    % 3. Upload Custom User Audio File
    function on_upload(~, ~)
        [filename, pathname] = uigetfile({'*.wav', 'Audio WAV Files (*.wav)'}, 'Select Audio File');
        if isequal(filename, 0), return; end
        full_path = fullfile(pathname, filename);
        try
            stop_audio();
            [x, fs_in] = audioread(full_path);
            if size(x, 2) > 1, x = mean(x, 2); end
            app_data.fs = fs_in;
            app_data.x_raw = (x(:) / max(abs(x(:)))) * 0.90;
            app_data.filename = filename;
            
            lbl_file_info.Text = sprintf('Loaded Custom File: "%s" (%.2f s, %d Hz).', ...
                                         filename, length(app_data.x_raw)/app_data.fs, app_data.fs);
            lbl_status.Text = 'Status: Custom audio loaded. Click "PROCESS ALL DSP STAGES".';
        catch ME
            uialert(fig, ['Could not load audio file: ', ME.message], 'File Read Error');
        end
    end

    % 4. Process DSP Pipeline Callback
    function on_process(~, ~)
        if isempty(app_data.x_raw)
            uialert(fig, 'Please select or upload an audio file first!', 'No Audio');
            return;
        end

        stop_audio();
        lbl_status.Text = 'Status: Processing DSP stages (Auto-Tune, Room Echo, Reverb, EQ)...';
        drawnow;

        fs = app_data.fs;
        x = app_data.x_raw;
        room_meters = num_room_size.Value;
        app_data.room_size_m = room_meters;

        % Parse scale mode from dropdown
        selected_scale = drop_scale.Value;
        if contains(selected_scale, 'Major Triad')
            scale_mode = 'major_triad';
        elseif contains(selected_scale, 'Pentatonic')
            scale_mode = 'pentatonic';
        elseif contains(selected_scale, 'C Major')
            scale_mode = 'c_major';
        else
            scale_mode = 'chromatic';
        end

        % Stage 1: Auto-Tune with selected wide reference grid
        [app_data.y_tuned, app_data.t_pitch, app_data.f0_raw, app_data.f0_tuned] = ...
            autotune(x, fs, scale_mode, 0.95);

        % Stage 2: Digital Echo using physical Room Size in METERS
        [app_data.y_echo, ~, actual_delay_sec, D_echo] = delay_echo(x, fs, room_meters, [], 0.45);
        
        % Stage 3: Schroeder Reverb scaled to room size
        [app_data.y_reverb, app_data.h_reverb, actual_T60] = schroeder_reverb(x, fs, room_meters, 0.40);

        % Stage 4: Spectral Denoising (STFT Spectral Subtraction)
        [app_data.y_denoised, app_data.psd_noisy, app_data.psd_clean, app_data.f_axis] = ...
            spectral_denoise(x, fs, 2.0, 0.02);

        % Stage 5: Chained Master Pipeline
        % Signal flow: Raw Noisy -> Spectral Denoise -> Auto-Tune -> Room Echo -> Schroeder Reverb
        m_clean = spectral_denoise(x, fs, 2.0, 0.02);
        m_tuned = autotune(m_clean, fs, scale_mode, 0.92);
        m_echo = delay_echo(m_tuned, fs, room_meters, [], 0.25);
        m_final = schroeder_reverb(m_echo, fs, room_meters, 0.25);
        app_data.y_master = (m_final / max(abs(m_final))) * 0.95;

        % Update all visual plots inside the GUI
        update_plots(actual_delay_sec, actual_T60, room_meters);

        lbl_status.Text = sprintf('Status: Processed for %.1f m Room (Delay: %.1f ms, T60: %.2f s)! Play below.', ...
                                  room_meters, actual_delay_sec * 1000, actual_T60);
    end

    % 5. Audio Playback Router
    function play_stage(stage)
        stop_audio();
        target_signal = [];
        stage_name = '';

        switch lower(stage)
            case 'raw'
                target_signal = app_data.x_raw;
                stage_name = 'Raw Input Audio';
            case 'tuned'
                target_signal = app_data.y_tuned;
                stage_name = 'Stage 1: Auto-Tuned Vocals';
            case 'echo'
                target_signal = app_data.y_echo;
                stage_name = sprintf('Stage 2: Digital Echo (Room: %.1f m, Delay: %.1f ms)', ...
                                     app_data.room_size_m, (2 * app_data.room_size_m / 343) * 1000);
            case 'reverb'
                target_signal = app_data.y_reverb;
                stage_name = sprintf('Stage 3: Schroeder Reverb (Room: %.1f m)', app_data.room_size_m);
            case 'denoised'
                target_signal = app_data.y_denoised;
                stage_name = 'Stage 4: Spectral Denoised Audio';
            case 'master'
                target_signal = app_data.y_master;
                stage_name = 'Stage 5: Final Studio Master (Chained)';
        end

        if isempty(target_signal)
            uialert(fig, 'Please click "PROCESS ALL DSP STAGES" before playing!', 'Not Processed');
            return;
        end

        lbl_status.Text = ['▶ Playing: ', stage_name];
        drawnow;
        
        try
            app_data.player = audioplayer(target_signal, app_data.fs);
            play(app_data.player);
        catch ME
            sound(target_signal, app_data.fs);
        end
    end

    % 6. Stop Audio Playback
    function stop_audio()
        if ~isempty(app_data.player) && isplaying(app_data.player)
            stop(app_data.player);
        end
        clear sound;
        lbl_status.Text = 'Status: Playback stopped.';
    end

    % 7. Render All Embedded Plots inside GUI Axes
    function update_plots(delay_sec, T60, room_m)
        if nargin < 1, delay_sec = (2 * app_data.room_size_m) / 343; end
        if nargin < 2, T60 = 1.8; end
        if nargin < 3, room_m = app_data.room_size_m; end

        fs = app_data.fs;
        t_audio = (0:length(app_data.x_raw) - 1) / fs;

        % -------------------------------------------------------------
        % TAB 1: Auto-Tune Pitch Tracking & Waveform
        % -------------------------------------------------------------
        cla(ax_pitch);
        hold(ax_pitch, 'on');
        plot(ax_pitch, app_data.t_pitch, app_data.f0_raw, 'r.', 'MarkerSize', 10);
        plot(ax_pitch, app_data.t_pitch, app_data.f0_tuned, 'b-', 'LineWidth', 2.2);
        
        y_vals = app_data.f0_tuned(~isnan(app_data.f0_tuned));
        if ~isempty(y_vals)
            unique_notes = unique(round(y_vals));
            for u = 1:length(unique_notes)
                yline(ax_pitch, unique_notes(u), 'k--', sprintf('%.1f Hz', unique_notes(u)), ...
                      'Alpha', 0.5, 'Color', [0.8 0.8 0.8]);
            end
            y_min = max(80, min(y_vals) - 50);
            y_max = max(y_vals) + 50;
            ylim(ax_pitch, [y_min, y_max]);
        end
        hold(ax_pitch, 'off');
        legend(ax_pitch, 'Raw Pitch (Continuous/Wobbly)', 'Tuned Pitch (Quantized)', ...
               'Location', 'northwest', 'TextColor', 'w');

        cla(ax_wave);
        hold(ax_wave, 'on');
        plot(ax_wave, t_audio, app_data.x_raw, 'Color', [0.6 0.6 0.6]);
        plot(ax_wave, t_audio, app_data.y_tuned, 'Color', [0.2 0.6 1.0], 'LineWidth', 1.1);
        hold(ax_wave, 'off');
        legend(ax_wave, 'Raw Input', 'Auto-Tuned', 'Location', 'northeast', 'TextColor', 'w');
        xlim(ax_wave, [0, min(4.5, max(t_audio))]);

        % -------------------------------------------------------------
        % TAB 2: Spectral Denoising (PSD & Noise Residual Analysis)
        % -------------------------------------------------------------
        cla(ax_psd);
        hold(ax_psd, 'on');
        plot(ax_psd, app_data.f_axis, app_data.psd_noisy, 'r-', 'LineWidth', 1.1);
        plot(ax_psd, app_data.f_axis, app_data.psd_clean, 'g-', 'LineWidth', 1.4);
        hold(ax_psd, 'off');
        legend(ax_psd, 'Noisy Input PSD', 'Cleaned Output PSD', 'Location', 'northeast', 'TextColor', 'w');
        xlim(ax_psd, [0, 12000]);

        cla(ax_residual);
        hold(ax_residual, 'on');
        len_cmp = min(length(app_data.x_raw), length(app_data.y_denoised));
        t_cmp = (0:len_cmp - 1) / fs;
        noise_residual = app_data.x_raw(1:len_cmp) - app_data.y_denoised(1:len_cmp);
        plot(ax_residual, t_cmp, app_data.x_raw(1:len_cmp), 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);
        plot(ax_residual, t_cmp, app_data.y_denoised(1:len_cmp), 'Color', [0.2 0.75 0.5], 'LineWidth', 1.1);
        plot(ax_residual, t_cmp, noise_residual, 'Color', [0.9 0.35 0.35], 'LineWidth', 0.9);
        hold(ax_residual, 'off');
        legend(ax_residual, 'Raw Noisy Input x[n]', 'Denoised Signal y[n]', 'Suppressed Noise Residual e[n]', ...
               'Location', 'northeast', 'TextColor', 'w');
        xlim(ax_residual, [0, min(4.5, max(t_cmp))]);

        % -------------------------------------------------------------
        % TAB 3: Echo & Schroeder Reverb (Showing Room Size Physics)
        % -------------------------------------------------------------
        cla(ax_spatial);
        hold(ax_spatial, 'on');
        plot(ax_spatial, t_audio, app_data.x_raw, 'Color', [0.6 0.6 0.6]);
        plot(ax_spatial, t_audio, app_data.y_echo, 'Color', [0.9 0.45 0.1], 'LineWidth', 1.1);
        plot(ax_spatial, t_audio, app_data.y_reverb, 'Color', [0.8 0.3 0.8], 'LineWidth', 1.1);
        hold(ax_spatial, 'off');
        title(ax_spatial, sprintf('Acoustics for Room Size = %.1f m (Echo Delay = %.1f ms | Reverb T60 = %.2f s)', ...
                                  room_m, delay_sec * 1000, T60), 'Color', 'w');
        legend(ax_spatial, 'Dry Input', ...
               sprintf('Echo (tau = 2L/c = %.1f ms)', delay_sec * 1000), ...
               sprintf('Schroeder Reverb (T60 = %.2f s)', T60), ...
               'Location', 'northeast', 'TextColor', 'w');

        cla(ax_impulse);
        t_h = (0:length(app_data.h_reverb) - 1) / fs;
        plot(ax_impulse, t_h, app_data.h_reverb, 'Color', [0.3 0.7 0.9], 'LineWidth', 1.0);
        title(ax_impulse, sprintf('Room Impulse Response h[n] (Exponential Decay T60 = %.2f s)', T60), 'Color', 'w');
        xlim(ax_impulse, [0, min(1.5, max(t_h))]);
    end
end
