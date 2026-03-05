% Set up the environment
close all;
clear;
clc;

% --- Set LaTeX as the default interpreter ---
set(groot, 'defaultTextInterpreter', 'latex');
set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
set(groot, 'defaultLegendInterpreter', 'latex');

% Load the data from the CSV file
filename = '../Data/voucher-awards-prices.csv';
data = readmatrix(filename);

% Parse the data into descriptive variables based on the columns
year = data(:, 1);                   % Column 1: Year

% For the voucher counts, replace any missing values (NaN) with 0
pediatric = fillmissing(data(:, 2), 'constant', 0);               % Column 2: Rare Pediatric
neglected_diseases = fillmissing(data(:, 3), 'constant', 0);      % Column 3: Neglected Tropical
medical_countermeasures = fillmissing(data(:, 4), 'constant', 0); % Column 4: Medical Countermeasure

% Column 5: Average price (convert to millions)
average_price = data(:, 5) / 1e6;         

% Data matrix for annual stacked bar chart
annual_data = [pediatric, neglected_diseases, medical_countermeasures];

% --- Create the Figure ---
fig = figure;
set(fig, 'Position', [100, 100, 900, 500]); % Set figure size for single panel

% Define colors matching the figure categories
% Dark blue (Pediatric), Light blue (Neglected), Light orange (MedicalCM)
colors = [
    0.00, 0.30, 0.55; ...
    0.47, 0.78, 0.91; ...
    0.99, 0.69, 0.37      
];
price_color = [0.12, 0.12, 0.12]; % Dark gray/black for price line

% --- Left Y-Axis: Stacked Bar Chart ---
yyaxis left;
b = bar(year, annual_data, 'stacked');

% Customize colors for each category in the stacked bar
for i = 1:3
    b(i).FaceColor = colors(i, :);
end

% Set left axis properties
ylabel('Number of vouchers awarded', 'FontSize', 12);
set(gca, 'YColor', 'k'); % Keep left axis text color black
ylim([0, max(sum(annual_data, 2)) + 2]); % Set dynamic upper limit with padding

% --- Right Y-Axis: Average Price Line Chart ---
yyaxis right;
hold on;

% Identify indices with missing price data
missing_indices = isnan(average_price);

% Plot the price line with markers, only for years with non-NaN price data
p = plot(year(~missing_indices), average_price(~missing_indices), '-o', ...
    'Color', price_color, 'MarkerFaceColor', price_color, 'LineWidth', 2, 'MarkerSize', 6);

% Add the text label for missing early data
% text(2009, 300, 'Price data for earliest vouchers not available', ...
%     'FontSize', 10, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
%     'Color', price_color);

% Set right axis properties (Note: \$ is used to escape the dollar sign in LaTeX)
ylabel('Average price (\$M)', 'FontSize', 12);
set(gca, 'YColor', price_color); % Match right axis color to the line
ylim([0, 350]);

% --- General Plot Formatting ---
% Set X-axis limits and ticks (2009, 2011, 2013, etc.)
xlim([2008, max(year)+1]);
xticks(2009:2:max(year));

xlabel('Year', 'FontSize', 12);
% Bold title in LaTeX
% title('\textbf{Voucher awards and average price over time}', 'FontSize', 14);

% Create a combined legend
legend([b(3), b(2), b(1), p], ...
    {'Medical Countermeasure', 'Neglected Tropical', 'Rare Pediatric', 'Average Price'}, ...
    'Location', 'northwest', 'EdgeColor', 'none', 'FontSize', 11);

grid on;
box off;

if 1 % to set latex Interpreter and FontSize
    set(findall(gcf,'-property','FontSize'),'FontSize',18)
    % set(findall(gcf,'-property','Interpreter'),'Interpreter','latex')
end
