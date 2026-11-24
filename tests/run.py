import ctypes
import os
from pathlib import Path
lib = ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
lib.lua_pushstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lib.lua_setglobal.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lib.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = [ctypes.c_void_p]
state = lib.luaL_newstate()
lib.luaL_openlibs(state)
try:
    test_dir = Path(__file__).resolve().parent
    addon_dir = test_dir.parent
    if not (addon_dir / "ForeverWeaponSwap.lua").is_file():
        addon_dir /= "ForeverWeaponSwap"
    lib.lua_pushstring(state, os.fsencode(addon_dir / "ForeverWeaponSwap.lua"))
    lib.lua_setglobal(state, b"addonSource")
    result = lib.luaL_loadfilex(state, os.fsencode(test_dir / "test.lua"), None)
    if not result:
        result = lib.lua_pcallk(state, 0, 0, 0, 0, None)
    if result:
        raise SystemExit(lib.lua_tolstring(state, -1, None).decode())
finally:
    lib.lua_close(state)
