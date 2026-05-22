function [bin_matrix, bin_edges, binning_meta] = binning_uniform(db_matrix, n_bins)
%BINNING_UNIFORM Равномерный биннинг по каждой частотной строке отдельно.
% Политика границ: для каждой строки спектрограммы берется собственный min/max.

[n_freqs, ~] = size(db_matrix);
bin_value_class = select_bin_value_class(n_bins);
bin_matrix = zeros(size(db_matrix), bin_value_class);
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
    idx = idx - 1;
    idx = min(max(idx, 0), n_bins - 1);

    bin_matrix(fi, :) = cast(idx, bin_value_class);
    bin_edges{fi} = edges;
end

binning_meta = struct();
binning_meta.type = 'uniform';
binning_meta.n_bins = n_bins;
binning_meta.index_base = 'zero';
binning_meta.edge_scope = 'per_frequency_row_minmax';
binning_meta.bin_value_class = bin_value_class;
end

function bin_value_class = select_bin_value_class(n_bins)
if n_bins <= intmax('uint8')
    bin_value_class = 'uint8';
elseif n_bins <= intmax('uint16')
    bin_value_class = 'uint16';
else
    bin_value_class = 'uint32';
end
end
