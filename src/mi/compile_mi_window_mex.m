function [ok, mex_path, message_text] = compile_mi_window_mex()
%COMPILE_MI_WINDOW_MEX Пытается собрать MEX-ядро расчета MI окна.

src_dir = fileparts(mfilename('fullpath'));
source_file = fullfile(src_dir, 'mex', 'mi_window_mex.cpp');
mex_name = 'mi_window_mex_v2';
mex_path = fullfile(src_dir, [mex_name, '.', mexext]);

ok = false;
message_text = "";

if ~isfile(source_file)
    message_text = "Не найден исходник MEX";
    return;
end

try
    clear(mex_name);
    if isfile(mex_path)
        delete(mex_path);
    end
    mex('-R2018a', '-output', mex_name, '-outdir', src_dir, source_file);
    ok = isfile(mex_path);
    if ok
        message_text = "MEX собран";
    else
        message_text = "mex завершился без ожидаемого бинарного файла";
    end
catch ME
    message_text = string(ME.message);
end
end
