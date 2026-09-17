-- Executed in the offline MTA harness after the original regression suite.
local U=Aura.util
sw,sh=1280,720; showCursor(true)
local function key(k,control,shift)
    keys.lctrl=control or false; keys.lshift=shift or false
    triggerEvent("onClientKey",root,k,true)
    keys.lctrl=false; keys.lshift=false
end
local panel=uiCreate("panel",{w=800,h=650})
local edit=uiCreate("edit",{x=20,y=20,w=300,h=44,text="İzmir"},panel)
uiFocus(edit); frame()
key("home"); triggerEvent("onClientCharacter",root,"Ö")
assert(uiGet(edit,"text")=="Öİzmir","caret inserts at start")
key("a",true); triggerEvent("onClientCharacter",root,"ş")
assert(uiGet(edit,"text")=="ş","selection replacement")
key("z",true); assert(uiGet(edit,"text")=="Öİzmir","undo")
key("y",true); assert(uiGet(edit,"text")=="ş","redo")
key("a",true); key("c",true); assert(clipboard=="ş")
key("x",true); assert(uiGet(edit,"text")=="")
triggerEvent("onClientPaste",root,"A\nB"); assert(uiGet(edit,"text")=="A B")
key("home"); key("arrow_r",false,true); key("delete"); assert(uiGet(edit,"text")==" B")
uiSet(edit,"password",true); key("a",true); clipboard="unchanged"; key("c",true); assert(clipboard=="unchanged")
uiSet(edit,"readOnly",true); triggerEvent("onClientPaste",root,"forbidden"); assert(uiGet(edit,"text")==" B")
local memo=uiCreate("memo",{x=20,y=80,w=300,h=120,text="Türkçe\nİkinci"},panel)
uiFocus(memo); frame(); key("home",true); key("end"); key("enter")
assert(uiGet(memo,"text")=="Türkçe\n\nİkinci","memo newline")
key("z",true); assert(uiGet(memo,"text")=="Türkçe\nİkinci")
key("arrow_d"); assert(Aura.nodes[memo].editor.caret==13,"vertical caret")
local submit=0; addEventHandler("onAuraSubmit",memo,function() submit=submit+1 end,false)
key("enter",true); assert(submit==1)
local scroll=uiCreate("scroll",{x=350,y=20,w=220,h=100,contentHeight=300},panel)
local visible=uiCreate("button",{x=10,y=10,w=180,h=40,text="Visible"},scroll)
local offscreen=uiCreate("button",{x=10,y=120,w=180,h=40,text="Offscreen"},scroll)
local clicks=0
addEventHandler("onAuraClick",offscreen,function() clicks=clicks+1 end,false)
frame(); assert(currentTarget==nil,"target restored")
click(370,150); assert(clicks==0,"clipped child cannot be clicked")
cx,cy=400/sw,70/sh; key("mouse_wheel_down"); assert(uiGet(scroll,"scrollY")==40)
uiSet(scroll,"scrollY",100); frame(); click(370,55); assert(clicks==1,"scrolled child can be clicked")
uiSet(scroll,"disabled",true); cx,cy=400/sw,70/sh; key("mouse_wheel_down"); assert(uiGet(scroll,"scrollY")==100)
uiSet(scroll,"disabled",false)
local nested=uiCreate("scroll",{x=10,y=190,w=180,h=60,contentHeight=120},scroll)
uiCreate("button",{x=10,y=10,w=120,h=30,text="Nested"},nested)
uiSet(scroll,"scrollY",170); frame(); assert(currentTarget==nil)
local rt=Aura.nodes[scroll].rt; local nestedRT=Aura.nodes[nested].rt
assert(isElement(rt) and isElement(nestedRT))
uiSet(scroll,"w",240); frame(); assert(Aura.nodes[scroll].rt~=rt and isElement(Aura.nodes[scroll].rt),"resize reallocates immediately")
assert(not isElement(rt)); rt=Aura.nodes[scroll].rt
uiDestroy(scroll); assert(not isElement(rt) and not isElement(nestedRT),"target cleanup")
-- Underlying hitboxes are rejected immediately, even before the next frame.
local underlying=uiCreate("button",{x=20,y=240,w=200,h=40},panel)
local underlyingClicks=0
addEventHandler("onAuraClick",underlying,function() underlyingClicks=underlyingClicks+1 end,false)
uiFocus(underlying); frame()
local modal=uiModal({w=400,h=200},panel)
local yes=uiCreate("button",{x=20,y=20,w=160,h=40,text="Yes"},modal)
local no=uiCreate("button",{x=200,y=20,w=160,h=40,text="No"},modal)
assert(not uiFocus(underlying),"modal focus trap")
click(30,250); assert(underlyingClicks==0)
uiFocus(yes); frame(); key("tab"); assert(U.focused()==no); key("tab"); assert(U.focused()==yes)
key("escape"); frame(); assert(not isElement(modal)); assert(U.focused()==underlying,"restore previous focus")
local dependent=uiModal({w=400,h=200},panel); uiDestroy(panel); frame(); assert(not isElement(dependent))
assert(uiStats().elements==0)
local tab=uiCreate("table",{x=20,y=20,w=600,h=250,pageSize=3,
    columns={{key="name",label="Name"},{key="score",label="Score"}},
    rows={{name="Ada",score=10},{name="Şule",score=2},{name="Can",score=30},{name="Bora",score=1},{name="Deniz",score=9}}})
frame(); click(400,40); local view=uiTableView(tab); assert(view[1]==4 and view[5]==3,"numeric ascending sort")
frame(); click(400,40); view=uiTableView(tab); assert(view[1]==3 and view[5]==4,"descending sort")
uiSet(tab,"query","şu"); assert(#uiTableView(tab)==1 and uiTableView(tab)[1]==2,"UTF-8 filter")
uiSet(tab,"query",""); frame(); click(583,245); assert(uiGet(tab,"page")==2,"pagination")
uiSet(tab,"rows",{{name="Only",score=1}}); frame(); assert(uiGet(tab,"page")==1,"page clamp")
uiDestroy(tab)
local ctx=uiCreate("button",{x=20,y=20,w=200,h=40,contextItems={"Copy","Remove"},tooltip="A tooltip"})
local chosen
addEventHandler("onAuraContextSelect",ctx,function(i) chosen=i end,false)
frame(); triggerEvent("onClientClick",root,"right","down",40,40); frame(); key("arrow_d"); key("enter"); assert(chosen==2)
-- Export is executable Lua and preserves the selected style values.
uiSet(ctx,"style","dashed"); uiSet(ctx,"sharp",true); uiSet(ctx,"dashLength",12)
exports={aura_ui={uiCreate=function(_,...) return uiCreate(...) end}}
parent=nil
local code=uiExport(ctx); assert(loadstring(code),"export Lua syntax")
local before=uiStats().elements; assert(loadstring(code))(); assert(uiStats().elements==before+1)
local cleanup={}; for el in pairs(Aura.nodes) do cleanup[#cleanup+1]=el end
for _,el in ipairs(cleanup) do uiDestroy(el) end
for _,kind in ipairs({"login","settings","inventory","shop"}) do
    local template=uiTemplate(kind,{w=760,h=380}); frame(); assert(template)
    local got=false; addEventHandler("onAuraSubmit",template,function(payload) got=type(payload)=="table" end,false)
    local submit,cell
    for el,n in pairs(Aura.nodes) do
        if n.parent==template and n.kind=="button" then submit=el end
        if n.kind=="button" and n.p.tooltip=="Sırt çantası" then cell=el end
    end
    if cell then triggerEvent("onAuraClick",cell) end
    triggerEvent("onAuraClick",submit); assert(got,"template submits local payload")
    uiDestroy(template); assert(uiStats().elements==0,"template cleanup")
end
-- No render-target allocation failure may draw unclipped children.
local original=dxCreateRenderTarget
dxCreateRenderTarget=function() return false end
local failed=uiCreate("scroll",{w=200,h=80,contentHeight=300})
local hidden=uiCreate("button",{y=10,w=100,h=40},failed)
local fired=false; addEventHandler("onAuraClick",hidden,function() fired=true end,false)
frame(); click(10,20); assert(not fired,"allocation failure is fail-closed")
uiDestroy(failed); dxCreateRenderTarget=original
assert(uiStats().elements==0)
