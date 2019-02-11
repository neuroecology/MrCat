function [L, merged] = islander_colonize(L, T, currentL, u, propConnected)
%
% Part of MrCat implementation of Thomas Gladwin's islander. This file copied and
% modified from his original colonize.m
%
% u will be colonized by currentL
%
% Check whether edge is a true valley separating the blobs.

L0 = L;
merged = 0;

fCurrent = find(L == currentL);
[ixC, iyC, izC] = ind2sub(size(T), fCurrent);

for iu = 1:length(u),
    if currentL == u(iu),
        continue;
    end;
    fOther = find(L == u(iu));
    [ixO, iyO, izO] = ind2sub(size(T), fOther);
    
    % Code voxels as blob-connecting edges or not
    memory = [];
    edgeConnectVals = [];
    edgeElsewhereVals = [];
    for ind00 = 1:length(fOther),
        ind0 = fOther(ind00);
        [x0, y0, z0] = ind2sub(size(L0), ind0);
        for dz = -1:1,
            zz = z0 + dz; if zz < 1 || zz > size(L0, 3), continue; end;
            for dy = -1:1;
                yy = y0 + dy; if yy < 1 || yy > size(L0, 2), continue; end;
                for dx = -1:1,
                    xx = x0 + dx; if xx < 1 || xx > size(L0, 1), continue; end;                    
                    if ~isempty(memory),
                        tester = abs(memory - [xx; yy; zz] * ones(1, size(memory, 2)));
                        tester = sum(tester);
                        ftester = find(tester == 0);
                        if length(ftester) > 0,
                            continue;
                        end;
                    end;
                    v1 = L0(xx, yy, zz);
                    if v1 == u(iu),
                        continue;
                    else,
                        if v1 == currentL,
                            edgeConnectVals = [edgeConnectVals; T(ind0)];
                        else,
                            edgeElsewhereVals = [edgeElsewhereVals; T(ind0)];
                        end;
                        memory = [memory [xx; yy; zz]];
                    end;
                end;
            end;
        end;
    end;    
    
    valConnect = mean(edgeConnectVals);
    valNonconnect = mean(edgeElsewhereVals);
    valPeakCurrent = max(T(fCurrent));
    valPeakOther = max(T(fOther));
    dPeakToPeak = abs(valPeakCurrent - valPeakOther);
    dEdgeToPeakCurrent = abs(valPeakCurrent - valConnect);
    dEdgeToPeakOther = abs(valPeakOther - valConnect);
    dNonEdgeToPeakOther = abs(valPeakOther - valNonconnect);
    
    val0 = dPeakToPeak / (dPeakToPeak + dEdgeToPeakOther);
    crit0 = 1 - propConnected;

%     if (valConnect / valNonconnect) >= 1 - propConnected, % log(propConnected) / log(0.5),
%     if (dNonEdgeToPeakOther / dEdgeToPeakOther) >= log(propConnected) / log(0.5),
%     if dPeakToPeak / dEdgeToPeakOther >= log(propConnected) / log(0.5),
    if val0 >= crit0,
%     if (valConnect / valNonconnect) * (dPeakToPeak / dEdgeToPeakCurrent) >= (log(propConnected)/log(0.5)) ^ 2,
%     if max(valConnect / valNonconnect, dPeakToPeak / dEdgeToPeakCurrent) >= 1 - propConnected, % log(propConnected) / log(0.1), % propConnected,
        L0(fOther) = currentL;
        merged = 1;
    end;
end;
L = L0;

function [d, v, COM, Centre] = inner_dist_val(f, T)
% [max0, ind0] = max(T(f));
% [ix0, iy0, iz0] = ind2sub(size(T), ind0);
% COM
[ixv, iyv, izv] = ind2sub(size(T), f);
ixCOM = ixv(:) .* T(f(:)) ./ sum(T(f(:)));
iyCOM = iyv(:) .* T(f(:)) ./ sum(T(f(:)));
izCOM = iyv(:) .* T(f(:)) ./ sum(T(f(:)));
ix0 = sum(ixCOM);
iy0 = sum(iyCOM);
iz0 = sum(izCOM);
COM = [ix0, iy0, iz0];
Centre = [mean(ixv), mean(iyv), mean(izv)];

d = [];
v = [];
for iV = 1:length(f),
    [ix, iy, iz] = ind2sub(size(T), f(iV));
    dist0 = sqrt((ix - ix0)^2 + (iy - iy0)^2 + (iz - iz0)^2);
    d = [d; dist0];
    v = [v; T(f(iV))];
end;
d = (d - min(d));
if max(d) > 0,
    d = d ./ max(d);
end;
