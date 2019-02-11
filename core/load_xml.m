function doc_node = load_xml(ip_file)

% Inputs:
%   ip_file: The filename including path of the gifti. Called by load_gifti.m 

%  Outputs:
%     doc_node: a Saxon XML node

% Martin Guthrie 2017

% Version history
% Martin Guthrie      v1.0       2018-02-05

%%

%     For some reason xmlread sometimes throws a
%     java.net.UnknownHostException. So try to load the file several times
%     before giving up
    i_try_count = 1;
    total_try_count = 5;
    b_success = false;
    while ~b_success && (i_try_count < total_try_count)
        try
            doc_node = xmlread(ip_file);
            b_success = true;
        catch ME
            fprintf('Failed to open %s: Try %d\n%s\n', ip_file, i_try_count, ME.message);
            i_try_count = i_try_count + 1;
            % Wait for a short time. Try 10ms first then ramp up with each
            % fail
            wait_time = 0.01 * i_try_count;
            pause(wait_time);
        end
    end

    if ~b_success
        error('Unable to open gifti file after %d tries\n', i_try_count);
    end
end
