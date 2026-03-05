clear;
clc;
close all;

if 0 % sandbox
    % 1. Define the Variables and Base Metric
    categories = {'Discount Rate', 'Variable Costs', 'Fixed Costs', 'Volume', 'Price'};
    base_value = 100; % The baseline metric (e.g., Base NPV)

    % 2. Define the Low and High Outcomes
    % (These represent the metric's value when the category is at its min/max)
    low_outcomes  = [95, 90, 85, 75, 50];
    high_outcomes = [102, 115, 120, 130, 160];

    % 3. Calculate Deviations
    % We plot the deviations from the base value, then relabel the axes later
    left_dev  = low_outcomes - base_value;
    right_dev = high_outcomes - base_value;

    % 4. Sort the Data (Crucial for the Tornado Shape)
    % Calculate the total spread (High - Low) for each category
    spread = abs(right_dev - left_dev);

    % Sort in ascending order so the largest spread ends up at the top of the barh plot
    [~, sort_idx] = sort(spread, 'ascend');

    categories_sorted = categories(sort_idx);
    left_dev_sorted   = left_dev(sort_idx);
    right_dev_sorted  = right_dev(sort_idx);

    % 5. Create the Plot
    figure('Color', 'w', 'Name', 'Tornado Chart');
    hold on;

    % Plot the negative (left) and positive (right) deviations
    % We assign outputs to b1 and b2 to easily change colors
    b1 = barh(left_dev_sorted, 'FaceColor', [0.85 0.33 0.10], 'EdgeColor', 'none'); % Red/Orange
    b2 = barh(right_dev_sorted, 'FaceColor', [0 0.45 0.74], 'EdgeColor', 'none');   % Blue

    % 6. Formatting and Aesthetics
    % Set Y-axis labels to the categories
    yticks(1:length(categories));
    yticklabels(categories_sorted);

    % Draw a bold line down the middle for the baseline
    xline(0, 'k-', 'LineWidth', 1.5);

    % Add grid, title, and labels
    grid on;
    ax = gca;
    ax.XGrid = 'on';
    ax.YGrid = 'off'; % Hide Y gridlines for a cleaner look
    title('Sensitivity Analysis - Tornado Chart', 'FontSize', 14);
    xlabel('Project Value', 'FontSize', 12);

    % 7. Relabel X-Axis to Show Actual Values (Pro-Tip)
    % Instead of showing "-50, 0, +50", this shifts the text to show "50, 100, 150"
    ax.XTickLabel = string(ax.XTick + base_value);

    % Add a legend
    legend([b1, b2], {'Low Case', 'High Case'}, 'Location', 'southoutside', 'Orientation', 'horizontal');

    hold off;

    return
end

% === Load data ===
al    = readtable('../Data/AL_US_top_21-23_data.csv', 'ReadVariableNames', true);
%al    = readtable('../../Input/AL_US_top_21-23_data.csv', 'ReadVariableNames', true);
sales_24 = readtable('../Data/24_sales_data.csv', 'ReadVariableNames', true);

al = [al sales_24(:,end)];

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

% share by year 
share = [0.11 0.31 0.58 0.76 0.89 1];

% Initialize storage
drugNames = al.("InternationalProductName");
projections = struct();

for i = 1:height(al)
    drugName = al.("InternationalProductName"){i};

    if strcmp(drugName,'ODEFSEY')

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

if 0 % sales
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
% =========================================================================
% ROBUSTNESS CHECK & TORNADO CHART GENERATION
% =========================================================================

% 1. Define Baseline Parameters (From Table A3)
p_base.m           = 0.21;    % Corporate tax rate (\kappa)
p_base.c           = 0.25;    % Cost of goods sold share
p_base.i_rate      = 0.105;   % Annual discount rate (r)
p_base.rho         = 0.95;    % Probability of approval
p_base.Delta_sigma = 0.009;   % Market share gain per quarter (\Delta m)
p_base.sigma       = 0.25;    % Baseline market share (m_0)
p_base.T           = 13;      % Time on market
p_base.tau_s       = 1.0;     % Time from voucher to submission (\tau^sub)
p_base.tau_es      = 0.825;   % Standard review time (\tau^std)
p_base.tau_ea      = 0.5;     % Priority review time (\tau^pri)

% 2. Define "Reduces Value" Bounds (From Table A3)
p_dec.m           = 0.25;   
p_dec.c           = 0.30;    
p_dec.i_rate      = 0.13;   
p_dec.rho         = 0.90;    
p_dec.Delta_sigma = 0.007;   
p_dec.sigma       = 0.30;    % UPDATED: Swapped to 0.30
p_dec.T           = 10;      
p_dec.tau_s       = 1.20;    
p_dec.tau_es      = 0.66;    % UPDATED: Swapped to 0.99
p_dec.tau_ea      = 0.60;    

% 3. Define "Increases Value" Bounds (From Table A3)
p_inc.m           = 0.17;   
p_inc.c           = 0.20;    
p_inc.i_rate      = 0.08;   
p_inc.rho         = 1.00;    
p_inc.Delta_sigma = 0.011;   
p_inc.sigma       = 0.20;    % UPDATED: Swapped to 0.20
p_inc.T           = 16;      
p_inc.tau_s       = 0.80;    
p_inc.tau_es      = 0.99;    % UPDATED: Swapped to 0.66
p_inc.tau_ea      = 0.40;    

% Extract parameter names dynamically
param_names = fieldnames(p_base);
num_params = length(param_names);

% Arrays to store results
res_dec = zeros(num_params, 1);
res_inc = zeros(num_params, 1);

% --- COMPUTE BASELINE ---
baseline_val = calcVoucherValue(p_base, projSales);
fprintf('Baseline NPV: %.4f\n\n', baseline_val);

% --- RUN ROBUSTNESS LOOP ---
for i = 1:num_params
    param = param_names{i};
    
    % Test "Reduces Value" bound
    p_test_dec = p_base; 
    p_test_dec.(param) = p_dec.(param); 
    res_dec(i) = calcVoucherValue(p_test_dec, projSales);
    
    % Test "Increases Value" bound
    p_test_inc = p_base; 
    p_test_inc.(param) = p_inc.(param); 
    res_inc(i) = calcVoucherValue(p_test_inc, projSales);
end

% =========================================================================
% TORNADO CHART PLOTTING
% =========================================================================

% 1. Calculate the spread to sort parameters (widest at the top)
spread = abs(res_inc - res_dec);
[~, sort_idx] = sort(spread, 'ascend'); 

% 2. Sort the data for the plot (Percentage Change)
sorted_names = param_names(sort_idx);
sorted_dec   = ((res_dec(sort_idx) - baseline_val) / baseline_val) * 100; % change
sorted_inc   = ((res_inc(sort_idx) - baseline_val) / baseline_val) * 100; % change

% --- NEW: Map variable names to LaTeX strings based on Table A3 ---
latex_dict = containers.Map(...
    {'m', 'c', 'i_rate', 'rho', 'Delta_sigma', 'sigma', 'T', 'tau_s', 'tau_es', 'tau_ea'}, ...
    {'Tax rate', 'Cost of goods', 'Discount rate', 'Prob. approval', ...
    'Share gain', 'Market share', 'Exclusivity', 'Hold time', ...
    'Standard time', 'Priority time'});

% Generate a cell array of the sorted LaTeX labels
sorted_latex_labels = cell(num_params, 1);
for k = 1:num_params
    sorted_latex_labels{k} = latex_dict(sorted_names{k});
end
% -----------------------------------------------------------------

% 3. Create Figure
figure('Color', 'w', 'Position', [100, 100, 800, 500]);
hold on;

% Plot bars 
h1 = barh(1:num_params, sorted_dec, 'FaceColor', [0.8500 0.3250 0.0980], 'EdgeColor', 'k');
h2 = barh(1:num_params, sorted_inc, 'FaceColor', [0.0000 0.4470 0.7410], 'EdgeColor', 'k');

% Add a vertical line for the Baseline
xline(0, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Baseline');

% Formatting
yticks(1:num_params);
yticklabels(sorted_latex_labels); % Apply the mapped LaTeX labels

% Tell MATLAB to render the tick labels using LaTeX!
set(gca, 'TickLabelInterpreter', 'latex', 'FontSize', 12); 

xlabel('Percentage change in voucher value (relative to baseline)', 'FontWeight', 'bold');
% title('Sensitivity Analysis Tornado Chart', 'FontWeight', 'bold', 'FontSize', 14);
% legend([h1, h2], {'Reduces value', 'Increases value'}, 'Location', 'southeast');
grid on;
ax = gca;
ax.GridAlpha = 0.3;
hold off;

if 1
    set(findall(gcf,'-property','FontSize'),'FontSize',20)
    set(findall(gcf,'-property','Interpreter'), 'Interpreter', 'latex')
end


% =========================================================================
% COMPUTE FUNCTION
% =========================================================================
function VoucherValue_comp = calcVoucherValue(p, salesVec)
    % 1. Handle derived parameters internally
    Delta_tau_e = p.tau_es - p.tau_ea;
    factor = (1 - p.m) * (1 - p.c);
    
    % 2. --- DYNAMIC SALES VECTOR ADJUSTMENT ---
    T_val = round(p.T);
    current_len = length(salesVec);
    
    if T_val > current_len
        % Pad the array: repeat the last value of salesVec
        padding = salesVec(end) * ones(T_val - current_len, 1);
        % Ensure column vector format
        adjustedSales = [salesVec(:); padding]; 
    else
        % Truncate the array: only take the first T_val elements
        adjustedSales = salesVec(1:T_val);
    end
    
    % --- NPV without voucher ---
    npv_no_voucher = 0;
    for t = 1:T_val
        npv_no_voucher = npv_no_voucher + ...
            p.rho * factor * adjustedSales(t) / (1 + p.i_rate)^(t + p.tau_s + p.tau_es);
    end
    
    % --- NPV with voucher (competitive effect) ---
    npv_with_both = 0;
    for t = 1:T_val
        npv_with_both = npv_with_both + ...
            p.rho * factor * adjustedSales(t)*(1+Delta_tau_e*p.Delta_sigma/p.sigma) / (1 + p.i_rate)^(t + p.tau_s + p.tau_ea);
    end
    
    % Add the final year residual (using the very last element of our adjusted vector)
    npv_with_both = npv_with_both + ...
        p.rho * Delta_tau_e * factor * adjustedSales(end)*(1+Delta_tau_e*p.Delta_sigma/p.sigma) / (1 + p.i_rate)^(T_val + p.tau_s + p.tau_ea);
    
    % Final Value
    VoucherValue_comp = npv_with_both - npv_no_voucher;
end