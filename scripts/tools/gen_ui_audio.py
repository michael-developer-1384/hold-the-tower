import math
import os
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "ui")
os.makedirs(OUT, exist_ok=True)


def write_wav(path, samples, sr=22050):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        w.writeframes(frames)


def tone(freq, dur, sr=22050, vol=0.25, attack=0.005, release=0.04, wave_type="sine"):
    n = int(sr * dur)
    out = []
    for i in range(n):
        t = i / sr
        env = 1.0
        if t < attack:
            env = t / attack
        if t > dur - release:
            env = max(0.0, (dur - t) / release)
        if wave_type == "sine":
            s = math.sin(2 * math.pi * freq * t)
        elif wave_type == "tri":
            s = 2 * abs(2 * ((t * freq) % 1) - 1) - 1
        else:
            s = 1.0 if (t * freq) % 1 < 0.5 else -1.0
        out.append(s * vol * env)
    return out


def blend(parts):
    out = []
    for p in parts:
        out += p
    return out


specs = {
    "ui_focus.wav": tone(880, 0.035, vol=0.08, wave_type="tri"),
    "ui_accept.wav": blend([tone(440, 0.04, vol=0.18), tone(660, 0.06, vol=0.14)]),
    "ui_back.wav": blend([tone(520, 0.04, vol=0.14), tone(320, 0.06, vol=0.12)]),
    "ui_error.wav": blend(
        [
            tone(180, 0.08, vol=0.2, wave_type="square"),
            tone(140, 0.1, vol=0.16, wave_type="square"),
        ]
    ),
    "ui_modal.wav": tone(300, 0.09, vol=0.12, wave_type="tri"),
    "ui_research.wav": blend([tone(500, 0.05, vol=0.12), tone(750, 0.08, vol=0.1)]),
    "ui_reward.wav": blend(
        [tone(523, 0.05, vol=0.14), tone(659, 0.05, vol=0.14), tone(784, 0.1, vol=0.12)]
    ),
    "ui_boot.wav": blend(
        [tone(220, 0.12, vol=0.1), tone(330, 0.16, vol=0.12), tone(440, 0.2, vol=0.1)]
    ),
}

sr = 22050
amb = []
for i in range(sr * 4):
    t = i / sr
    s = (
        0.04 * math.sin(2 * math.pi * 55 * t)
        + 0.02 * math.sin(2 * math.pi * 82.5 * t)
        + 0.01 * math.sin(2 * math.pi * 110 * t + 0.3)
    )
    if int(t * 2) % 7 == 0 and (t * 2) % 1 < 0.01:
        s += 0.03 * math.sin(2 * math.pi * 900 * t)
    amb.append(s)
specs["ui_ambient.wav"] = amb

for name, samples in specs.items():
    write_wav(os.path.join(OUT, name), samples)
    print("wrote", name, len(samples))
print("done")
