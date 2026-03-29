#!/usr/bin/env python3
import wave, struct, math, random, os

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib")

def write_wav(name, samples, rate=RATE):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s)))) for s in samples))
    print(f"  {name} ({len(samples)/rate:.2f}s)")

def env(samples, attack=0.005, release=0.05):
    n = len(samples)
    a = int(attack * RATE)
    r = int(release * RATE)
    for i in range(min(a, n)):
        samples[i] *= i / max(a, 1)
    for i in range(max(0, n - r), n):
        samples[i] *= (n - i) / max(r, 1)
    return samples

def noise(dur):
    return [random.uniform(-1, 1) for _ in range(int(RATE * dur))]

def sine(freq, dur):
    return [math.sin(2 * math.pi * freq * t / RATE) for t in range(int(RATE * dur))]

def amp(samples, vol):
    return [s * vol for s in samples]

def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    pk = max(abs(s) for s in out) or 1
    if pk > 1.0:
        out = [s / pk for s in out]
    return out

def normalize(samples, peak=0.95):
    mx = max(abs(s) for s in samples) or 1
    return [s * peak / mx for s in samples]

def to16(samples):
    return [s * 30000 for s in samples]

# Jet engine: turbine whine + roar
def gen_jet(dur=2.0, whine_freq=480):
    n = len(sine(100, dur))
    out = [0.0] * n
    # turbine whine (the distinctive jet sound)
    for f, v in [(whine_freq, 0.4), (whine_freq*2, 0.25), (whine_freq*3, 0.12)]:
        t = sine(f, dur)
        for i in range(n): out[i] += t[i] * v
    # high-pitched whistle
    t = sine(whine_freq * 5, dur)
    for i in range(n): out[i] += t[i] * 0.06
    # broadband roar (noise shaped by simple averaging)
    raw = noise(dur)
    avg = [0.0] * n
    w = 20
    run = 0.0
    for i in range(n):
        run += raw[i]
        if i >= w: run -= raw[i - w]
        avg[i] = run / min(i + 1, w)
    for i in range(n): out[i] += avg[i] * 0.3
    # low rumble
    t = sine(80, dur)
    for i in range(n): out[i] += t[i] * 0.15
    return to16(env(normalize(out), attack=0.3, release=0.3))

# Prop engine: clear drone with buzzy harmonics
def gen_prop(dur=2.0, rpm=110):
    n = int(RATE * dur)
    out = [0.0] * n
    # fundamental + many harmonics for buzzy character
    for h in range(1, 12):
        v = 0.8 / h
        t = sine(rpm * h, dur)
        for i in range(n): out[i] += t[i] * v
    # slight noise for air turbulence
    raw = noise(dur)
    avg = [0.0] * n
    w = 40
    run = 0.0
    for i in range(n):
        run += raw[i]
        if i >= w: run -= raw[i - w]
        avg[i] = run / min(i + 1, w)
    for i in range(n): out[i] += avg[i] * 0.15
    return to16(env(normalize(out), attack=0.3, release=0.3))

# Gunshot: white noise burst, no filtering
def gen_gunshot(dur=0.08):
    n = noise(dur)
    return to16(env(normalize(n), attack=0.0005, release=0.03))

# .50 cal: very short sharp crack
def gen_50cal():
    n = noise(0.06)
    pop = amp(sine(1200, 0.01), 0.8)
    n[:len(pop)] = [n[i] + pop[i] for i in range(len(pop))]
    return to16(env(normalize(n), attack=0.0003, release=0.02))

# 20mm: crack + brief low thump
def gen_20mm():
    crack = amp(noise(0.03), 1.0)
    thump = env(amp(sine(120, 0.08), 0.8), attack=0.001, release=0.04)
    s = crack + thump[len(crack):]
    return to16(env(normalize(s), attack=0.0003, release=0.02))

# 60mm: big bang
def gen_60mm():
    bang = amp(noise(0.02), 1.0)
    boom = env(amp(sine(60, 0.15), 1.0), attack=0.001, release=0.08)
    boom2 = env(amp(sine(30, 0.2), 0.6), attack=0.005, release=0.12)
    s = list(bang)
    for i in range(len(boom)):
        if i < len(s): s[i] += boom[i]
        else: s.append(boom[i])
    for i in range(len(boom2)):
        if i < len(s): s[i] += boom2[i]
        else: s.append(boom2[i])
    return to16(env(normalize(s), attack=0.0003, release=0.03))

# Cannon
def gen_cannon():
    crack = amp(noise(0.02), 1.0)
    thump = env(amp(sine(90, 0.1), 0.9), attack=0.001, release=0.06)
    s = list(crack)
    for i in range(len(thump)):
        if i < len(s): s[i] += thump[i]
        else: s.append(thump[i])
    return to16(env(normalize(s), attack=0.0003, release=0.03))

# Rocket whoosh
def gen_rocket(dur=0.7):
    samples = []
    for t in range(int(RATE * dur)):
        p = t / (RATE * dur)
        f = 200 + 600 * p
        v = math.sin(2 * math.pi * f * t / RATE) * (1.0 - p * 0.5)
        samples.append(v)
    return to16(env(normalize(samples), attack=0.005, release=0.15))

# Explosion: sine thump + noise burst, fast decay
def gen_explosion(dur=1.0, power=1.0):
    n = int(RATE * dur)
    out = [0.0] * n
    thump = amp(sine(35 * power, min(dur, 0.3)), power)
    for i, s in enumerate(thump):
        if i < n: out[i] += s
    burst_len = min(int(RATE * 0.15), n)
    burst = noise(0.15)
    for i in range(burst_len):
        fade = 1.0 - i / burst_len
        if i < n: out[i] += burst[i] * fade * 0.7
    rumble = amp(sine(20 * power, dur), 0.4 * power)
    for i in range(min(len(rumble), n)):
        decay = math.exp(-3.0 * i / n)
        out[i] += rumble[i] * decay
    return to16(env(normalize(out), attack=0.001, release=dur * 0.3))

# Click
def gen_click():
    n = noise(0.03)
    return to16(env(normalize(n), attack=0.0003, release=0.01))

# Mechanical
def gen_mechanical(dur=0.35):
    click = amp(noise(0.015), 1.0)
    tone = env(amp(sine(220, dur - 0.03), 0.6), attack=0.02, release=0.02)
    click2 = amp(noise(0.015), 0.8)
    s = list(click) + list(tone) + list(click2)
    return to16(normalize(s))

# Wind: very gentle
def gen_wind(dur=3.0):
    s = noise(dur)
    # simple moving average for smoothness
    w = 800
    out = [0.0] * len(s)
    running = 0.0
    for i in range(len(s)):
        running += s[i]
        if i >= w: running -= s[i - w]
        out[i] = running / min(i + 1, w)
    return to16(env(amp(normalize(out), 0.5), attack=0.5, release=0.5))

# Screech
def gen_screech(dur=0.4):
    samples = []
    for t in range(int(RATE * dur)):
        f = 1500 + 500 * math.sin(2 * math.pi * 30 * t / RATE)
        samples.append(math.sin(2 * math.pi * f * t / RATE))
    return to16(env(normalize(samples), attack=0.002, release=0.08))

# Crash
def gen_crash(dur=1.2):
    bang = gen_explosion(0.5, 1.3)
    metal = []
    for t in range(int(RATE * 0.7)):
        p = t / (RATE * 0.7)
        v = math.sin(2 * math.pi * 350 * (1.0 - p * 0.4) * t / RATE) * math.exp(-4 * p)
        metal.append(v * 20000)
    return (bang + metal)[:int(RATE * dur)]

# Hit
def gen_hit():
    bang = amp(noise(0.01), 1.0)
    ping = env(amp(sine(600, 0.06), 0.7), attack=0.001, release=0.04)
    s = list(bang) + list(ping)
    return to16(env(normalize(s), attack=0.0003, release=0.02))

# Flak
def gen_flak():
    pop = amp(noise(0.015), 1.0)
    thud = env(amp(sine(180, 0.06), 0.6), attack=0.001, release=0.04)
    s = list(pop) + list(thud)
    return to16(env(normalize(s), attack=0.0003, release=0.03))

print("Generating sound effects...")

write_wav("jet_engine.wav", gen_jet(2.0, 480))
write_wav("sabre_engine.wav", gen_jet(2.0, 520))
write_wav("mig15_engine.wav", gen_jet(2.0, 440))
write_wav("f84_engine.wav", gen_jet(2.0, 500))
write_wav("p51_engine.wav", gen_prop(2.0, 110))
write_wav("yak09_engine.wav", gen_prop(2.0, 95))

write_wav("gun.wav", gen_gunshot(0.08))
write_wav("cannon.wav", gen_cannon())
write_wav("50cal.wav", gen_50cal())
write_wav("20mm.wav", gen_20mm())
write_wav("60mm.wav", gen_60mm())
write_wav("rocket.wav", gen_rocket())

write_wav("expl_light.wav", gen_explosion(0.6, 0.5))
write_wav("expl_medium.wav", gen_explosion(1.0, 0.8))
write_wav("expl_heavy.wav", gen_explosion(1.5, 1.0))
write_wav("bomb_expl.wav", gen_explosion(2.0, 1.2))
write_wav("50cal_expl.wav", gen_explosion(0.3, 0.3))
write_wav("20mm_expl.wav", gen_explosion(0.4, 0.5))
write_wav("60mm_expl.wav", gen_explosion(0.6, 0.7))
write_wav("rocket_expl.wav", gen_explosion(1.0, 0.9))
write_wav("bomb500_expl.wav", gen_explosion(1.5, 1.1))
write_wav("bomb1000_expl.wav", gen_explosion(2.0, 1.3))
write_wav("tank_expl.wav", gen_explosion(0.7, 0.5))

write_wav("gear.wav", gen_mechanical(0.35))
write_wav("flaps.wav", gen_mechanical(0.4))
write_wav("speedbrakes.wav", gen_mechanical(0.3))
write_wav("click.wav", gen_click())

write_wav("wind.wav", gen_wind(3.0))
write_wav("screech.wav", gen_screech())
write_wav("crash.wav", gen_crash())
write_wav("badlanding.wav", gen_crash(0.8))
write_wav("hit.wav", gen_hit())
write_wav("flak.wav", gen_flak())

print("Done!")
