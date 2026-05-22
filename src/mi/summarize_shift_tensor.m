function shift_stats = summarize_shift_tensor(shift_tensor, perm_dim)
%SUMMARIZE_SHIFT_TENSOR Считает summary-статистики по permutation tensor.

if nargin < 2 || isempty(perm_dim)
    perm_dim = 3;
end

if isempty(shift_tensor)
    shift_stats = [];
    return;
end

shift_stats = struct();
shift_stats.count = size(shift_tensor, perm_dim);
shift_stats.mean = mean(shift_tensor, perm_dim);
shift_stats.median = median(shift_tensor, perm_dim);
shift_stats.std = std(shift_tensor, 0, perm_dim);
end
