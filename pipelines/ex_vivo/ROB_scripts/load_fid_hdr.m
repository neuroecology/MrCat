function [npoints,nblocks,ntraces,bitdepth] = load_fid_hdr(fidpath)

try
    fid = fopen(fidpath,'r','ieee-be');
catch ME
    disp(ME)
end

% Read datafileheader
nblocks   = fread(fid,1,'int32');
ntraces   = fread(fid,1,'int32');
npoints   = fread(fid,1,'int32');
trash     = fread(fid,1,'int32');
trash     = fread(fid,1,'int32');
trash     = fread(fid,1,'int32');
trash     = fread(fid,1,'int16');
status    = fread(fid,1,'int16');

%get bitdepth
s_32      = bitget(status,3);
s_float   = bitget(status,4);

if s_32==1
    bitdepth='int32';
elseif s_float==1
    bitdepth='float32';
else
    bitdepth='int16';
end

fclose(fid);
