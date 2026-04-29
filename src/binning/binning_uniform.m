function [bin_matrix, bin_edges, binning_meta] = binning_uniform(db_matrix, n_bins)
%BINNING_UNIFORM Равномерный биннинг по каждой частотной строке отдельно.
% Политика границ: для каждой строки спектрограммы берется собственный min/max.

[n_freqs, ~] = size(db_matrix);
bin_matrix = zeros(size(db_matrix), 'int32');
bin_edges = cell(n_freqs, 1);

for fi = 1:n_freqs
    row = db_matrix(fi, :);
    mn = min(row);
    mx = max(row);

    if mx <= mn
        edges = [-inf, inf];
    else
        edges = linspace(mn, mx, n_bins + 1);
        edges(1) = edges(1) - 1e-10;
        edges(end) = edges(end) + 1e-10;
    end

    [~, idx] = histc(row, edges); %#ok<HISTC>
    idx = int32(idx) - 1;
    idx = min(max(idx, 0), int32(n_bins - 1));

    bin_matrix(fi, :) = idx;
    bin_edges{fi} = edges;
end

binning_meta = struct();
binning_meta.type = 'uniform';
binning_meta.n_bins = n_bins;
binning_meta.index_base = 'zero';
binning_meta.edge_scope = 'per_frequency_row_minmax';
end
