function [u,s,v]=ss_svds(x,n)
% Steve Smith's Singular Value Decomposition
% [u,s,v] = ss_svds(x,n) performs a singular value decomposition of matrix
% x with n components, such that x = u*s*v'.
%
%--------------------------------------------------------------------------
%
% version history
% 2018-04-15    Lennart added to MrCat and documented
% pre-history   Steve Smith (c)
%
%--------------------------------------------------------------------------

% switch decomposition depending on matrix orientation n x m or m x n
if size(x,1) < size(x,2)
  
  % switch depending on number of desired components
  % decompose covariance of x in u (eigenvectors) and d (eigenvalues)
  if n < size(x,1)
    [u,d] = eigs(x*x',n);
  else
    [u,d] = eig(x*x');
    u = fliplr(u);
    d = rot90(d,2); % rotate 180 degrees
  end
  % retrieve singular values and right vectors (v)
  s = sqrt(abs(d));
  v = x' * (u * diag((1./diag(s))));
  
else
  
  % switch depending on number of desired components
  % decompose covariance of x in v (eigenvectors) and d (eigenvalues)
  if n < size(x,2)
    [v,d] = eigs(x'*x,n);
  else
    [v,d] = eig(x'*x);
    v = fliplr(v);
    d = rot90(d,2); % rotate 180 degrees
  end
  % retrieve singular values and left vectors (u)
  s = sqrt(abs(d));
  u = x * (v * diag((1./diag(s))));
  
end

