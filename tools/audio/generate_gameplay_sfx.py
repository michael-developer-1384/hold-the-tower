"""Generate dry, mechanical placeholder gameplay SFX for HODL THE TOWER.
Run once; commit the WAVs. Style: ridiculously serious — no pew, no casino.
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
SR = 22050
RNG = random.Random(42)


def write_wav(path, samples, sr=SR):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        w.writeframes(frames)


def env(n, attack, release, sr=SR):
    out = []
    dur = n / sr
    for i in range(n):
        t = i / sr
        e = 1.0
        if t < attack:
            e = t / max(attack, 1e-6)
        if t > dur - release:
            e = max(0.0, (dur - t) / max(release, 1e-6))
        out.append(e)
    return out


def noise(n, vol=0.2):
    return [RNG.uniform(-1, 1) * vol for _ in range(n)]


def tone(freq, dur, vol=0.2, attack=0.002, release=0.03, wave_type="sine", sr=SR):
    n = int(sr * dur)
    e = env(n, attack, release, sr)
    out = []
    for i in range(n):
        t = i / sr
        if wave_type == "sine":
            s = math.sin(2 * math.pi * freq * t)
        elif wave_type == "tri":
            s = 2 * abs(2 * ((t * freq) % 1) - 1) - 1
        elif wave_type == "square":
            s = 1.0 if (t * freq) % 1 < 0.5 else -1.0
        else:
            s = RNG.uniform(-1, 1)
        # slight pitch drop for weight
        out.append(s * vol * e[i])
    return out


def blend(parts):
    out = []
    for p in parts:
        out += p
    return out


def mix(tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max(0.001, max(abs(s) for s in out))
    if peak > 0.95:
        out = [s * 0.95 / peak for s in out]
    return out


def click(dur=0.04, vol=0.35):
    n = int(SR * dur)
    e = env(n, 0.0005, dur * 0.7)
    return [noise(1, vol)[0] * e[i] * (1.0 - i / n) for i in range(n)]


# --- Event palette ---

specs = {}

# Sentry fire: electromechanical snap + metal click + soft body (~80ms)
specs["sentry_fire.wav"] = mix(
    [
        click(0.025, 0.45),
        tone(180, 0.07, vol=0.22, attack=0.001, release=0.05, wave_type="tri"),
        tone(920, 0.035, vol=0.12, attack=0.0005, release=0.02, wave_type="square"),
        tone(2400, 0.018, vol=0.06, attack=0.0003, release=0.01),
    ]
)

# Projectile impact: short crack/tick
specs["projectile_hit.wav"] = mix(
    [
        click(0.018, 0.4),
        tone(1400, 0.025, vol=0.14, attack=0.0003, release=0.015, wave_type="square"),
        tone(320, 0.03, vol=0.1, attack=0.001, release=0.02, wave_type="tri"),
    ]
)

# Guard attack: mechanical whoosh/swing
specs["guard_attack.wav"] = mix(
    [
        [n * e for n, e in zip(noise(int(SR * 0.08), 0.18), env(int(SR * 0.08), 0.01, 0.04))],
        tone(140, 0.07, vol=0.12, attack=0.01, release=0.04, wave_type="tri"),
    ]
)

# Enemy attack: thinner servo swing
specs["enemy_attack.wav"] = mix(
    [
        [n * e for n, e in zip(noise(int(SR * 0.07), 0.14), env(int(SR * 0.07), 0.008, 0.035))],
        tone(220, 0.055, vol=0.1, attack=0.008, release=0.03, wave_type="tri"),
    ]
)

# Melee hit: dry armor knock
specs["melee_hit.wav"] = mix(
    [
        click(0.02, 0.5),
        tone(110, 0.05, vol=0.2, attack=0.001, release=0.035, wave_type="tri"),
        tone(680, 0.03, vol=0.1, attack=0.0005, release=0.02),
    ]
)

# Enemy death: digital collapse + pitch drop
n_d = int(SR * 0.18)
death = []
for i in range(n_d):
    t = i / SR
    e = max(0.0, 1.0 - t / 0.18)
    f = 280 * (1.0 - 0.55 * (t / 0.18))
    s = 0.18 * math.sin(2 * math.pi * f * t) * e
    s += 0.08 * RNG.uniform(-1, 1) * e * e
    if i % 37 == 0:
        s += 0.05 * e
    death.append(s)
specs["enemy_death.wav"] = death

# Guard death: heavier power-down
n_g = int(SR * 0.22)
gdeath = []
for i in range(n_g):
    t = i / SR
    e = max(0.0, 1.0 - t / 0.22)
    f = 160 * (1.0 - 0.65 * (t / 0.22))
    s = 0.24 * math.sin(2 * math.pi * f * t) * e
    s += 0.1 * math.sin(2 * math.pi * (f * 0.5) * t) * e
    s += 0.06 * RNG.uniform(-1, 1) * e
    gdeath.append(s)
specs["guard_death.wav"] = gdeath

# Tower build: CLUNK / LOCK / power-on
specs["tower_build.wav"] = blend(
    [
        mix(
            [
                click(0.03, 0.55),
                tone(90, 0.09, vol=0.28, attack=0.001, release=0.06, wave_type="tri"),
            ]
        ),
        tone(440, 0.06, vol=0.12, attack=0.005, release=0.04),
        tone(660, 0.08, vol=0.1, attack=0.01, release=0.05),
    ]
)

# Wave start: deep double pulse
specs["wave_start.wav"] = blend(
    [
        tone(90, 0.1, vol=0.28, attack=0.005, release=0.06, wave_type="sine"),
        [0.0] * int(SR * 0.05),
        tone(110, 0.12, vol=0.24, attack=0.005, release=0.07, wave_type="sine"),
    ]
)

# Wave complete: two clean tones, subtle positive
specs["wave_complete.wav"] = blend(
    [
        tone(392, 0.08, vol=0.16, attack=0.005, release=0.05),
        tone(523, 0.12, vol=0.14, attack=0.008, release=0.07),
    ]
)

# Core hit: deep impact + warn
specs["core_hit.wav"] = mix(
    [
        tone(70, 0.14, vol=0.35, attack=0.001, release=0.1, wave_type="tri"),
        click(0.04, 0.4),
        tone(880, 0.08, vol=0.1, attack=0.002, release=0.05, wave_type="square"),
    ]
)

# Level complete: precise system success sting (~1.2s)
specs["level_complete.wav"] = blend(
    [
        tone(262, 0.1, vol=0.14),
        tone(330, 0.1, vol=0.14),
        tone(392, 0.12, vol=0.14),
        tone(523, 0.28, vol=0.16, release=0.15),
    ]
)

# Game over: short deep failure
specs["game_over.wav"] = blend(
    [
        tone(140, 0.16, vol=0.26, attack=0.01, release=0.1, wave_type="tri"),
        tone(90, 0.22, vol=0.22, attack=0.02, release=0.14, wave_type="sine"),
    ]
)

for name, samples in specs.items():
    path = os.path.join(OUT, name)
    write_wav(path, samples)
    print("wrote", path, "frames", len(samples))

print("done", len(specs), "files")
