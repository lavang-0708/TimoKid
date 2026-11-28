#!/usr/bin/env python3
"""Tổng hợp âm thanh TimoKid (PLAN T2-08): hiệu ứng ngắn + 2 bản nhạc nền.

Mọi âm đều do script này tự tạo (sóng sin/tam giác có đường bao và vang
nhẹ), không lấy từ nguồn ngoài nên không vướng giấy phép. Chạy lại cho
cùng kết quả (hạt giống cố định).

Đầu ra (trong ``app/assets/sounds/``):
  - SFX mono 44,1 kHz 16-bit WAV: tap, swoosh, hatch, level_up, purchase,
    gift_open, streak, error_soft.
  - Nhạc nền stereo OGG Vorbis: music_town.ogg (Đô trưởng, 110 BPM, 32
    ô nhịp) và music_room.ogg (Fa trưởng, 85 BPM, 24 ô nhịp). Độ dài đúng
    số ô nhịp và vang xử lý vòng tròn nên lặp liền mạch.
  - Nhạc chuẩn hóa khoảng -16 LUFS (đỉnh <= -1 dBFS); SFX đỉnh ~ -2 dBFS
    nên to hơn nhạc.

Cách dùng:
    python3 tools/audio/generate_audio.py [--out app/assets/sounds]
                                         [--preview /tmp/preview.mp3]
Cần numpy; ffmpeg (libvorbis) để mã hóa OGG và đo độ ồn.
"""

import argparse
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
SEED = 20241128


# --- Công cụ cơ bản -------------------------------------------------------

def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def tgrid(dur):
    return np.arange(int(round(dur * SR))) / SR


def env_ad(n, attack, decay_tau, release=0.01):
    """Đường bao: lên nhanh, tắt mũ, xuống 0 mượt ở cuối."""
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay_tau)
    r = int(release * SR)
    if r > 0 and n > r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def place(buf, sig, start_s, gain=1.0, pan=0.0, circular=False):
    """Cộng ``sig`` vào ``buf`` (n,2) tại ``start_s``; pan -1..1."""
    i = int(round(start_s * SR))
    n = len(sig)
    l = gain * np.cos((pan + 1) * np.pi / 4)
    r = gain * np.sin((pan + 1) * np.pi / 4)
    total = buf.shape[0]
    if circular:
        idx = (np.arange(n) + i) % total
        np.add.at(buf[:, 0], idx, sig * l)
        np.add.at(buf[:, 1], idx, sig * r)
    else:
        m = min(n, total - i)
        if m > 0:
            buf[i:i + m, 0] += sig[:m] * l
            buf[i:i + m, 1] += sig[:m] * r


def tone(freq, dur, partials, attack=0.005, tau=0.3, release=0.02):
    """Cộng các họa âm [(tỉ lệ tần số, biên độ, hệ số tắt nhanh hơn)]."""
    n = int(round(dur * SR))
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, fast in partials:
        e = np.exp(-t / (tau / fast))
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * e
    a = np.minimum(1.0, t / attack)
    out *= a
    r = int(release * SR)
    if r > 0 and n > r:
        out[-r:] *= np.linspace(1, 0, r)
    return out


# Âm sắc (tỉ lệ họa âm, biên độ, độ tắt nhanh tương đối)
MARIMBA = [(1, 1.0, 1.0), (4, 0.28, 3.0), (10, 0.05, 8.0)]
MUSICBOX = [(1, 1.0, 1.0), (2.0, 0.35, 1.8), (4.1, 0.18, 3.5), (6.3, 0.05, 6.0)]
BELL = [(1, 1.0, 1.0), (2.76, 0.45, 1.6), (5.4, 0.22, 2.4), (8.9, 0.08, 4.0)]
SOFTBASS = [(1, 1.0, 1.0), (2, 0.42, 1.5), (3, 0.12, 2.0)]
PLUCK = [(1, 1.0, 1.0), (2, 0.5, 1.8), (3, 0.2, 2.5)]


def triangle(freq, dur, attack=0.02, release=0.05, tau=None):
    n = int(round(dur * SR))
    t = np.arange(n) / SR
    ph = (freq * t) % 1.0
    w = 2 * np.abs(2 * ph - 1) - 1
    e = np.minimum(1.0, t / attack)
    if tau:
        e = e * np.exp(-t / tau)
    r = int(release * SR)
    if r > 0 and n > r:
        e[-r:] *= np.linspace(1, 0, r)
    return w * e


def lowpass(x, cutoff):
    """Lọc thông thấp một cực (nhẹ, đủ làm mềm)."""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def reverb_ir(rng, length_s=1.1, tau=0.28, stereo=True):
    n = int(length_s * SR)
    t = np.arange(n) / SR
    shape = np.exp(-t / tau)
    cols = 2 if stereo else 1
    ir = rng.standard_normal((n, cols)) * shape[:, None]
    # Làm tối đuôi vang: thông thấp nhẹ để không chói.
    for c in range(cols):
        ir[:, c] = lowpass(ir[:, c], 3500)
    ir[0, :] = 0
    ir /= np.sqrt((ir ** 2).sum(axis=0, keepdims=True))
    return ir


def apply_reverb(x, ir, wet, circular):
    """x (n,ch). circular=True: vang vòng tròn (nhạc lặp liền mạch)."""
    n = x.shape[0]
    cols = x.shape[1]
    size = n if circular else n + ir.shape[0]
    nfft = 1 << int(np.ceil(np.log2(size + (0 if circular else 1))))
    if circular:
        nfft = n  # vòng tròn đúng độ dài lặp
    out = np.zeros((size, cols))
    for c in range(cols):
        irc = ir[:, c if ir.shape[1] > 1 else 0]
        if circular:
            # gập đuôi IR vào độ dài n để tích chập vòng tròn
            h = np.zeros(n)
            for k in range(0, len(irc), n):
                seg = irc[k:k + n]
                h[:len(seg)] += seg
            y = np.fft.irfft(np.fft.rfft(x[:, c]) * np.fft.rfft(h), n)
            out[:, c] = y
        else:
            f = 1 << int(np.ceil(np.log2(n + len(irc))))
            y = np.fft.irfft(np.fft.rfft(x[:, c], f) * np.fft.rfft(irc, f), f)
            out[:, c] = y[:size]
    base = np.zeros((size, cols))
    base[:n] = x
    return (1 - wet) * base + wet * out * 1.0


def echo(x, delay_s, fb, taps):
    """Vang dội (echo) đơn giản cho SFX mono."""
    d = int(delay_s * SR)
    out = np.zeros(len(x) + d * taps)
    out[:len(x)] += x
    for k in range(1, taps + 1):
        out[k * d:k * d + len(x)] += x * (fb ** k)
    return out


def soft_limit(x, ceiling=0.89):
    return np.tanh(x / ceiling) * ceiling


def peak_norm(x, peak_db):
    p = np.max(np.abs(x))
    return x * (10 ** (peak_db / 20) / p) if p > 0 else x


# --- Đo độ ồn bằng ffmpeg -------------------------------------------------

def write_wav(path, x, channels):
    data = np.clip(x, -1, 1)
    pcm = (data * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def measure_lufs(x):
    with tempfile.TemporaryDirectory() as d:
        p = pathlib.Path(d) / 'm.wav'
        write_wav(p, x, 1 if x.ndim == 1 else x.shape[1])
        r = subprocess.run(
            ['ffmpeg', '-hide_banner', '-nostats', '-i', str(p), '-af',
             'ebur128=peak=true', '-f', 'null', '-'],
            capture_output=True, text=True)
    m = re.findall(r'I:\s+(-?[\d.]+) LUFS', r.stderr)
    return float(m[-1]) if m else None


def normalize_music(x, target=-16.0, peak_db=-1.5):
    """Đưa về ~target LUFS, giới hạn mềm để đỉnh <= peak_db."""
    y = x.copy()
    for _ in range(4):
        lufs = measure_lufs(y)
        if lufs is None:
            break
        y = y * 10 ** ((target - lufs) / 20)
        y = soft_limit(y, 10 ** (peak_db / 20) * 0.97)
    return y


# --- Hiệu ứng ngắn --------------------------------------------------------

def mono_sfx(parts, total, rng_unused=None):
    buf = np.zeros(int(total * SR))
    for start, sig, gain in parts:
        i = int(start * SR)
        m = min(len(sig), len(buf) - i)
        if m > 0:
            buf[i:i + m] += sig[:m] * gain
    return buf


def sfx_tap():
    n = int(0.13 * SR)
    t = np.arange(n) / SR
    f = 620 * (1 + 0.12 * (1 - np.exp(-t / 0.01)))
    sig = np.sin(2 * np.pi * f * t) * env_ad(n, 0.003, 0.035)
    sig += 0.3 * np.sin(2 * np.pi * f * 2 * t) * env_ad(n, 0.003, 0.02)
    return peak_norm(sig, -4)


def sfx_swoosh(rng):
    dur = 0.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # Bộ lọc trạng thái biến thiên (band-pass), tâm quét 350 -> 2200 Hz.
    fc = 350 * (2200 / 350) ** (t / dur)
    q = 0.9
    low = band = 0.0
    out = np.empty(n)
    for i in range(n):
        f = 2 * np.sin(np.pi * fc[i] / SR)
        low += f * band
        high = noise[i] - low - q * band
        band += f * high
        out[i] = band
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    sig = out * e
    # Thêm một nốt sin trượt nhẹ cho "đáng yêu".
    glide = np.sin(2 * np.pi * np.cumsum(400 + 600 * t / dur) / SR) * e * 0.35
    sig = peak_norm(sig, -8) + glide * 0.3
    return peak_norm(sig, -4)


def sfx_hatch(rng):
    parts = []
    # 3 tiếng nứt vỏ: cú "tik" nhỏ + hơi ồn lọc cao.
    for k, (ts, f0) in enumerate([(0.0, 2600), (0.15, 2200), (0.29, 3000)]):
        n = int(0.05 * SR)
        t = np.arange(n) / SR
        crack = rng.standard_normal(n) * env_ad(n, 0.001, 0.008)
        crack = highpass(crack, 1800)
        tik = np.sin(2 * np.pi * f0 * t) * env_ad(n, 0.001, 0.012)
        parts.append((ts, 0.55 * peak_norm(crack, -3) + 0.45 * tik, 0.6))
    # Tiếng "pop" mở vỏ: sin trượt lên.
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    pop = np.sin(2 * np.pi * np.cumsum(300 + 700 * (t / 0.16)) / SR)
    parts.append((0.42, pop * env_ad(n, 0.004, 0.05), 0.5))
    # Lấp lánh: chuông bay lên Đô-Mi-Sol-Đô.
    for k, m in enumerate([84, 88, 91, 96, 100]):
        parts.append((0.50 + 0.07 * k, tone(mtof(m), 0.5, BELL, tau=0.18), 0.28))
    sig = mono_sfx(parts, 1.0)
    sig = echo(sig, 0.11, 0.35, 3)[:int(1.0 * SR)]
    fade = int(0.1 * SR)
    sig[-fade:] *= np.linspace(1, 0, fade)
    return peak_norm(sig, -2)


def sfx_level_up():
    parts = []
    step = 0.11
    for k, m in enumerate([72, 76, 79]):  # Đô Mi Sol bay lên
        parts.append((k * step, tone(mtof(m), 0.5, MUSICBOX, tau=0.35), 0.5))
        parts.append((k * step, triangle(mtof(m), 0.3, tau=0.2), 0.2))
    t0 = 3 * step + 0.02
    for m, g in [(72, 0.4), (76, 0.4), (79, 0.4), (84, 0.55)]:
        parts.append((t0, tone(mtof(m), 1.1, MUSICBOX, tau=0.6), g))
        parts.append((t0, triangle(mtof(m), 1.0, attack=0.01, tau=0.5), g * 0.4))
    parts.append((t0 + 0.08, tone(mtof(96), 0.8, BELL, tau=0.3), 0.18))
    parts.append((t0 + 0.2, tone(mtof(100), 0.8, BELL, tau=0.3), 0.14))
    sig = mono_sfx(parts, 1.6)
    sig = echo(sig, 0.16, 0.3, 3)[:int(1.6 * SR)]
    fade = int(0.25 * SR)
    sig[-fade:] *= np.linspace(1, 0, fade)
    return peak_norm(sig, -2)


def sfx_purchase(rng):
    parts = []
    # Hai tiếng "cạch" cơ khí rất nhẹ.
    for ts in (0.0, 0.07):
        n = int(0.03 * SR)
        click = highpass(rng.standard_normal(n), 2500) * env_ad(n, 0.0005, 0.006)
        parts.append((ts, peak_norm(click, -3), 0.35))
    # "Ting" chuông hai tầng kiểu máy tính tiền.
    parts.append((0.11, tone(mtof(88), 0.7, BELL, tau=0.3), 0.55))
    parts.append((0.20, tone(mtof(95), 0.7, BELL, tau=0.35), 0.5))
    sig = mono_sfx(parts, 0.95)
    sig = echo(sig, 0.09, 0.25, 2)[:int(0.95 * SR)]
    fade = int(0.12 * SR)
    sig[-fade:] *= np.linspace(1, 0, fade)
    return peak_norm(sig, -2)


def sfx_gift_open(rng):
    parts = []
    scale = [79, 83, 86, 88, 91, 95, 98, 100, 103]  # thang ngũ cung sáng
    for k, m in enumerate(scale):
        ts = 0.05 + 0.055 * k
        parts.append((ts, tone(mtof(m), 0.45, BELL, tau=0.17), 0.22 + 0.01 * k))
    t0 = 0.05 + 0.055 * len(scale)
    for m in (79, 83, 86):
        parts.append((t0, tone(mtof(m), 0.6, MUSICBOX, tau=0.4), 0.22))
    # vài hạt lấp lánh ngẫu nhiên (đã gieo hạt)
    for _ in range(6):
        ts = rng.uniform(0.1, 0.8)
        m = int(rng.choice([91, 95, 98, 100, 103]))
        parts.append((ts, tone(mtof(m), 0.25, BELL, tau=0.08), 0.12))
    sig = mono_sfx(parts, 1.0)
    sig = echo(sig, 0.12, 0.3, 3)[:int(1.0 * SR)]
    fade = int(0.15 * SR)
    sig[-fade:] *= np.linspace(1, 0, fade)
    return peak_norm(sig, -2)


def sfx_streak():
    parts = []
    notes = [72, 76, 79, 84, 88]
    for k, m in enumerate(notes):
        last = k == len(notes) - 1
        dur = 0.7 if last else 0.3
        parts.append((0.075 * k, tone(mtof(m), dur, MARIMBA, tau=0.5 if last else 0.18), 0.5))
        parts.append((0.075 * k, triangle(mtof(m), dur, tau=0.25), 0.18))
    parts.append((0.075 * 4, tone(mtof(96), 0.5, BELL, tau=0.2), 0.14))
    sig = mono_sfx(parts, 1.0)
    sig = echo(sig, 0.1, 0.3, 3)[:int(1.0 * SR)]
    fade = int(0.12 * SR)
    sig[-fade:] *= np.linspace(1, 0, fade)
    return peak_norm(sig, -2)


def sfx_error_soft():
    dur = 0.28
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 392 - 90 * (t / dur) ** 0.7
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR)
    sig += 0.25 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR)
    e = np.minimum(1, t / 0.02) * np.exp(-t / 0.12)
    e[-int(0.04 * SR):] *= np.linspace(1, 0, int(0.04 * SR))
    return peak_norm(sig * e, -5)


# --- Nhạc nền -------------------------------------------------------------

NOTE_PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
NOTE_RE = re.compile(r'^([A-G])(b?)(\d)$')


def midi(name):
    m = NOTE_RE.match(name)
    return 12 * (int(m.group(3)) + 1) + NOTE_PC[m.group(1)] - (1 if m.group(2) else 0)


def parse_bar(text):
    """'E5:1 r:1 G5:2' -> [(bắt đầu_nốt8, midi|None, độ dài_nốt8)] (tổng 8)."""
    pos = 0
    out = []
    for tok in text.split():
        name, d = tok.split(':')
        d = float(d)
        out.append((pos, None if name == 'r' else midi(name), d))
        pos += d
    assert abs(pos - 8) < 1e-9, f'ô nhịp không đủ 8 móc đơn: {text} ({pos})'
    return out


def chord_notes(name):
    """Tên hợp âm (C, Am, Bb, Dm, G) -> (gốc pc, [các nốt tam âm])."""
    root = name[0]
    flat = len(name) > 1 and name[1] == 'b'
    rest = name[2:] if flat else name[1:]
    pc = NOTE_PC[root] - (1 if flat else 0)
    minor = rest.startswith('m')
    third = 3 if minor else 4
    return pc % 12, [0, third, 7]


def render_music(spec, seed):
    """Dựng một bản nhạc lặp từ ``spec``; trả (n,2) float, độ dài = số ô."""
    rng = np.random.default_rng(seed)
    bpm = spec['bpm']
    eighth = 30.0 / bpm
    bars = spec['chords']
    nbars = len(bars)
    total = int(round(nbars * 8 * eighth * SR))
    buf = np.zeros((total, 2))
    mel = spec['melody']
    assert len(mel) == nbars, (len(mel), nbars)

    for b in range(nbars):
        t0 = b * 8 * eighth
        pc, tri = chord_notes(bars[b])

        # Giai điệu
        for pos, m, d in parse_bar(mel[b]):
            if m is None:
                continue
            dur = d * eighth + spec['mel_tail']
            sig = tone(mtof(m), dur, spec['mel_timbre'], tau=spec['mel_tau'])
            place(buf, sig, t0 + pos * eighth, spec['mel_gain'],
                  pan=spec['mel_pan'], circular=True)

        # Bè (bass)
        for pos, dur8, off in spec['bass_pattern']:
            m = 36 + pc + off
            if m > 47:
                m -= 12
            m += spec.get('bass_shift', 0)
            sig = tone(mtof(m), dur8 * eighth, SOFTBASS, attack=0.008,
                       tau=spec['bass_tau'], release=0.04)
            place(buf, sig, t0 + pos * eighth, spec['bass_gain'], pan=-0.1,
                  circular=True)

        # Đệm hợp âm / rải
        base = spec['comp_base']
        voic = [base + ((pc - base) % 12) + o for o in tri]
        voic = [v if v < base + 12 else v - 12 for v in voic]
        voic = sorted(voic)
        voic += [voic[0] + 12]
        for pos, dur8, pick in spec['comp_pattern']:
            notes = [voic[i] for i in pick]
            for k, m in enumerate(notes):
                sig = tone(mtof(m), dur8 * eighth + 0.1, spec['comp_timbre'],
                           tau=spec['comp_tau'])
                place(buf, sig, t0 + pos * eighth + 0.004 * k,
                      spec['comp_gain'] / np.sqrt(len(notes)),
                      pan=spec['comp_pan'], circular=True)

        # Nền (pad) tam giác rất nhỏ
        if spec['pad_gain'] > 0:
            for k, o in enumerate(tri):
                m = 60 + ((pc + o - 60) % 12)
                dur = 8 * eighth + 0.5
                sig = triangle(mtof(m), dur, attack=0.35, release=0.5)
                place(buf, sig, t0, spec['pad_gain'], pan=-0.4 + 0.4 * k,
                      circular=True)

        # Nhịp (rất nhẹ)
        for kind, positions, gain in spec['perc']:
            for pos in positions:
                s = perc_hit(kind, rng)
                place(buf, s, t0 + pos * eighth, gain, pan=0.15, circular=True)

    ir = reverb_ir(rng, spec['rev_len'], spec['rev_tau'])
    buf = apply_reverb(buf, ir, spec['rev_wet'], circular=True)
    # Cắt DC / trầm quá thấp
    for c in range(2):
        buf[:, c] -= buf[:, c].mean()
    return buf


def perc_hit(kind, rng):
    if kind == 'kick':
        n = int(0.2 * SR)
        t = np.arange(n) / SR
        f = 55 + 85 * np.exp(-t / 0.03)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.002, 0.07)
    if kind == 'shaker':
        n = int(0.06 * SR)
        x = highpass(rng.standard_normal(n), 5000)
        return x * env_ad(n, 0.004, 0.018) * 0.6
    if kind == 'rim':
        n = int(0.05 * SR)
        t = np.arange(n) / SR
        x = np.sin(2 * np.pi * 1700 * t) * env_ad(n, 0.001, 0.01)
        x += 0.3 * highpass(rng.standard_normal(n), 3000) * env_ad(n, 0.001, 0.008)
        return x
    raise ValueError(kind)


def town_spec():
    # Đô trưởng, 110 BPM, 32 ô: I-V-vi-IV
    A = 'C G Am F C G F G'.split()
    A2 = 'C G Am F C G F C'.split()
    B = 'F C G Am F C Dm G'.split()
    chords = A + A2 + B + A
    mA = [
        'E5:1 r:1 G5:1 E5:1 C5:1 E5:1 G5:2',
        'D5:1 r:1 G5:1 D5:1 B4:1 D5:1 G5:2',
        'C5:1 E5:1 A5:2 G5:1 E5:1 C5:2',
        'A4:1 C5:1 F5:2 E5:1 D5:1 C5:2',
        'G5:2 E5:1 G5:1 C6:2 G5:2',
        'G5:2 D5:1 G5:1 B5:2 G5:2',
        'A5:2 F5:1 A5:1 C6:2 A5:2',
        'G5:1 F5:1 E5:1 D5:1 B4:2 D5:2',
    ]
    mA2 = mA[:4] + [
        'E5:2 G5:1 E5:1 G5:2 C6:2',
        'D5:2 G5:1 B5:1 D6:2 B5:2',
        'C6:1 A5:1 F5:2 A5:2 C6:2',
        'E5:1 G5:1 C6:4 r:2',
    ]
    mB = [
        'A5:2 C6:3 A5:1 F5:2',
        'G5:2 E5:2 G5:2 E5:1 C5:1',
        'D5:2 G5:2 B5:3 G5:1',
        'A5:4 E5:2 C5:2',
        'C6:2 D6:2 C6:2 A5:2',
        'G5:1 A5:1 G5:1 E5:1 C5:4',
        'D5:2 F5:2 A5:2 F5:2',
        'G5:2 B5:2 D6:2 r:2',
    ]
    return dict(
        bpm=110, chords=chords, melody=mA + mA2 + mB + mA,
        mel_timbre=MARIMBA, mel_tau=0.30, mel_tail=0.25, mel_gain=0.55,
        mel_pan=0.1,
        bass_pattern=[(0, 1.5, 0), (2, 1.5, 7), (4, 1.5, 0), (6, 1.5, 7)],
        bass_tau=0.35, bass_gain=0.5, comp_base=60,
        comp_pattern=[(2, 1, [0, 1, 2]), (6, 1, [0, 1, 2])],
        comp_timbre=PLUCK, comp_tau=0.12, comp_gain=0.33, comp_pan=-0.3,
        pad_gain=0.05,
        perc=[('kick', [0, 4], 0.45), ('rim', [2, 6], 0.10),
              ('shaker', [1, 3, 5, 7], 0.10)],
        rev_len=1.0, rev_tau=0.25, rev_wet=0.16,
    )


def room_spec():
    # Fa trưởng, 85 BPM, 24 ô: I-V-vi-IV (F C Dm Bb), nhẹ, hộp nhạc
    A = 'F C Dm Bb F C Bb C'.split()
    B = 'Bb F C Dm Bb F C C'.split()
    chords = A + B + A
    mA = [
        'A5:3 C6:1 A5:2 F5:2',
        'G5:3 E5:1 G5:4',
        'F5:2 A5:2 D6:3 A5:1',
        'D6:4 C6:2 Bb5:2',
        'A5:3 C6:1 F6:2 C6:2',
        'E6:2 D6:2 C6:4',
        'D6:2 C6:2 Bb5:2 A5:2',
        'G5:4 r:2 E5:2',
    ]
    mB = [
        'D6:4 F6:2 D6:2',
        'C6:3 A5:1 C6:4',
        'E6:2 D6:2 C6:4',
        'D6:2 A5:2 F5:4',
        'Bb5:2 D6:2 F6:4',
        'A5:2 C6:2 A5:4',
        'G5:2 C6:2 E6:4',
        'D6:4 C6:2 G5:2',
    ]
    mA3 = mA[:7] + ['G5:4 E5:4']
    return dict(
        bpm=85, chords=chords, melody=mA + mB + mA3,
        mel_timbre=MUSICBOX, mel_tau=0.9, mel_tail=0.6, mel_gain=0.5,
        mel_pan=0.15,
        bass_pattern=[(0, 3.5, 0), (4, 3.5, 0)],
        bass_tau=0.9, bass_gain=0.42, comp_base=53,
        # rải nốt đều: 1-3-5-8-5-3 ...
        comp_pattern=[(i, 1.5, [p]) for i, p in
                      enumerate([0, 1, 2, 3, 2, 1, 2, 1])],
        comp_timbre=MARIMBA, comp_tau=0.35, comp_gain=0.30, comp_pan=-0.25,
        pad_gain=0.07,
        perc=[('shaker', [2, 6], 0.05)],
        rev_len=1.6, rev_tau=0.45, rev_wet=0.26,
    )


# --- Xuất file ------------------------------------------------------------

def encode_ogg(wav_path, ogg_path, bitrate='80k'):
    subprocess.run(
        ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i',
         str(wav_path), '-c:a', 'libvorbis', '-b:a', bitrate,
         '-fflags', '+bitexact', '-flags:a', '+bitexact', str(ogg_path)],
        check=True)


def main():
    ap = argparse.ArgumentParser()
    root = pathlib.Path(__file__).resolve().parents[2]
    ap.add_argument('--out', default=str(root / 'app' / 'assets' / 'sounds'))
    ap.add_argument('--preview', default=None,
                    help='Ghi file nghe thử (mp3/wav) ghép mọi SFX + 20 s mỗi bản nhạc')
    args = ap.parse_args()
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    if not shutil.which('ffmpeg'):
        sys.exit('Cần ffmpeg (libvorbis) để mã hóa nhạc và đo độ ồn.')
    rng = np.random.default_rng(SEED)

    sfx = {
        'tap': sfx_tap(),
        'swoosh': sfx_swoosh(rng),
        'hatch': sfx_hatch(rng),
        'level_up': sfx_level_up(),
        'purchase': sfx_purchase(rng),
        'gift_open': sfx_gift_open(rng),
        'streak': sfx_streak(),
        'error_soft': sfx_error_soft(),
    }
    for name, x in sfx.items():
        x = peak_norm(x, -2)
        sfx[name] = x
        write_wav(out / f'{name}.wav', x, 1)
        print(f'{name}.wav  {len(x) / SR:.2f}s  LUFS~{measure_lufs(x)}')

    music = {}
    for name, spec, seed in (('town', town_spec(), SEED + 1),
                             ('room', room_spec(), SEED + 2)):
        x = render_music(spec, seed)
        x = normalize_music(x)
        music[name] = x
        with tempfile.TemporaryDirectory() as d:
            w = pathlib.Path(d) / f'{name}.wav'
            write_wav(w, x, 2)
            encode_ogg(w, out / f'music_{name}.ogg')
        peak = 20 * np.log10(np.max(np.abs(x)))
        print(f'music_{name}.ogg  {len(x) / SR:.1f}s  '
              f'LUFS~{measure_lufs(x)}  peak {peak:.1f} dBFS')

    if args.preview:
        parts = []
        gap = np.zeros(int(0.5 * SR))
        order = ['tap', 'swoosh', 'hatch', 'level_up', 'purchase',
                 'gift_open', 'streak', 'error_soft']
        for n in order:
            m = np.repeat(sfx[n][:, None], 2, axis=1)
            parts += [m, np.zeros((int(0.5 * SR), 2))]
        for n in ('town', 'room'):
            seg = music[n][:20 * SR].copy()
            fade = int(0.5 * SR)
            seg[-fade:] *= np.linspace(1, 0, fade)[:, None]
            # Nhạc phát ở âm lượng app 0,35 so với SFX (nghe đúng tỉ lệ).
            parts += [seg * 0.35 * 1.0, np.zeros((int(1.0 * SR), 2))]
        pv = np.concatenate(parts)
        prev = pathlib.Path(args.preview)
        with tempfile.TemporaryDirectory() as d:
            w = pathlib.Path(d) / 'p.wav'
            write_wav(w, pv, 2)
            if prev.suffix == '.mp3':
                subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel',
                                'error', '-i', str(w), '-c:a', 'libmp3lame',
                                '-b:a', '128k', str(prev)], check=True)
            else:
                shutil.copy(w, prev)
        print('preview ->', prev)


if __name__ == '__main__':
    main()
