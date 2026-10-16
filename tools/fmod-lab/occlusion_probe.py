"""Effect of the engine's occlusion factors on a source, per frequency band, with the game's FMOD init flags."""
import math
import os
import tempfile

import fmodlab as lab

BANDS = (300, 1000, 3000, 6000, 10000)
FACTORS = (0.0, 0.24, 0.33, 0.59, 0.79, 0.9)


def main():
    """Prints the level change per frequency band for each occlusion factor."""
    signal = os.path.join(tempfile.mkdtemp(), "signal.wav")
    lab.write_test_signal(signal, BANDS)
    reference = None
    print("level in dB relative to no occlusion, source 3 units ahead")
    print("occlusion " + "".join(f"{band:>9d}Hz" for band in BANDS))
    for factor in FACTORS:
        def setup(channel, factor=factor):
            """Configures the channel with a wide distance range and the occlusion factor under test."""
            lab.fmod.FMOD_Channel_Set3DMinMaxDistance(channel, 100, 10000)
            lab.fmod.FMOD_Channel_Set3DOcclusion(channel, factor, 0.0)
        audio = lab.render(signal, (0, 0, 3), (0, 0, 1), (0, 1, 0), channel_setup=setup)
        levels = [lab.band_level(audio[:, 0], band) for band in BANDS]
        reference = reference or levels
        print(f"{factor:9.2f} " + "".join(f"{20 * math.log10((v + 1e-9) / (r + 1e-9)):11.1f}" for v, r in zip(levels, reference)))


if __name__ == "__main__":
    main()
