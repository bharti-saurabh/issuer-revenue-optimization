# Issuer Revenue Optimisation

**Segment:** Issuer | **Category:** Revenue Optimisation | **Owner:** Straive Strategic Analytics | **Year:** 2024

## Objective
Identify cross-sell opportunities and optimise revolving balance mix to increase net interest income (NIM) without increasing credit risk.

## Methodology
1. Customer profitability segmentation (Transactor / Revolver tiers)
2. Propensity-to-revolve model — predict likelihood of revolving balance
3. Cross-sell scoring: balance transfer, credit limit increase, rewards upgrade
4. APR and credit limit strategy by segment
5. Revenue attribution decomposition

## Key Metrics
| Metric | Benchmark |
|---|---|
| Net Interest Margin | 8.2% |
| Revenue Per Active Account | $142/yr |
| Cross-sell Conversion Rate | 6.8% |
| Balance Transfer Uptake | 11.4% |

## Assets
- `src/revenue_model.py` — XGBoost cross-sell propensity model with SHAP
- `src/nim_optimizer.py` — NIM optimisation by revolve segment
- `sql/revenue_attribution.sql` — Per-account revenue decomposition
- `sql/cross_sell_pipeline.sql` — Eligibility and priority pipeline
