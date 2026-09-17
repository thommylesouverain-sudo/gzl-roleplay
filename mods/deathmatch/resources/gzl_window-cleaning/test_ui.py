from pathlib import Path
from lupa.lua51 import LuaRuntime
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent
vm=LuaRuntime(unpack_returned_tuples=True)
base=(root.parent/'aura_ui/tests/check.py').read_text(encoding='utf-8')
g=vm.globals(); g.py_len=len; g.py_lower=str.lower; g.py_sub=lambda s,i,j=None:s[int(i)-1:int(j) if j else None]
vm.execute(base.split("lua.execute(r'''",1)[1].split("''')",1)[0])
vm.execute('''
localPlayer=createElement("player"); requests={}; Audio={playButtonClick=function() end}
function getElementChildren(el) local out={}; for child,parent in pairs(parents) do if parent==el and isElement(child) then out[#out+1]=child end end; return out end
function getPlayerName() return "Test Oyuncusu" end
function triggerServerEvent(event,...) requests[#requests+1]=event end
exports={aura_ui=setmetatable({}, {__index=function(_,key) return function(_,...) return _G[key](...) end end})}
''')
vm.execute((root.parent/'aura_ui/client/core.lua').read_text(encoding='utf-8'))
vm.execute((root/'shared/config.lua').read_text(encoding='utf-8-sig'))
vm.execute((root/'client/ui_lobby.lua').read_text(encoding='utf-8-sig'))
vm.execute('''
LobbyUI.open(nil,{})
assert(LobbyUI.isOpen())
local tabs
for el,n in pairs(Aura.nodes) do if n.kind=="tabs" then tabs=el end end
assert(tabs)
uiSet(tabs,"value",2); triggerEvent("onAuraChange",tabs,2)
LobbyUI.updateData(nil,{})
for el,n in pairs(Aura.nodes) do if n.kind=="tabs" then assert(n.p.value==2) end end
local create
for el,n in pairs(Aura.nodes) do if n.p.text=="Takım oluştur" then create=el end end
assert(create); triggerEvent("onAuraClick",create)
assert(requests[#requests]=="windowCleaning:createTeam")
LobbyUI.close(); assert(not LobbyUI.isOpen() and uiStats().elements==0)
LobbyUI.open({isGroup=true,leader=localPlayer,members={{element=localPlayer,name="Test"}}},{})
assert(LobbyUI.isOpen()); LobbyUI.close(); assert(uiStats().elements==0)
''')
compile=vm.eval('function(code) local f,e=loadstring(code); return f~=nil,e end')
for resource in (root,root.parent/'gzl_loading'):
    for script in ET.parse(resource/'meta.xml').getroot().findall('script'):
        path=resource/script.get('src'); ok,error=compile(path.read_text(encoding='utf-8-sig')); assert ok,(path,error)
print('PASS: lobby create-team action, team rendering, tab persistence, cleanup and loading/cleaning Lua 5.1 syntax.')
