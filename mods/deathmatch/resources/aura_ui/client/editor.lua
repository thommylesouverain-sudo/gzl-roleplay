-- Shared UTF-8 editor for single-line edit and multi-line memo.
local A,U=Aura,Aura.util
local E={}; A.editor=E
local function sub(s,a,b) if b and b<a then return "" end; return utf8.sub(s,a,b) end
local function len(s) return utf8.len(s) end
local function ctrl() return getKeyState("lctrl") or getKeyState("rctrl") end
local function shift() return getKeyState("lshift") or getKeyState("rshift") end
function E.init(n)
    if not n.editor then
        local pos=n.p.readOnly and 0 or len(n.p.text)
        n.editor={caret=pos,anchor=pos,sx=0,sy=0,undo={},redo={}}
    end
    return n.editor
end
function E.reset(n) n.editor=nil; E.init(n) end
local function snapshot(n) local e=E.init(n); return {text=n.p.text,caret=e.caret,anchor=e.anchor} end
local function stash(n)
    local e=E.init(n); e.undo[#e.undo+1]=snapshot(n); e.redo={}
    if #e.undo>32 then table.remove(e.undo,1) end
end
local function changed(n) U.emit(n,"onAuraChange",n.p.text) end
local function range(e) return math.min(e.caret,e.anchor),math.max(e.caret,e.anchor) end
function E.insert(n,content)
    if n.p.readOnly then return end
    local e=E.init(n); local a,b=range(e)
    content=content:gsub("\r\n","\n"):gsub("\r","\n")
    if n.kind~="memo" then content=content:gsub("\n"," ") end
    content=sub(content,1,math.max(0,(n.p.maxLength or (n.kind=="memo" and 4096 or 128))-(len(n.p.text)-(b-a))))
    if content=="" and a==b then return end
    stash(n)
    n.p.text=sub(n.p.text,1,a)..content..sub(n.p.text,b+1)
    e.caret=a+len(content); e.anchor=e.caret; e.reveal=true; changed(n)
end
local function lines(n)
    local result,pos={},0
    for value in (n.p.text.."\n"):gmatch("(.-)\n") do
        result[#result+1]={text=value,start=pos}; pos=pos+len(value)+1
    end
    return result
end
local function position(n)
    local e=E.init(n); local rows=lines(n)
    for i,row in ipairs(rows) do if e.caret<=row.start+len(row.text) then return rows,i,e.caret-row.start end end
    return rows,#rows,len(rows[#rows].text)
end
local function move(n,pos)
    local e=E.init(n); e.caret=U.clamp(pos,0,len(n.p.text))
    if not shift() then e.anchor=e.caret end
    e.reveal=true
end
local function restore(n,from,to)
    local e=E.init(n); if #e[from]==0 or n.p.readOnly then return end
    e[to][#e[to]+1]=snapshot(n); local previous=table.remove(e[from])
    n.p.text,e.caret,e.anchor=previous.text,previous.caret,previous.anchor; e.reveal=true; changed(n)
end
function E.key(n,key)
    local e=E.init(n); local a,b=range(e)
    if ctrl() and key=="a" then e.anchor=0; e.caret=len(n.p.text)
    elseif ctrl() and (key=="c" or key=="x") then
        if a~=b and not n.p.password then setClipboard(sub(n.p.text,a+1,b)); if key=="x" then E.insert(n,"") end end
    elseif ctrl() and key=="z" then restore(n,shift() and "redo" or "undo",shift() and "undo" or "redo")
    elseif ctrl() and key=="y" then restore(n,"redo","undo")
    elseif key=="arrow_l" then move(n,(a~=b and not shift()) and a or e.caret-1)
    elseif key=="arrow_r" then move(n,(a~=b and not shift()) and b or e.caret+1)
    elseif key=="home" or key=="end" then
        local rows,i=position(n)
        move(n,ctrl() and (key=="home" and 0 or len(n.p.text)) or (rows[i].start+(key=="home" and 0 or len(rows[i].text))))
    elseif (key=="arrow_u" or key=="arrow_d") and n.kind=="memo" then
        local rows,i,col=position(n); local nextLine=rows[U.clamp(i+(key=="arrow_u" and -1 or 1),1,#rows)]
        move(n,nextLine.start+math.min(col,len(nextLine.text)))
    elseif key=="backspace" or key=="delete" then
        if not n.p.readOnly then
            if a==b then e.anchor=U.clamp(e.caret+(key=="backspace" and -1 or 1),0,len(n.p.text)) end
            E.insert(n,"")
        end
    elseif key=="enter" then
        if n.kind=="memo" and not ctrl() then E.insert(n,"\n") else U.emit(n,"onAuraSubmit",n.p.text) end
    else return false end
    return true
end
local function display(n,s) return n.p.password and string.rep("*",len(s)) or s end
function E.draw(n,x,y,w,h,s,alpha)
    local p,t,e=n.p,A.theme,E.init(n)
    local f=(p.size or 10)*s; local fh=math.max(18*s,dxGetFontHeight(1,U.font(f,false)))
    U.box(x,y,w,h,p.color or t.surface,(p.radius or 10)*s,U.focused()==n.el and t.accent or t.border,nil,alpha,p)
    local ix,iy,iw,ih=x+12*s,y+8*s,w-24*s,h-16*s
    local rows,row,col=position(n)
    local caretX=dxGetTextWidth(display(n,sub(rows[row].text,1,col)),1,U.font(f,false))
    if e.reveal~=false then
        e.sx=math.max(0,math.min(e.sx,caretX)); if caretX-e.sx>iw-3*s then e.sx=caretX-iw+3*s end
        e.sy=math.max(0,math.min(e.sy,(row-1)*fh)); if row*fh-e.sy>ih then e.sy=row*fh-ih end
    end
    e.reveal=false
    e.layout={x=ix,y=iy,w=iw,h=ih,f=f,fh=fh,s=s,rows=rows}
    local saved=U.beginClip(n,ix,iy,iw,ih,p.color or t.surface)
    if not saved then U.text("Metin çizimi kullanılamıyor",ix,iy,iw,ih,t.muted,f); return end
    local a,b=range(e)
    if p.text=="" then U.text(p.placeholder or "",ix,iy,iw,n.kind=="memo" and fh or ih,t.muted,f) end
    for i,line in ipairs(rows) do
        local ly=n.kind=="memo" and iy+(i-1)*fh-e.sy or iy+(ih-fh)/2
        if ly+fh>=iy and ly<iy+ih then
            local start,finish=line.start,line.start+len(line.text)
            if b>start and a<=finish and a~=b then
                local left=dxGetTextWidth(display(n,sub(line.text,1,math.max(0,a-start))),1,U.font(f,false))
                local right=dxGetTextWidth(display(n,sub(line.text,1,math.min(len(line.text),b-start))),1,U.font(f,false))
                if b>finish then right=right+5*s end
                U.rect(ix+left-e.sx,ly,math.max(0,right-left),fh,U.mix(t.surface,t.accent,0.3))
            end
            U.text(display(n,line.text),ix-e.sx,ly,math.max(iw+e.sx,dxGetTextWidth(display(n,line.text),1,U.font(f,false))+1),fh,t.text,f,false)
            if U.focused()==n.el and i==row and getTickCount()%1000<550 then U.rect(ix+caretX-e.sx,ly+2*s,1,fh-4*s,t.accent) end
        end
    end
    U.endClip(n,saved)
end
function E.pointer(n,mx,my,dragging)
    local e=E.init(n); local l=e.layout; if not l then return end
    local index=n.kind=="memo" and U.clamp(math.floor((my-l.y+e.sy)/l.fh)+1,1,#l.rows) or 1
    local row=l.rows[index]; local offset=len(row.text); local px=mx-l.x+e.sx
    local previous=0
    for i=1,len(row.text) do
        local width=dxGetTextWidth(display(n,sub(row.text,1,i)),1,U.font(l.f,false))
        if px<(previous+width)/2 then offset=i-1; break end
        previous=width
    end
    e.caret=row.start+offset
    if not dragging and not shift() then e.anchor=e.caret end
    e.reveal=true
end
A.renderers.memo=function(n,x,y,w,h,s,dt,mx,my,alpha) E.draw(n,x,y,w,h,s,alpha) end
A.interactive.memo=true
