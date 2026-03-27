"""
Net Interest Margin Optimisation — Revolve Segment Strategy
Straive Strategic Analytics
"""
import pandas as pd
import numpy as np
from dataclasses import dataclass
from typing import Dict

REVOLVE_TIERS = {
    "Transactor":        (0.00, 0.15),
    "Occasional":        (0.15, 0.40),
    "Moderate Revolver": (0.40, 0.70),
    "Heavy Revolver":    (0.70, 1.01),
}

@dataclass
class SegmentStrategy:
    tier: str
    recommended_apr_delta: float  # bps vs current
    credit_limit_action: str
    cross_sell_priority: str
    expected_nim_uplift_bps: float


def assign_tier(revolve_prob: float) -> str:
    for tier, (lo, hi) in REVOLVE_TIERS.items():
        if lo <= revolve_prob < hi:
            return tier
    return "Transactor"


def compute_nim_by_segment(df: pd.DataFrame) -> pd.DataFrame:
    """Compute NIM contribution per revolve segment."""
    df = df.copy()
    df["tier"] = df["revolve_prob"].apply(assign_tier)
    df["interest_income"] = df["avg_balance"] * df["apr"] * df["revolve_prob"]
    df["funding_cost"]    = df["avg_balance"] * df["cost_of_funds_rate"]
    df["nim_contribution"] = df["interest_income"] - df["funding_cost"]

    summary = df.groupby("tier").agg(
        accounts=("account_id", "count"),
        avg_balance=("avg_balance", "mean"),
        avg_revolve_prob=("revolve_prob", "mean"),
        total_nim=("nim_contribution", "sum"),
        nim_per_account=("nim_contribution", "mean"),
    ).reset_index()
    return summary


def recommend_strategies(segment_summary: pd.DataFrame) -> Dict[str, SegmentStrategy]:
    strategies = {
        "Transactor":        SegmentStrategy("Transactor",        0,   "Maintain",  "Rewards Upgrade",        12),
        "Occasional":        SegmentStrategy("Occasional",       +25,  "Increase",  "Balance Transfer",       35),
        "Moderate Revolver": SegmentStrategy("Moderate Revolver",+50,  "Review",    "Credit Limit Increase",  60),
        "Heavy Revolver":    SegmentStrategy("Heavy Revolver",   +75,  "Cap",       "Payment Plan Offer",     20),
    }
    return strategies
