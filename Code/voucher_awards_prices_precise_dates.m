% Set up the environment
close all;
clear;
clc;

% --- Set LaTeX as the default interpreter ---
set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');

% --- Load annual voucher award counts ---
awards_filename = fullfile('..', 'Data', 'voucher-awards-prices.csv');
if exist(awards_filename, 'file') ~= 2
    if exist('voucher-awards-prices.csv', 'file') == 2
        awards_filename = 'voucher-awards-prices.csv';
    elseif exist('voucher-awards-prices(2).csv', 'file') == 2
        awards_filename = 'voucher-awards-prices(2).csv';
    else
        error('Could not find voucher-awards-prices.csv. Check the file path.');
    end
end

data = readmatrix(awards_filename);

% Parse the data into descriptive variables based on the columns
award_year = data(:, 1);                   % Column 1: Year

% For the voucher counts, replace any missing values (NaN) with 0
pediatric = fillmissing(data(:, 2), 'constant', 0);               % Column 2: Rare Pediatric
neglected_diseases = fillmissing(data(:, 3), 'constant', 0);      % Column 3: Neglected Tropical
medical_countermeasures = fillmissing(data(:, 4), 'constant', 0); % Column 4: Medical Countermeasure

% Data matrix for annual stacked bar chart
annual_data = [pediatric, neglected_diseases, medical_countermeasures];

% --- Load individual voucher sale prices ---
prices_filename = fullfile('..', 'Data', 'voucher-prices.csv');
if exist(prices_filename, 'file') ~= 2
    if exist('voucher-prices.csv', 'file') == 2
        prices_filename = 'voucher-prices.csv';
    elseif exist('voucher-prices(2).csv', 'file') == 2
        prices_filename = 'voucher-prices(2).csv';
    else
        error('Could not find voucher-prices.csv. Check the file path.');
    end
end

price_table = readtable(prices_filename);

% Find DateSold and Price columns robustly, even if MATLAB slightly changes
% the imported variable names.
price_var_names = price_table.Properties.VariableNames;
clean_var_names = regexprep(lower(price_var_names), '[^a-z0-9]', '');

date_col_index = find(strcmp(clean_var_names, 'datesold') | ...
                      strcmp(clean_var_names, 'saledate') | ...
                      strcmp(clean_var_names, 'date'), 1);
price_col_index = find(strcmp(clean_var_names, 'price') | ...
                       strcmp(clean_var_names, 'saleprice') | ...
                       strcmp(clean_var_names, 'pricesold'), 1);

if isempty(date_col_index)
    error('Could not find a DateSold column in %s.', prices_filename);
end
if isempty(price_col_index)
    error('Could not find a Price column in %s.', prices_filename);
end

date_col = price_table{:, date_col_index};
price_col = price_table{:, price_col_index};

% Convert DateSold into true datetime values. This preserves the precise
% sale timing within each calendar year instead of collapsing all dots to
% the integer year.
n_price_rows = height(price_table);
voucher_date = NaT(n_price_rows, 1);

if isa(date_col, 'datetime')
    voucher_date = date_col;
else
    for i = 1:n_price_rows
        this_date_text = strtrim(char(string(date_col(i))));

        % Main expected format, e.g., 7/30/14 or 7/30/2014.
        token = regexp(this_date_text, '^(\d{1,2})/(\d{1,2})/(\d{2,4})$', 'tokens', 'once');

        if ~isempty(token)
            mm = str2double(token{1});
            dd = str2double(token{2});
            yyyy = str2double(token{3});

            if yyyy < 100
                yyyy = yyyy + 2000;
            end

            voucher_date(i) = datetime(yyyy, mm, dd);
        else
            % Fallback for unexpected but MATLAB-readable date formats.
            try
                voucher_date(i) = datetime(this_date_text);
            catch
                warning('Could not parse DateSold value in row %d: %s', i, this_date_text);
            end
        end
    end
end

% Extra safety if MATLAB parsed a two-digit year as year 14, 15, ..., 26.
yr_tmp = year(voucher_date);
year_needs_century = yr_tmp >= 0 & yr_tmp < 100;
voucher_date(year_needs_century) = voucher_date(year_needs_century) + calyears(2000);

% Convert individual voucher prices to millions.
if isnumeric(price_col)
    voucher_price = price_col / 1e6;
else
    voucher_price = str2double(erase(string(price_col), {'$', ','})) / 1e6;
end

valid_price_rows = ~isnat(voucher_date) & ~isnan(voucher_price);
voucher_date = voucher_date(valid_price_rows);
voucher_price = voucher_price(valid_price_rows);

% Sort by exact sale date.
[~, sort_order] = sort(voucher_date);
voucher_date = voucher_date(sort_order);
voucher_price = voucher_price(sort_order);

% Convert exact sale dates to decimal years for plotting on the same numeric
% x-axis as the annual stacked bars. For example, a sale midway through 2014
% is plotted around x = 2014.5, not x = 2014.
voucher_year = year(voucher_date);
start_of_year = datetime(voucher_year, 1, 1);
start_next_year = datetime(voucher_year + 1, 1, 1);
dot_x = voucher_year + days(voucher_date - start_of_year) ./ days(start_next_year - start_of_year);

% --- Create the Figure ---
fig = figure;
set(fig, 'Position', [100, 100, 900, 500]); % Set figure size for single panel

% Define colors matching the figure categories
% Dark blue (Pediatric), Light blue (Neglected), Light orange (MedicalCM)
colors = [
    0.30, 0.60, 0.85; ...
    0.47, 0.78, 0.91; ...
    0.99, 0.69, 0.37
];
price_axis_color = [0.00, 0.00, 0.00];  % Black for price axis and voucher-price series
voucher_line_color = [0.00, 0.00, 0.00]; % Black line and dots

% --- Left Y-Axis: Stacked Bar Chart ---
yyaxis left;
b = bar(award_year, annual_data, 'stacked');
hold on;

% Customize colors for each category in the stacked bar
for i = 1:3
    b(i).FaceColor = colors(i, :);
end

% Set left axis properties
ylabel('Number of vouchers awarded', 'FontSize', 12);
set(gca, 'YColor', 'k'); % Keep left axis text color black
ylim([0, max(sum(annual_data, 2)) + 2]); % Set dynamic upper limit with padding

% --- Right Y-Axis: Connected Individual Voucher Prices ---
yyaxis right;
hold on;

% Plot and connect individual voucher sale prices at their exact sale timing
% within the year. Because voucher_date has already been sorted, the line
% connects transactions chronologically.
s = plot(dot_x, voucher_price, '-o', ...
    'Color', voucher_line_color, ...
    'MarkerFaceColor', voucher_line_color, ...
    'MarkerEdgeColor', voucher_line_color, ...
    'LineWidth', 1.2, ...
    'MarkerSize', 5.5);

% Set right axis properties. Note: \$ escapes the dollar sign in LaTeX.
ylabel('Voucher price (\$M)', 'FontSize', 12);
set(gca, 'YColor', price_axis_color); % Keep right axis in dark gray/black

right_axis_values = voucher_price(~isnan(voucher_price));
if ~isempty(right_axis_values)
    ylim([0, ceil(max(right_axis_values) * 1.1 / 50) * 50]);
else
    ylim([0, 350]);
end

% --- General Plot Formatting ---
% Set X-axis limits and ticks (2009, 2011, 2013, etc.)
min_plot_year = min(award_year);
max_plot_year = max([award_year; voucher_year]);
xlim([min_plot_year - 1, max_plot_year + 1]);
xticks(min_plot_year:2:max_plot_year);

xlabel('Year', 'FontSize', 12);
% Bold title in LaTeX
% title('\textbf{Voucher awards and connected individual voucher prices over time}', 'FontSize', 14);

% Create a combined legend
legend([b(3), b(2), b(1), s], ...
    {'Medical Countermeasure', 'Neglected Tropical', 'Rare Pediatric', ...
     'Individual voucher price'}, ...
    'Location', 'northwest', 'EdgeColor', 'none', 'FontSize', 11);

grid on;
box off;

if 1 % to set latex Interpreter and FontSize
    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 18)
    % set(findall(gcf,'-property','Interpreter'),'Interpreter','latex')
end

fprintf('Plotted %d individual voucher price dots from %s to %s.\n', ...
    numel(voucher_price), datestr(min(voucher_date), 'yyyy-mm-dd'), datestr(max(voucher_date), 'yyyy-mm-dd'));
