-- Immutable instances of AURA's exact shader: no rasterization, downsampling,
-- render-target text, or per-frame export/uniform updates on cache hits.
InventorySurface={}
local cache,order={},{}
local white=tocolor(255,255,255,255)
local retryAt=0
local function rgba(c) return c[1]/255,c[2]/255,c[3]/255,(c[4] or 255)/255 end
local function colorKey(c)
    return c and table.concat(c,",") or "-"
end
function InventorySurface.clear()
    for _,material in pairs(cache) do if isElement(material) then destroyElement(material) end end
    cache,order={},{}
end
function InventorySurface.draw(x,y,w,h,c,r,edge)
    if w<=0 or h<=0 then return end
    r=r or 5
    if r==0 and not edge then
        return dxDrawRectangle(x,y,w,h,tocolor(c[1],c[2],c[3],c[4] or 255),true)
    end
    -- Exact float sizes retained: fractional scaling matches AURA's SDF inputs.
    local key=w..":"..h..":"..r..":"..colorKey(c)..":"..colorKey(edge)
    local material=cache[key]
    if not isElement(material) and getTickCount()>=retryAt then
        material=dxCreateShader(":aura_ui/assets/surface.fx")
        if material then
            if #order>=96 then
                local oldest=table.remove(order,1)
                if isElement(cache[oldest]) then destroyElement(cache[oldest]) end
                cache[oldest]=nil
            end
            dxSetShaderValue(material,"size",w,h)
            dxSetShaderValue(material,"radius",math.min(r,w/2,h/2))
            dxSetShaderValue(material,"borderWidth",edge and 1 or 0)
            dxSetShaderValue(material,"fillColor",rgba(c))
            dxSetShaderValue(material,"endColor",rgba(c))
            dxSetShaderValue(material,"edgeColor",rgba(edge or c))
            dxSetShaderValue(material,"style",0)
            dxSetShaderValue(material,"direction",0)
            dxSetShaderValue(material,"dashLength",8)
            dxSetShaderValue(material,"dashGap",5)
            dxSetShaderValue(material,"intensity",0.7)
            cache[key]=material; order[#order+1]=key
        else retryAt=getTickCount()+2000 end
    end
    if isElement(material) then return dxDrawImage(x,y,w,h,material,0,0,0,white,true) end
    -- Preserve the existing renderer if GPU resource creation fails.
    return exports.aura_ui:uiDrawSurface(x,y,w,h,{color=c,radius=r,borderColor=edge},true)
end
addEventHandler("onClientResourceStop",resourceRoot,InventorySurface.clear)
