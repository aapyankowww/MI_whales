function [mi_window, shift_stats, backend_used] = calc_window_mi_backend(bin_matrix, window_start_frame, mi_constants, perm_cache, backend_mode)
%CALC_WINDOW_MI_BACKEND Выбирает MATLAB или MEX backend для одного окна.

if nargin < 5 || strlength(string(backend_mode)) == 0
    backend_mode = "auto";
end

backend_mode = lower(string(backend_mode));

switch backend_mode
    case "matlab"
        [mi_window, shift_stats] = calc_window_mi_matlab( ...
            bin_matrix, window_start_frame, mi_constants, perm_cache);
        backend_used = "matlab";
    case "mex"
        [mi_window, shift_stats] = run_mex_backend( ...
            bin_matrix, window_start_frame, mi_constants, perm_cache);
        backend_used = "mex";
    case "auto"
        if exist('mi_window_mex_v2', 'file') == 3
            [mi_window, shift_stats] = run_mex_backend( ...
                bin_matrix, window_start_frame, mi_constants, perm_cache);
            backend_used = "mex";
        else
            [mi_window, shift_stats] = calc_window_mi_matlab( ...
                bin_matrix, window_start_frame, mi_constants, perm_cache);
            backend_used = "matlab";
        end
    otherwise
        error('Неподдерживаемый backend_mode: %s', string(backend_mode));
end
end

function [mi_window, shift_stats] = run_mex_backend(bin_matrix, window_start_frame, mi_constants, perm_cache)
[mi_window, shift_mean, shift_median, shift_std] = mi_window_mex_v2( ...
    bin_matrix, ...
    int32(window_start_frame), ...
    int32(mi_constants.window_dur_frames), ...
    int32(mi_constants.dt_frames_int32(:).'), ...
    int32(mi_constants.n_bins), ...
    mi_constants.phi_lut, ...
    int32(perm_cache.base_orders), ...
    int32(perm_cache.shifted_linear_idx));

if perm_cache.n_perms > 0
    shift_stats = struct( ...
        'count', perm_cache.n_perms, ...
        'mean', shift_mean, ...
        'median', shift_median, ...
        'std', shift_std);
else
    shift_stats = [];
end
end
