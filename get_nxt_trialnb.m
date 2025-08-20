function [next_idx] = get_nxt_trialnb(pathname)

lf = dir(pathname);
max_idx = -1;
file_name_st = '';
for i = 1:size(lf)
   file_name_st = lf(i).name;
   if(isempty(strfind(file_name_st,'.bin')) == 0)
       if str2num(file_name_st(end-6:end-4)) > max_idx
            max_idx = str2num(file_name_st(end-6:end-4));
       end
   end
end
        next_idx = max_idx + 1;
end