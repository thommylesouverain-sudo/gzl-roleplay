"""Compare cached shader inputs to the original AURA renderer, without GPU claims."""
import check_dx as test
from lupa.lua51 import LuaRuntime
def runtime():
    vm=LuaRuntime(unpack_returned_tuples=True)
    vm.execute(test.mock)
    return vm
original=runtime()
for name in ('core.lua','immediate.lua'):
    original.execute((test.ROOT.parent/'aura_ui/client'/name).read_text(encoding='utf-8'))
original.execute('triggerEvent("onClientResourceStart",resourceRoot)')
cached=runtime()
cached.execute((test.ROOT/'client/surfaces.lua').read_text(encoding='utf-8'))
cases=[(123.2,123.2,10,[22,25,29],[48,54,61]),(96,60,9,[201,244,111],None),
       (82.13,82.13,6.67,[38,46,34],[201,244,111]),(1600,890,18,[15,17,20],[48,54,61]),
       (112,46,8,[15,17,20],[201,244,111]),(284,104,8,[22,25,29,250],[48,54,61])]
for w,h,r,c,edge in cases:
    options=original.table_from({'color':original.table_from(c),'radius':r})
    if edge:options.borderColor=original.table_from(edge)
    original.globals().uiDrawSurface(0,0,w,h,options,True)
    cached.globals().InventorySurface.draw(0,0,w,h,cached.table_from(c),r,cached.table_from(edge) if edge else None)
    a={k:tuple(v.values()) for k,v in original.globals().uniforms.items()}
    b={k:tuple(v.values()) for k,v in cached.globals().uniforms.items()}
    assert a==b,(a,b)
cached.execute('''
local writes=0
dxSetShaderValue=function() writes=writes+1 end
InventorySurface.draw(0,0,284,104,{22,25,29,250},8,{48,54,61})
assert(writes==0)
InventorySurface.clear()
local exportsCount=0
exports={aura_ui={uiDrawSurface=function() exportsCount=exportsCount+1 end}}
dxCreateShader=function() return false end
InventorySurface.draw(0,0,100,100,{22,25,29},10)
InventorySurface.draw(0,0,100,100,{22,25,29},10)
assert(exportsCount==2)
''')
print('PASS: exact AURA shader uniform parity for six surfaces; warm-frame zero export/uniform writes; shader failure preserves original fallback.')
