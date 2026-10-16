"""Level of each ear while the listener turns, for a radio at a fixed place.

usage: python3 pan_probe.py [--listener vanilla|camera]
"""
import argparse
import math
import os
import tempfile

import fmodlab as lab

VANILLA_FORWARD = (-math.sqrt(0.5), -math.sqrt(0.5), 0.0)
UP = (0.0, 0.0, 1.0)


def camera_orientation(yaw, pitch):
    """Listener forward and up vectors for a camera yaw and pitch, as Viewpoint builds them."""
    c = math.cos(pitch)
    forward = (math.cos(yaw) * c, math.sin(yaw) * c, math.sin(pitch) * 3 / 2.4494896)
    length = math.sqrt(sum(v * v for v in forward))
    forward = tuple(v / length for v in forward)
    up = (-forward[2] * forward[0], -forward[2] * forward[1], 1 - forward[2] ** 2)
    up_length = math.sqrt(sum(v * v for v in up))
    return forward, tuple(v / up_length for v in up)


def main():
    """Prints the level of each ear while the listener turns on the spot."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--listener", choices=("vanilla", "camera"), default="camera")
    args = parser.parse_args()

    signal = os.path.join(tempfile.mkdtemp(), "signal.wav")
    lab.write_test_signal(signal, (300, 1000, 3000))
    source = (4.0, 0.0, 0.0)

    def engine_setup(channel):
        """Applies the distance settings the game uses for radios."""
        lab.fmod.FMOD_Channel_Set3DMinMaxDistance(channel, 2, 75)
        lab.fmod.FMOD_Channel_Set3DLevel(channel, 1.0)

    print("radio 4 tiles east, minimum distance 2, maximum 75; level of each ear in dB")
    print("heading    left     right")
    for degrees in range(0, 360, 45):
        forward, up = camera_orientation(math.radians(degrees), 0.0) if args.listener == "camera" else (
            tuple(math.cos(math.radians(degrees)) * v for v in VANILLA_FORWARD), UP)
        audio = lab.render(signal, source, forward, up, channel_setup=engine_setup)
        print(f"{degrees:7d} {lab.rms_db(audio[:, 0]):8.1f} {lab.rms_db(audio[:, 1]):8.1f}")


if __name__ == "__main__":
    main()
