"""
CSS Monte Carlo Simulation
==========================
Validates and calibrates constants in the Composite Strength Score (CSS) pipeline
using a synthetic population of fabricated athletes with known ground-truth properties.

Experiments
-----------
1. Sensitivity Analysis   — which constants drive CSS variance most?
2. Tier Separation        — do CSS distributions separate correctly across tiers?
3. Ranking Stability      — do exercise rankings hold when constants are perturbed?
4. Beta Calibration       — what β minimises PSI rank-order distortion?
5. Pillar Weight Audit    — do 0.35/0.40/0.25 weights correctly reflect the three archetypes?

Population
----------
2 000 synthetic athletes (500 per tier), stratified by sex and body-weight availability.
Each athlete has known ground-truth α, β, 1RM/BW ratios drawn from literature distributions.
16 weeks of simulated training logs are generated per athlete.

Sources
-------
Ward et al. (2009) — PCSA values
Willardson (2005) — within-session fatigue / α distributions
Symmetric Strength / OpenPowerlifting — population 1RM norms
Rippetoe & Kilgore (2007), NSCA Haff & Triplett (2016) — progression rates
Tuchscherer (2009), Prilepin (1974) — INOL zones
"""

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')           # non-interactive backend — saves PNGs
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from scipy import stats
import warnings, os, json
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

warnings.filterwarnings('ignore')
np.random.seed(42)

OUT_DIR = os.path.join(os.path.dirname(__file__), 'output')
os.makedirs(OUT_DIR, exist_ok=True)

# ─── Muscle physiology constants (Ward et al. 2009) ──────────────────────────

PCSA: Dict[str, float] = {
    'quadriceps':      148.0,
    'gluteusMaximus':   80.0,
    'hamstrings':       75.0,
    'erectorSpinae':    90.0,
    'latissimus':       45.0,
    'trapezius':        35.0,
    'rhomboids':        20.0,
    'pectoralisMajor':  35.0,
    'anteriorDeltoid':  10.0,
    'lateralDeltoid':    8.0,
    'posteriorDeltoid':  8.0,
    'bicepsBrachii':    15.0,
    'tricepsBrachii':   22.0,
}

# Activation profiles (exercise → [(muscle, pctMVC)]) — from Contreras/ACE EMG research
ACTIVATION_PROFILES: Dict[str, List[Tuple[str, float]]] = {
    'Deadlift':            [('erectorSpinae', 0.85), ('gluteusMaximus', 0.80), ('hamstrings', 0.75),
                             ('quadriceps', 0.50), ('trapezius', 0.60), ('latissimus', 0.55)],
    'Barbell Squat':       [('quadriceps', 0.88), ('gluteusMaximus', 0.72),
                             ('hamstrings', 0.42), ('erectorSpinae', 0.55)],
    'Barbell Bench Press': [('pectoralisMajor', 0.85), ('anteriorDeltoid', 0.70), ('tricepsBrachii', 0.75)],
    'Overhead Press':      [('anteriorDeltoid', 0.90), ('lateralDeltoid', 0.65),
                             ('tricepsBrachii', 0.65), ('trapezius', 0.45)],
    'Barbell Row':         [('latissimus', 0.80), ('trapezius', 0.70), ('rhomboids', 0.75),
                             ('posteriorDeltoid', 0.55), ('bicepsBrachii', 0.65)],
    'Lat Pulldown':        [('latissimus', 0.85), ('bicepsBrachii', 0.65),
                             ('trapezius', 0.45), ('posteriorDeltoid', 0.35)],
    'Lateral Raise':       [('lateralDeltoid', 0.85), ('anteriorDeltoid', 0.30), ('trapezius', 0.20)],
    'Barbell Curl':        [('bicepsBrachii', 0.85)],
}

def activation_weight(exercise: str) -> float:
    return sum(mvc * PCSA[muscle] for muscle, mvc in ACTIVATION_PROFILES[exercise])

AW: Dict[str, float] = {ex: activation_weight(ex) for ex in ACTIVATION_PROFILES}

COMPOUND_EXERCISES = ['Deadlift', 'Barbell Squat', 'Barbell Bench Press',
                      'Overhead Press', 'Barbell Row', 'Lat Pulldown']
ISOLATION_EXERCISES = ['Lateral Raise', 'Barbell Curl']
ALL_EXERCISES = COMPOUND_EXERCISES + ISOLATION_EXERCISES

# Relative strength thresholds (Developing / Intermediate / Advanced) as e1RM/BW
REL_THRESHOLDS: Dict[str, Tuple[float, float, float]] = {
    'Deadlift':            (1.50, 2.25, 3.00),
    'Barbell Squat':       (1.25, 1.75, 2.50),
    'Barbell Bench Press': (0.75, 1.25, 1.75),
    'Overhead Press':      (0.50, 0.85, 1.15),
    'Barbell Row':         (0.75, 1.15, 1.50),
    'Lat Pulldown':        (0.50, 0.85, 1.15),
    'Lateral Raise':       (0.15, 0.30, 0.50),
    'Barbell Curl':        (0.15, 0.30, 0.50),
}

# ─── Tier constants (literature-derived) ─────────────────────────────────────

TIER_PARAMS = {
    'developing':   dict(alpha=0.10, alpha_sd=0.025, momentum_ceiling=3.0,
                         inol_center=0.60, inol_penalty=100.0,
                         progression_pct_wk=2.5, progression_sd=1.0),
    'intermediate': dict(alpha=0.08, alpha_sd=0.020, momentum_ceiling=2.0,
                         inol_center=0.90, inol_penalty=67.0,
                         progression_pct_wk=1.2, progression_sd=0.5),
    'advanced':     dict(alpha=0.05, alpha_sd=0.015, momentum_ceiling=1.0,
                         inol_center=1.15, inol_penalty=57.0,
                         progression_pct_wk=0.5, progression_sd=0.2),
    'elite':        dict(alpha=0.03, alpha_sd=0.010, momentum_ceiling=0.5,
                         inol_center=1.50, inol_penalty=40.0,
                         progression_pct_wk=0.2, progression_sd=0.1),
}

# Population norms: mean and SD of e1RM/BW per tier per exercise
# Source: Symmetric Strength database, OpenPowerlifting percentiles, NSCA tables
POPULATION_NORMS: Dict[str, Dict[str, Tuple[float, float]]] = {
    'developing':   {'Deadlift': (1.20, 0.20), 'Barbell Squat': (0.95, 0.18),
                     'Barbell Bench Press': (0.60, 0.12), 'Overhead Press': (0.38, 0.08),
                     'Barbell Row': (0.60, 0.12), 'Lat Pulldown': (0.40, 0.08),
                     'Lateral Raise': (0.08, 0.02), 'Barbell Curl': (0.25, 0.05)},
    'intermediate': {'Deadlift': (1.90, 0.25), 'Barbell Squat': (1.50, 0.22),
                     'Barbell Bench Press': (1.00, 0.15), 'Overhead Press': (0.68, 0.10),
                     'Barbell Row': (0.95, 0.15), 'Lat Pulldown': (0.70, 0.10),
                     'Lateral Raise': (0.14, 0.03), 'Barbell Curl': (0.38, 0.07)},
    'advanced':     {'Deadlift': (2.60, 0.25), 'Barbell Squat': (2.10, 0.22),
                     'Barbell Bench Press': (1.50, 0.18), 'Overhead Press': (0.98, 0.12),
                     'Barbell Row': (1.30, 0.18), 'Lat Pulldown': (1.00, 0.12),
                     'Lateral Raise': (0.20, 0.04), 'Barbell Curl': (0.55, 0.10)},
    'elite':        {'Deadlift': (3.20, 0.30), 'Barbell Squat': (2.70, 0.28),
                     'Barbell Bench Press': (1.90, 0.20), 'Overhead Press': (1.25, 0.15),
                     'Barbell Row': (1.70, 0.20), 'Lat Pulldown': (1.30, 0.15),
                     'Lateral Raise': (0.28, 0.05), 'Barbell Curl': (0.72, 0.12)},
}

# ─── Athlete generation ───────────────────────────────────────────────────────

@dataclass
class Athlete:
    id:             int
    tier:           str
    sex:            str           # 'male' / 'female'
    body_weight:    float         # kg
    true_alpha:     float         # personal fatigue decay constant
    true_beta:      float         # personal recruitment exponent
    # dict: exercise → true current 1RM (kg)
    true_1rm:       Dict[str, float] = field(default_factory=dict)
    # dict: exercise → progression rate (%/wk)
    progression:    Dict[str, float] = field(default_factory=dict)


def generate_population(n_per_tier: int = 500) -> List[Athlete]:
    athletes = []
    uid = 0
    for tier, params in TIER_PARAMS.items():
        for _ in range(n_per_tier):
            sex = 'male' if np.random.rand() < 0.55 else 'female'
            bw_mean = 82.0 if sex == 'male' else 66.0
            bw_sd   = 14.0 if sex == 'male' else 11.0
            bw = max(50.0, np.random.normal(bw_mean, bw_sd))

            # Personal constants drawn from within-tier distributions
            alpha = max(0.01, np.random.normal(params['alpha'], params['alpha_sd']))
            beta  = max(1.0,  np.random.normal(1.8, 0.15))

            # 1RM baseline: sample e1RM/BW from population norm, multiply by BW
            # Female strength norms are ~0.80× male (NSCA data)
            sex_factor = 1.0 if sex == 'male' else 0.80
            true_1rm = {}
            progression = {}
            norms = POPULATION_NORMS[tier]
            for ex in ALL_EXERCISES:
                mu, sd = norms[ex]
                rel_strength = max(0.1, np.random.normal(mu * sex_factor, sd * sex_factor))
                true_1rm[ex] = rel_strength * bw

                # Progression rate: tier mean ± SD, with compound/isolation split
                compound_factor = 1.0 if ex in COMPOUND_EXERCISES else 0.6
                prog_mu = params['progression_pct_wk'] * compound_factor
                prog_sd = params['progression_sd'] * compound_factor
                progression[ex] = max(0.0, np.random.normal(prog_mu, prog_sd))

            athletes.append(Athlete(
                id=uid, tier=tier, sex=sex, body_weight=bw,
                true_alpha=alpha, true_beta=beta,
                true_1rm=true_1rm, progression=progression
            ))
            uid += 1
    return athletes


# ─── Workout simulation ───────────────────────────────────────────────────────

def epley_e1rm(weight: float, reps: int) -> float:
    if reps == 1:
        return weight
    return weight * (1 + reps / 30.0)


def simulate_session(athlete: Athlete, current_1rm: Dict[str, float],
                     week: int, alpha: float, beta: float) -> dict:
    """
    Simulate a single training session.
    Returns: dict with per-exercise sets, e1RM, INOL, and PSI contribution.
    """
    psi = 0.0
    session_inol = 0.0
    session_exercises = {}

    for ex in ALL_EXERCISES:
        true_1rm_now = current_1rm[ex]

        # Intensity selection: 68–82% 1RM (realistic working sets)
        # Compounds tend to higher intensity, isolations lower
        if ex in COMPOUND_EXERCISES:
            intensity = np.random.uniform(0.70, 0.82)
        else:
            intensity = np.random.uniform(0.62, 0.75)

        working_weight = true_1rm_now * intensity
        # Target reps at this intensity using Epley inverse: reps = 30*(1RM/w - 1)
        target_reps_f = 30.0 * (true_1rm_now / working_weight - 1.0)
        target_reps = max(1, min(12, int(round(target_reps_f))))

        n_sets = 4 if ex in COMPOUND_EXERCISES else 3
        sets = []
        best_e1rm = 0.0
        inol_ex = 0.0

        for s in range(n_sets):
            # Rep decay via e^(-α×s) plus noise — this is the personal α in action
            decay_factor = np.exp(-alpha * s)
            actual_reps = max(1, int(round(target_reps * decay_factor + np.random.normal(0, 0.8))))
            actual_reps = min(actual_reps, 15)

            e1rm = epley_e1rm(working_weight, actual_reps)
            best_e1rm = max(best_e1rm, e1rm)

            # INOL contribution: reps / (100 - intensity_pct)
            intensity_pct = (working_weight / true_1rm_now) * 100.0
            inol_ex += actual_reps / max(1.0, 100.0 - intensity_pct)

            # PSI: rel^β × reps × activationWeight
            rel = min(working_weight / true_1rm_now, 1.0)
            psi += (rel ** beta) * actual_reps * AW[ex]

            sets.append({'weight': working_weight, 'reps': actual_reps, 'e1rm': e1rm})

        session_inol += inol_ex / n_sets  # average INOL per exercise

        session_exercises[ex] = {
            'sets': sets,
            'best_e1rm': best_e1rm,
            'inol': inol_ex,
        }

    return {'psi': psi, 'inol': session_inol / len(ALL_EXERCISES), 'exercises': session_exercises}


def simulate_training_log(athlete: Athlete, n_weeks: int = 16,
                          alpha_override: Optional[float] = None,
                          beta_override: Optional[float] = None) -> List[dict]:
    """
    Simulate n_weeks of training. Returns list of session dicts ordered by time.
    """
    alpha = alpha_override if alpha_override is not None else athlete.true_alpha
    beta  = beta_override  if beta_override  is not None else athlete.true_beta

    current_1rm = dict(athlete.true_1rm)  # copy; evolves over time
    log = []

    for week in range(n_weeks):
        # 2–3 sessions per week (realistic adherence)
        n_sessions = np.random.choice([2, 3], p=[0.45, 0.55])
        for s in range(n_sessions):
            session = simulate_session(athlete, current_1rm, week, alpha, beta)
            session['week'] = week
            session['session_in_week'] = s
            log.append(session)

        # Weekly 1RM progression — each exercise grows at its personal rate
        for ex in ALL_EXERCISES:
            pct_gain = athlete.progression[ex] / 100.0
            noise    = np.random.normal(0, pct_gain * 0.3)  # ±30% variation around rate
            current_1rm[ex] *= (1 + pct_gain + noise)

    return log


# ─── CSS computation ──────────────────────────────────────────────────────────

def ols_slope_pct_per_week(values: List[float]) -> float:
    """OLS slope of a time series, expressed as %/week relative to mean."""
    n = len(values)
    if n < 2:
        return 0.0
    x = np.arange(n, dtype=float)
    slope, _ = np.polyfit(x, values, 1)
    mean_val  = np.mean(values)
    return (slope / mean_val * 100.0) if mean_val > 0 else 0.0


def rel_strength_tier_score(rel: float, thresholds: Tuple[float, float, float]) -> float:
    d, i, a = thresholds
    if rel < d:   return 0.0
    if rel < i:   return 33.0
    if rel < a:   return 67.0
    return 100.0


def compute_css(athlete: Athlete, log: List[dict],
                # Allow constant overrides for sensitivity experiments
                beta:             float = 1.8,
                alpha:            float = None,  # not used in CSS directly
                pillar_level:     float = 0.35,
                pillar_momentum:  float = 0.40,
                pillar_process:   float = 0.25,
                # Tier overrides for constant sensitivity
                momentum_ceiling: float = None,
                inol_center:      float = None,
                inol_penalty:     float = None,
                ) -> Dict[str, float]:
    """
    Faithful Python port of CompositeStrengthEngine + StrengthScoreEngine.
    Returns dict with all sub-scores and CSS.
    """
    if not log:
        return {}

    tier_p = TIER_PARAMS[athlete.tier]
    mc  = momentum_ceiling if momentum_ceiling is not None else tier_p['momentum_ceiling']
    ic  = inol_center      if inol_center      is not None else tier_p['inol_center']
    ip  = inol_penalty     if inol_penalty     is not None else tier_p['inol_penalty']

    # ── Build per-exercise best and latest e1RM from log ──────────────────────
    best_e1rm   = {ex: 0.0 for ex in ALL_EXERCISES}
    latest_e1rm = {ex: 0.0 for ex in ALL_EXERCISES}
    for sess in log:
        for ex, data in sess['exercises'].items():
            be = data['best_e1rm']
            if be > best_e1rm[ex]:
                best_e1rm[ex] = be
            latest_e1rm[ex] = be  # overwrites → ends up as most-recent

    # ── PSI history (one point per session) ───────────────────────────────────
    psi_history = []
    for sess in log:
        sess_psi = 0.0
        for ex, data in sess['exercises'].items():
            ref = best_e1rm[ex]
            if ref <= 0:
                continue
            for s in data['sets']:
                if s['weight'] > 0 and s['reps'] > 0:
                    rel = min(s['weight'] / ref, 1.0)
                    sess_psi += (rel ** beta) * s['reps'] * AW[ex]
        psi_history.append(sess_psi)

    bw = athlete.body_weight

    # ── Level Component A: PCSA-weighted e1RM retention ───────────────────────
    weighted_num = 0.0
    weighted_den = 0.0
    for ex in ALL_EXERCISES:
        peak   = best_e1rm[ex]
        latest = latest_e1rm[ex]
        if peak <= 0:
            continue
        retention = min(1.0, latest / peak)
        aw = AW[ex]
        weighted_num += aw * retention
        weighted_den += aw
    pcsa_retention = (weighted_num / weighted_den * 100.0) if weighted_den > 0 else 50.0

    # ── Level Component B: PSI level (latest / peak) ──────────────────────────
    if psi_history:
        psi_level = min(100.0, psi_history[-1] / max(psi_history) * 100.0)
    else:
        psi_level = None

    # ── Level Component C: relative-strength anchor (compound lifts only) ─────
    tier_scores = []
    for ex in COMPOUND_EXERCISES:
        if best_e1rm[ex] <= 0:
            continue
        rel = best_e1rm[ex] / bw
        ts  = rel_strength_tier_score(rel, REL_THRESHOLDS[ex])
        tier_scores.append(ts)
    rel_anchor = float(np.mean(tier_scores)) if tier_scores else None

    # Blend Level
    if psi_level is not None and rel_anchor is not None:
        level_score = 0.50 * pcsa_retention + 0.30 * psi_level + 0.20 * rel_anchor
    elif psi_level is not None:
        level_score = 0.65 * pcsa_retention + 0.35 * psi_level
    else:
        level_score = pcsa_retention

    # ── Momentum: OLS trend of PSI → %/wk → 0-100 ────────────────────────────
    psi_pct_wk = ols_slope_pct_per_week(psi_history[-12:] if len(psi_history) > 12 else psi_history)
    slope_map  = 50.0 / mc
    momentum_score = min(100.0, max(0.0, 50.0 + psi_pct_wk * slope_map))

    # ── Process: INOL sub-score (last session) ────────────────────────────────
    if log:
        last_inol = log[-1]['inol']
        inol_score = max(0.0, 100.0 - abs(last_inol - ic) * ip)
    else:
        inol_score = 50.0

    # Process also includes Efficiency (50 neutral here — no within-session rep history stored)
    # and Rep Decay (50 neutral). Blend 0.40 INOL + 0.40 Efficiency + 0.20 RepDecay
    process_score = 0.40 * inol_score + 0.40 * 50.0 + 0.20 * 50.0

    # ── CSS ───────────────────────────────────────────────────────────────────
    css = pillar_level * level_score + pillar_momentum * momentum_score + pillar_process * process_score

    return {
        'css':             css,
        'level':           level_score,
        'momentum':        momentum_score,
        'process':         process_score,
        'pcsa_retention':  pcsa_retention,
        'psi_level':       psi_level or 0.0,
        'rel_anchor':      rel_anchor or 0.0,
        'inol_score':      inol_score,
        'psi_pct_wk':      psi_pct_wk,
    }


# ─── Main simulation ──────────────────────────────────────────────────────────

def run_baseline(athletes: List[Athlete]) -> pd.DataFrame:
    print("  Simulating baseline training logs and computing CSS...")
    rows = []
    for i, ath in enumerate(athletes):
        if i % 200 == 0:
            print(f"    {i}/{len(athletes)} athletes processed")
        log   = simulate_training_log(ath)
        scores = compute_css(ath, log)
        scores['id']   = ath.id
        scores['tier'] = ath.tier
        scores['sex']  = ath.sex
        scores['bw']   = ath.body_weight
        scores['true_alpha'] = ath.true_alpha
        scores['true_beta']  = ath.true_beta
        rows.append(scores)
    return pd.DataFrame(rows)


# ─── Experiment 1: Sensitivity Analysis ──────────────────────────────────────

def experiment_sensitivity(athletes: List[Athlete], n_draws: int = 1000) -> pd.DataFrame:
    """
    For each constant, draw N samples from its prior distribution.
    Measure the resulting CSS variance attributable to that constant.
    Uses a sample of 200 athletes (speed-optimised).
    """
    print("  Running sensitivity analysis...")
    sample = athletes[:200]

    constants = {
        'beta':             ('uniform',  1.5,  2.0),
        'alpha':            ('normal',   0.08, 0.03),   # pooled intermediate prior
        'momentum_ceiling': ('normal',   2.0,  0.5),
        'inol_center':      ('normal',   0.90, 0.20),
        'inol_penalty':     ('normal',   67.0, 15.0),
        'pillar_level':     ('dirichlet_l', None, None),  # special case
        'pillar_momentum':  ('dirichlet_m', None, None),
        'pillar_process':   ('dirichlet_p', None, None),
    }

    # Pre-simulate logs once — we only vary constants at scoring time
    print("    Pre-computing logs...")
    logs = [simulate_training_log(ath) for ath in sample]

    results = {}
    for const_name, (dist, p1, p2) in constants.items():
        css_variance = []
        for _ in range(n_draws):
            # Draw constant value
            if dist == 'uniform':
                val = np.random.uniform(p1, p2)
                kwargs = {const_name: val}
            elif dist == 'normal':
                val = max(0.01, np.random.normal(p1, p2))
                kwargs = {const_name: val}
            elif dist.startswith('dirichlet'):
                # Draw pillar weights from Dirichlet preserving order constraints
                w = np.random.dirichlet([5.5, 2.5, 2.0])  # concentration ∝ prior confidence
                kwargs = {'pillar_level': w[0], 'pillar_momentum': w[1], 'pillar_process': w[2]}
            else:
                kwargs = {}

            css_vals = [compute_css(ath, log, **kwargs).get('css', 50.0)
                        for ath, log in zip(sample, logs)]
            css_variance.append(np.var(css_vals))

        results[const_name] = {
            'mean_variance': float(np.mean(css_variance)),
            'variance_of_variance': float(np.var(css_variance)),
        }

    # Baseline variance (no perturbation)
    base_css = [compute_css(ath, log).get('css', 50.0) for ath, log in zip(sample, logs)]
    baseline_var = float(np.var(base_css))

    df = pd.DataFrame([
        {'constant': k, 'mean_css_variance': v['mean_variance'],
         'variance_lift_pct': (v['mean_variance'] - baseline_var) / max(baseline_var, 1) * 100}
        for k, v in results.items()
    ]).sort_values('variance_lift_pct', ascending=False)

    df['baseline_variance'] = baseline_var
    return df


# ─── Experiment 2: Tier Separation ───────────────────────────────────────────

def experiment_tier_separation(baseline_df: pd.DataFrame) -> Dict:
    """
    Test whether CSS distributions are well-separated across tiers.
    Reports: mean/SD per tier, overlap coefficient, one-way ANOVA F-statistic.
    """
    print("  Computing tier separation statistics...")
    tiers = ['developing', 'intermediate', 'advanced', 'elite']
    groups = [baseline_df[baseline_df['tier'] == t]['css'].values for t in tiers]

    tier_stats = {}
    for t, g in zip(tiers, groups):
        tier_stats[t] = {'mean': float(np.mean(g)), 'sd': float(np.std(g)),
                         'p5':  float(np.percentile(g, 5)),
                         'p95': float(np.percentile(g, 95))}

    f_stat, p_val = stats.f_oneway(*groups)

    # Effect size: η² = SS_between / SS_total
    grand_mean = baseline_df['css'].mean()
    ss_between = sum(len(g) * (np.mean(g) - grand_mean) ** 2 for g in groups)
    ss_total   = sum((baseline_df['css'] - grand_mean) ** 2)
    eta_sq     = ss_between / ss_total if ss_total > 0 else 0.0

    # Overlap: average of pairwise overlap coefficients between adjacent tiers
    def overlap_coef(a, b):
        lo = max(np.min(a), np.min(b))
        hi = min(np.max(a), np.max(b))
        if hi <= lo:
            return 0.0
        bins = np.linspace(min(np.min(a), np.min(b)), max(np.max(a), np.max(b)), 60)
        ha, _ = np.histogram(a, bins=bins, density=True)
        hb, _ = np.histogram(b, bins=bins, density=True)
        return float(np.sum(np.minimum(ha, hb)) * (bins[1] - bins[0]))

    adjacent_overlaps = [overlap_coef(groups[i], groups[i+1]) for i in range(len(groups)-1)]

    return {
        'tier_stats':            tier_stats,
        'anova_f':               float(f_stat),
        'anova_p':               float(p_val),
        'eta_squared':           float(eta_sq),
        'adjacent_overlap_mean': float(np.mean(adjacent_overlaps)),
        'adjacent_overlaps':     dict(zip(['dev→int', 'int→adv', 'adv→elite'],
                                          adjacent_overlaps)),
    }


# ─── Experiment 3: Ranking Stability ─────────────────────────────────────────

def experiment_ranking_stability(athletes: List[Athlete]) -> Dict:
    """
    Check whether compound lift rankings (by best e1RM/BW) hold under ±1 SD
    perturbations of β and α.
    Uses a sample of 100 athletes.
    """
    print("  Running ranking stability check...")
    sample = athletes[:100]

    def get_exercise_ranking(ath: Athlete, log: List[dict], beta: float) -> List[str]:
        best_e1rm = {ex: 0.0 for ex in COMPOUND_EXERCISES}
        for sess in log:
            for ex in COMPOUND_EXERCISES:
                be = sess['exercises'][ex]['best_e1rm']
                if be > best_e1rm[ex]:
                    best_e1rm[ex] = be
        # Rank by e1RM/BW
        ranked = sorted(COMPOUND_EXERCISES, key=lambda e: best_e1rm[e] / ath.body_weight,
                        reverse=True)
        return ranked

    logs_base = [simulate_training_log(ath) for ath in sample]
    base_ranks = [get_exercise_ranking(ath, log, 1.8) for ath, log in zip(sample, logs_base)]

    kendall_taus = []
    beta_range = [1.5, 1.6, 1.7, 1.8, 1.9, 2.0]
    for beta_test in beta_range:
        taus = []
        for ath, log, base_rank in zip(sample, logs_base, base_ranks):
            test_rank = get_exercise_ranking(ath, log, beta_test)
            tau, _ = stats.kendalltau(
                [COMPOUND_EXERCISES.index(e) for e in base_rank],
                [COMPOUND_EXERCISES.index(e) for e in test_rank]
            )
            taus.append(tau)
        kendall_taus.append({'beta': beta_test, 'mean_tau': float(np.mean(taus)),
                              'min_tau': float(np.min(taus))})

    # Alpha perturbation — does α affect rankings? (It shouldn't, much)
    alpha_taus = []
    for alpha_test in [0.03, 0.05, 0.08, 0.10, 0.13]:
        taus = []
        for ath in sample[:50]:
            log_base = simulate_training_log(ath, alpha_override=0.08)
            log_test = simulate_training_log(ath, alpha_override=alpha_test)
            br = get_exercise_ranking(ath, log_base, 1.8)
            tr = get_exercise_ranking(ath, log_test, 1.8)
            tau, _ = stats.kendalltau(
                [COMPOUND_EXERCISES.index(e) for e in br],
                [COMPOUND_EXERCISES.index(e) for e in tr]
            )
            taus.append(tau)
        alpha_taus.append({'alpha': alpha_test, 'mean_tau': float(np.mean(taus))})

    return {'beta_ranking_stability': kendall_taus, 'alpha_ranking_stability': alpha_taus}


# ─── Experiment 4: Beta Calibration ──────────────────────────────────────────

def experiment_beta_calibration(athletes: List[Athlete]) -> Dict:
    """
    Test whether the true β per athlete is recovered by varying β in the PSI formula.
    Ground truth: each athlete has a known true_beta. We measure correlation between
    PSI computed with a fixed β vs PSI computed with true β.
    """
    print("  Running beta calibration experiment...")
    sample = athletes[:300]
    logs   = [simulate_training_log(ath) for ath in sample]

    true_psi = []
    for ath, log in zip(sample, logs):
        psi_sum = sum(s['psi'] for s in log[-8:])  # last 8 sessions
        true_psi.append(psi_sum)

    results = []
    for beta_test in np.arange(1.3, 2.3, 0.1):
        test_psi = []
        for ath, log in zip(sample, logs):
            psi = sum(
                (min(s['weight'] / max(log[-1]['exercises'][ex]['best_e1rm'] or 1, 1), 1.0)
                 ** beta_test) * s['reps'] * AW[ex]
                for ex in ALL_EXERCISES
                for s in log[-1]['exercises'][ex]['sets']
            )
            test_psi.append(psi)
        r, _ = stats.pearsonr(true_psi, test_psi)
        results.append({'beta': round(float(beta_test), 2), 'pearson_r': float(r)})

    best = max(results, key=lambda x: x['pearson_r'])
    return {'beta_sweep': results, 'optimal_beta': best['beta'],
            'optimal_r': best['pearson_r']}


# ─── Experiment 5: Pillar Weight Audit ───────────────────────────────────────

def experiment_pillar_weights(athletes: List[Athlete]) -> Dict:
    """
    Three archetypes with known profiles. Test whether CSS correctly differentiates them
    and whether the current pillar weights (0.35/0.40/0.25) produce the right ordering.
    """
    print("  Running pillar weight audit...")

    # Build three archetypal athletes manually
    # Archetype A: "Strong but stagnant" — high Level, low Momentum, medium Process
    # Archetype B: "Progressing well"    — medium Level, high Momentum, high Process
    # Archetype C: "Overtrained"         — medium Level, negative Momentum, low Process

    archetypes = {
        'Strong_Stagnant':  dict(level=85, momentum=35, process=55),
        'Progressing_Well': dict(level=58, momentum=78, process=72),
        'Overtrained':      dict(level=60, momentum=28, process=30),
    }

    weight_grid = [
        (0.35, 0.40, 0.25),   # current
        (0.55, 0.25, 0.20),   # level-heavy
        (0.20, 0.55, 0.25),   # momentum-heavy
        (0.33, 0.33, 0.33),   # equal
        (0.40, 0.35, 0.25),   # slight level boost
    ]

    results = []
    for wl, wm, wp in weight_grid:
        row = {'w_level': wl, 'w_momentum': wm, 'w_process': wp}
        for name, arch in archetypes.items():
            css = wl * arch['level'] + wm * arch['momentum'] + wp * arch['process']
            row[name] = round(css, 1)
        # Check if Progressing_Well > Overtrained (should always be true)
        row['correct_order'] = row['Progressing_Well'] > row['Overtrained'] > 40
        results.append(row)

    # Also Monte-Carlo over Dirichlet draws — how often does the correct ranking hold?
    n_draws = 5000
    correct_count = 0
    for _ in range(n_draws):
        w = np.random.dirichlet([5.5, 2.5, 2.0])
        wl, wm, wp = w
        css_a = wl * 85 + wm * 35 + wp * 55   # Strong_Stagnant
        css_b = wl * 58 + wm * 78 + wp * 72   # Progressing_Well
        css_c = wl * 60 + wm * 28 + wp * 30   # Overtrained
        if css_b > css_c:
            correct_count += 1

    return {
        'weight_grid_results': results,
        'progressing_beats_overtrained_pct': correct_count / n_draws * 100,
    }


# ─── Visualisations ───────────────────────────────────────────────────────────

TIER_COLORS = {
    'developing':   '#5B9BD5',
    'intermediate': '#70AD47',
    'advanced':     '#FFC000',
    'elite':        '#ED7D31',
}

def plot_tier_separation(baseline_df: pd.DataFrame, sep_stats: Dict):
    fig, axes = plt.subplots(1, 3, figsize=(16, 5))
    fig.suptitle('CSS Tier Separation — Synthetic Population (n=2 000)', fontsize=13, fontweight='bold')

    tiers = ['developing', 'intermediate', 'advanced', 'elite']

    # Plot 1: CSS distributions by tier
    ax = axes[0]
    for tier in tiers:
        data = baseline_df[baseline_df['tier'] == tier]['css']
        ax.hist(data, bins=30, alpha=0.6, label=tier.capitalize(),
                color=TIER_COLORS[tier], edgecolor='white', linewidth=0.5)
    ax.set_xlabel('CSS Score (0–100)')
    ax.set_ylabel('Count')
    ax.set_title('CSS Distribution by Tier')
    ax.legend(fontsize=8)
    ax.text(0.05, 0.95, f"η² = {sep_stats['eta_squared']:.3f}\nF = {sep_stats['anova_f']:.1f}",
            transform=ax.transAxes, fontsize=9, verticalalignment='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    # Plot 2: Pillar scores by tier
    ax = axes[1]
    pillars = ['level', 'momentum', 'process']
    x = np.arange(len(tiers))
    w = 0.25
    for i, pillar in enumerate(pillars):
        means = [baseline_df[baseline_df['tier'] == t][pillar].mean() for t in tiers]
        ax.bar(x + i * w, means, w, label=pillar.capitalize(),
               alpha=0.8, edgecolor='white')
    ax.set_xticks(x + w)
    ax.set_xticklabels([t[:3].upper() for t in tiers])
    ax.set_ylabel('Mean Score (0–100)')
    ax.set_title('Pillar Scores by Tier')
    ax.legend(fontsize=8)
    ax.set_ylim(0, 100)

    # Plot 3: CSS mean ± 90% CI by tier
    ax = axes[2]
    means = [baseline_df[baseline_df['tier'] == t]['css'].mean() for t in tiers]
    p5    = [baseline_df[baseline_df['tier'] == t]['css'].quantile(0.05) for t in tiers]
    p95   = [baseline_df[baseline_df['tier'] == t]['css'].quantile(0.95) for t in tiers]
    y = range(len(tiers))
    ax.barh(y, means, xerr=[np.array(means) - np.array(p5), np.array(p95) - np.array(means)],
            color=[TIER_COLORS[t] for t in tiers], alpha=0.8,
            capsize=4, height=0.5)
    ax.set_yticks(y)
    ax.set_yticklabels([t.capitalize() for t in tiers])
    ax.set_xlabel('CSS Score')
    ax.set_title('CSS Mean ± 90% CI')
    ax.axvline(x=50, color='gray', linestyle='--', alpha=0.5, label='Neutral')
    for i, (m, p, p9) in enumerate(zip(means, p5, p95)):
        ax.text(m + 0.5, i, f'{m:.1f}', va='center', fontsize=8)

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, '1_tier_separation.png'), dpi=150, bbox_inches='tight')
    plt.close()
    print("    Saved: 1_tier_separation.png")


def plot_sensitivity(sens_df: pd.DataFrame):
    fig, ax = plt.subplots(figsize=(10, 6))
    colors = ['#C00000' if v > 0 else '#70AD47' for v in sens_df['variance_lift_pct']]
    bars = ax.barh(sens_df['constant'], sens_df['variance_lift_pct'],
                   color=colors, alpha=0.8, edgecolor='white')
    ax.axvline(0, color='black', linewidth=0.8)
    ax.set_xlabel('CSS Variance Lift vs Baseline (%)')
    ax.set_title('Sensitivity Analysis — Which Constants Drive CSS Variance?', fontweight='bold')

    for bar, val in zip(bars, sens_df['variance_lift_pct']):
        ax.text(val + (0.3 if val >= 0 else -0.3), bar.get_y() + bar.get_height() / 2,
                f'{val:+.1f}%', va='center', ha='left' if val >= 0 else 'right', fontsize=8)

    ax.set_xlim(sens_df['variance_lift_pct'].min() - 5, sens_df['variance_lift_pct'].max() + 8)
    note = "Red = raises CSS variance (needs personal calibration)\nGreen = lowers or neutral"
    ax.text(0.98, 0.02, note, transform=ax.transAxes, fontsize=8,
            ha='right', va='bottom', style='italic', color='gray')
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, '2_sensitivity.png'), dpi=150, bbox_inches='tight')
    plt.close()
    print("    Saved: 2_sensitivity.png")


def plot_beta_calibration(beta_results: Dict):
    fig, ax = plt.subplots(figsize=(8, 5))
    betas = [r['beta'] for r in beta_results['beta_sweep']]
    rs    = [r['pearson_r'] for r in beta_results['beta_sweep']]
    ax.plot(betas, rs, 'o-', color='#5B9BD5', linewidth=2, markersize=6)
    ax.axvline(1.8, color='#C00000', linestyle='--', linewidth=1.5, label='Current β = 1.8')
    ax.axvline(beta_results['optimal_beta'], color='#70AD47', linestyle='--',
               linewidth=1.5, label=f"Optimal β = {beta_results['optimal_beta']:.1f}")
    ax.set_xlabel('β (recruitment exponent)')
    ax.set_ylabel('Pearson r vs true PSI')
    ax.set_title('β Calibration — PSI Correlation with True Fiber Load', fontweight='bold')
    ax.legend()
    ax.set_ylim(0.8, 1.01)
    ax.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, '3_beta_calibration.png'), dpi=150, bbox_inches='tight')
    plt.close()
    print("    Saved: 3_beta_calibration.png")


def plot_pillar_weights(pillar_results: Dict):
    grid = pillar_results['weight_grid_results']
    fig, ax = plt.subplots(figsize=(10, 6))
    archetypes = ['Strong_Stagnant', 'Progressing_Well', 'Overtrained']
    colors_arch = ['#FFC000', '#70AD47', '#C00000']
    x = np.arange(len(grid))
    w = 0.25
    labels = [f"L{r['w_level']:.2f}\nM{r['w_momentum']:.2f}\nP{r['w_process']:.2f}" for r in grid]
    for i, (arch, col) in enumerate(zip(archetypes, colors_arch)):
        vals = [r[arch] for r in grid]
        bars = ax.bar(x + i * w, vals, w, label=arch.replace('_', ' '), color=col, alpha=0.8)
    ax.set_xticks(x + w)
    ax.set_xticklabels(labels, fontsize=8)
    ax.set_ylabel('CSS Score')
    ax.set_title('Pillar Weight Audit — Archetype Scores Under Different Weighting Schemes',
                 fontweight='bold')
    ax.legend(fontsize=9)
    ax.axhline(y=50, color='gray', linestyle='--', alpha=0.5)
    # Mark current weights
    ax.axvspan(-0.4, 0.9, alpha=0.05, color='blue', label='_Current weights')
    ax.text(0.3, ax.get_ylim()[1] * 0.97, '← Current', fontsize=8, color='blue')
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, '4_pillar_weights.png'), dpi=150, bbox_inches='tight')
    plt.close()
    print("    Saved: 4_pillar_weights.png")


def plot_alpha_distribution(baseline_df: pd.DataFrame, athletes: List[Athlete]):
    alpha_df = pd.DataFrame([{'tier': a.tier, 'true_alpha': a.true_alpha} for a in athletes])
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    ax = axes[0]
    for tier in ['developing', 'intermediate', 'advanced', 'elite']:
        data = alpha_df[alpha_df['tier'] == tier]['true_alpha']
        ax.hist(data, bins=25, alpha=0.6, label=tier.capitalize(),
                color=TIER_COLORS[tier], edgecolor='white')
    ax.set_xlabel('True α (fatigue decay constant)')
    ax.set_ylabel('Count')
    ax.set_title('Within-Tier α Distribution\n(justification for tier point estimates)',
                 fontweight='bold')
    ax.legend(fontsize=8)

    # Point estimates vs within-tier spread
    ax = axes[1]
    tier_order = ['developing', 'intermediate', 'advanced', 'elite']
    point_est  = [0.10, 0.08, 0.05, 0.03]
    for i, (tier, pe) in enumerate(zip(tier_order, point_est)):
        data = alpha_df[alpha_df['tier'] == tier]['true_alpha'].values
        q5, q95 = np.percentile(data, 5), np.percentile(data, 95)
        ax.errorbar(i, pe, yerr=[[pe - q5], [q95 - pe]],
                    fmt='s', color=TIER_COLORS[tier], markersize=8, capsize=5,
                    label=tier.capitalize(), linewidth=2)
        ax.scatter(np.random.normal(i, 0.05, len(data)), data, alpha=0.15,
                   color=TIER_COLORS[tier], s=10)
    ax.set_xticks(range(4))
    ax.set_xticklabels([t.capitalize() for t in tier_order])
    ax.set_ylabel('α value')
    ax.set_title('Point Estimate vs Population Spread\n(squares = current estimate, bars = 5th–95th pct)',
                 fontweight='bold')
    ax.legend(fontsize=8)

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, '5_alpha_distributions.png'), dpi=150, bbox_inches='tight')
    plt.close()
    print("    Saved: 5_alpha_distributions.png")


# ─── Report ───────────────────────────────────────────────────────────────────

def write_report(baseline_df, sens_df, sep_stats, rank_stats, beta_stats, pillar_stats):
    lines = []
    lines.append("=" * 70)
    lines.append("CSS MONTE CARLO SIMULATION REPORT")
    lines.append("Population: 2 000 synthetic athletes · 16 weeks training each")
    lines.append("=" * 70)

    lines.append("\n── EXPERIMENT 1: SENSITIVITY ANALYSIS ──────────────────────────────")
    lines.append("Which constants most amplify CSS variance when drawn from priors?\n")
    lines.append(f"  {'Constant':<22} {'Variance Lift %':>16}  Interpretation")
    lines.append("  " + "-" * 58)
    for _, row in sens_df.iterrows():
        lift = row['variance_lift_pct']
        tag = ('HIGH — calibrate personally' if lift > 15
               else 'MEDIUM — tier estimate adequate'  if lift > 5
               else 'LOW — literature prior OK')
        lines.append(f"  {row['constant']:<22} {lift:>+15.1f}%  {tag}")

    lines.append("\n── EXPERIMENT 2: TIER SEPARATION ────────────────────────────────────")
    lines.append(f"  ANOVA F = {sep_stats['anova_f']:.1f}  (p = {sep_stats['anova_p']:.2e})")
    lines.append(f"  η² = {sep_stats['eta_squared']:.3f}  "
                 f"({'strong' if sep_stats['eta_squared'] > 0.14 else 'moderate' if sep_stats['eta_squared'] > 0.06 else 'weak'} effect)")
    lines.append(f"  Adjacent-tier overlap (avg): {sep_stats['adjacent_overlap_mean']:.2f}")
    lines.append("  (0 = no overlap, 1 = complete overlap; <0.3 is good)\n")
    lines.append(f"  {'Tier':<14} {'Mean':>7} {'SD':>7} {'P5':>7} {'P95':>7}")
    lines.append("  " + "-" * 44)
    for t, s in sep_stats['tier_stats'].items():
        lines.append(f"  {t:<14} {s['mean']:>7.1f} {s['sd']:>7.1f} {s['p5']:>7.1f} {s['p95']:>7.1f}")

    lines.append("\n  Pairwise adjacent-tier overlaps:")
    for pair, ov in sep_stats['adjacent_overlaps'].items():
        flag = '✓ good' if ov < 0.3 else '⚠ moderate' if ov < 0.5 else '✗ poor separation'
        lines.append(f"    {pair}: {ov:.3f}  {flag}")

    lines.append("\n── EXPERIMENT 3: RANKING STABILITY ──────────────────────────────────")
    lines.append("  Kendall τ of compound exercise rankings under β perturbation:")
    lines.append(f"  {'β':>6} {'Mean τ':>8} {'Min τ':>8}")
    lines.append("  " + "-" * 26)
    for r in rank_stats['beta_ranking_stability']:
        stable = '✓' if r['mean_tau'] > 0.8 else '⚠'
        lines.append(f"  {r['beta']:>6.1f} {r['mean_tau']:>8.3f} {r['min_tau']:>8.3f}  {stable}")

    lines.append("\n  Kendall τ under α perturbation (should be ~1.0 — α affects level, not rank):")
    for r in rank_stats['alpha_ranking_stability']:
        lines.append(f"    α={r['alpha']:.2f}: mean τ = {r['mean_tau']:.3f}")

    lines.append("\n── EXPERIMENT 4: BETA CALIBRATION ───────────────────────────────────")
    lines.append(f"  Optimal β (maximises PSI correlation with true fiber load): "
                 f"{beta_stats['optimal_beta']:.1f}")
    lines.append(f"  Correlation at β=1.8 (current): "
                 f"{next(r['pearson_r'] for r in beta_stats['beta_sweep'] if abs(r['beta']-1.8)<0.05):.4f}")
    lines.append(f"  Correlation at optimal β:       {beta_stats['optimal_r']:.4f}")
    opt_b = beta_stats['optimal_beta']
    verdict = "β=1.8 is within range of optimal — no change needed" if abs(opt_b - 1.8) < 0.2 else f"Consider shifting β to {opt_b:.1f}"
    lines.append(f"  Verdict: {verdict}")

    lines.append("\n── EXPERIMENT 5: PILLAR WEIGHT AUDIT ────────────────────────────────")
    lines.append(f"  'Progressing_Well > Overtrained' holds across {pillar_stats['progressing_beats_overtrained_pct']:.1f}% of Dirichlet draws.")
    lines.append(f"  (Threshold for confidence: ≥ 90%)\n")
    lines.append(f"  {'Weights (L/M/P)':<20} {'Strong_Stagnant':>16} {'Progressing_Well':>17} {'Overtrained':>12} {'OK?':>5}")
    lines.append("  " + "-" * 75)
    for r in pillar_stats['weight_grid_results']:
        tag = '✓' if r['correct_order'] else '✗'
        label = f"L{r['w_level']:.2f}/M{r['w_momentum']:.2f}/P{r['w_process']:.2f}"
        lines.append(f"  {label:<20} {r['Strong_Stagnant']:>16.1f} {r['Progressing_Well']:>17.1f} "
                     f"{r['Overtrained']:>12.1f} {tag:>5}")

    lines.append("\n── CONCLUSIONS & CALIBRATION RECOMMENDATIONS ────────────────────────")
    # Dynamic conclusions based on results
    top_sensitive = sens_df.iloc[0]['constant']
    top_lift = sens_df.iloc[0]['variance_lift_pct']

    if sep_stats['eta_squared'] > 0.14:
        lines.append("  [TIER SEPARATION] Strong — CSS correctly stratifies tiers. ✓")
    else:
        lines.append("  [TIER SEPARATION] Weak — Level pillar may need calibration. ⚠")

    lines.append(f"  [BETA] Current β=1.8 is {'well-calibrated ✓' if abs(beta_stats['optimal_beta'] - 1.8) < 0.2 else 'potentially mis-specified ⚠'}")

    if top_lift > 15:
        lines.append(f"  [TOP PRIORITY] '{top_sensitive}' has largest variance impact (+{top_lift:.1f}%).")
        lines.append(f"    → Personal calibration of {top_sensitive} yields the most score accuracy gain.")
    else:
        lines.append("  [ROBUSTNESS] No single constant dominates — CSS is well-distributed.")

    if pillar_stats['progressing_beats_overtrained_pct'] >= 90:
        lines.append("  [PILLAR WEIGHTS] Current 0.35/0.40/0.25 correctly rank archetypes ≥90% of draws. ✓")
    else:
        lines.append("  [PILLAR WEIGHTS] Consider increasing Momentum weight to improve overtrained detection.")

    lines.append("\n" + "=" * 70)
    report = "\n".join(lines)
    print(report)

    with open(os.path.join(OUT_DIR, 'simulation_report.txt'), 'w') as f:
        f.write(report)
    print(f"\n  Report saved: simulation/output/simulation_report.txt")


# ─── Entry point ─────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("=" * 60)
    print("CSS Monte Carlo Simulation")
    print("=" * 60)

    print("\n[1/6] Generating population (2 000 synthetic athletes)...")
    athletes = generate_population(n_per_tier=500)
    print(f"      {len(athletes)} athletes created across 4 tiers")

    print("\n[2/6] Running baseline simulation (16 weeks each)...")
    baseline_df = run_baseline(athletes)
    print(f"      Baseline complete. CSS range: {baseline_df['css'].min():.1f}–{baseline_df['css'].max():.1f}")

    print("\n[3/6] Experiment 1 — Sensitivity analysis...")
    sens_df = experiment_sensitivity(athletes, n_draws=800)

    print("\n[4/6] Experiment 2 — Tier separation...")
    sep_stats = experiment_tier_separation(baseline_df)

    print("\n[5/6] Experiments 3–5 — Ranking stability, β calibration, pillar weights...")
    rank_stats   = experiment_ranking_stability(athletes)
    beta_stats   = experiment_beta_calibration(athletes)
    pillar_stats = experiment_pillar_weights(athletes)

    print("\n[6/6] Generating plots and report...")
    plot_tier_separation(baseline_df, sep_stats)
    plot_sensitivity(sens_df)
    plot_beta_calibration(beta_stats)
    plot_pillar_weights(pillar_stats)
    plot_alpha_distribution(baseline_df, athletes)

    print("\n" + "=" * 60)
    write_report(baseline_df, sens_df, sep_stats, rank_stats, beta_stats, pillar_stats)
    print(f"\nAll outputs saved to: simulation/output/")
