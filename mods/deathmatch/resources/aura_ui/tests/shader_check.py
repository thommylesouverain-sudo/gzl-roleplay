"""Compile the actual shader entry point with Windows D3DCompiler (not an MTA GPU test)."""
import ctypes as C
from pathlib import Path

compiler = C.WinDLL("d3dcompiler_47.dll")
source = (Path(__file__).resolve().parents[1]/"assets"/"surface.fx").read_bytes()
compile_shader = compiler.D3DCompile
compile_shader.restype = C.c_long
compile_shader.argtypes = [C.c_void_p,C.c_size_t,C.c_char_p,C.c_void_p,C.c_void_p,C.c_char_p,C.c_char_p,C.c_uint,C.c_uint,C.POINTER(C.c_void_p),C.POINTER(C.c_void_p)]

def method(blob,index,return_type):
    table=C.cast(blob,C.POINTER(C.POINTER(C.c_void_p))).contents
    return C.WINFUNCTYPE(return_type,C.c_void_p)(table[index])

assert b"VertexShader = compile vs_3_0 surfaceVertex()" in source
assert b"PixelShader = compile ps_3_0 surface()" in source
for entry,profile in ((b"surfaceVertex",b"vs_3_0"),(b"surface",b"ps_3_0")):
    code, errors = C.c_void_p(), C.c_void_p()
    result = compile_shader(source,len(source),b"surface.fx",None,None,entry,profile,0,0,C.byref(code),C.byref(errors))
    if errors:
        pointer=method(errors,3,C.c_void_p)(errors)
        size=method(errors,4,C.c_size_t)(errors)
        print(C.string_at(pointer,size).decode("utf-8",errors="replace"))
        method(errors,2,C.c_ulong)(errors)
    if code:
        print(profile.decode(),"compiled bytes:",method(code,4,C.c_size_t)(code))
        method(code,2,C.c_ulong)(code)
    assert result >= 0, f"D3DCompile {profile!r} failed: {result}"
print("PASS: matched vs_3_0/ps_3_0 stages compile; MTA GPU rendering still requires in-game validation.")
