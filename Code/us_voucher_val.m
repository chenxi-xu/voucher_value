clear;
clc;
close all;

% === Load data ===
al    = readtable('../Data/AL_US_top_21-23_data.csv', 'ReadVariableNames', true);
%al    = readtable('../../Input/AL_US_top_21-23_data.csv', 'ReadVariableNames', true);
sales_24 = readtable('../Data/24_sales_data.csv', 'ReadVariableNames', true);

al = [al sales_24(:,end)];

% --- Keep only drugs in groupA or groupB (case-insensitive, trimmed) ---
groupA = ["BIKTARVY","MOUNJARO","VABYSMO","RINVOQ","TREMFYA","DOVATO","ODEFSEY", ...
    "ULTOMIRIS","JULUCA","NURTEC","QULIPTA","IMJUDO","MAYZENT","PRALUENT", ...
    "AJOVY","BEOVU","SOLIQUA"];
groupB = ["SKYRIZI","OZEMPIC","JARDIANCE","GENVOYA","TRULICITY","IMFINZI", ...
    "TECENTRIQ","STELARA","XARELTO","VICTOZA","FORXIGA"];
keepList = [groupA, groupB];

% normalize function (trim, collapse spaces, uppercase)
normalizeName = @(s) upper(strtrim(regexprep(string(s),'\s+',' ')));

% create normalized product names for matching
midasNamesNorm = normalizeName(al.("InternationalProductName"));
keepNorm = normalizeName(keepList);

% build logical mask (case-insensitive)
keepMask = ismember(midasNamesNorm, keepNorm);

% --- Fix AL table: convert year columns to numeric ---
yearVars = strcat('x', string(2014:2023)); % adjust if names are x2014, etc.

for v = yearVars
    if ismember(v{1}, al.Properties.VariableNames)
        col = al.(v{1});
        if iscell(col)              % case: stored as cell array of strings
            col = strrep(col, ',', '');   % remove commas
            col = str2double(col);       % convert to numeric
        end
        al.(v{1}) = col;            % overwrite column with numeric values
    else
        % if column missing, add NaNs
        al.(v{1}) = NaN(height(al),1);
    end
end

% Growth rates by year (quarters 1–4, 5–8, 9–12, etc.)
share = [0.11 0.31 0.58 0.76 0.89 1];

% Initialize storage
drugNames = al.("InternationalProductName");
projections = struct();

for i = 1:height(al)
    drugName = al.("InternationalProductName"){i};

    % if strcmp(drugName,'VICTOZA')
    %     1
    % end

    % 3. Search for this name in Column C of midas_updated
    % strcmpi compares strings case-insensitively (e.g. "Humira" == "HUMIRA")
    isMatch = strcmpi(al.("InternationalProductName"), drugName);
    
    % Extract all rows that match this drug
    drugRows = al(isMatch, :);
    
    % If we found matches, clean the sales data and append
    if ~isempty(drugRows)
        alSales = drugRows{:, startsWith(drugRows.Properties.VariableNames,'x')};
        alSales = alSales(~isnan(alSales));
        alSales = alSales(alSales ~= 0);

        realSales{i} = alSales;
    end

    
    % --- Projection (for 13 years) ---
    projSales = zeros(1, 13);
    if strcmp(drugName, 'STELARA')
        % approved 9/25/2009
        projSales(6:numel(alSales)+5) = alSales;
        projSales(numel(alSales)+6:end) = alSales(end);

        currentSales = alSales(1);
        for q = 1:5
            projSales(q) = currentSales*share(q)/share(6);
        end
        projections.(matlab.lang.makeValidName(drugName)) = projSales;
    elseif strcmp(drugName, 'XARELTO')
        % approved 7/1/2011
        projSales(4:numel(alSales)+3) = alSales;
        projSales(numel(alSales)+4:end) = alSales(end);

        currentSales = alSales(1);
        for q = 1:3
            projSales(q) = currentSales*share(q)/share(4);
        end
        projections.(matlab.lang.makeValidName(drugName)) = projSales;
    elseif strcmp(drugName, 'VICTOZA')
        % approved 1/25/2010
        projSales(5:numel(alSales)+4) = alSales;
        projSales(numel(alSales)+5:end) = alSales(end);

        currentSales = alSales(1);
        for q = 1:4
            projSales(q) = currentSales*share(q)/share(5);
        end
        projections.(matlab.lang.makeValidName(drugName)) = projSales;
    else
        projSales(1:numel(alSales)) = alSales;

        currentSales = alSales(end);
        for q = numel(alSales)+1:13
            if q > numel(share)
                projSales(q) = currentSales;
            else
                projSales(q) = currentSales*share(q)/share(q-1);
            end
            currentSales = projSales(q);
        end
        projections.(matlab.lang.makeValidName(drugName)) = projSales;
    end

    
end

if 0 % growth
    % Normalize Group A names for comparison
    groupA_norm = normalizeName(groupA);
    
    if 1
        % Find the maximum length among all cells
        maxLen = max(cellfun(@length, growth_rate));

        % Preallocate a matrix with NaNs
        data = NaN(numel(growth_rate), maxLen);

        % Fill the matrix with values from each cell
        for i = 1:numel(growth_rate)
            drugName = midas_us.("InternationalProduct"){i};
            drugNameNorm = normalizeName(drugName);

            if ismember(drugNameNorm, groupA_norm)
                len = numel(growth_rate{i});
                data(i, 1:len) = growth_rate{i};
            end
        end

        % Compute mean across rows, ignoring NaNs
        meanVals = mean(data, 'omitnan');

        % meanVals now contains the mean of the 1st, 2nd, ... element
    end

    fig = figure('units','normalized','outerposition',[.1 0 .7 1]);
    % fig = figure('units','normalized','outerposition',[.1 0 .9 1.5],'Visible', 'off');
    hold on

    

    for i = 1:height(midas_us)
        drugName = midas_us.("InternationalProduct"){i};
        drugNameNorm = normalizeName(drugName);

        % Only plot if the drug is in group A
        if ismember(drugNameNorm, groupA_norm)
            y = growth_rate{i}*100;
            x = 1:length(y);
            plot(x, y, 'LineWidth', 2);

            % === Add drug name to the right end of the curve ===
            % find last nonzero / non-NaN value to place the label
            validIdx = find(~isnan(y), 1, 'last');
            if ~isempty(validIdx)
                text(x(validIdx) + 0.1, y(validIdx), drugName, ...
                    'Interpreter', 'latex', ...
                    'FontSize', 10, ...
                    'VerticalAlignment', 'middle', ...
                    'HorizontalAlignment', 'left');
            end
        end
    end

    plot(1:24,[29.6,29.6,29.6,29.6,...
        29.6,29.6,29.6,29.6,...
        11.5,11.5,11.5,11.5,...
        4.6,4.6,4.6,4.6,...
        3.7,3.7,3.7,3.7,...
        2.5,2.5,2.5,2.5],'LineStyle','--','LineWidth',2,'Color','black')
    % plot(meanVals*100,'LineWidth',2,'LineStyle',':','Color','black')
    plot(median(data, 'omitnan')*100,'LineWidth',2,'Color','black')

    xlabel('Quarters from Launch');
    ylabel('Quarterly Growth Rate (\%)');
    set(gca, 'YScale', 'log');
    set(gca, 'TickLabelInterpreter', 'latex');
    % xticks(0:1:1*13)
    % xticklabels(string(0:13))
    yticks([1 10 100 1000])
    yticklabels({'1','10','100','1000'})
    % ylim([1 3200])

    % Apply LaTeX formatting
    if 1
        set(findall(gcf,'-property','Interpreter'), 'Interpreter', 'latex')
    end

    print(fig, 'growth.eps', '-depsc');

    return
end

if 1 % sales
    % figure('units','normalized','outerposition',[.1 0 .7 1])
    fig = figure('units','normalized','outerposition',[0 0 1 2],'Visible', 'off');
    hold on

    % Normalize Group A names for comparison
    groupA_norm = normalizeName(groupA);

    for i = 1:height(al)
        drugName = al.("InternationalProductName"){i};
        drugNameNorm = normalizeName(drugName);

        % Only plot if the drug is in group A
        if ismember(drugNameNorm, groupA_norm)
            

            x = 1:13;
            y = projections.(matlab.lang.makeValidName(drugName))/1e6;
            h1 = plot(x, y, 'LineWidth', 2, 'LineStyle','--');

            % Extract the color MATLAB chose automatically
            c = get(h1, 'Color');

            % Plot observed (solid) using the same color
            y_1 = realSales{i} / 1e6;
            x_1 = 1:length(y_1);
            plot(x_1, y_1, 'LineWidth', 2, 'Color', c);

            % === Add drug name to the right end of the curve ===
            % find last nonzero / non-NaN value to place the label
            validIdx = find(~isnan(y) & y > 0, 1, 'last');
            if ~isempty(validIdx)
                % if strcmp(drugName,'TREMEYA')
                %     text(x(validIdx) + 1, y(validIdx)*1.1, drugName, ...
                %         'Interpreter', 'latex', ...
                %         'FontSize', 16, ...
                %         'VerticalAlignment', 'middle', ...
                %         'HorizontalAlignment', 'left');
                if strcmp(drugName,'ULTOMIRIS') || strcmp(drugName,'NURTEC')...
                        || strcmp(drugName,'MAYZENT')
                    text(x(validIdx) + 1, y(validIdx)*0.95, drugName, ...
                        'Interpreter', 'latex', ...
                        'FontSize', 16, ...
                        'VerticalAlignment', 'middle', ...
                        'HorizontalAlignment', 'left');
                elseif strcmp(drugName,'AJOVY')
                    text(x(validIdx) + 1, y(validIdx)*0.85, drugName, ...
                        'Interpreter', 'latex', ...
                        'FontSize', 16, ...
                        'VerticalAlignment', 'middle', ...
                        'HorizontalAlignment', 'left');
                else
                    text(x(validIdx) + 1, y(validIdx), drugName, ...
                        'Interpreter', 'latex', ...
                        'FontSize', 16, ...
                        'VerticalAlignment', 'middle', ...
                        'HorizontalAlignment', 'left');
                end
            end
        end
    end

    xlabel('Years from Launch','FontSize', 16);
    ylabel('Annual Net Sales (millions of USD)','FontSize', 16);
    set(gca, 'YScale', 'log');
    set(gca, 'TickLabelInterpreter', 'latex');
    xticks(1:13)
    xticklabels(string(1:13))
    yticks([1 10 100 1000 10000])
    yticklabels({'1','10','100','1000','10000'})
    ylim([1 20000])

    % Apply LaTeX formatting
    if 1
        set(findall(gcf,'-property','FontSize'),'FontSize',24)
        set(findall(gcf,'-property','Interpreter'), 'Interpreter', 'latex')
    end

    print(fig, 'net_sales_at_launch_used_vouchers.eps', '-depsc');

    return
end

if 0 % Exhibit 2
    % figure('units','normalized','outerposition',[.1 0 .7 1])
    fig = figure('units','normalized','outerposition',[.1 .1 .8 .8]);
    hold on

    for i = 1:height(al)
        drugName = al.("InternationalProductName"){i};
        drugNameNorm = normalizeName(drugName);

        % Only plot if the drug is in group A
        if strcmp(drugNameNorm, 'JULUCA')
            

            x = 1:13;
            y = projections.(matlab.lang.makeValidName(drugName))*(1+1.3*0.009/0.25)/1e6;
            h1 = plot([x 13+1/3], [y y(end)], 'LineWidth', 2, 'LineStyle','--');

            % Extract the color MATLAB chose automatically
            c = get(h1, 'Color');

            % Plot observed (solid) using the same color
            y_1 = realSales{i}*(1+1.3*0.009/0.25) / 1e6;
            x_1 = 1:length(y_1);
            plot(x_1, y_1, 'LineWidth', 2, 'Color', c);

            if 1
                x_prime = x+1/3;
                h1 = plot(x_prime, y/(1+1.3*0.009/0.25), 'LineWidth', 2, 'LineStyle','--');

                % Extract the color MATLAB chose automatically
                c = get(h1, 'Color');

                % Plot observed (solid) using the same color
                x_1_prime = x_1+1/3;
                plot(x_1_prime, y_1/(1+1.3*0.009/0.25), 'LineWidth', 2, 'Color', c);

                % create polygon that goes along curve1 then back along curve2
                xp = [[x x_prime(end)], fliplr(x_prime)];
                yp = [[y y(end)], fliplr(y/(1+1.3*0.009/0.25))];

                % draw filled patch with transparency and no edge
                hPatch = fill(xp, yp, 'r', 'FaceAlpha', 0.25, 'EdgeColor','none');
            end

            % === Add drug name to the right end of the curve ===
            % find last nonzero / non-NaN value to place the label
            % validIdx = find(~isnan(y) & y > 0, 1, 'last');
            % if ~isempty(validIdx)
            %     text(x(validIdx) + 1, y(validIdx), drugName, ...
            %         'Interpreter', 'latex', ...
            %         'FontSize', 16, ...
            %         'VerticalAlignment', 'middle', ...
            %         'HorizontalAlignment', 'left');
            % end

            break
        end
    end

    xlabel('Years from Launch','FontSize', 16);
    ylabel('Annual Net Sales (millions of USD)','FontSize', 16);
    % set(gca, 'YScale', 'log');
    set(gca, 'TickLabelInterpreter', 'latex');
    xticks(1:13)
    xticklabels(string(1:13))
    % xlim([0 54])
    % yticks([1 10 100 1000])
    % yticklabels({'1','10','100','1000'})
    % ylim([0 3200])

    % Apply LaTeX formatting
    if 1
        set(findall(gcf,'-property','FontSize'),'FontSize',25)
        set(findall(gcf,'-property','Interpreter'), 'Interpreter', 'latex')
    end

    print(fig, 'priority_area.eps', '-depsc');

    return
end

% === Build results table ===
rebateTable = table(drugNames);
% disp(rebateTable);



%%
% === Parameters ===
rho = 0.95; % prob of success
c = 0.25;     % cost of goods sold
c_high = 0.6;
i_rate = 0.105; % annual discount rate
m = 0.21;    % tax rate
tau_s = 4/4;   % submission delay (years)
tau_es = 3.3/4; % standard review (years)
tau_ea = 2/4;  % priority review (years)
sigma = 0.25;
Delta_tau_e = tau_es-tau_ea;
Delta_sigma = 0.009;

% Initialize result storage
VoucherValue_comp = nan(height(al),1);
VoucherValue_comp_high_cost = nan(height(al),1);
VoucherValue_peak = nan(height(al),1);

for i = 1:height(al)
    
    drugName = al.("InternationalProductName"){i};
    salesVec = projections.(matlab.lang.makeValidName(drugName));

    % Cash flow adjustment factor
    factor = (1 - m) * (1 - c);
    factor_high_cost = (1 - m) * (1 - c_high);
    
    % Horizon length
    T = length(salesVec);
    
    % --- NPV without voucher ---
    npv_no_voucher = 0;
    npv_no_voucher_high_cost = 0;
    for t = 1:T
        npv_no_voucher = npv_no_voucher + ...
            rho * factor * salesVec(t) / (1 + i_rate)^(t + tau_s + tau_es);
        npv_no_voucher_high_cost = npv_no_voucher_high_cost + ...
            rho * factor_high_cost * salesVec(t) / (1 + i_rate)^(t + tau_s + tau_es);
    end
    

    % --- NPV with voucher (competitive effect) ---
    npv_with_both = 0;
    npv_with_both_high_cost = 0;
    for t = 1:T
        npv_with_both = npv_with_both + ...
            rho * factor * salesVec(t)*(1+Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(t + tau_s + tau_ea);
        npv_with_both_high_cost = npv_with_both_high_cost + ...
            rho * factor_high_cost * salesVec(t)*(1+Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(t + tau_s + tau_ea);
    end
    npv_with_both = npv_with_both + ...
        rho * Delta_tau_e * factor * salesVec(end)*(1+Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(T + tau_s + tau_ea);
    npv_with_both_high_cost = npv_with_both_high_cost + ...
        rho * Delta_tau_e * factor_high_cost * salesVec(end)*(1+Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(T + tau_s + tau_ea);

    
    % Voucher value = difference

    VoucherValue_comp(i) = npv_with_both - npv_no_voucher;

    VoucherValue_comp_high_cost(i) = npv_with_both_high_cost - npv_no_voucher_high_cost;

    VoucherValue_peak(i) = 0.15*salesVec(end);
end

% Add results to output table
rebateTable.VoucherValue_comp = VoucherValue_comp;
% rebateTable.VoucherValue_peak = VoucherValue_peak;

if 1 % table in latex
    table4Tab = rebateTable;
    table4Tab.VoucherValue_comp = round(table4Tab.VoucherValue_comp/1e6);
    % table4Tab.VoucherValue_peak = ceil(table4Tab.VoucherValue_peak/1e6);

    table4Tab = sortrows(table4Tab, 'VoucherValue_comp', 'descend');
    disp(table4Tab);
    
    if 0 % round
        temp = varfun(@round, table4Tab, 'InputVariables', @isnumeric);
        areNumeric = varfun(@isnumeric, table4Tab, 'OutputFormat', 'uniform');
        table4Tab(:, areNumeric) = temp;
    end

    

    % table4Tab = table4Tab(:,{'drugNames','VoucherValue_comp'})
    % table4Tab = table4Tab(:,{'drugNames','rebateRates','rebateStd','rebateGrowth',...
    %     'rebateGrowth_median'})
    table2latex(table4Tab, 'OutputTable.tex')

    return
end