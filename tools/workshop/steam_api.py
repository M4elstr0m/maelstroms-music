"""ctypes bindings of the Steam Workshop calls that steam_publish.py uses, over the libsteam_api.so shipped with the game."""
import ctypes
import os
from pathlib import Path

NATIVES = Path(os.environ.get("PZ_NATIVES", "~/Games/Steam/steamapps/common/ProjectZomboid/projectzomboid/natives")).expanduser()
APP_ID = 108600
INVALID_HANDLE = 0xFFFFFFFFFFFFFFFF
SUBMIT_ITEM_UPDATE_RESULT = 3404

P, c_char_p, u64, u32, i32 = ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint64, ctypes.c_uint32, ctypes.c_int32


class StringArray(ctypes.Structure):
    """Steam's array of strings, as used for the tags."""
    _fields_ = [("strings", ctypes.POINTER(c_char_p)), ("count", i32)]


class SubmitResult(ctypes.Structure):
    """Steam's answer to the submission of an update."""
    _fields_ = [("result", i32), ("needsLegalAgreement", ctypes.c_bool), ("itemId", u64)]


def load():
    """Loads the game's Steam library and declares the signatures of the calls used."""
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
