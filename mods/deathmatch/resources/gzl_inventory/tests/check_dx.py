"""Offline Lua 5.1 integration checks. Does not simulate the MTA GPU/server."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import xml.etree.ElementTree as ET
import re, hashlib, json
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
# Use the existing engine test double without running the AURA screenshot suite.
base=(ROOT.parent/'aura_ui/tests/check.py').read_text(encoding='utf-8')
mock=base.split("lua.execute(r'''",1)[1].split("''')",1)[0]
g=lua.globals(); g.py_len=len; g.py_lower=str.lower; g.py_sub=lambda s,i,j=None:s[int(i)-1:int(j) if j else None]
lua.execute(mock)
lua.execute('''
localPlayer=createElement("player"); setElementParent(localPlayer,root)
serverCalls={}; inputEnabled=false; data={["character:id"]=1}; timers={}
function guiGetInputEnabled() return inputEnabled end
function guiSetInputEnabled(v) inputEnabled=v end
function getElementData(_,key) return data[key] end
function setElementData(_,key,value) data[key]=value end
function isMainMenuActive() return false end
function isMTAWindowFocused() return true end
function getResourceFromName(name) return name end
function getResourceState() return "stopped" end
function triggerServerEvent(name,source,...) serverCalls[#serverCalls+1]={name,source,...} end
function isTimer(t) return t and timers[t]~=nil end
function setTimer(fn,delay,times,...) local t=createElement("timer"); timers[t]={fn,...}; return t end
function killTimer(t) timers[t]=nil end
function removeEventHandler(event,el,fn)
 for i=#(handlers[event] or {}),1,-1 do local h=handlers[event][i]; if h[1]==el and h[2]==fn then table.remove(handlers[event],i) end end
end
function fileExists() return true end
function dxCreateTexture(path) local e=createElement("texture"); return e end
function dxGetMaterialSize() return 128,128 end
function dxDrawImage() end
exports={aura_ui={uiDrawSurface=function() return true end},gzl_ui={isProgressBarActive=function() return false end,startProgressBar=function() return true end}}
''')
for script in ET.parse(ROOT/'meta.xml').getroot().findall('script'):
    if script.get('type') in ('client','shared'):
        code=(ROOT/script.get('src')).read_text(encoding='utf-8-sig')
        assert not re.search(r'\b(?:guiCreateBrowser|createBrowser|executeBrowserJavascript)\s*\(',code)
        lua.execute(code)
lua.execute('''
local D=InventoryDX
local left={id="one",type="player",label="Thommy_Souverain",slots=40,maxWeight=30000,items={
 [1]={slot=1,name="id_card",label="Kimlik Kartı",count=1,weight=50},
 [2]={slot=2,name="phone",label="Akıllı Telefon",count=1,weight=190},
 [3]={slot=3,name="burger",label="Hamburger",count=1,weight=250},
 [4]={slot=4,name="water",label="Su",count=8,weight=350},
 [5]={slot=5,name="cash",label="Nakit Para",count=2466,weight=0}}}
local right={id="world",type="drop",label="Dünya",slots=40,maxWeight=100000,items={}}
triggerEvent("ox_inventory:syncInventory",root,left,right)
assert(not D.visible and #(handlers.onClientRender or {})==0)
inputMode="no_binds_when_editing"
toggleInventory(true); assert(D.visible and cursorVisible and inputMode=="no_binds")
frame()
assert(D.weights[1]==3290)
local cursorReads,materialReads=0,0
local oldCursor,oldSize=getCursorPosition,dxGetMaterialSize
local uniformWrites,exportCalls=0,0
local oldUniform,oldExport=dxSetShaderValue,exports.aura_ui.uiDrawSurface
dxSetShaderValue=function(...) uniformWrites=uniformWrites+1; return oldUniform(...) end
exports.aura_ui.uiDrawSurface=function(...) exportCalls=exportCalls+1; return oldExport(...) end
getCursorPosition=function() cursorReads=cursorReads+1; return oldCursor() end
dxGetMaterialSize=function(...) materialReads=materialReads+1; return oldSize(...) end
frame()
assert(cursorReads==1 and materialReads==0)
assert(uniformWrites==0 and exportCalls==0)
dxSetShaderValue,exports.aura_ui.uiDrawSurface=oldUniform,oldExport
getCursorPosition,dxGetMaterialSize=oldCursor,oldSize
local function point(side,slot)
 local l=D.layout(); local col=(slot-1)%5; local row=math.floor((slot-1)/5)
 return (side==1 and l.x or l.right)+col*(l.cell+l.gap)+l.cell/2,l.y+56*l.s+row*(l.cell+l.gap)+l.cell/2
end
local function sendClick(state,x,y,button)
 cx=x/sw; cy=y/sh; triggerEvent("onClientClick",root,button or "left",state,x,y)
end
local x,y=point(1,4); local tx,ty=point(2,1)
sendClick("down",x,y); keys.lshift=true; sendClick("up",tx,ty); keys.lshift=false
local c=serverCalls[#serverCalls]
assert(c[1]=="ox_inventory:swapItems" and c[3]==4 and c[4]==1 and c[5]=="player" and c[6]=="drop" and c[7]==4)
assert(left.items[4].count==8) -- no optimistic mutation of authoritative data
local l=D.layout(); local ax,ay=l.center,l.y+244*l.s
sendClick("down",ax,ay); triggerEvent("onClientCharacter",root,"3")
assert(D.amount=="3")
sendClick("down",x,y); sendClick("up",tx,ty)
assert(serverCalls[#serverCalls][7]==3)
-- Context menu dispatch, not direct calls to the action bridge.
sendClick("down",x,y,"right"); frame()
sendClick("down",x+10*l.s,y+54*l.s)
assert(serverCalls[#serverCalls][1]=="ox_inventory:giveItem" and serverCalls[#serverCalls][4]==3)
-- Mouse wheel reaches remaining rows independently per panel.
cx=x/sw; cy=y/sh
triggerEvent("onClientKey",root,"mouse_wheel_down",true)
assert(D.scroll[1]==1 and D.scroll[2]==0)
-- Full server snapshots and deltas retain right-hand container types.
right.type="trunk"; right.id="trunk_3"
triggerEvent("ox_inventory:syncInventory",root,left,right); frame()
assert(D.right.type=="trunk")
triggerEvent("ox_inventory:refreshSlots",root,{items={{inventory="player",item={slot=4}}}})
assert(not D.left.items[4])
assert(D.weights[1]==490)
toggleInventory(false)
assert(not D.visible and not cursorVisible and inputMode=="no_binds_when_editing")
assert(next(D.textures)==nil and #(handlers.onClientRender or {})==0)
toggleHotbarDisplay(); assert(D.hotbar and not cursorVisible); frame()
toggleHotbarDisplay(); assert(not D.hotbar and #(handlers.onClientRender or {})==0)
-- Resource and session teardown restore input and clear stale UI.
toggleInventory(true); triggerEvent("auth:showLoginScreen",root)
assert(not D.visible and not isInventoryOpenState())
triggerEvent("onClientResourceStop",resourceRoot)
for _,f in pairs(D.fonts) do assert(not isElement(f)) end
-- Responsive columns stay within the screen.
for _,size in ipairs({{800,600},{1280,720},{1920,1080},{3440,1440}}) do
 sw,sh=size[1],size[2]; local q=D.layout()
 assert(q.x>=0 and q.right+q.w<=sw+1 and q.y>=0 and q.y+744*q.s<=sh)
end
''')
print('PASS: no CEF creation; Lua 5.1; drag/half-stack/count/give/scroll; authoritative snapshots/deltas; container types; hotbar; focus/teardown; 4 resolutions.')
# Server logic, definitions and web source were not part of this presentation migration.
manifest=json.loads((ROOT.parent/'aura_ui/tests/migration_manifest.json').read_text(encoding='utf-8'))
for name,expected in manifest['protected'].items():
    if name.startswith('gzl_inventory/') and name not in ('gzl_inventory/client/main.lua','gzl_inventory/meta.xml'):
        assert hashlib.sha256((ROOT.parent/name).read_bytes()).hexdigest()==expected,name
print('PASS: inventory server/shared/web assets match the pre-migration audit.')
