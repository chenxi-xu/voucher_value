# US Voucher Valuation Analysis

This repository contains the MATLAB scripts used to analyze US voucher awards, project future sales, compute voucher values, and conduct robustness checks. It provides the replication code for the figures and tables in the associated study.

## 📊 Data Description

The scripts rely on the following datasets. Please ensure the publicly available CSV files are placed in the same directory as the scripts before running them.

* **`voucher-awards-prices.csv`**
  Contains historical data on voucher awards and their associated prices. This dataset is required to run `us_voucher_award_and_price.m` and generate **Figure 1**.

* **`24_sales_data.csv`**
  Contains public sales data for 2024 extracted directly from the respective firms' financial filings. 

* **Proprietary Commercial Data (IQVIA)**
  The analysis also utilizes commercial data on annual net-of-rebate drug sales obtained from **IQVIA Analytics Link** (version current as of 2025). 
  > **Note:** This data was obtained under a third-party data-use agreement. Due to licensing restrictions, these proprietary datasets cannot be publicly redistributed in this repository. Researchers wishing to fully replicate all sales projections must obtain access directly from IQVIA under similar licensing terms.

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
2. Ensure the publicly available CSV datasets are in the root directory.
3. Open the directory in MATLAB.
4. Ensure all `.m` files are in your active MATLAB path.
5. Run the scripts individually depending on which figure or table you wish to replicate.
