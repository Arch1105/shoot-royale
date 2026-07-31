"""Procedurally generates all sound-effect WAV assets for Shoot Royale.
Run once (or whenever tuning sounds): python tools/generate_sfx.py
No external dependencies - stdlib only.
"""
import math
import random
import struct
import wave
import os

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")


def write_wav(path: str, samples: list[float]) -> None:
    peak = max(0.0001, max(abs(s) for s in samples))
    if peak > 1.0:
        samples = [s / peak for s in samples]
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(bytes(frames))
    print(f"wrote {path} ({len(samples) / SR:.3f}s)")


def n_samples(duration: float) -> int:
    return int(SR * duration)


def silence(duration: float) -> list[float]:
    return [0.0] * n_samples(duration)


def sine(freq: float, duration: float, phase: float = 0.0) -> list[float]:
    n = n_samples(duration)
    return [math.sin(2 * math.pi * freq * (i / SR) + phase) for i in range(n)]


def sine_sweep(f_start: float, f_end: float, duration: float) -> list[float]:
    n = n_samples(duration)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = f_start + (f_end - f_start) * t
        phase += 2 * math.pi * freq / SR
        out.append(math.sin(phase))
    return out


def noise(duration: float, seed: int = 0) -> list[float]:
    rnd = random.Random(seed)
    n = n_samples(duration)
    return [rnd.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(samples: list[float], amount: float) -> list[float]:
    out = [0.0] * len(samples)
    prev = 0.0
    for i, s in enumerate(samples):
        prev = prev + amount * (s - prev)
        out[i] = prev
    return out


def env_linear(samples: list[float], attack: float, release: float) -> list[float]:
    n = len(samples)
    a = max(1, n_samples(attack))
    r = max(1, n_samples(release))
    out = list(samples)
    for i in range(min(a, n)):
        out[i] *= i / a
    for i in range(min(r, n)):
        idx = n - 1 - i
        out[idx] *= i / r
    return out


def env_exp_decay(samples: list[float], rate: float) -> list[float]:
    n = len(samples)
    return [s * math.exp(-rate * (i / SR)) for i, s in enumerate(samples)]


def mix(*layers: list[float]) -> list[float]:
    length = max(len(l) for l in layers)
    out = [0.0] * length
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def scale(samples: list[float], gain: float) -> list[float]:
    return [s * gain for s in samples]


def pad_to(samples: list[float], length: int) -> list[float]:
    if len(samples) >= length:
        return samples[:length]
    return samples + [0.0] * (length - len(samples))


def make_footstep(seed: int) -> list[float]:
    thump = env_exp_decay(sine(90, 0.09), 55)
    crunch = env_exp_decay(lowpass(noise(0.06, seed), 0.5), 90)
    return mix(scale(thump, 0.8), scale(crunch, 0.5))


def make_swing() -> list[float]:
    body = env_linear(lowpass(noise(0.22, 11), 0.35), 0.02, 0.18)
    tone = env_linear(sine_sweep(1200, 250, 0.22), 0.02, 0.18)
    return mix(scale(body, 0.9), scale(tone, 0.25))


def make_hit() -> list[float]:
    crack = env_exp_decay(lowpass(noise(0.08, 22), 0.85), 70)
    thump = env_exp_decay(sine(70, 0.18), 30)
    return mix(scale(crack, 1.0), scale(thump, 0.9))


def make_miss() -> list[float]:
    whiff = env_linear(lowpass(noise(0.18, 33), 0.6), 0.01, 0.16)
    tone = env_linear(sine_sweep(900, 500, 0.18), 0.01, 0.16)
    return mix(scale(whiff, 0.55), scale(tone, 0.15))


def make_cooldown_ready() -> list[float]:
    a = env_exp_decay(sine(880, 0.09), 25)
    b = env_exp_decay(sine(1320, 0.12), 20)
    gap = silence(0.09)
    return mix(a, pad_to([0.0] * len(gap) + b, len(a) + len(gap) + len(b)))


def make_wall() -> list[float]:
    thump = env_exp_decay(sine(60, 0.16), 35)
    rattle = env_exp_decay(lowpass(noise(0.1, 44), 0.4), 60)
    return mix(scale(thump, 0.9), scale(rattle, 0.4))


def make_death() -> list[float]:
    sweep = env_linear(sine_sweep(500, 60, 0.45), 0.01, 0.4)
    crash = env_exp_decay(lowpass(noise(0.12, 55), 0.5), 35)
    return mix(scale(sweep, 0.8), scale(crash, 0.5))


def make_respawn() -> list[float]:
    sweep = env_linear(sine_sweep(300, 900, 0.4), 0.05, 0.2)
    shimmer = env_linear(sine_sweep(900, 1400, 0.35), 0.08, 0.2)
    return mix(scale(sweep, 0.7), scale(shimmer, 0.3))


def make_denied() -> list[float]:
    a = env_exp_decay(sine(220, 0.06), 60)
    b = env_exp_decay(sine(180, 0.06), 60)
    gap_len = n_samples(0.04)
    return a + [0.0] * gap_len + b


def make_range_beep() -> list[float]:
    return env_exp_decay(sine(1400, 0.07), 40)


def make_hum(freq: float, duration: float = 2.0) -> list[float]:
    n = n_samples(duration)
    out = []
    for i in range(n):
        t = i / SR
        vibrato = 1.0 + 0.004 * math.sin(2 * math.pi * 4.5 * t)
        out.append(0.5 * math.sin(2 * math.pi * freq * vibrato * t)
                   + 0.15 * math.sin(2 * math.pi * freq * 2 * vibrato * t))
    # fade first/last 15ms so the loop point clicks less
    return env_linear(out, 0.015, 0.015)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    write_wav(os.path.join(OUT_DIR, "footstep1.wav"), make_footstep(1))
    write_wav(os.path.join(OUT_DIR, "footstep2.wav"), make_footstep(2))
    write_wav(os.path.join(OUT_DIR, "swing.wav"), make_swing())
    write_wav(os.path.join(OUT_DIR, "hit.wav"), make_hit())
    write_wav(os.path.join(OUT_DIR, "miss.wav"), make_miss())
    write_wav(os.path.join(OUT_DIR, "cooldown_ready.wav"), make_cooldown_ready())
    write_wav(os.path.join(OUT_DIR, "wall.wav"), make_wall())
    write_wav(os.path.join(OUT_DIR, "death.wav"), make_death())
    write_wav(os.path.join(OUT_DIR, "respawn.wav"), make_respawn())
    write_wav(os.path.join(OUT_DIR, "denied.wav"), make_denied())
    write_wav(os.path.join(OUT_DIR, "range_beep.wav"), make_range_beep())

    # Distinct musical pitches per bot so each is identifiable by ear (A2, D3, A3, D4).
    hum_pitches = {1: 110.0, 2: 146.83, 3: 220.0, 4: 293.66}
    for idx, freq in hum_pitches.items():
        write_wav(os.path.join(OUT_DIR, f"hum_bot{idx}.wav"), make_hum(freq))

    print("Done.")


if __name__ == "__main__":
    main()
