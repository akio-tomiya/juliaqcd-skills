"""Fill a working folder with a made-up interrupted run for example 18.

Usage: python3 interrupted_run.py WORKDIR

Writes runs/b60/ as hmc_puregauge.jl would have left it after a crash at
trajectory 412: meta.toml, state.toml (next trajectory 401), a synthetic
history.csv, placeholder checkpoints every 50 trajectories, and a log that
ends in "Killed". The numbers are synthetic; only the layout is real.
"""
import math
import os
import random
import sys

work = sys.argv[1]
out = os.path.join(work, "runs", "b60")
os.makedirs(os.path.join(out, "checkpoints"))
with open(os.path.join(out, "meta.toml"), "w") as f:
    f.write('''beta = 6.0
colors = 3
flow_time = 2.88
lattice = [16, 16, 16, 16]
ntraj = 1000
out = "runs/b60"
q_every = 10
restart = false
save_every = 50
seed = 1234
start = "cold"
steps = 40
tau = 1.0
julia_version = "1.11.7"
host = "ws1"
threads = 1
started = "2026-11-02T21:14:05"

[packages]
Gaugefields = "1.0.3"
JACC = "0.4.3"
QCDMeasurements = "1.0.1"
''')
with open(os.path.join(out, "state.toml"), "w") as f:
    f.write("next_trajectory = 401\n")
random.seed(7)
lines = ["traj,dH,exp_minus_dH,accepted,plaquette,polyakov_re,polyakov_im,Q,seconds"]
P = 1.0
for k in range(1, 413):
    P = 0.5937 + (P - 0.5937) * 0.85 + random.gauss(0, 0.0004)
    dH = random.gauss(0.05, 0.3)
    acc = 1 if random.random() < min(1, math.exp(-dH)) else 0
    Q = round(random.gauss(0, 1.5)) + random.gauss(0, 0.03) if k % 10 == 0 else float("nan")
    lines.append(f"{k},{dH:.12e},{math.exp(-dH):.12e},{acc},{P:.15e},"
                 f"{random.gauss(0, 0.002):.15e},{random.gauss(0, 0.002):.15e},"
                 f"{Q:.10e},{random.gauss(41.2, 0.4):.4f}")
with open(os.path.join(out, "history.csv"), "w") as f:
    f.write("\n".join(lines) + "\n")
for k in range(50, 401, 50):
    with open(os.path.join(out, "checkpoints", f"conf_{k:06d}.jld2"), "w") as f:
        f.write("placeholder for the test\n")
with open(os.path.join(work, "runs", "b60.log"), "w") as f:
    f.write("Killed\n")
