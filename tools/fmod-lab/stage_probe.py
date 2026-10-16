"""Level of each ear for a source on a ring around the listener, in the game's real 5.1 mix.

The game mixes in 5.1 and, on a PulseAudio stereo output, only the front left and front right speakers reach the
ears (centre and surrounds are dropped). `pulse` models that, `downmix` models a correct stereo fold down.

usage: python3 stage_probe.py [--distance 4]
"""
import argparse
import math
import os
import tempfile

import fmodlab as lab

FORWARD = (1.0, 0.0, 0.0)
UP = (0.0, 0.0, 1.0)
DOWNMIX_WEIGHT = 0.7071


def db(value):
    """Converts a linear level to dB."""
    return 20 * math.log10(value + 1e-9)


def speakers(audio):
    """RMS level of every speaker channel of the rendered mix."""
    return [float(math.sqrt((audio[:, i] ** 2).mean())) for i in range(audio.shape[1])]


def pulse(levels):
    """Ear levels when only the front left and front right speakers reach the ears."""
    return levels[lab.SPEAKER_FRONT_LEFT], levels[lab.SPEAKER_FRONT_RIGHT]


def downmix(levels):
    """Ear levels of a correct stereo fold down of the 5.1 mix."""
    fl, fr, c, _, sl, sr = levels[:6]
    return fl + DOWNMIX_WEIGHT * (c + sl), fr + DOWNMIX_WEIGHT * (c + sr)


def main():
    """Prints the PulseAudio and fold down ear levels for a source around the listener."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--distance", type=float, default=4.0)
    args = parser.parse_args()

    signal = os.path.join(tempfile.mkdtemp(), "signal.wav")
    lab.write_test_signal(signal, (300, 1000, 3000))

    def engine_setup(channel):
        """Applies the distance settings the game uses for radios."""
        lab.fmod.FMOD_Channel_Set3DMinMaxDistance(channel, 2, 75)
        lab.fmod.FMOD_Channel_Set3DLevel(channel, 1.0)

    print(f"source {args.distance} tiles away; azimuth is counter clockwise from the listener forward (positive is right)")
    print("azimuth  pulse L   pulse R   downmix L  downmix R")
    for azimuth in range(0, 360, 15):
        a = math.radians(azimuth)
        source = (args.distance * math.cos(a), args.distance * math.sin(a), 0.0)
        audio = lab.render(signal, source, FORWARD, UP, channel_setup=engine_setup,
                           speaker_mode=lab.SPEAKERMODE_5POINT1, mix_rate=lab.GAME_MIX_RATE)
        levels = speakers(audio)
        pl, pr = pulse(levels)
        dl, dr = downmix(levels)
        print(f"{azimuth:7d} {db(pl):8.1f} {db(pr):9.1f} {db(dl):10.1f} {db(dr):10.1f}")


if __name__ == "__main__":
    main()
