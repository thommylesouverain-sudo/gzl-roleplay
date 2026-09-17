-- Immediate-mode calls must not inherit fullscreen showroom state or reset an external RT.
local U=Aura.util
local rt=dxCreateRenderTarget(320,200,false)
dxSetRenderTarget(rt,true)
assert(uiDrawSurface(10,20,100,40,{style="glass",color=4281554286,borderColor=4294967295},false))
assert(currentTarget==rt,"external render target preserved")
assert(#targets[rt].calls==1)
assert(uiDrawBorder(0,0,100,50,10,2,4294967295,false))
local border=targets[rt].calls[2]
assert(border.u.fillColor[4]==0,"border must not cover panel interior")
assert(border.u.edgeColor[4]==1)
assert(uiDrawRectangle(0,0,100,100,2147483648,false))
assert(targets[rt].calls[3].c[4]==128,"packed ARGB alpha preserved")
assert(not uiDrawSurface(0,0,-10,20,{}))
dxSetRenderTarget(); destroyElement(rt)
local f=uiGetFont("bold",12); assert(isElement(f))
assert(uiTextWidth("Account",1,"default-bold")==dxGetTextWidth("Account",1,uiGetFont("default-bold",9)))
commands.aura(); frame()
calls={}
assert(uiDrawPanel(20,20,160,80,12,false)); assert(calls[1].post==false,"showroom postGUI leaked to immediate call")
assert(uiDrawPanel(20,20,160,80,12,true)); assert(calls[2].post==true,"postGUI argument retained")
commands.aura()
