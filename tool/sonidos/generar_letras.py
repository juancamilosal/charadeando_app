"""Genera los sonidos del juego Letras (tic de la bomba y explosión) en WAV.

Uso: python3 tool/sonidos/generar_letras.py <carpeta>; luego se pasan a MP3
con ffmpeg (libmp3lame, 96k) a assets/audio/tic.mp3 y explosion.mp3.
Son sintéticos: no tienen licencia de terceros.
"""
import math, random, struct, wave, sys
R = 22050
def save(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s / peak * 0.92)) * 32767)) for s in samples))
random.seed(7)
# Tic: un golpe corto de madera (dos tonos que se apagan rápido).
tic = []
for i in range(int(R * 0.07)):
    t = i / R
    env = math.exp(-t * 90)
    tic.append(env * (math.sin(2 * math.pi * 1800 * t) * 0.6 + math.sin(2 * math.pi * 3200 * t) * 0.3 + (random.random() * 2 - 1) * 0.25 * math.exp(-t * 300)))
save(sys.argv[1] + '/tic.wav', tic)
# Explosión: golpe grave que baja de tono + ruido filtrado que se apaga,
# con chasquidos de escombros.
n = int(R * 2.4)
boom = []
lp = 0.0
lp2 = 0.0
phase = 0.0
for i in range(n):
    t = i / R
    # Ruido rosado aproximado con dos filtros pasa bajos.
    white = random.random() * 2 - 1
    cutoff = 0.08 + 0.5 * math.exp(-t * 6)
    lp += cutoff * (white - lp)
    lp2 += 0.05 * (lp - lp2)
    noise = (lp * 0.7 + lp2 * 1.6) * (math.exp(-t * 1.6) * (1 - math.exp(-t * 400)))
    # Golpe grave: de 90 a 35 Hz.
    freq = 35 + 55 * math.exp(-t * 5)
    phase += 2 * math.pi * freq / R
    thump = math.sin(phase) * math.exp(-t * 3.2) * (1 - math.exp(-t * 600)) * 1.3
    crackle = 0.0
    if t > 0.05 and random.random() < 0.004 * math.exp(-t * 1.2):
        crackle = (random.random() * 2 - 1) * 0.8
    boom.append(noise * 1.4 + thump + crackle)
# Suavizar el final.
for i in range(int(R * 0.3)):
    boom[-1 - i] *= i / (R * 0.3)
save(sys.argv[1] + '/explosion.wav', boom)
print('ok')
