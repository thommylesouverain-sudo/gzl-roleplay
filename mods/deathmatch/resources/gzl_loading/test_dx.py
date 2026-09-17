from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parent
source=(root.parent/'aura_ui/tests/check.py').read_text(encoding='utf-8')
vm=LuaRuntime(unpack_returned_tuples=True)
vm.execute(source.split("lua.execute(r'''",1)[1].split("''')",1)[0])
vm.execute('''
localPlayer=createElement("player"); char=1; chat=true; timers={}; cameraCalls=0; requests=0; exportsCount=0
function getElementData() return char end
function getResourceFromName(n) return n end
function getResourceState(name) return name=="aura_ui" and auraStarted and "running" or "stopped" end
function isChatVisible() return chat end
function showChat(v) chat=v end
function setPlayerHudComponentVisible() end
function fadeCamera() cameraCalls=cameraCalls+1 end
function dxCreateTexture() return createElement("texture") end
function dxGetMaterialSize() return 1920,1080 end
function dxDrawImage() end
function isTransferBoxActive() return transfer==true end
function triggerServerEvent() requests=requests+1 end
function setTimer(f) local t=createElement("timer"); timers[t]=f; return t end
function isTimer(t) return t and timers[t]~=nil end
function killTimer(t) timers[t]=nil end
function outputChatBox() end
function removeEventHandler(event,el,fn)
 for i=#(handlers[event] or {}),1,-1 do if handlers[event][i][2]==fn then table.remove(handlers[event],i) end end
end
exports={aura_ui={uiDrawSurface=function() exportsCount=exportsCount+1; return true end}}
function advance(ms) tick=tick+ms; local list={}; for _,f in pairs(timers) do list[#list+1]=f end; for _,f in ipairs(list) do f() end end
''')
code=(root/'client.lua').read_text(encoding='utf-8-sig')
assert 'guiCreateBrowser' not in code
vm.execute(code)
vm.execute('''
triggerEvent("onClientResourceStart",resourceRoot)
assert(#(handlers.onClientRender or {})==0) -- restarting in game does not interrupt play
commands.loadingtest(); assert(#handlers.onClientRender==1 and cursorVisible)
assert(exportsCount==0) -- dependency not ready: local fallback
auraStarted=true; advance(1000); assert(exportsCount>0)
local before=exportsCount; frame(); frame(); assert(exportsCount==before)
advance(1000); assert(exportsCount==before) -- recovered cache stays stable
advance(20000); assert(#handlers.onClientRender==1) -- preview does not auto-close
assert(cameraCalls==0 and chat and requests==0 and inputMode=="allow_binds")
commands.loadingtest(); assert(#handlers.onClientRender==0 and not cursorVisible and next(timers)==nil)
commands.loadingtest(); triggerEvent("onClientKey",root,"escape",true); assert(#handlers.onClientRender==0)
char=nil; triggerEvent("onClientResourceStart",resourceRoot); assert(requests==1)
triggerEvent("gzl_loading:status",resourceRoot,10,10,false,true)
transfer=true; advance(500); frame(); assert(#handlers.onClientRender==1)
transfer=false; advance(250); advance(1500); assert(#handlers.onClientRender==0 and next(timers)==nil)
-- Unknown progress and reported startup progress both render safely.
triggerEvent("gzl_loading:status",resourceRoot,0,0,true,false)
triggerEvent("onClientResourceStart",resourceRoot); frame()
triggerEvent("gzl_loading:status",resourceRoot,3,10,true,false); frame()
advance(1600); assert(#handlers.onClientRender==1) -- not ready cannot close
triggerEvent("gzl_loading:status",resourceRoot,10,10,false,true)
advance(1500); assert(#handlers.onClientRender==0) -- no forced 30-second delay
char=1; commands.loadingtest(); triggerEvent("onClientResourceStop",resourceRoot); assert(#handlers.onClientRender==0 and next(timers)==nil)
''')
print('PASS: loading toggle/Esc, preview isolation, cached idle frame, ready/transfer gating, automatic completion and stop cleanup.')
