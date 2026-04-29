function stats = compute_profile_ci(samples, ci_level)
%COMPUTE_PROFILE_CI Вычисляет среднее и доверительный интервал по профилям.

if nargin < 2 || isempty(ci_level)
    ci_level = 0.95;
end

if isempty(samples)
    error('samples не должен быть пустым');
end

if isvector(samples)
    samples = samples(:).';
end

n = size(samples, 1);
mean_profile = mean(samples, 1);

if n <= 1
    sample_std = zeros(1, size(samples, 2));
    ci_half_width = zeros(1, size(samples, 2));
else
    sample_std = std(samples, 0, 1);
    alpha = 1 - ci_level;
    t_crit = tinv(1 - alpha / 2, n - 1);
    ci_half_width = t_crit .* sample_std ./ sqrt(n);
end

stats = struct();
stats.mean_profile = mean_profile;
stats.sample_std = sample_std;
stats.ci_half_width = ci_half_width;
stats.ci_lower = mean_profile - ci_half_width;
stats.ci_upper = mean_profile + ci_half_width;
stats.n_samples = n;
stats.ci_level = ci_level;
end
