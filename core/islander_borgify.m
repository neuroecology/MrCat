function L0 = islander_borgify(L0, T, param0)
%
% MrCat implementation of Thomas Gladwin's islander. This file copied and
% modified from his original borgify.m

u = unique(L0);
u(find(u == 0)) = [];

for iLabel = 1:length(u),
    label0 = u(1 + length(u) - iLabel);
%     label0 = u(iLabel);
    f = find(L0 == label0);
    adjacents = [];
    memory = [];
    for ind00 = 1:length(f),
        ind0 = f(ind00);
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
                    if v1 == label0,
                        continue;
                    end;
                    memory = [memory [xx; yy; zz]];
                    adjacents = [adjacents; v1];
                end;
            end;
        end;
    end;
    f0 = find(adjacents == 0);
    N = length(adjacents);
    propConnected = 1 - length(f0) / N;
    if propConnected > param0,
        adjacents(f0) = [];
        fHigher = find(adjacents > label0);
        if isempty(fHigher),
            continue;
        end;
        adjacents = adjacents(fHigher);
%         m0 = mode(adjacents);
        m0 = min(adjacents); % Cluster with highest peak
        [L0, merged0] = islander_colonize(L0, T, m0, label0, propConnected);
        if merged0 == 1,
%             fprintf('Borged and colonized\n');
        else,
%             fprintf('Borged only\n');
        end;
    end;
end;
