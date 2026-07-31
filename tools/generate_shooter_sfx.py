"""Procedurally generates the shooter mode's sound-effect WAV assets, in the
same spirit as generate_sfx.py (stdlib-only synthesis, no external audio
sourced from anywhere) since no bundled CC0 pack under tools/sfx_src has a
gunshot. Run once (or whenever tuning sounds): python tools/generate_shooter_sfx.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from generate_sfx import (  # noqa: E402
    OUT_DIR, write_wav, n_samples, silence, sine, sine_sweep, noise,
    lowpass, env_linear, env_exp_decay, mix, scale, pad_to, make_hum,
)


def make_gunshot() -> list[float]:
    crack = env_exp_decay(noise(0.04, 101), 160)
    body = env_exp_decay(lowpass(noise(0.12, 102), 0.6), 45)
    thump = env_exp_decay(sine(85, 0.15), 40)
    return mix(scale(crack, 1.0), scale(body, 0.7), scale(thump, 0.9))


def make_reload() -> list[float]:
    def click(pitch: float, seed: int) -> list[float]:
        rap = env_exp_decay(lowpass(noise(0.04, seed), 0.7), 130)
        tick = env_exp_decay(sine(pitch, 0.03), 200)
        return mix(scale(rap, 0.8), scale(tick, 0.5))

    click1 = click(1800, 201)
    click2 = click(1200, 202)
    gap = silence(0.22)
    total_len = len(click1) + len(gap) + len(click2)
    return mix(pad_to(click1, total_len), pad_to(gap + click2, total_len))


def make_jump() -> list[float]:
    sweep = env_linear(sine_sweep(300, 750, 0.18), 0.01, 0.12)
    puff = env_exp_decay(lowpass(noise(0.05, 301), 0.5), 90)
    return mix(scale(sweep, 0.6), scale(puff, 0.4))


def make_proximity_beep() -> list[float]:
    return env_exp_decay(sine(700, 0.09), 45)


def make_lock_beep() -> list[float]:
    ping = env_exp_decay(sine(1600, 0.06), 50)
    overtone = env_exp_decay(sine(3200, 0.05), 60)
    return mix(ping, scale(overtone, 0.3))


def make_lock_on_full() -> list[float]:
    return make_hum(2000.0, 0.6)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUT_DIR, "gunshot.wav"), make_gunshot())
    write_wav(os.path.join(OUT_DIR, "reload.wav"), make_reload())
    write_wav(os.path.join(OUT_DIR, "jump.wav"), make_jump())
    write_wav(os.path.join(OUT_DIR, "proximity_beep.wav"), make_proximity_beep())
    write_wav(os.path.join(OUT_DIR, "lock_beep.wav"), make_lock_beep())
    write_wav(os.path.join(OUT_DIR, "lock_on_full.wav"), make_lock_on_full())
    print("Done.")


if __name__ == "__main__":
    main()
