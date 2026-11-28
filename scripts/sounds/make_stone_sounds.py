"""Synthesise the Daily Review stone sounds (spec 10.2).

Usage (from the repo root):

    python3 -I scripts/sounds/make_stone_sounds.py

Writes three short mono WAVs to DhammaDiary/Resources/Sounds/. They're made
from sine partials and filtered noise, with a fixed random seed, so there is
no third-party audio and running it again gives the same files. Change this
script, not the WAVs.

- stone-palm.wav  the first stone onto an empty palm: a soft, fleshy tap.
- stone-pile.wav  a stone landing on the pile: heavier and duller.
- stone-clack.wav stones touching afterwards: a light, bright clack.
"""
import os
import wave

import numpy as np

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "DhammaDiary", "Resources", "Sounds")
rng = np.random.default_rng(28112026)


def timeline(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def partial(t, freq, decay, amp=1.0, glide=0.0):
    """A decaying sine; `glide` drops the pitch a little as it fades, like a thud."""
    f = freq * (1 - glide * (1 - np.exp(-t / max(decay, 1e-4))))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    return amp * np.sin(phase) * np.exp(-t / decay)


def lowpass(x, cutoff):
    """One-pole low-pass, run twice for a gentler, duller edge."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise_burst(t, decay, cutoff_low=None, cutoff_high=None, amp=1.0):
    n = rng.standard_normal(len(t)) * np.exp(-t / decay)
    if cutoff_high:
        n = lowpass(n, cutoff_high)
    if cutoff_low:
        n = highpass(n, cutoff_low)
    return amp * n / (np.max(np.abs(n)) or 1)


def finish(x, peak):
    attack = int(RATE * 0.0008)
    x[:attack] *= np.linspace(0, 1, attack)
    tail = int(RATE * 0.004)
    x[-tail:] *= np.linspace(1, 0, tail)
    x = x - np.mean(x)
    return x / np.max(np.abs(x)) * peak


def write(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


# iPhone speakers play little below about 400 Hz, so each sound's character
# sits between 400 Hz and 4 kHz; the low thud underneath is for headphones
# (PJ, 28 Nov: nothing could be heard on the phone).


def palm():
    """Soft and fleshy: a muffled, short tap."""
    t = timeline(0.16)
    body = (partial(t, 640, 0.018, 1.0, glide=0.15) + partial(t, 1050, 0.012, 0.55)
            + partial(t, 160, 0.030, 0.5, glide=0.2))
    skin = noise_burst(t, 0.007, cutoff_low=500, cutoff_high=3200, amp=0.6)
    return finish(body + skin, 0.95)


def pile():
    """Heavier and duller: lower, longer, with a muted knock of stone."""
    t = timeline(0.26)
    body = (partial(t, 430, 0.040, 1.0, glide=0.12) + partial(t, 690, 0.028, 0.6)
            + partial(t, 980, 0.018, 0.35) + partial(t, 110, 0.050, 0.6, glide=0.2))
    knock = partial(t, 1500, 0.010, 0.3)
    grit = noise_burst(t, 0.012, cutoff_low=350, cutoff_high=1800, amp=0.5)
    return finish(body + knock + grit, 0.95)


def clack():
    """Light and bright: two stones touching."""
    t = timeline(0.12)
    modes = (partial(t, 2350, 0.020, 1.0) + partial(t, 3710, 0.014, 0.6)
             + partial(t, 5480, 0.009, 0.35) + partial(t, 1520, 0.016, 0.3))
    click = noise_burst(t, 0.0015, cutoff_low=1500, amp=0.5)
    return finish(modes + click, 0.8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("stone-palm.wav", palm())
    write("stone-pile.wav", pile())
    write("stone-clack.wav", clack())
    print("wrote", sorted(os.listdir(OUT)))
