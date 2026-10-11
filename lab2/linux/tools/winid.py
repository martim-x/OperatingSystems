#!/usr/bin/env python3
"""winid.py — найти окно VMware Fusion на экране мака и напечатать:
   <window_id> <x> <y> <w> <h>
Нужен для `screencapture -l<id> file.png` (снимок окна) и `-R x,y,w,h`.
"""
import ctypes
import ctypes.util
import sys
from ctypes import c_void_p, c_int32, c_uint32, c_double, c_long, POINTER, byref

cf = ctypes.cdll.LoadLibrary(ctypes.util.find_library("CoreGraphics") or
                             "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")

cf.CGWindowListCopyWindowInfo.restype = c_void_p
cf.CGWindowListCopyWindowInfo.argtypes = [c_uint32, c_uint32]

kCGWindowListOptionOnScreenOnly = 1
kCGWindowListExcludeDesktopElements = 16
kCGNullWindowID = 0

cf.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32, POINTER(c_void_p)]
cf.CFStringCreateWithCString.restype = c_void_p
cf.CFDictionaryGetValue.argtypes = [c_void_p, c_void_p]
cf.CFDictionaryGetValue.restype = c_void_p
cf.CFNumberGetValue.argtypes = [c_void_p, c_uint32, POINTER(c_double)]
cf.CFNumberGetValue.restype = c_void_p
cf.CFStringGetCString.argtypes = [c_void_p, ctypes.c_char_p, c_long, c_uint32]
cf.CFStringGetCString.restype = c_void_p
cf.CFStringGetLength.argtypes = [c_void_p]
cf.CFStringGetLength.restype = c_long

kCGWindowNumber = "kCGWindowNumber"
kCGWindowOwnerName = "kCGWindowOwnerName"
kCGWindowName = "kCGWindowName"
kCGWindowBounds = "kCGWindowBounds"
kCGWindowLayer = "kCGWindowLayer"


def cfstr(s: str):
    b = s.encode()
    return cf.CFStringCreateWithCString(None, b, len(b), None)


def to_str(cfstr_ref) -> str:
    if not cfstr_ref:
        return ""
    n = cf.CFStringGetLength(cfstr_ref)
    buf = ctypes.create_string_buffer(n + 1)
    cf.CFStringGetCString(cfstr_ref, buf, n + 1, 0x08000100)
    return buf.value.decode("utf-8", "replace")


def get_num(d, key) -> float:
    ref = cf.CFDictionaryGetValue(d, cfstr(key))
    if not ref:
        return 0.0
    out = c_double(0)
    cf.CFNumberGetValue(ref, 6, byref(out))  # kCFNumberCFFloat64Type
    return out.value


def get_str(d, key) -> str:
    return to_str(cf.CFDictionaryGetValue(d, cfstr(key)))


list_ref = cf.CGWindowListCopyWindowInfo(
    kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID)
if not list_ref:
    raise SystemExit("не удалось получить список окон")

CFArrayGetCount = cf.CFArrayGetCount
CFArrayGetCount.argtypes = [c_void_p]
CFArrayGetCount.restype = c_long
CFArrayGetValueAtIndex = cf.CFArrayGetValueAtIndex
CFArrayGetValueAtIndex.argtypes = [c_void_p, c_long]
CFArrayGetValueAtIndex.restype = c_void_p

n = CFArrayGetCount(list_ref)
want = (sys.argv[1] if len(sys.argv) > 1 else "VMware")

for i in range(n):
    d = CFArrayGetValueAtIndex(list_ref, i)
    if not d:
        continue
    owner = get_str(d, kCGWindowOwnerName)
    if want.lower() not in owner.lower():
        continue
    name = get_str(d, kCGWindowName)
    layer = get_num(d, kCGWindowLayer)
    wid = int(get_num(d, kCGWindowNumber))
    b = cf.CFDictionaryGetValue(d, cfstr(kCGWindowBounds))
    x = y = w = h = 0
    if b:
        vals = {}
        for k in ("X", "Y", "Width", "Height"):
            ref = cf.CFDictionaryGetValue(b, cfstr(k))
            v = c_double(0)
            if ref:
                cf.CFNumberGetValue(ref, 6, byref(v))
            vals[k] = v.value
        x, y = int(vals["X"]), int(vals["Y"])
        w, h = int(vals["Width"]), int(vals["Height"])
    print(f"{wid} {x} {y} {w} {h}  owner={owner!r} name={name!r} layer={layer}")
