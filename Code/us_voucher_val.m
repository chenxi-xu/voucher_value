clear;
clc;
close all;

% === Load data ===
al    = readtable('../Data/AL_US_top_21-23_data.csv', 'ReadVariableNames', true);
%al    = readtable('../../Input/AL_US_top_21-23_data.csv', 'ReadVariableNames', true);
sales_24 = readtable('../Data/24_sales_data.csv', 'ReadVariableNames', true);
sales_25 = readtable('../Data/Company-filings/annual-filings-2025.csv', 'ReadVariableNames', true);

% Rename sales_25 columns for clarity
sales_25.Properties.VariableNames = {'InternationalProductName','Year','x2025'};

% Drop the first row, which is just the header "Drug"
sales_25 = sales_25(~strcmp(sales_25.InternationalProductName, 'Drug'), :);

% Convert sales_25 values from millions to dollars if needed
% In your sales_25 table, x2025 seems to be in millions, while x2024 is dollars.
sales_25.x2025 = sales_25.x2025 * 1e6;

% Append 2025 sales to sales_24 by matching drug name
[tf, loc] = ismember(sales_24.InternationalProductName, sales_25.InternationalProductName);

% Initialize with NaN for drugs not appearing in sales_25
sales_24.x2025 = nan(height(sales_24), 1);

% Fill matched rows
sales_24.x2025(tf) = sales_25.x2025(loc(tf));

al = [al sales_24(:,end-1:end)];

% --- Keep only drugs in groupA or groupB (case-insensitive, trimmed) ---
groupA = ["BIKTARVY","MOUNJARO","VABYSMO","RINVOQ","TREMFYA","DOVATO","ODEFSEY", ...
    "ULTOMIRIS","JULUCA","NURTEC","QULIPTA","IMJUDO","MAYZENT","PRALUENT", ...
    "AJOVY","BEOVU","SOLIQUA"];
groupB = ["OZEMPIC","JARDIANCE","GENVOYA","TRULICITY","IMFINZI", ...
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
yearVars = strcat('x', string(2014:2025)); % adjust if names are x2014, etc.

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

num_obs = 0;
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

    if ismember(drugName, groupA) || ismember(drugName, groupB)
        %drugName
        %alSales
        num_obs = num_obs + length(alSales);

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

end


if 0 % sales
    % figure('units','normalized','outerposition',[.1 0 .7 1])
    fig = figure('units','normalized','outerposition',[0 0 1 2],'Visible', 'off');
    hold on

    % Normalize Group A names for comparison
    groupA_norm = normalizeName(groupA);

    % Initialize before the loop
    drugNames_out = strings(0,1);
    yValues_out   = zeros(0,13);

    for i = 1:height(al)
        drugName = al.("InternationalProductName"){i};
        drugNameNorm = normalizeName(drugName);

        % Only plot if the drug is in group A
        if ismember(drugNameNorm, groupA_norm)


            x = 1:13;
            y = projections.(matlab.lang.makeValidName(drugName))/1e6;

            % Save drug name and corresponding y values
            drugNames_out(end+1,1) = string(drugName);
            yValues_out(end+1,:)   = y(:)';

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
                elseif strcmp(drugName,'IMJUDO')
                    text(x(validIdx) + 1, y(validIdx)*1.1, drugName, ...
                        'Interpreter', 'latex', ...
                        'FontSize', 16, ...
                        'VerticalAlignment', 'middle', ...
                        'HorizontalAlignment', 'left');
                elseif strcmp(drugName,'AJOVY')
                    text(x(validIdx) + 1, y(validIdx)*0.93, drugName, ...
                        'Interpreter', 'latex', ...
                        'FontSize', 16, ...
                        'VerticalAlignment', 'middle', ...
                        'HorizontalAlignment', 'left');
                elseif strcmp(drugName,'PRALUENT')
                    text(x(validIdx) + 1, y(validIdx)*0.9, drugName, ...
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

    %print(fig, 'net_sales_at_launch_used_vouchers.eps', '-depsc');
    exportgraphics(fig, 'net_sales_at_launch_used_vouchers.png', ...
        'Resolution', 300, ...
        'ContentType', 'image');

    % Create table
    T = array2table(yValues_out, ...
        'VariableNames', compose('Year%d', 1:13));

    T = addvars(T, drugNames_out, ...
        'Before', 1, ...
        'NewVariableNames', 'DrugName');

    % Save to Excel
    writetable(T, 'groupA_projection_values.xlsx');

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
            y = projections.(matlab.lang.makeValidName(drugName))*(1+1.3*0.009/0.5)/1e6;
            h1 = plot([x 13+1/3], [y y(end)], 'LineWidth', 2, 'LineStyle','--');

            % Extract the color MATLAB chose automatically
            c = get(h1, 'Color');

            % Plot observed (solid) using the same color
            y_1 = realSales{i}*(1+1.3*0.009/0.5) / 1e6;
            x_1 = 1:length(y_1);
            plot(x_1, y_1, 'LineWidth', 2, 'Color', c);

            if 1
                x_prime = x+1/3;
                h1 = plot(x_prime, y/(1+1.3*0.009/0.5), 'LineWidth', 2, 'LineStyle','--');

                % Extract the color MATLAB chose automatically
                c = get(h1, 'Color');

                % Plot observed (solid) using the same color
                x_1_prime = x_1+1/3;
                plot(x_1_prime, y_1/(1+1.3*0.009/0.5), 'LineWidth', 2, 'Color', c);

                % create polygon that goes along curve1 then back along curve2
                xp = [[x x_prime(end)], fliplr(x_prime)];
                yp = [[y y(end)], fliplr(y/(1+1.3*0.009/0.5))];

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


%return

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
sigma = 0.5;
Delta_tau_e = tau_es-tau_ea;
Delta_sigma = 0.009;

drugNames = fieldnames(projections);

rebateTable = table(drugNames);

VoucherValue_comp = nan(height(drugNames),1);
VoucherValue_comp_high_cost = nan(height(drugNames),1);
VoucherValue_peak = nan(height(drugNames),1);

for i = 1:height(drugNames)

    drugName = drugNames{i};
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
            rho * factor * salesVec(t)*(1+4*Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(t + tau_s + tau_ea);
        npv_with_both_high_cost = npv_with_both_high_cost + ...
            rho * factor_high_cost * salesVec(t)*(1+4*Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(t + tau_s + tau_ea);
    end
    npv_with_both = npv_with_both + ...
        rho * Delta_tau_e * factor * salesVec(end)*(1+4*Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(T + tau_s + tau_ea);
    npv_with_both_high_cost = npv_with_both_high_cost + ...
        rho * Delta_tau_e * factor_high_cost * salesVec(end)*(1+4*Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(T + tau_s + tau_ea);


    % Voucher value = difference

    VoucherValue_comp(i) = npv_with_both - npv_no_voucher;

    VoucherValue_comp_high_cost(i) = npv_with_both_high_cost - npv_no_voucher_high_cost;

    VoucherValue_peak(i) = 0.18*max(salesVec);
end

% Add results to output table
rebateTable.VoucherValue_comp = VoucherValue_comp;
rebateTable.VoucherValue_peak = VoucherValue_peak;

if 1 % table in latex
    table4Tab = rebateTable;
    table4Tab.VoucherValue_comp = round(table4Tab.VoucherValue_comp/1e6);
    table4Tab.VoucherValue_peak = round(table4Tab.VoucherValue_peak/1e6);

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

    %return
end

if 1 % Figure 2
    T = table4Tab;

    drug = string(T.drugNames);
    value = T.VoucherValue_comp;   % already in million USD

    % Keep only Group A drugs
    keep = ismember(drug, groupA);

    drug = drug(keep);
    value = value(keep);

    % Sort from largest to smallest
    [valueSorted, idx] = sort(value, 'descend');
    drugSorted = drug(idx);

    % Reverse for horizontal plot so largest appears at top
    drugPlot = flipud(drugSorted);
    valuePlot = flipud(valueSorted);

    % Summary statistics for Group A only
    medVal = median(value, 'omitnan');
    meanVal = mean(value, 'omitnan');

    figure;
    hold on;

    nDrugs = numel(drugPlot);
    xMax = max(valueSorted) * 1.08;

    % Horizontal guide lines only from y-axis to each dot
    for i = 1:nDrugs
        plot([0, valuePlot(i)], [i, i], '-', ...
            'Color', [0.85 0.85 0.85], ...
            'LineWidth', 0.6);
    end

    % Dots
    scatter(valuePlot, 1:nDrugs, 70, 'k', 'filled');

    % Set limits before placing vertical labels
    xlim([0, xMax]);
    ylim([0.5, nDrugs + 0.5]);

    % Median and mean lines WITHOUT built-in xline labels
    % This avoids LaTeX parsing warnings from xline label strings.
    xline(medVal, '--', ...
        'LineWidth', 1.2, ...
        'Color', [0.4 0.4 0.4]);

    xline(meanVal, ':', ...
        'LineWidth', 1.8, ...
        'Color', [0.25 0.25 0.25]);

    % Add median and mean labels manually, with interpreter turned off
    text(medVal + xMax * 0.012, 1.0, ...
        sprintf('Median: $%dM', round(medVal)), ...
        'Rotation', 90, ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Interpreter', 'none');

    text(meanVal + xMax * 0.012, 1.0, ...
        sprintf('Mean: $%dM', round(meanVal)), ...
        'Rotation', 90, ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Interpreter', 'none');

    % Label top 3
    topK = min(3, numel(drugSorted));

    for k = 1:topK
        drugName = drugSorted(k);
        val = valueSorted(k);

        y = find(drugPlot == drugName, 1);

        text(val + xMax * 0.015, y, ...
            sprintf('$%dM', round(val)), ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 10, ...
            'Interpreter', 'none');
    end

    % Axis formatting
    yticks(1:nDrugs);
    yticklabels(drugPlot);

    xlabel('Estimated value of priority review, $ millions', ...
        'Interpreter', 'none');

    set(gca, 'YDir', 'normal');
    grid off;
    box off;

    % Footnote
    % annotation('textbox', [0.08 0.01 0.8 0.04], ...
    %     'String', 'Values are reported in millions of US dollars.', ...
    %     'EdgeColor', 'none', ...
    %     'FontSize', 9, ...
    %     'Interpreter', 'none');

    hold off;
end

if 1 % Figure 3
    T = table4Tab;

    drug = string(T.drugNames);
    value = T.VoucherValue_comp;   % already in million USD

    % Keep only Group A drugs
    keep = ismember(drug, groupB);

    drug = drug(keep);
    value = value(keep);

    % Sort from largest to smallest
    [valueSorted, idx] = sort(value, 'descend');
    drugSorted = drug(idx);

    % Reverse for horizontal plot so largest appears at top
    drugPlot = flipud(drugSorted);
    valuePlot = flipud(valueSorted);

    % Summary statistics for Group B only
    medVal = median(value, 'omitnan');
    meanVal = mean(value, 'omitnan');

    figure;
    hold on;

    nDrugs = numel(drugPlot);
    xMax = max(valueSorted) * 1.08;

    % Horizontal guide lines only from y-axis to each dot
    for i = 1:nDrugs
        plot([0, valuePlot(i)], [i, i], '-', ...
            'Color', [0.85 0.85 0.85], ...
            'LineWidth', 0.6);
    end

    % Dots
    scatter(valuePlot, 1:nDrugs, 70, 'k', 'filled');

    % Set limits before placing vertical labels
    xlim([0, xMax]);
    ylim([0.5, nDrugs + 0.5]);

    % Median and mean lines WITHOUT built-in xline labels
    % This avoids LaTeX parsing warnings from xline label strings.
    xline(medVal, '--', ...
        'LineWidth', 1.2, ...
        'Color', [0.4 0.4 0.4]);

    xline(meanVal, ':', ...
        'LineWidth', 1.8, ...
        'Color', [0.25 0.25 0.25]);

    % Add median and mean labels manually, with interpreter turned off
    text(medVal + xMax * 0.012, 1.0, ...
        sprintf('Median: $%dM', round(medVal)), ...
        'Rotation', 90, ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Interpreter', 'none');

    text(meanVal + xMax * 0.012, 1.0, ...
        sprintf('Mean: $%dM', round(meanVal)), ...
        'Rotation', 90, ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10, ...
        'Interpreter', 'none');

    % Label top 3
    topK = min(3, numel(drugSorted));

    for k = 1:topK
        drugName = drugSorted(k);
        val = valueSorted(k);

        y = find(drugPlot == drugName, 1);

        text(val + xMax * 0.015, y, ...
            sprintf('$%dM', round(val)), ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 10, ...
            'Interpreter', 'none');
    end

    % Axis formatting
    yticks(1:nDrugs);
    yticklabels(drugPlot);

    xlabel('Estimated value of priority review, $ millions', ...
        'Interpreter', 'none');

    set(gca, 'YDir', 'normal');
    grid off;
    box off;

    % Footnote
    % annotation('textbox', [0.08 0.01 0.8 0.04], ...
    %     'String', 'Values are reported in millions of US dollars.', ...
    %     'EdgeColor', 'none', ...
    %     'FontSize', 9, ...
    %     'Interpreter', 'none');

    hold off;
end