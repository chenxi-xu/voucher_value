close all
clear
clc

% === Parameters ===
rho = 0.95;
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


salesVec = [
0.11
0.31
0.58
0.76
0.89
1
1
1
1
1
1
1
1
];

T = length(salesVec);

factor = (1 - m) * (1 - c);

% --- NPV without voucher ---
npv_no_voucher = 0;
for t = 1:T
    npv_no_voucher = npv_no_voucher + ...
        rho * factor * salesVec(t) / (1 + i_rate)^(t + tau_s + tau_es);
end

% --- NPV with voucher (competitive effect) ---
npv_with_both = 0;
for t = 1:T
    npv_with_both = npv_with_both + ...
        rho * factor * salesVec(t)*(1+Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(t + tau_s + tau_ea);
end
npv_with_both = npv_with_both + ...
    rho * Delta_tau_e * factor * salesVec(end)*(1+Delta_tau_e*Delta_sigma/sigma) / (1 + i_rate)^(T + tau_s + tau_ea);

% --- NPV with voucher (no competitive effect) ---
npv_with_voucher = 0;
for t = 1:T
    npv_with_voucher = npv_with_voucher + ...
        rho * factor * salesVec(t) / (1 + i_rate)^(t + tau_s + tau_ea);
end
npv_with_voucher = npv_with_voucher + ...
    rho * Delta_tau_e * factor * salesVec(end) / (1 + i_rate)^(T + tau_s + tau_ea);

% Voucher value = difference
VoucherValue_comp = npv_with_both - npv_no_voucher
VoucherValue = npv_with_voucher - npv_no_voucher

VoucherValue_comp/salesVec(end)

(VoucherValue_comp-VoucherValue)/VoucherValue_comp