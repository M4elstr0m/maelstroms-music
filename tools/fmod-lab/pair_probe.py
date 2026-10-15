"""Level of each ear for the two emitter stage of a device, for pan positions from hard left to hard right.

The two emitters sit 40 degrees to each side of the listener and are weighted with the equal power pan law of the
mod. The ears are measured as a PulseAudio stereo output (front left and right speakers only) of the game's 5.1 mix.

usage: python3 pair_probe.py [--distance 6]
"""
import argparse
import math
import os
import tempfile

import fmodlab as lab
from stage_probe import FORWARD, UP, db, pulse, speakers

STAGE_ANGLE = math.radians(40)


def ears(signal, distance, side):
    source = (distance * math.cos(STAGE_ANGLE), distance * math.sin(STAGE_ANGLE) * side, 0.0)

    def engine_setup(channel):
        lab.fmod.FMOD_Channel_Set3DMinMaxDistance(channel, 2, 75)
        lab.fmod.FMOD_Channel_Set3DLevel(channel, 1.0)

    audio = lab.render(signal, source, FORWARD, UP, channel_setup=engine_setup,
                       speaker_mode=lab.SPEAKERMODE_5POINT1, mix_rate=lab.GAME_MIX_RATE)
    return pulse(speakers(audio))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--distance", type=float, default=6.0)
    args = parser.parse_args()

    signal = os.path.join(tempfile.mkdtemp(), "signal.wav")
    lab.write_test_signal(signal, (300, 1000, 3000))
    left_emitter, right_emitter = ears(signal, args.distance, -1), ears(signal, args.distance, 1)

    print(f"stage emitters at 40 degrees, {args.distance} tiles; pulse output level of each ear in dB")
    print("   pan   left ear  right ear  total power")
    for pan in (-1.0, -0.5, 0.0, 0.5, 1.0):
        angle = (pan + 1) * math.pi / 4
        left_gain, right_gain = math.cos(angle), math.sin(angle)
        left = left_gain * left_emitter[0] + right_gain * right_emitter[0]
        right = left_gain * left_emitter[1] + right_gain * right_emitter[1]
        print(f"{pan:6.1f} {db(left):9.1f} {db(right):10.1f} {db(math.sqrt(left ** 2 + right ** 2)):11.1f}")


if __name__ == "__main__":
    main()
