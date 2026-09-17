"""Offline Lua 5.1 behavior checks and approximate DX layout rendering."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import xml.etree.ElementTree as ET

BASE = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
g.py_len = len
g.py_lower = str.lower
g.py_sub = lambda s, i, j=None: s[int(i)-1 : int(j) if j is not None else None]
lua.execute(r'''
root=1; resourceRoot=2; sourceResource=nil
local nextID=10
elements={[1]=true,[2]=true}; parents={[2]=1}; handlers={}; commands={}; bindings={}; calls={}
sw=1440; sh=960; tick=1000; cx=nil; cy=nil; inputMode="allow_binds"; cursorVisible=false
utf8={len=function(s) return py_len(s) end,sub=function(s,i,j) return py_sub(s,i,j) end,lower=function(s) return py_lower(s) end}
function createElement(t) nextID=nextID+1; elements[nextID]=true; return nextID end
function isElement(e) return elements[e]==true end
function setElementParent(e,p) parents[e]=p end
function getThisResource() return 3 end
function addEvent() return true end
function addEventHandler(event,el,fn,propagate)
 handlers[event]=handlers[event] or {}; table.insert(handlers[event],{el,fn,propagate~=false})
end
function triggerEvent(event,el,...)
 local old=source; source=el
 for _,h in ipairs(handlers[event] or {}) do
  local match=h[1]==el; local p=parents[el]
  while p and not match and h[3] do match=p==h[1]; p=parents[p] end
  if match then h[2](...) end
 end
 source=old
end
function destroyElement(e) if not elements[e] then return false end; triggerEvent("onClientElementDestroy",e); elements[e]=nil; return true end
function guiGetScreenSize() return sw,sh end
function getCursorPosition() if cursorVisible then return cx,cy end end
function isCursorShowing() return cursorVisible end
function showCursor(v) cursorVisible=v end
function getTickCount() return tick end
function guiGetInputMode() return inputMode end
function guiSetInputMode(m) inputMode=m end
keys={}
function getKeyState(key) return keys[key] or false end
function setClipboard(value) clipboard=value; return true end
function cancelEvent() end
function outputDebugString() end
function addCommandHandler(name,fn) commands[name]=fn end
function bindKey(name,state,fn) bindings[name]=fn end
function tocolor(r,g,b,a) return {r,g,b,a or 255} end
function dxCreateFont(path,size) local el=createElement("font"); fonts[el]={path,size}; return el end
fonts={}; uniforms={}; targets={}; currentTarget=nil
function dxCreateRenderTarget(w,h) local el=createElement("rt"); targets[el]={w=w,h=h,calls={}}; return el end
function dxSetRenderTarget(el,clear) currentTarget=el; if el and clear then targets[el].calls={} end; return true end
function dxSetBlendMode() return true end
local function record(call) table.insert(currentTarget and targets[currentTarget].calls or calls,call) end
function dxCreateShader() return createElement("shader") end
function dxSetShaderValue(shader,key,...) uniforms[key]={...} end
function dxDrawImage(x,y,w,h,material,rotation,cx,cy,tint,post)
 if targets[material] then record({kind="target",x=x,y=y,w=w,h=h,target=targets[material]}); return end
 local u={}; for k,v in pairs(uniforms) do u[k]=v end
 record({kind="box",x=x,y=y,w=w,h=h,u=u,post=post})
end
function dxDrawText(s,x,y,x2,y2,c,scale,f,align)
 record({kind="text",s=s,x=x,y=y,w=x2-x,h=y2-y,c=c,f=f,align=align})
end
function dxGetTextWidth(s,scale,f) return utf8.len(s)*(fonts[f] and fonts[f][2] or 10)*0.72 end
function dxGetFontHeight(scale,f) return (fonts[f] and fonts[f][2] or 10)*1.6 end
function dxDrawRectangle(x,y,w,h,c) record({kind="rect",x=x,y=y,w=w,h=h,c=c}) end
function dxDrawLine(x,y,x2,y2,c,width) record({kind="line",x=x,y=y,x2=x2,y2=y2,c=c,width=width}) end
function frame() tick=tick+16; calls={}; triggerEvent("onClientRender",root) end
function click(x,y)
 cx=x/sw; cy=y/sh; frame()
 triggerEvent("onClientClick",root,"left","down",x,y)
 triggerEvent("onClientClick",root,"left","up",x,y)
end
''')
meta = ET.parse(BASE / "meta.xml")
for item in meta.getroot():
    if "src" in item.attrib:
        assert (BASE / item.attrib["src"]).is_file(), item.attrib
for script in meta.getroot().findall("script"):
    lua.execute((BASE / script.attrib["src"]).read_text(encoding="utf-8"))
lua.execute('triggerEvent("onClientResourceStart",resourceRoot); commands.aura(); frame()')

def render(path=None, call_list=None, width=None, height=None):
    scale = 2
    width, height = width or int(g.sw), height or int(g.sh)
    im = Image.new("RGB", (width*scale, height*scale), (9, 11, 13))
    d = ImageDraw.Draw(im)
    def bounds(c):
        return tuple(round(v*scale) for v in (c.x,c.y,c.x+c.w,c.y+c.h))
    def rgb(c, normalized=False):
        return tuple(max(0,min(255,round(c[i]*(255 if normalized else 1)))) for i in (1,2,3))
    for _, c in (call_list if call_list is not None else g.calls).items():
        if c.kind == "box":
            u=c.u
            # CPU approximation of surface.fx, including gradients and dashed borders.
            pw,ph=max(1,round(c.w*scale)),max(1,round(c.h*scale))
            yy,xx=np.mgrid[0:ph,0:pw].astype(np.float32)
            ux,uy=(xx+.5)/pw,(yy+.5)/ph
            qx=np.abs((ux-.5)*c.w)-c.w*.5+u.radius[1]
            qy=np.abs((uy-.5)*c.h)-c.h*.5+u.radius[1]
            distance=np.sqrt(np.maximum(qx,0)**2+np.maximum(qy,0)**2)+np.minimum(np.maximum(qx,qy),0)-u.radius[1]
            def smooth(a,b,v):
                t=np.clip((v-a)/(b-a),0,1)
                return t*t*(3-2*t)
            coverage=1-smooth(-1,0,distance)
            edge=smooth(-u.borderWidth[1]-1,-u.borderWidth[1],distance) if u.borderWidth[1] else np.zeros_like(ux)
            start=np.array([u.fillColor[i] for i in range(1,5)],dtype=np.float32)
            end=np.array([u.endColor[i] for i in range(1,5)],dtype=np.float32)
            axis=ux if u.direction[1] else uy
            base=start[None,None,:]+(end-start)[None,None,:]*axis[:,:,None]
            style=int(u.style[1]); strength=u.intensity[1]
            if style==2: base[:,:,:3]+=((1-uy)**7*.24+np.exp(-np.abs(uy-.45)*18)*.035)[:,:,None]*strength
            if style==4: base[:,:,:3]+=(1-ux)[:,:,None]*.09*strength
            if style==5: base[:,:,:3]+=np.exp(-(((ux-.5)*1.2)**2+((uy-.1)*1.8)**2)*5)[:,:,None]*.32*strength
            stroke=np.array([u.edgeColor[i] for i in range(1,5)],dtype=np.float32)
            if style==6:
                px,py=ux*c.w,uy*c.h
                horizontal=np.minimum(py,c.h-py)<np.minimum(px,c.w-px)
                ah=np.where(py<c.h/2,px,c.w+c.h+c.w-px)
                av=np.where(px>c.w/2,c.w+py,2*c.w+c.h+c.h-py)
                along=np.where(horizontal,ah,av)
                dash=(along%(u.dashLength[1]+u.dashGap[1])<=u.dashLength[1])
                stroke=np.where(dash[:,:,None],stroke,base)
            pixels=base+(stroke-base)*edge[:,:,None]
            pixels[:,:,3]*=coverage
            surface=Image.fromarray((np.clip(pixels,0,1)*255).astype(np.uint8))
            im.paste(surface,(round(c.x*scale),round(c.y*scale)),surface)
        elif c.kind == "target":
            child=render(call_list=c.target.calls,width=int(c.target.w),height=int(c.target.h))
            im.paste(child,(round(c.x*scale),round(c.y*scale)))
        elif c.kind == "rect":
            d.rectangle(bounds(c),fill=rgb(c.c))
        elif c.kind == "line":
            d.line(tuple(round(v*scale) for v in (c.x,c.y,c.x2,c.y2)),fill=rgb(c.c),width=max(1,round(c.width*scale)))
        elif c.kind == "text":
            f = g.fonts[c.f]
            font = ImageFont.truetype(str(BASE/f[1]),max(1,round(f[2]*96/72*scale)))
            text_width=d.textlength(c.s,font=font)
            x=c.x*scale
            if c.align == "center": x+=(c.w*scale-text_width)/2
            elif c.align == "right": x+=c.w*scale-text_width
            bb=d.textbbox((0,0),c.s,font=font)
            y=(c.y+c.h/2)*scale-(bb[3]-bb[1])/2-bb[1]
            d.text((x,y),c.s,font=font,fill=rgb(c.c))
    if path: im.resize((width,height),Image.Resampling.LANCZOS).save(path)
    return im

render(BASE/"tests"/"preview.png")
for title, filename in (("Form elemanları", "forms.png"), ("Butonlar", "buttons.png"), ("Rectangle stilleri", "rectangles.png"), ("Canlı düzenleyici", "studio.png"), ("Liste & tablo", "data.png"), ("Etkileşim & ikon", "interaction.png"), ("Hazır ekranlar", "templates.png")):
    g.target_title = title
    lua.execute('for el,n in pairs(Aura.nodes) do if n.kind=="button" and n.p.x==24 and n.p.text==target_title then triggerEvent("onAuraClick",el); break end end; frame()')
    render(BASE/"tests"/filename)
lua.execute(r'''
local baseline=uiStats().elements
assert(baseline>20)
-- Visit every showroom page repeatedly: no accumulating component trees.
for pass=1,3 do
 local buttons={}
 for el,n in pairs(Aura.nodes) do if n.kind=="button" and n.p.x==24 then buttons[#buttons+1]=el end end
 for _,el in ipairs(buttons) do triggerEvent("onAuraClick",el); frame(); assert(uiStats().elements<160) end
end
commands.aura(); frame(); assert(uiStats().elements==0); assert(not cursorVisible)
showCursor(true)
local panel=uiCreate("panel",{x=0,y=0,w=600,h=600})
local edit=uiCreate("edit",{x=20,y=20,w=200,h=40,maxLength=8},panel)
local changes=0
addEventHandler("onAuraChange",edit,function() changes=changes+1 end,false)
frame(); click(40,40); assert(inputMode=="no_binds")
triggerEvent("onClientCharacter",root,"ş"); triggerEvent("onClientCharacter",root,"ı")
assert(uiGet(edit,"text")=="şı")
triggerEvent("onClientKey",root,"backspace",true); assert(uiGet(edit,"text")=="ş")
triggerEvent("onClientPaste",root,"abc\n123456"); assert(utf8.len(uiGet(edit,"text"))==8)
assert(changes==4)
uiSet(panel,"visible",false); assert(inputMode=="allow_binds")
uiSet(panel,"visible",true)
local check=uiCreate("checkbox",{x=20,y=90,w=200,h=40},panel)
frame(); click(30,100); assert(uiGet(check,"value")==true)
uiSet(check,"disabled",true); frame(); click(30,100); assert(uiGet(check,"value")==true)
local slider=uiCreate("slider",{x=20,y=150,w=200,h=30,min=0,max=100,step=5},panel)
frame(); click(120,165); assert(uiGet(slider,"value")==50)
triggerEvent("onClientKey",root,"arrow_r",true); assert(uiGet(slider,"value")==55)
local select=uiCreate("select",{x=20,y=200,w=200,h=40,items={"One","Two","Three"}},panel)
frame(); click(40,220); frame(); click(40,300); assert(uiGet(select,"value")==2)
local button=uiCreate("button",{x=20,y=360,w=200,h=40},panel)
local clicks=0; addEventHandler("onAuraClick",button,function() clicks=clicks+1 end,false)
frame(); triggerEvent("onClientClick",root,"left","down",30,370)
triggerEvent("onClientClick",root,"left","up",500,500); assert(clicks==0)
click(30,370); assert(clicks==1)
uiFocus(edit); destroyElement(panel); assert(uiStats().elements==0); assert(inputMode=="allow_binds")
sourceResource=77
local foreign=uiCreate("panel",{})
sourceResource=nil
triggerEvent("onClientResourceStop",root,77); assert(not isElement(foreign)); assert(uiStats().elements==0)
assert(not uiSetTheme({accent={"bad",0,0}}))
assert(uiSetTheme({accent={132,205,255}}))
sw=1280; sh=720; commands.aura(); frame(); assert(uiStats().elements>40)
commands.aura(); assert(uiStats().elements==0)
''')
lua.execute((BASE/"tests"/"advanced.lua").read_text(encoding="utf-8"))
lua.execute((BASE/"tests"/"immediate.lua").read_text(encoding="utf-8"))
lua.execute('''
function getResourceFromName(name) return name end
function getResourceState() return "running" end
function getFont() return "default" end
exports.aura_ui=setmetatable({}, {__index=function(_,key) return function(_,...) return _G[key](...) end end})
''')
lua.execute((BASE.parent/"gzl_ui/client/aura.lua").read_text(encoding="utf-8"))
lua.execute('''
calls={}
assert(drawGlassPanel(0,0,300,200,12,false))
assert(drawRoundedBorder(0,0,100,40,10,1,4294967295,false))
assert(calls[2].u.fillColor[4]==0)
assert(drawLiquidButtonSVG(0,0,100,40,10,"blue","hover",false))
assert(drawEditBoxSVG(0,0,100,40,10,"active",false))
assert(drawDiagonalTabBarSVG(0,0,200,40,10,"register",false))
assert(drawNotificationCardSVG(0,0,300,70,12,"error",false,128))
assert(isElement(getFont("bold",12)))
''')
print("PASS: Lua 5.1, original regressions + caret/selection/undo/redo, password clipboard, memo, nested clipping, scrolling, RT cleanup/failure, modal focus trap, table sort/filter/pagination, context menu, exported Lua, all four template submissions")
print(f"Layout preview: {BASE/'tests'/'preview.png'}")
print("PASS: immediate API external RT/postGUI isolation, packed ARGB, border transparency and gzl_ui compatibility facade.")
g.legacySource=(BASE.parent/"gzl_ui/client/components.lua").read_text(encoding="utf-8")
lua.execute('''
inputEnabled=false
function guiGetInputEnabled() return inputEnabled end
function guiSetInputEnabled(value) inputEnabled=value end
local legacyRoot=createElement("resource"); setElementParent(legacyRoot,root)
local legacy=setmetatable({resourceRoot=legacyRoot,drawIconSVG=function() end},{__index=_G})
local chunk=assert(loadstring(legacySource)); setfenv(chunk,legacy); chunk()
legacy.setEditBoxText("regression","")
inputMode="no_binds_when_editing"
legacy.setActiveEditBox("regression")
assert(inputMode=="no_binds" and inputEnabled)
local edit=uiCreate("edit",{text=""})
uiFocus(edit)
assert(legacy.getActiveEditBox()==nil and not inputEnabled)
triggerEvent("onClientCharacter",root,"a")
assert(uiGet(edit,"text")=="a" and legacy.getEditBoxText("regression")=="")
legacy.setActiveEditBox(nil) -- An unrelated background click must not unlock AURA.
assert(inputMode=="no_binds")
legacy.setActiveEditBox("regression")
assert(Aura.util.focused()==nil)
triggerEvent("onClientCharacter",root,"b")
assert(uiGet(edit,"text")=="a" and legacy.getEditBoxText("regression")=="b")
triggerEvent("onClientResourceStop",legacyRoot)
assert(inputMode=="no_binds_when_editing" and not inputEnabled)
uiDestroy(edit)
local shared=getFont("bold",12)
local retained=uiGetFont("bold",12)
assert(shared~=retained)
destroyElement(retained)
assert(isElement(shared) and getFont("bold",12)==shared)
local replacement=uiGetFont("bold",12)
assert(isElement(replacement) and replacement~=retained)
local create=dxCreateFont
dxCreateFont=function() return false end
assert(uiGetFont("bold",91)=="default")
dxCreateFont=create
assert(isElement(uiGetFont("bold",91)))
''')
print("PASS: bidirectional legacy/AURA focus transfer, exclusive text delivery, input mode restoration, independent font ownership and cache recovery.")
