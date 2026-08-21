%% ================================================================
%  Manual SNR + PSD (Welch) Analysis for Sensor Vibration Data
%  No use of snr(), pwelch(), periodogram(), or bandpower()
%  Only fft() is used as the core mathematical transform - everything
%  around it (windowing, segmenting, averaging, scaling) is hand-built.
% ================================================================

clear; clc; close all;
%% 1. Load Data (robust)
csvName = 'sensor_vibration_dataset.csv';

% Show current folder for debugging
fprintf('Current folder: %s\n', pwd);

if exist(csvName, 'file') ~= 2
    fprintf('File "%s" not found in current folder.\n', csvName);
    [file, path] = uigetfile({'*.csv','CSV files (*.csv)';'*.*','All files'}, ...
        'Select sensor_vibration_dataset.csv');
    if isequal(file,0)
        error('No file selected. Place "%s" in the current folder or select it.', csvName);
    end
    csvName = fullfile(path, file);
end

data = readtable(csvName);
x    = double(data.Raw_Accel_Z);
N    = length(x);
Fs   = 1000;              % Sampling frequency in Hz (update if different)
dt   = 1/Fs;
t    = (0:N-1)' * dt;


%% 2. Preprocessing
x_clean = x - mean(x);          % remove DC offset
% Optional: remove linear trend manually (comment out if not needed)
n_idx   = (0:N-1)';
p_slope = sum((n_idx - mean(n_idx)).*(x_clean - mean(x_clean))) / ...
          sum((n_idx - mean(n_idx)).^2);
p_int   = mean(x_clean) - p_slope*mean(n_idx);
x_clean = x_clean - (p_slope*n_idx + p_int);

%% =================================================================
%  3. SNR CALCULATION (manual, FFT-based, no snr())
% =================================================================
X_fft   = fft(x_clean);
half_N  = floor(N/2);
mag     = (2/N) * abs(X_fft(1:half_N));   % single-sided amplitude spectrum
power_spec = mag.^2;                       % power per bin (proportional)
f_axis  = (0:half_N-1)' * (Fs/N);

% Identify the dominant (signal) frequency peak, ignoring DC (bin 1)
search_range          = 2:half_N;         % skip DC bin
[~, rel_idx]           = max(power_spec(search_range));
peak_idx                = search_range(rel_idx);

% Include a small guard band around the peak (main-lobe leakage) as signal power
guard = 2;                                 % bins on each side of the peak
lo    = max(peak_idx - guard, 1);
hi    = min(peak_idx + guard, half_N);

signal_power = sum(power_spec(lo:hi));
total_power  = sum(power_spec);
noise_power  = total_power - signal_power;

snr_db = 10*log10(signal_power / noise_power);

fprintf('Dominant frequency        : %.2f Hz\n', f_axis(peak_idx));
fprintf('Signal power (peak+guard) : %.6g\n', signal_power);
fprintf('Noise power (remainder)   : %.6g\n', noise_power);
fprintf('Calculated SNR            : %.2f dB\n\n', snr_db);

%% =================================================================
%  4. PSD CALCULATION - Manual Welch's Method (no pwelch())
% =================================================================
seg_len   = 256;                 % window length (samples)
overlap   = 128;                 % overlap (samples)
step      = seg_len - overlap;   % hop size
nfft      = seg_len;
n_segs    = floor((N - overlap) / step);

% --- Manually build a Hamming window (no hamming() call) ---
M = seg_len;
win_n = (0:M-1)';
win   = 0.54 - 0.46*cos(2*pi*win_n/(M-1));
U     = sum(win.^2);             % window power (normalization constant)

half_nfft = nfft/2;              % nfft is even (256)
Pxx_accum = zeros(half_nfft+1, 1);

for k = 0:n_segs-1
    idx_start = k*step + 1;
    idx_end   = idx_start + seg_len - 1;
    if idx_end > N
        break;
    end
    seg   = x_clean(idx_start:idx_end);
    seg   = seg - mean(seg);        % de-mean each segment
    segw  = seg .* win;             % apply window

    Xk    = fft(segw, nfft);
    Xk    = Xk(1:half_nfft+1);      % one-sided

    Pk    = (abs(Xk).^2) / (Fs * U);   % PSD scaling (V^2/Hz)
    Pk(2:end-1) = 2*Pk(2:end-1);       % double all bins except DC & Nyquist

    Pxx_accum = Pxx_accum + Pk;
end

psd = Pxx_accum / n_segs;           % average over segments (Welch averaging)
f   = (0:half_nfft)' * (Fs/nfft);

%% 5. Plot PSD (log scale) to visualize noise character
figure;
semilogy(f, psd, 'r', 'LineWidth', 1.5);
grid on;
title('Power Spectral Density (PSD) - Manual Welch Method');
xlabel('Frequency (Hz)');
ylabel('Power/Frequency (V^2/Hz)');

%% =================================================================
%  6. NOISE TYPE IDENTIFICATION (manual log-log slope fit)
% =================================================================
% Exclude f = 0 (log undefined) and the dominant signal peak region,
% so the fit reflects the noise floor, not the tone itself.
valid = f > 0;
f_fit  = f(valid);
p_fit  = psd(valid);

% Remove the neighbourhood of the dominant peak found earlier (in Hz terms)
peak_freq = f_axis(peak_idx);
band_hz   = 3;   % Hz to exclude around the peak
mask      = abs(f_fit - peak_freq) > band_hz;
f_fit     = f_fit(mask);
p_fit     = p_fit(mask);

logf = log10(f_fit);
logp = log10(p_fit);

% Manual least-squares line fit: logp = slope*logf + intercept
mean_logf = mean(logf);
mean_logp = mean(logp);
slope     = sum((logf-mean_logf).*(logp-mean_logp)) / sum((logf-mean_logf).^2);
intercept = mean_logp - slope*mean_logf;

fprintf('Spectral slope (log-log)  : %.3f\n', slope);

if slope > -0.5
    noise_type = 'White noise (flat PSD, slope ~ 0)';
elseif slope <= -0.5 && slope > -1.5
    noise_type = 'Pink / Flicker noise (1/f, slope ~ -1)';
elseif slope <= -1.5 && slope > -2.5
    noise_type = 'Red / Brownian noise (1/f^2, slope ~ -2)';
else
    noise_type = 'Steeply colored noise (slope < -2.5, possibly 1/f^n, n>2)';
end

fprintf('Identified noise type      : %s\n', noise_type);

% Overlay the fitted trend line on the PSD plot for visual confirmation
hold on;
fit_line = 10.^(slope*log10(f(valid)) + intercept);
semilogy(f(valid), fit_line, 'b--', 'LineWidth', 1.2);
legend('Measured PSD', sprintf('Fitted slope = %.2f (%s)', slope, noise_type), ...
       'Location', 'best');
hold off;