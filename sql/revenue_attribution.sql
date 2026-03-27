-- Per-Account Revenue Attribution
-- Straive Strategic Analytics | Issuer Revenue Optimisation

WITH interest_income AS (
    SELECT
        bs.account_id,
        SUM(bs.revolving_balance * a.apr / 12)          AS interest_income_12m
    FROM fact_billing_statements bs
    JOIN dim_accounts a ON bs.account_id = a.account_id
    WHERE bs.stmt_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY bs.account_id
),

fee_income AS (
    SELECT account_id,
        SUM(CASE WHEN fee_type = 'ANNUAL_FEE'       THEN amount ELSE 0 END) AS annual_fee,
        SUM(CASE WHEN fee_type = 'LATE_PAYMENT'     THEN amount ELSE 0 END) AS late_fee,
        SUM(CASE WHEN fee_type = 'CASH_ADVANCE_FEE' THEN amount ELSE 0 END) AS ca_fee,
        SUM(CASE WHEN fee_type = 'FOREIGN_TXN'      THEN amount ELSE 0 END) AS fx_fee
    FROM fact_account_fees
    WHERE fee_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY account_id
),

interchange AS (
    SELECT account_id,
        SUM(amount * interchange_rate)                   AS interchange_income_12m
    FROM fact_transactions
    WHERE txn_date >= CURRENT_DATE - INTERVAL '12 months'
      AND status = 'POSTED'
    GROUP BY account_id
),

funding_cost AS (
    SELECT bs.account_id,
        SUM(bs.revolving_balance * cf.cost_rate / 12)   AS cost_of_funds_12m
    FROM fact_billing_statements bs
    CROSS JOIN dim_cost_of_funds cf
    WHERE bs.stmt_date >= CURRENT_DATE - INTERVAL '12 months'
      AND cf.effective_date = (SELECT MAX(effective_date) FROM dim_cost_of_funds)
    GROUP BY bs.account_id
)

SELECT
    a.account_id,
    a.product_type,
    a.customer_segment,
    CASE
        WHEN a.account_open_date >= CURRENT_DATE - INTERVAL '12 months' THEN 'New'
        WHEN a.account_open_date >= CURRENT_DATE - INTERVAL '36 months' THEN '1-3 Years'
        ELSE '3+ Years'
    END AS tenure_band,
    COALESCE(ii.interest_income_12m, 0)               AS interest_income,
    COALESCE(fi.annual_fee + fi.late_fee + fi.ca_fee + fi.fx_fee, 0) AS fee_income,
    COALESCE(ix.interchange_income_12m, 0)            AS interchange_income,
    COALESCE(ii.interest_income_12m, 0)
        + COALESCE(fi.annual_fee + fi.late_fee + fi.ca_fee + fi.fx_fee, 0)
        + COALESCE(ix.interchange_income_12m, 0)      AS total_revenue,
    COALESCE(fc.cost_of_funds_12m, 0)                 AS cost_of_funds,
    COALESCE(ii.interest_income_12m, 0)
        + COALESCE(fi.annual_fee + fi.late_fee + fi.ca_fee + fi.fx_fee, 0)
        + COALESCE(ix.interchange_income_12m, 0)
        - COALESCE(fc.cost_of_funds_12m, 0)           AS net_revenue
FROM dim_accounts a
LEFT JOIN interest_income ii ON a.account_id = ii.account_id
LEFT JOIN fee_income fi      ON a.account_id = fi.account_id
LEFT JOIN interchange ix     ON a.account_id = ix.account_id
LEFT JOIN funding_cost fc    ON a.account_id = fc.account_id
WHERE a.status = 'ACTIVE'
ORDER BY net_revenue DESC
