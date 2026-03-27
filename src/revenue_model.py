"""
Cross-Sell Propensity Model — Issuer Revenue Optimisation
Straive Strategic Analytics
"""
import pandas as pd
import numpy as np
from xgboost import XGBClassifier
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import roc_auc_score
import shap, joblib, logging

log = logging.getLogger(__name__)

FEATURES = [
    "revolve_rate_6m", "credit_utilisation", "tenure_months",
    "reward_redemption_flag", "avg_balance_12m", "income_band_encoded",
    "payment_behaviour_score", "txn_count_90d", "autopay_active",
    "cash_advance_count_12m", "balance_transfer_history_flag",
]
TARGET = "cross_sell_accepted"


def build_decile_lift(y_true, y_score, n_deciles=10):
    df = pd.DataFrame({"y": y_true, "score": y_score})
    df["decile"] = pd.qcut(df["score"], n_deciles, labels=False, duplicates="drop") + 1
    agg = df.groupby("decile").agg(count=("y","count"), events=("y","sum")).sort_index(ascending=False)
    agg["response_rate"] = agg["events"] / agg["count"]
    agg["cum_lift"] = (agg["events"].cumsum() / agg["count"].cumsum()) / (y_true.mean())
    return agg


def train(data_path: str, model_out: str = "cross_sell_model.pkl"):
    df = pd.read_parquet(data_path)
    X, y = df[FEATURES], df[TARGET]
    log.info(f"Training: {len(df):,} rows | positive rate: {y.mean():.2%}")

    model = XGBClassifier(
        n_estimators=400, max_depth=5, learning_rate=0.05,
        subsample=0.8, colsample_bytree=0.8,
        scale_pos_weight=(y==0).sum()/(y==1).sum(),
        eval_metric="auc", early_stopping_rounds=25,
        random_state=42, n_jobs=-1,
    )
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    oof = np.zeros(len(y))
    for fold, (tr, va) in enumerate(cv.split(X, y)):
        model.fit(X.iloc[tr], y.iloc[tr], eval_set=[(X.iloc[va], y.iloc[va])], verbose=False)
        oof[va] = model.predict_proba(X.iloc[va])[:, 1]
        log.info(f"Fold {fold+1} AUC: {roc_auc_score(y.iloc[va], oof[va]):.4f}")
    log.info(f"OOF AUC: {roc_auc_score(y, oof):.4f}")
    log.info("Decile Lift:\n" + build_decile_lift(y, oof).to_string())

    model.fit(X, y, verbose=False)
    joblib.dump(model, model_out)

    explainer = shap.TreeExplainer(model)
    shap_vals = explainer.shap_values(X.sample(min(3000, len(X)), random_state=42))
    top_feats = pd.Series(np.abs(shap_vals).mean(0), index=X.columns).sort_values(ascending=False)
    log.info("Top features:\n" + top_feats.head(8).to_string())
    return model
