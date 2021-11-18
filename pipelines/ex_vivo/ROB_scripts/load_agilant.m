clc; clear all; close all;

% load data

filename =''; %file name /home/user/vnmrsys/data/gems_01.fid/
fidfile = [filename 'fid'];
procparfile = [filename 'procpar'];

procpar = readprocpar(procparfile);
[npoints,nblocks,ntraces,bitdepth] = load_fid_hdr(fidfile);
npoints = npoints/2; % Due to complex data
pan_ang = procpar.nv;
pan_rot = procpar.nv2;
data_buffer = load_fid(fidfile,nblocks,ntraces,2*npoints,bitdepth,1,[npoints pan_ang pan_rot nblocks]);
