local A,U=Aura,Aura.util
local menu,hover,hoverSince,drag,restoreFocus
local icons={
    plus={{{3,12},{21,12}},{{12,3},{12,21}}},
    close={{{5,5},{19,19}},{{19,5},{5,19}}},
    check={{{4,12},{9,17},{20,6}}},
    arrow={{{4,12},{20,12}},{{13,5},{20,12},{13,19}}},
    chevron={{{7,4},{15,12},{7,20}}},
    menu={{{4,6},{20,6}},{{4,12},{20,12}},{{4,18},{20,18}}},
    grid={{{3,3},{9,3},{9,9},{3,9},{3,3}},{{15,3},{21,3},{21,9},{15,9},{15,3}},{{3,15},{9,15},{9,21},{3,21},{3,15}},{{15,15},{21,15},{21,21},{15,21},{15,15}}},
    search={{{14,15},{21,22}},{{16,8},{14,3},{8,2},{3,5},{2,11},{6,16},{12,17},{16,13},{16,8}}},
    user={{{8,4},{16,4},{17,10},{12,13},{7,10},{8,4}},{{3,22},{4,17},{9,15},{15,15},{20,17},{21,22}}},
    lock={{{6,10},{6,5},{9,2},{15,2},{18,5},{18,10}},{{4,10},{20,10},{20,22},{4,22},{4,10}},{{12,15},{12,18}}},
    bag={{{3,7},{21,7},{20,22},{4,22},{3,7}},{{8,9},{8,4},{10,2},{14,2},{16,4},{16,9}}},
    bell={{{4,17},{7,13},{7,7},{10,3},{14,3},{17,7},{17,13},{20,17},{4,17}},{{9,21},{15,21}}},
    copy={{{8,8},{21,8},{21,21},{8,21},{8,8}},{{16,5},{16,2},{2,2},{2,16},{5,16}}},
    settings={{{12,3},{15,5},{19,5},{20,9},{22,12},{20,15},{19,19},{15,19},{12,22},{9,19},{5,19},{4,15},{2,12},{4,9},{5,5},{9,5},{12,3}},{{9,9},{15,9},{15,15},{9,15},{9,9}}}
}
function uiIcons() local names={}; for name in pairs(icons) do names[#names+1]=name end; table.sort(names); return names end
A.renderers.icon=function(n,x,y,w,h,s,dt,mx,my,alpha)
    local size=math.min(w,h); x=x+(w-size)/2; y=y+(h-size)/2
    for _,path in ipairs(icons[n.p.icon or "grid"] or icons.grid) do
        for i=2,#path do local a,b=path[i-1],path[i]; U.line(x+a[1]*size/24,y+a[2]*size/24,x+b[1]*size/24,y+b[2]*size/24,n.p.textColor or A.theme[n.p.tone or "text"],(n.p.stroke or 1.5)*s,alpha) end
    end
end
A.renderers.scroll=function(n,x,y,w,h,s,dt,mx,my,alpha)
    U.box(x,y,w,h,n.p.color or A.theme.panel,(n.p.radius or 10)*s,A.theme.border,nil,alpha,n.p)
end
A.interactive.scroll=true
local function lower(s) return utf8.lower(tostring(s or "")) end
local function tableView(n)
    if n.view then return n.view end
    local p=n.p; local result={}; local query=lower(p.query)
    for i,row in ipairs(p.rows or {}) do
        local match=query==""
        for _,column in ipairs(p.columns or {}) do if lower(row[column.key]):find(query,1,true) then match=true end end
        if match then result[#result+1]=i end
    end
    local column=(p.columns or {})[p.sortColumn or 0]
    if column then
        table.sort(result,function(a,b)
            local va,vb=p.rows[a][column.key],p.rows[b][column.key]
            if type(va)~="number" or type(vb)~="number" then va,vb=lower(va),lower(vb) end
            if va==vb then return a<b end
            if p.sortDescending then return va>vb end
            return va<vb
        end)
    end
    n.view=result; return result
end
function uiTableView(el) local n=A.nodes[el]; return n and n.kind=="table" and U.copy(tableView(n)) or false end
A.renderers.table=function(n,x,y,w,h,s,dt,mx,my,alpha)
    local p,t=n.p,A.theme; local view=tableView(n)
    local rowsPerPage=math.max(1,math.min(p.pageSize or 6,math.floor((h-88*s)/(38*s))))
    local pages=math.max(1,math.ceil(#view/rowsPerPage)); p.page=U.clamp(p.page or 1,1,pages)
    n.pageCount,n.rowsPerPage=pages,rowsPerPage
    U.box(x,y,w,h,p.color or t.panel,12*s,t.border,nil,alpha,p)
    local columns=p.columns or {}; local total=0
    for _,column in ipairs(columns) do total=total+(column.width or 1) end
    local cx=x+12*s
    for i,column in ipairs(columns) do
        local cw=(w-24*s)*(column.width or 1)/math.max(1,total)
        U.text((column.label or column.key)..(p.sortColumn==i and (p.sortDescending and " ↓" or " ↑") or ""),cx+8*s,y+5*s,cw-16*s,38*s,t.muted,9*s,true)
        U.addHit(n,cx,y,cw,44*s,{header=i})
        cx=cx+cw
    end
    U.rect(x+12*s,y+44*s,w-24*s,1,t.border)
    for rowIndex=1,rowsPerPage do
        local index=view[(p.page-1)*rowsPerPage+rowIndex]
        if index then
            local row=p.rows[index]; local ry=y+48*s+(rowIndex-1)*38*s
            if p.value==index or U.inside(x,ry,w,36*s,mx,my) then U.box(x+8*s,ry,w-16*s,36*s,p.value==index and U.mix(t.panel,t.accent,0.12) or t.surface,6*s) end
            cx=x+12*s
            for _,column in ipairs(columns) do
                local cw=(w-24*s)*(column.width or 1)/math.max(1,total)
                U.text(tostring(row[column.key] or ""),cx+8*s,ry,cw-16*s,36*s,t.text,9*s)
                cx=cx+cw
            end
            U.addHit(n,x+8*s,ry,w-16*s,36*s,{row=index})
        end
    end
    if #view==0 then U.text("Sonuç bulunamadı",x+20*s,y+60*s,w-40*s,50*s,t.muted,11*s) end
    U.text(#view.." kayıt  ·  "..p.page.." / "..pages,x+20*s,y+h-38*s,w-140*s,30*s,t.muted,9*s)
    for i,label in ipairs({"‹","›"}) do
        local bx=x+w-(3-i)*44*s
        U.box(bx,y+h-38*s,34*s,28*s,t.surface,6*s,t.border)
        U.text(label,bx,y+h-38*s,34*s,28*s,t.text,14*s,false,"center")
        U.addHit(n,bx,y+h-38*s,34*s,28*s,{pageDelta=i==1 and -1 or 1})
    end
end
A.interactive.table=true
A.changed=function(n,key)
    if n.kind=="table" and (key=="rows" or key=="columns" or key=="query" or key=="sortColumn" or key=="sortDescending") then n.view=nil; n.p.page=1 end
end
A.activate=function(n,h)
    if n.kind~="table" or not h then return false end
    if h.header then
        n.p.sortDescending=n.p.sortColumn==h.header and not n.p.sortDescending or false
        n.p.sortColumn=h.header; n.view=nil; n.p.page=1
    elseif h.pageDelta then n.p.page=U.clamp((n.p.page or 1)+h.pageDelta,1,n.pageCount or 1)
    elseif h.row then n.p.value=h.row; U.emit(n,"onAuraChange",h.row,U.copy(n.p.rows[h.row])) end
    return true
end
function uiModal(properties,lifetimeParent)
    if lifetimeParent and not A.nodes[lifetimeParent] then return false end
    local p=U.copy(properties or {}); p.modal=true; p.centered=p.centered~=false; p.autoScale=true
    p.w,p.h=p.w or 440,p.h or 240
    local previous=U.focused(); uiFocus(nil); U.invalidate(); menu=nil
    local el=uiCreate("panel",p)
    if el then A.nodes[el].returnFocus=previous; A.nodes[el].lifetimeParent=lifetimeParent; uiFocus(el) end
    return el
end
local function hideMenu() menu=nil end
A.context=function(n,x,y)
    menu={el=n.el,x=x,y=y,items=U.copy(n.p.contextItems),index=1}; uiFocus(n.el)
end
local function chooseContext(index)
    if not menu then return end
    local n=A.nodes[menu.el]; local item=menu.items[index]; menu=nil
    if n and item then U.emit(n,"onAuraContextSelect",index,item) end
end
addEvent("onAuraContextSelect",false)
A.overlay=function(dt,mx,my,hits)
    if menu then
        local n=A.nodes[menu.el]
        if not U.active(n) or not U.enabled(n) or not U.scope(menu.el) then hideMenu(); return end
        local sw,sh=guiGetScreenSize(); local h=#menu.items*34+8
        menu.x,menu.y=U.clamp(menu.x,4,math.max(4,sw-224)),U.clamp(menu.y,4,math.max(4,sh-h-4))
        U.box(menu.x,menu.y,220,h,A.theme.panel,10,A.theme.border)
        for i,label in ipairs(menu.items) do
            local y=menu.y+4+(i-1)*34
            if U.inside(menu.x,y,220,34,mx,my) then menu.index=i end
            if i==menu.index then U.box(menu.x+4,y,212,34,A.theme.surface,6) end
            U.text(label,menu.x+14,y,192,34,A.theme.text,10)
        end
        return
    end
    local candidate
    for i=#hits,1,-1 do local h=hits[i]; if h.enabled and U.scope(h.el) and U.inside(h.x,h.y,h.w,h.h,mx,my) then candidate=h.el; break end end
    if hover~=candidate then hover=candidate; hoverSince=getTickCount() end
    local n=hover and A.nodes[hover]
    if n and n.p.tooltip and getTickCount()-(hoverSince or 0)>500 and mx then
        local sw,sh=guiGetScreenSize(); local w=math.min(sw-16,360,dxGetTextWidth(n.p.tooltip,1,U.font(9,false))+24)
        local x,y=U.clamp(mx+14,8,sw-w-8),U.clamp(my+22,8,sh-44)
        U.box(x,y,w,34,A.theme.surface,8,A.theme.border)
        U.text(n.p.tooltip,x+12,y,w-24,34,A.theme.text,9)
    end
end
A.click=function(button,state,mx,my)
    if not menu then return false end
    if state=="down" then
        if button=="left" and U.inside(menu.x,menu.y+4,220,#menu.items*34,mx,my) then chooseContext(math.floor((my-menu.y-4)/34)+1)
        else hideMenu() end
    end
    return true
end
A.pointer=function(n,h,mx,my)
    if n.kind=="edit" or n.kind=="memo" then A.editor.pointer(n,mx,my,false); drag={el=n.el,editor=true}
    elseif h.scrollbar then drag={el=n.el,scrollbar=true} end
end
A.update=function(dt,mx,my)
    if restoreFocus then local el=restoreFocus; restoreFocus=nil; uiFocus(A.nodes[el] and el or nil) end
    if not drag or U.pressed()~=drag.el or not mx then drag=nil; return end
    local n=A.nodes[drag.el]; if not U.active(n) or not U.enabled(n) or not U.scope(drag.el) then drag=nil; return end
    if drag.editor then A.editor.pointer(n,mx,my,true)
    elseif drag.scrollbar then
        local _,y,_,h=U.geometry(n)
        n.p.scrollY=U.clamp((my-y)/h,0,1)*math.max(0,(n.p.contentHeight or n.p.h)-n.p.h)
    end
end
A.key=function(key)
    if menu then
        if key=="escape" then hideMenu()
        elseif key=="arrow_d" then menu.index=math.min(#menu.items,menu.index+1)
        elseif key=="arrow_u" then menu.index=math.max(1,menu.index-1)
        elseif key=="enter" then chooseContext(menu.index) end
        return true
    end
    local n=A.nodes[U.focused()]
    if n and n.kind=="memo" and (key=="mouse_wheel_up" or key=="mouse_wheel_down") then
        local e=A.editor.init(n); local l=e.layout
        if l then e.sy=U.clamp(e.sy+(key=="mouse_wheel_up" and -1 or 1)*l.fh*3,0,math.max(0,#l.rows*l.fh-l.h)); e.reveal=false end
        return true
    end
    if n and n.kind=="table" and (key=="pgup" or key=="pgdn") then n.p.page=U.clamp((n.p.page or 1)+(key=="pgup" and -1 or 1),1,n.pageCount or 1); return true end
    return false
end
A.forget=function(n)
    if n.p.modal then restoreFocus=n.returnFocus; U.emit(n,"onAuraClose") end
    if menu and menu.el==n.el then menu=nil end
    local remove={}
    for el,node in pairs(A.nodes) do if node.lifetimeParent==n.el then remove[#remove+1]=el end end
    for _,el in ipairs(remove) do uiDestroy(el) end
end
local function literal(value)
    if type(value)=="string" then return string.format("%q",value) end
    if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
    if type(value)=="table" then local parts={}; for i,v in ipairs(value) do parts[i]=literal(v) end; return "{"..table.concat(parts,", ").."}" end
    return "nil"
end
function uiExport(el)
    local n=A.nodes[el]; if not n then return false end
    local lines={"local component = exports.aura_ui:uiCreate("..literal(n.kind)..", {"}
    for _,key in ipairs({"x","y","w","h","text","style","variant","tone","radius","sharp","borderWidth","borderColor","color","gradient","direction","dashLength","dashGap","intensity","opacity"}) do
        if n.p[key]~=nil then lines[#lines+1]="    "..key.." = "..literal(n.p[key]).."," end
    end
    lines[#lines+1]="}, parent)"
    return table.concat(lines,"\n")
end
