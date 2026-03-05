# US Voucher Valuation Analysis

This repository contains the MATLAB scripts used to analyze US voucher awards, project future sales, compute voucher values, and conduct robustness checks. It provides the replication code for the figures and tables in the associated study.

## 📁 File Overview

The analysis is divided into the following primary scripts:

* **`us_voucher_award_and_price.m`**
  Replicates **Figure 1**. It processes and visualizes the number of vouchers awarded each year alongside their average price.

* **`us_voucher_val.m`**
  The main valuation script. It projects future sales and computes the voucher values. Running this script generates the data for **Figures 2 and A1**, as well as **Tables 1, 2, and A3**.

* **`us_voucher_val_fn_sales.m`**
  Computes the voucher value specifically as a function of annual peak sales.

* **`robustness_check.m`**
  Conducts the necessary robustness checks for the valuation model and generates the tornado chart shown in **Figure 3**.

## 🛠️ Helper Functions

* **`table2latex.m`**
  A utility script used to format and convert tables into LaTeX code. *(Authored by Victor Martinez Cagigal)*.

## 🚀 Usage

1. Clone this repository to your local machine.
2. Open the directory in MATLAB.
3. Ensure all `.m` files are in your active MATLAB path.
4. Run the scripts individually depending on which figure or table you wish to replicate.
