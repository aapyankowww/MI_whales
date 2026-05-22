function [bin_matrix, bin_edges, binning_meta] = binning_quantile(db_matrix, n_bins)
%BINNING_QUANTILE Поквантильный биннинг по каждой частотной строке отдельно.

[n_freqs, ~] = size(db_matrix);
bin_value_class = select_bin_value_class(n_bins);
bin_matrix = zeros(size(db_matrix), bin_value_class);
bin_edges = cell(n_freqs, 1);
prc = linspace(0, 100, n_bins + 1);

for fi = 1:n_freqs
    row = db_matrix(fi, :);
    edges = prctile(row, prc);
    edges(1) = edges(1) - 1e-10;
    edges(end) = edges(end) + 1e-10;
    edges = unique(edges);

    if numel(edges) < 2
        edges = [-inf, inf];
    end

    [~, idx] = histc(row, edges); %#ok<HISTC>
    idx = idx - 1;
    idx = min(max(idx, 0), n_bins - 1);

    bin_matrix(fi, :) = cast(idx, bin_value_class);
    bin_edges{fi} = edges;
end

binning_meta = struct();
binning_meta.type = 'quantile';
binning_meta.n_bins = n_bins;
binning_meta.index_base = 'zero';
binning_meta.edge_scope = 'per_frequency_row';
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
