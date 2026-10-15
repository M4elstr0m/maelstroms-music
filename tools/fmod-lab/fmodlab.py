"""Offline probe of the game's own FMOD build: render a test signal to a WAV file and measure the level of each ear."""
import ctypes
import math
import os
import struct
import tempfile
import wave

import numpy as np

NATIVES = os.environ.get("PZ_NATIVES", "~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/natives")
RATE = 48000

FMOD_2D, FMOD_3D, FMOD_LOOP_NORMAL, FMOD_CREATESAMPLE = 0x8, 0x10, 0x2, 0x100
OUTPUT_WAVWRITER_NRT = 5
SPEAKERMODE_STEREO = 3
INIT_FLAGS_GAME = 0x20300

P = ctypes.c_void_p


class Vec(ctypes.Structure):
    _fields_ = [("x", ctypes.c_float), ("y", ctypes.c_float), ("z", ctypes.c_float)]


def _load():
    lib = ctypes.CDLL(os.path.join(os.path.expanduser(NATIVES), "libfmod.so"))
    c_float, c_int = ctypes.c_float, ctypes.c_int
    signatures = {
        "FMOD_System_Create": [ctypes.POINTER(P), ctypes.c_uint],
        "FMOD_System_SetOutput": [P, c_int],
        "FMOD_System_SetSoftwareFormat": [P, c_int, c_int, c_int],
        "FMOD_System_Init": [P, c_int, ctypes.c_uint, ctypes.c_char_p],
        "FMOD_System_Set3DSettings": [P, c_float, c_float, c_float],
        "FMOD_System_CreateSound": [P, ctypes.c_char_p, ctypes.c_uint, P, ctypes.POINTER(P)],
        "FMOD_System_PlaySound": [P, P, P, c_int, ctypes.POINTER(P)],
        "FMOD_System_Set3DListenerAttributes": [P, c_int] + [ctypes.POINTER(Vec)] * 4,
        "FMOD_System_Update": [P],
        "FMOD_System_Release": [P],
        "FMOD_Channel_Set3DAttributes": [P, ctypes.POINTER(Vec), ctypes.POINTER(Vec)],
        "FMOD_Channel_Set3DMinMaxDistance": [P, c_float, c_float],
        "FMOD_Channel_Set3DLevel": [P, c_float],
        "FMOD_Channel_Set3DSpread": [P, c_float],
        "FMOD_Channel_Set3DOcclusion": [P, c_float, c_float],
        "FMOD_Channel_SetPaused": [P, c_int],
        "FMOD_Channel_Stop": [P],
        "FMOD_Sound_Release": [P],
    }
    for name, argtypes in signatures.items():
        getattr(lib, name).argtypes = argtypes
    return lib


fmod = _load()


def create_system():
    system = P()
    for minor in range(0, 10):
        for patch in range(0, 60):
            if fmod.FMOD_System_Create(ctypes.byref(system), (2 << 16) | (minor << 8) | patch) == 0:
                return system
    raise RuntimeError("no FMOD header version is accepted by this library")


def write_test_signal(path, tones, seconds=2):
    t = np.arange(int(seconds * RATE)) / RATE
    signal = sum(np.sin(2 * np.pi * f * t + i) for i, f in enumerate(tones)) * 0.6 / len(tones)
    pcm = (np.stack([signal, signal], axis=1) * 32767).astype("<i2")
    with wave.open(path, "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def _read_wav(path):
    with open(path, "rb") as f:
        data = f.read()
    position, fmt, samples = 12, None, None
    while position + 8 <= len(data):
        chunk, size = data[position:position + 4], struct.unpack("<I", data[position + 4:position + 8])[0]
        body = data[position + 8:position + 8 + size]
        if chunk == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif chunk == b"data":
            samples = body
        position += 8 + size + (size & 1)
    tag, channels, _, _, _, bits = fmt
    dtype = "<f4" if tag == 3 and bits == 32 else "<i2"
    audio = np.frombuffer(samples, dtype=dtype).astype(np.float32)
    return (audio / 32768 if dtype == "<i2" else audio).reshape(-1, channels)


def render(signal, source, listener_forward, listener_up, mode_3d=True, channel_setup=None, init_flags=INIT_FLAGS_GAME):
    output = tempfile.mktemp(suffix=".wav")
    system = create_system()
    fmod.FMOD_System_SetOutput(system, OUTPUT_WAVWRITER_NRT)
    fmod.FMOD_System_SetSoftwareFormat(system, RATE, SPEAKERMODE_STEREO, 0)
    assert fmod.FMOD_System_Init(system, 1024, init_flags, output.encode()) == 0
    fmod.FMOD_System_Set3DSettings(system, 1.0, 1.0, 1.0)
    sound, channel, still = P(), P(), Vec(0, 0, 0)
    mode = (FMOD_3D if mode_3d else FMOD_2D) | FMOD_LOOP_NORMAL | FMOD_CREATESAMPLE
    assert fmod.FMOD_System_CreateSound(system, signal.encode(), mode, None, ctypes.byref(sound)) == 0
    fmod.FMOD_System_Set3DListenerAttributes(system, 0, ctypes.byref(still), ctypes.byref(still),
                                             ctypes.byref(Vec(*listener_forward)), ctypes.byref(Vec(*listener_up)))
    fmod.FMOD_System_PlaySound(system, sound, None, 1, ctypes.byref(channel))
    if mode_3d:
        fmod.FMOD_Channel_Set3DAttributes(channel, ctypes.byref(Vec(*source)), ctypes.byref(still))
        if channel_setup:
            channel_setup(channel)
    fmod.FMOD_Channel_SetPaused(channel, 0)
    for _ in range(150):
        fmod.FMOD_System_Update(system)
    fmod.FMOD_Channel_Stop(channel)
    fmod.FMOD_System_Update(system)
    fmod.FMOD_Sound_Release(sound)
    fmod.FMOD_System_Release(system)
    audio = _read_wav(output)
    os.unlink(output)
    return audio[int(0.4 * RATE):int(1.6 * RATE)]


def rms_db(channel):
    return 20 * math.log10(float(np.sqrt(np.mean(channel * channel))) + 1e-12)


def band_level(channel, frequency):
    spectrum = np.abs(np.fft.rfft(channel * np.hanning(len(channel)))) * 2 / len(channel)
    k = int(round(frequency * len(channel) / RATE))
    return float(spectrum[max(0, k - 2):k + 3].max())
