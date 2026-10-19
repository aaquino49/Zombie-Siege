"""Rebuild T-029 CC0 audio: python project/tools/make_audio.py.

Requires numpy, soundfile and Pillow (pip install numpy soundfile Pillow).
Kenney originals stay in asset_library/kenney; downloaded sources and archived
CC0 pages stay in asset_library/audio/t029. No engine addons are used.
Generated horn/alarm/stingers are original work dedicated to CC0 1.0.
WAV output is mono, 44100 Hz, 16-bit PCM written using Python's wave module.
"""
from pathlib import Path
import argparse
import json
import wave

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "asset_library/audio/t029"
ASSETS = ROOT / "game/assets"
SR = 44100
GENERATED = "generated for Zombie Siege, CC0; project/tools/make_audio.py"
CATALOG = []


def mono(path):
    samples, rate = sf.read(path, dtype="float64")
    if samples.ndim == 2:
        samples = samples.mean(axis=1)
    return samples, rate


def fade(samples, rate=SR, attack=0.003, release=0.025):
    samples = samples.copy()
    for duration, start in [(attack, True), (release, False)]:
        count = min(int(rate * duration), len(samples) // 2)
        ramp = np.sin(np.linspace(0, np.pi / 2, count)) ** 2
        if start:
            samples[:count] *= ramp
        else:
            samples[-count:] *= ramp[::-1]
    return samples


def resample(samples, old_rate, new_rate=SR):
    # Windowed-sinc low-pass before decimating the 96 kHz recording.
    if old_rate > new_rate:
        taps = np.arange(-64, 65)
        cutoff = 0.45 * new_rate / old_rate
        kernel = 2 * cutoff * np.sinc(2 * cutoff * taps) * np.hanning(129)
        samples = np.convolve(samples, kernel / kernel.sum(), mode="same")
    count = round(len(samples) * new_rate / old_rate)
    return np.interp(np.arange(count) * old_rate / new_rate,
                     np.arange(len(samples)), samples)


def normalize(samples, db):
    peak = np.max(np.abs(samples))
    if not np.isfinite(samples).all() or peak <= 1e-8:
        raise ValueError("Non-finite or silent audio")
    return samples * (10 ** (db / 20) / peak)


def save(name, purpose, samples, rate, source, processing, music=False):
    target = -10.0 if music else -3.0
    samples = normalize(samples, target)
    folder = "music" if music else "sfx"
    path = ASSETS / folder / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix == ".wav":
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(rate)
            output.writeframes(np.rint(samples * 32767).astype("<i2").tobytes())
    else:
        # Match the decoded peak, including Vorbis reconstruction overshoot.
        for _ in range(3):
            channels = 1 if samples.ndim == 1 else samples.shape[1]
            # Bounded writes also avoid a libsndfile Windows Vorbis failure
            # when a full stereo music track is passed to one write call.
            with sf.SoundFile(path, "w", rate, channels, format="OGG", subtype="VORBIS") as output:
                for start in range(0, len(samples), 4096):
                    output.write(samples[start:start + 4096])
            decoded, _ = sf.read(path)
            samples *= 10 ** (target / 20) / np.max(np.abs(decoded))
    decoded, decoded_rate = sf.read(path)
    peak = float(np.max(np.abs(decoded)))
    assert 0 < peak < 1, name
    CATALOG.append({
        "file": f"{folder}/{name}", "purpose": purpose,
        "source": source, "license": "CC0 1.0", "processing": processing,
        "duration_seconds": round(len(decoded) / decoded_rate, 6),
        "peak_dbfs": round(float(20 * np.log10(peak)), 3),
        "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean(decoded ** 2)))), 3),
        "sample_rate_hz": decoded_rate,
        "channels": 1 if decoded.ndim == 1 else decoded.shape[1],
        "bytes": path.stat().st_size,
        "clipped_samples": int(np.count_nonzero(np.abs(decoded) >= 1)),
        "loop_boundary_delta": round(float(np.max(np.abs(decoded[0] - decoded[-1]))), 8)
        if music else None,
    })


def kenney():
    selections = [
        ("zombie_hit", "Bullet hits zombie: soft thud", "impact", "impactSoft_medium_000"),
        ("zombie_die", "Zombie killed: deeper body fall", "impact", "impactSoft_heavy_001"),
        ("building_hit", "Zombie hits structure: plank impact", "impact", "impactPlank_medium_000"),
        ("building_destroyed", "Structure destroyed: heavy timber collapse", "impact", "impactWood_heavy_002"),
        ("building_placed", "Blueprint placed: wooden placement tap", "impact", "impactWood_light_001"),
        ("build_complete", "Construction finished: confirmation", "interface", "confirmation_002"),
        ("survivor_hurt", "Survivor damaged: punch impact", "impact", "impactPunch_medium_000"),
        ("ui_click", "Button click", "interface", "click_001"),
        ("ui_error", "Invalid placement / cannot afford", "interface", "error_004"),
    ]
    for name, purpose, pack, stem in selections:
        source = Path(f"asset_library/kenney/kenney_{pack}-sounds/Audio/{stem}.ogg")
        samples, rate = mono(ROOT / source)
        processing = "Mono downmix; 3 ms/25 ms edge fades; decoded peak -3 dBFS; Vorbis retained."
        samples = fade(samples, rate)
        if name == "building_destroyed":
            # Layer three falling timbers; heavier and longer than a plank hit.
            result = np.zeros(round(rate * 1.1))
            for offset, gain, stretch in [(0, 1.0, 1.35), (0.18, 0.7, 1.6), (0.42, 0.45, 1.8)]:
                timber = resample(samples, round(rate / stretch), rate)
                start = round(offset * rate)
                result[start:start + len(timber)] += timber * gain
            samples = fade(result, rate, release=0.08)
            processing += " Three staggered, pitch-lowered timber layers (0/180/420 ms)."
        save(name + ".ogg", purpose, samples, rate, source.as_posix(), processing)


def recordings():
    gun_source = RAW / "22 Pistol.wav"
    samples, rate = mono(gun_source)
    # Select only the first report, excluding later shots and long outdoor echo.
    onset = int(np.flatnonzero(np.abs(samples) > 0.05)[0])
    start = max(0, onset - round(0.002 * rate))
    shot = resample(samples[start:start + round(0.28 * rate)], rate)
    shot = np.convolve(shot, np.hanning(9) / np.hanning(9).sum(), mode="same")
    shot = fade(shot)
    source = "asset_library/audio/t029/22 Pistol.wav; https://opengameart.org/content/gunshots (kurt)"
    save("gunshot.wav", "Guard shot: softened pistol report", shot, SR, source,
         "First report, 0.28 s; mono; windowed-sinc resample 96000 to 44100 Hz; soft low-pass; edge fades; -3 dBFS.")
    turret = resample(shot, round(SR * 1.28))
    save("turret_shot.wav", "Turret shot: shorter, lighter and higher pistol", fade(turret), SR,
         source, "Same report pitched up 28%, 0.2188 s; edge fades; -3 dBFS.")
    for variant, track in [(1, 5), (2, 6), (3, 7)]:
        source_path = RAW / f"ZombieMoans - Track {track} - ZombieMoan{variant}.wav"
        samples, rate = mono(source_path)
        if variant == 1:
            # Original is 2.13 seconds; trim the low-level breath at both ends.
            samples = samples[round(0.08 * rate):round(2.03 * rate)]
        save(f"zombie_groan_{variant}.wav", f"Night ambient zombie groan variant {variant}",
             fade(samples, rate, attack=0.025, release=0.06), rate,
             f"asset_library/audio/t029/{source_path.name}; https://opengameart.org/content/zombie-moans-01-by-emopreben (EmoPreben)",
             "Mono downmix; 25 ms attack / 60 ms release; -3 dBFS; variant 1 trims 0.08..2.03 s, others retain duration.")


def time_axis(duration):
    return np.arange(round(duration * SR)) / SR


def bell(frequency, duration):
    t = time_axis(duration)
    tone = sum(gain * np.sin(2 * np.pi * frequency * ratio * t) * np.exp(-t / decay)
               for ratio, gain, decay in [(1, 1, 0.7), (2, 0.3, 0.4), (3.01, 0.08, 0.2)])
    return fade(tone, attack=0.006, release=0.15)


def generated():
    t = time_axis(2.4)
    # Low horn with mellow harmonics, slow beating and a rounded envelope.
    frequency = 110 + 1.0 * np.sin(2 * np.pi * 0.7 * t)
    phase = 2 * np.pi * np.cumsum(frequency) / SR
    horn = sum(np.sin(h * phase) / h ** 1.65 for h in range(1, 7))
    horn += 0.3 * np.sin(phase * 1.008)
    save("night_horn.wav", "Nightfall: ominous low horn", fade(horn, attack=0.25, release=0.65),
         SR, GENERATED, "Original 110 Hz detuned additive horn, rounded attack/release; 16-bit PCM mono; -3 dBFS.")
    chime = np.zeros(round(1.8 * SR))
    for start, frequency, gain in [(0, 523.25, 0.8), (0.25, 659.25, 0.7), (0.5, 783.99, 0.6)]:
        offset = round(start * SR)
        chime[offset:] += gain * bell(frequency, len(chime[offset:]) / SR)
    save("dawn_chime.wav", "Dawn: gentle rising chime", fade(chime, release=0.2), SR, GENERATED,
         "Original C5/E5/G5 additive bells with exponential tails; 16-bit PCM mono; -3 dBFS.")
    alarm = np.zeros(round(0.8 * SR))
    for start, frequency in [(0, 740), (0.22, 554.37)]:
        t = time_axis(0.18)
        beep = fade(np.sin(2 * np.pi * frequency * t), attack=0.015, release=0.04)
        offset = round(start * SR)
        alarm[offset:offset + len(beep)] += beep
    save("cc_alarm.wav", "Command Center under attack: repeatable two-tone alarm", alarm, SR, GENERATED,
         "Original rounded 740/554 Hz two-tone alert with quiet repeat gap; 16-bit PCM mono; -3 dBFS.")
    for name, notes, purpose in [
        ("victory", [261.63, 329.63, 392.0, 523.25], "Victory screen: hopeful major stinger"),
        ("game_over", [220, 207.65, 174.61, 110], "Defeat screen: descending somber stinger"),
    ]:
        stinger = np.zeros(round(3.2 * SR))
        for index, frequency in enumerate(notes):
            offset = round(index * 0.4 * SR)
            duration = len(stinger[offset:]) / SR
            if name == "victory":
                tone = bell(frequency, duration)
            else:
                t = time_axis(duration)
                tone = (np.sin(2 * np.pi * frequency * t)
                        + 0.18 * np.sin(2 * np.pi * frequency * 2 * t)) * np.exp(-t / 0.75)
                tone = fade(tone, attack=0.04, release=0.3)
            stinger[offset:] += tone * (0.8 if index < 3 else 1)
        save(name + ".wav", purpose, fade(stinger, release=0.3), SR, GENERATED,
             "Original four-note additive composition, 0.4 s note spacing and decaying tails; 16-bit PCM mono; -3 dBFS.")


def music():
    for name, original, url, author, purpose in [
        ("day_loop", "SunsetWalk.ogg", "https://opengameart.org/node/87082", "Kilua Boy", "Calm day: quiet melodic ambient loop"),
        ("night_loop", "dark_place.ogg", "https://opengameart.org/content/dark-place-loop", "SkyleTheFrench", "Tense night: dark ambient loop"),
    ]:
        samples, rate = sf.read(RAW / original)
        samples -= samples.mean(axis=0)
        # Circular seam smoothing preserves the source's exact musical period.
        # Blend a 3 ms moving average across the join inside a 12 ms radius.
        radius = round(0.012 * rate)
        kernel_width = round(0.003 * rate) | 1
        extended = np.concatenate([samples[-radius-kernel_width:], samples[:radius+kernel_width]])
        smooth = np.stack([np.convolve(extended[:, ch], np.ones(kernel_width) / kernel_width,
                                      mode="same") for ch in range(samples.shape[1])], axis=1)
        segment = extended[kernel_width:-kernel_width]
        filtered = smooth[kernel_width:-kernel_width]
        weight = (0.5 + 0.5 * np.cos(np.linspace(-np.pi, np.pi, 2 * radius)))[:, None]
        seam = segment * (1 - weight) + filtered * weight
        samples[-radius:] = seam[:radius]
        samples[:radius] = seam[radius:]
        save(name + ".ogg", purpose, samples, rate,
             f"asset_library/audio/t029/{original}; {url} ({author})",
             "Original stereo loop and exact duration retained; DC removal; circular 12 ms seam smoothing; decoded peak -10 dBFS; Vorbis. Import loop=true.", music=True)


def contact_sheet(run):
    image = Image.new("RGB", (1440, 1050), "#1b2421")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 14)
    title_font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 22)
    draw.text((20, 14), "Zombie Siege / T-029 audio contact sheet", font=title_font, fill="#e9ddbc")
    draw.text((20, 44), "CC0 | SFX -3 dBFS | music -10 dBFS | measured decoded waveforms", font=font, fill="#c9cfcb")
    for index, asset in enumerate(CATALOG):
        x = 20 + (index % 3) * 473
        y = 86 + (index // 3) * 125
        draw.rounded_rectangle((x, y, x + 453, y + 115), radius=6, fill="#303b34")
        draw.text((x + 10, y + 6), asset["file"], font=font, fill="#f2e7cf")
        draw.text((x + 10, y + 26), f'{asset["duration_seconds"]:.3f}s  {asset["peak_dbfs"]:.2f}dBFS  {asset["channels"]}ch', font=font, fill="#bcc8bd")
        samples, _ = sf.read(ASSETS / asset["file"])
        if samples.ndim == 2:
            samples = samples.mean(axis=1)
        for column, chunk in enumerate(np.array_split(samples, 428)):
            lo, hi = float(chunk.min()), float(chunk.max())
            draw.line((x + 12 + column, y + 80 - hi * 32,
                       x + 12 + column, y + 80 - lo * 32), fill="#96bb7c")
    draw.text((20, 986), "Existing Kenney world palette references (audio-only task):", font=font, fill="#c9cfcb")
    for index, path in enumerate(["tiles/grass_1.png", "buildings/command_center.png", "buildings/wall_wood.png"]):
        if (ASSETS / path).exists():
            tile = Image.open(ASSETS / path).convert("RGBA")
            tile.thumbnail((48, 48))
            image.paste(tile, (570 + index * 65, 980), tile)
    image.save(run / "contact_sheet.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", type=Path, default=ROOT / "project/runs/T-029/a1")
    args = parser.parse_args()
    args.report_dir.mkdir(parents=True, exist_ok=True)
    kenney()
    recordings()
    generated()
    music()
    assert len(CATALOG) == 21
    total = sum(asset["bytes"] for asset in CATALOG)
    assert total < 25_000_000
    for asset in CATALOG:
        if asset["file"].startswith("music/"):
            assert 30 <= asset["duration_seconds"] <= 90
            assert asset["bytes"] < 5_000_000
            assert asset["loop_boundary_delta"] < 0.002
    report = {"assets": CATALOG, "total_bytes": total, "license": "CC0 1.0"}
    (RAW / "sources.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (args.report_dir / "audio_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    contact_sheet(args.report_dir)
    for asset in CATALOG:
        print(f'{asset["file"]}: {asset["duration_seconds"]:.3f}s, {asset["peak_dbfs"]:.3f} dBFS, {asset["bytes"]} bytes')
    print(f"Total: {total} bytes; all finite, non-silent and unclipped.")


if __name__ == "__main__":
    main()
