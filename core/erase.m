function s = erase(str, match)
%ERASE Remove content from text
%   NEWSTR = ERASE(STR,MATCH) removes occurrences of MATCH from STR. If
%   STR contains multiple occurrences of MATCH, then ERASE removes all
%   occurrences that do not overlap.
%
%   STR can be a string array, a character vector, or a cell array of
%   character vectors. So can MATCH. MATCH and STR need not be the same
%   size. If MATCH is a string array or cell array, then ERASE removes each
%   occurrence of all the elements of MATCH from STR.
%
%   Examples:
%       STR = "The quick brown fox";
%       erase(STR,"quick")
%
%       returns:
%
%           "The  brown fox"
%
%       STR = 'Hello World';
%       erase(STR,'Hello ')
%
%       returns:
%
%           'World'
%
%   See also STRREP, REGEXPREP, REPLACE, ERASEBETWEEN

%   Copyright 2016-2017 The MathWorks, Inc.

    narginchk(2, 2);
    
    if ~isTextStrict(str)
        firstInput = getString(message('MATLAB:string:FirstInput'));
        error(message('MATLAB:string:MustBeCharCellArrayOrString', firstInput));
    end

    try
        s = string(str);
        s = s.erase(match);
        s = convertStringToOriginalTextType(s, str);
        
    catch E
        throw(E)
    end
end
