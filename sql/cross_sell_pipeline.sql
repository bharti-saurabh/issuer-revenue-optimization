-- Cross-Sell Eligibility Pipeline
-- Straive Strategic Analytics | Issuer Revenue Optimisation

WITH balance_transfer_eligible AS (
    SELECT a.account_id, 'BALANCE_TRANSFER' AS offer_type, 1 AS priority
    FROM dim_accounts a
    JOIN fact_credit_bureau cb ON a.account_id = cb.account_id
    WHERE a.credit_utilisation < 0.6                   -- has room for transferred balance
      AND cb.total_external_revolving_balance > 2000   -- has external balance to transfer
      AND a.delinquency_days_max_12m = 0               -- clean payment history
      AND a.account_tenure_months >= 6
),

cli_eligible AS (
    SELECT a.account_id, 'CREDIT_LIMIT_INCREASE' AS offer_type, 2 AS priority
    FROM dim_accounts a
    JOIN (
        SELECT account_id, SUM(amount) AS spend_12m
        FROM fact_transactions
        WHERE txn_date >= CURRENT_DATE - INTERVAL '12 months' AND status = 'POSTED'
        GROUP BY account_id
    ) s ON a.account_id = s.account_id
    WHERE a.credit_utilisation BETWEEN 0.7 AND 0.95    -- high utilisation — constrained
      AND s.spend_12m > a.credit_limit * 0.8           -- regularly hitting limit
      AND a.delinquency_days_max_12m = 0
      AND a.account_tenure_months >= 12
),

rewards_upgrade_eligible AS (
    SELECT a.account_id, 'REWARDS_UPGRADE' AS offer_type, 3 AS priority
    FROM dim_accounts a
    LEFT JOIN (
        SELECT account_id, COUNT(*) AS redemptions_12m
        FROM fact_reward_redemptions
        WHERE redemption_date >= CURRENT_DATE - INTERVAL '12 months'
        GROUP BY account_id
    ) r ON a.account_id = r.account_id
    JOIN (
        SELECT account_id, SUM(amount) AS spend_12m
        FROM fact_transactions
        WHERE txn_date >= CURRENT_DATE - INTERVAL '12 months' AND status = 'POSTED'
        GROUP BY account_id
    ) s ON a.account_id = s.account_id
    WHERE s.spend_12m > 15000                          -- high spender
      AND COALESCE(r.redemptions_12m, 0) = 0          -- not engaging with rewards
      AND a.product_type = 'STANDARD'                 -- on basic product
)

SELECT account_id, offer_type, priority,
    CURRENT_DATE AS pipeline_date
FROM balance_transfer_eligible
UNION ALL
SELECT account_id, offer_type, priority FROM cli_eligible
UNION ALL
SELECT account_id, offer_type, priority FROM rewards_upgrade_eligible
ORDER BY priority, account_id
