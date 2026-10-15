"""Updates the Workshop item through the Steam API, without the game's uploader.

usage: python3 tools/workshop/steam_publish.py            dry run: prepares the update like the game, submits nothing
       python3 tools/workshop/steam_publish.py --submit   publishes the update

Reads the staging folder written by `sync-mods.sh release` (~/Zomboid/Workshop/<repository folder name>), the change
note of the version in mod.info from CHANGELOG.md, and uses the Steam session logged in on this machine (no password).
PZ_NATIVES points at the game's natives folder when it is not in the default Steam library.
"""
import ctypes
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build

ROOT = Path(__file__).resolve().parents[2]
STAGING = Path.home() / "Zomboid" / "Workshop" / ROOT.name
NATIVES = Path(os.environ.get("PZ_NATIVES", "~/Games/Steam/steamapps/common/ProjectZomboid/projectzomboid/natives")).expanduser()
APP_ID = 108600
GENERATED_FILES = ("GeneratedRadios.txt", "_radios_manifest.txt")
INVALID_HANDLE = 0xFFFFFFFFFFFFFFFF
SUBMIT_ITEM_UPDATE_RESULT = 3404
VISIBILITIES = {"public": 0, "friendsOnly": 1, "private": 2, "unlisted": 3}
POLL_SECONDS = 1.0
TIMEOUT_SECONDS = 600

P, c_char_p, u64, u32, i32 = ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint64, ctypes.c_uint32, ctypes.c_int32


class StringArray(ctypes.Structure):
    _fields_ = [("strings", ctypes.POINTER(c_char_p)), ("count", i32)]


class SubmitResult(ctypes.Structure):
    _fields_ = [("result", i32), ("needsLegalAgreement", ctypes.c_bool), ("itemId", u64)]


def load_steam():
    os.environ["SteamAppId"] = str(APP_ID)
    os.environ["SteamGameId"] = str(APP_ID)
    lib = ctypes.CDLL(str(NATIVES / "libsteam_api.so"))
    lib.SteamAPI_InitFlat.argtypes = [ctypes.c_char_p]
    lib.SteamAPI_InitFlat.restype = ctypes.c_int
    lib.SteamAPI_SteamUGC_v021.restype = P
    lib.SteamAPI_SteamUtils_v010.restype = P
    lib.SteamAPI_ISteamUGC_StartItemUpdate.argtypes = [P, u32, u64]
    lib.SteamAPI_ISteamUGC_StartItemUpdate.restype = u64
    for setter in ("SetItemTitle", "SetItemDescription", "SetItemContent", "SetItemPreview"):
        function = getattr(lib, f"SteamAPI_ISteamUGC_{setter}")
        function.argtypes = [P, u64, c_char_p]
        function.restype = ctypes.c_bool
    lib.SteamAPI_ISteamUGC_SetItemVisibility.argtypes = [P, u64, ctypes.c_int]
    lib.SteamAPI_ISteamUGC_SetItemVisibility.restype = ctypes.c_bool
    lib.SteamAPI_ISteamUGC_SetItemTags.argtypes = [P, u64, ctypes.POINTER(StringArray), ctypes.c_bool]
    lib.SteamAPI_ISteamUGC_SetItemTags.restype = ctypes.c_bool
    lib.SteamAPI_ISteamUGC_SubmitItemUpdate.argtypes = [P, u64, c_char_p]
    lib.SteamAPI_ISteamUGC_SubmitItemUpdate.restype = u64
    lib.SteamAPI_ISteamUGC_GetItemUpdateProgress.argtypes = [P, u64, ctypes.POINTER(u64), ctypes.POINTER(u64)]
    lib.SteamAPI_ISteamUGC_GetItemUpdateProgress.restype = ctypes.c_int
    lib.SteamAPI_ISteamUtils_IsAPICallCompleted.argtypes = [P, u64, ctypes.POINTER(ctypes.c_bool)]
    lib.SteamAPI_ISteamUtils_IsAPICallCompleted.restype = ctypes.c_bool
    lib.SteamAPI_ISteamUtils_GetAPICallResult.argtypes = [P, u64, P, ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_bool)]
    lib.SteamAPI_ISteamUtils_GetAPICallResult.restype = ctypes.c_bool
    return lib


def read_fields(path):
    fields = {}
    for line in path.read_text(encoding="utf-8").split("\n"):
        key, _, value = line.partition("=")
        fields.setdefault(key, []).append(value)
    return fields


def refuse_generated_files():
    found = [path for name in GENERATED_FILES for path in (STAGING / "Contents").rglob(name)]
    if found:
        sys.exit("the upload folder holds files the game generated from the maintainer's addons, run "
                 "`sync-mods.sh release` right before this script:\n  " + "\n  ".join(str(path) for path in found))


def mod_info_value(key):
    return re.search(rf"^{key}=(.+)$", build.MOD_INFO.read_text(encoding="utf-8"), re.MULTILINE).group(1).strip()


def prepare(lib, ugc, item_id, fields, description):
    handle = lib.SteamAPI_ISteamUGC_StartItemUpdate(ugc, APP_ID, int(item_id))
    if handle == INVALID_HANDLE:
        sys.exit("StartItemUpdate returned an invalid handle")
    tags = fields["tags"][0].split(";")
    array = (c_char_p * len(tags))(*[tag.encode() for tag in tags])
    steps = [
        ("title", lib.SteamAPI_ISteamUGC_SetItemTitle(ugc, handle, fields["title"][0].encode())),
        ("description", lib.SteamAPI_ISteamUGC_SetItemDescription(ugc, handle, description.encode())),
        ("visibility", lib.SteamAPI_ISteamUGC_SetItemVisibility(ugc, handle, VISIBILITIES[fields["visibility"][0]])),
        ("tags", lib.SteamAPI_ISteamUGC_SetItemTags(ugc, handle, ctypes.byref(StringArray(array, len(tags))), False)),
        ("content", lib.SteamAPI_ISteamUGC_SetItemContent(ugc, handle, str(STAGING / "Contents").encode())),
        ("preview", lib.SteamAPI_ISteamUGC_SetItemPreview(ugc, handle, str(STAGING / "preview.png").encode())),
    ]
    print("prepared   :", ", ".join(f"{name}={ok}" for name, ok in steps))
    if not all(ok for _, ok in steps):
        sys.exit("a preparation step failed")
    return handle


def submit(lib, ugc, utils, handle, note):
    call = lib.SteamAPI_ISteamUGC_SubmitItemUpdate(ugc, handle, note.encode())
    if call == 0:
        sys.exit("SubmitItemUpdate was refused (invalid handle)")
    failed = ctypes.c_bool(False)
    started = time.time()
    while not lib.SteamAPI_ISteamUtils_IsAPICallCompleted(utils, call, ctypes.byref(failed)):
        lib.SteamAPI_RunCallbacks()
        done, total = u64(0), u64(0)
        status = lib.SteamAPI_ISteamUGC_GetItemUpdateProgress(ugc, handle, ctypes.byref(done), ctypes.byref(total))
        print(f"  {time.time() - started:5.1f}s status={status} {done.value}/{total.value} bytes", flush=True)
        time.sleep(POLL_SECONDS)
        if time.time() - started > TIMEOUT_SECONDS:
            sys.exit("timed out waiting for Steam")
    result = SubmitResult()
    lib.SteamAPI_ISteamUtils_GetAPICallResult(utils, call, ctypes.byref(result), ctypes.sizeof(result),
                                              SUBMIT_ITEM_UPDATE_RESULT, ctypes.byref(failed))
    print("EResult:", result.result, "| needs legal agreement:", result.needsLegalAgreement, "| item:", result.itemId)
    print("EResult 1 means OK, anything else is Steam's reason for refusing the update.")


def main():
    fields = read_fields(STAGING / "workshop.txt")
    item_id, mod_id, version = fields["id"][0], mod_info_value("id"), mod_info_value("modversion")
    description = "\n".join(fields["description"]) + f"\n\nWorkshop ID: {item_id}\nMod ID: {mod_id}"
    note = build.change_note(version)
    refuse_generated_files()

    print("item       :", item_id)
    print("title      :", fields["title"][0])
    print("version    :", version)
    print("description:", len(description.encode()), "bytes, change note:", len(note.encode()), "bytes")

    lib = load_steam()
    error = ctypes.create_string_buffer(1024)
    if lib.SteamAPI_InitFlat(error) != 0:
        sys.exit("Steam API init failed: " + error.value.decode(errors="replace"))
    ugc, utils = lib.SteamAPI_SteamUGC_v021(), lib.SteamAPI_SteamUtils_v010()
    handle = prepare(lib, ugc, item_id, fields, description)
    if "--submit" in sys.argv:
        submit(lib, ugc, utils, handle, note)
    else:
        print("dry run: SubmitItemUpdate was NOT called, pass --submit to publish")
    lib.SteamAPI_Shutdown()


if __name__ == "__main__":
    main()
