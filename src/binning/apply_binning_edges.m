function bin_matrix = apply_binning_edges(db_matrix, bin_edges, n_bins)
%APPLY_BINNING_EDGES Применяет заранее рассчитанные границы бинов к матрице dB.

[n_freqs, ~] = size(db_matrix);
bin_value_class = select_bin_value_class(n_bins);
bin_matrix = zeros(size(db_matrix), bin_value_class);

if numel(bin_edges) ~= n_freqs
    error('Число наборов границ бинов не совпадает с числом частотных строк');
end

for fi = 1:n_freqs
    row = db_matrix(fi, :);
    edges = bin_edges{fi};
    [~, idx] = histc(row, edges); %#ok<HISTC>
    idx = idx - 1;
    idx = min(max(idx, 0), n_bins - 1);
    bin_matrix(fi, :) = cast(idx, bin_value_class);
end
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
