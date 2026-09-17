-- Reusable local UI compositions; gameplay/auth/payment stays with the caller.
function uiTemplate(kind,properties,parent)
    local supported={login=true,settings=true,inventory=true,shop=true}
    if not supported[kind] then return false end
    local p=Aura.util.copy(properties or {})
    p.w,p.h=p.w or 760,p.h or 380
    if p.w<500 or p.h<330 then return false end
    local root=uiCreate("panel",p,parent)
    if not root then return false end
    local function create(type,x,y,w,h,props,owner)
        props=props or {}; props.x,props.y,props.w,props.h=x,y,w,h
        return uiCreate(type,props,owner or root)
    end
    local function label(text,x,y,w,h,size)
        return create("label",x,y,w,h,{text=text,size=size or 11,bold=true})
    end
    local function click(el,fn) addEventHandler("onAuraClick",el,fn,false) end
    if kind=="login" then
        label("Tekrar hoş geldin.",28,22,p.w-56,42,24)
        create("label",28,65,p.w-56,30,{text="Hesabınla devam et.",textColor=Aura.theme.muted})
        local name=create("edit",28,116,p.w-56,44,{placeholder="Kullanıcı adı",maxLength=48})
        local password=create("edit",28,174,p.w-56,44,{placeholder="Şifre",password=true,maxLength=128})
        local remember=create("checkbox",28,235,p.w-56,30,{text="Beni hatırla",value=false})
        local submit=create("button",28,p.h-72,p.w-56,44,{text="Giriş yap  →",variant="primary",tooltip="Bu şablon kendi başına oturum açmaz."})
        click(submit,function() triggerEvent("onAuraSubmit",root,{username=uiGet(name,"text"),password=uiGet(password,"text"),remember=uiGet(remember,"value")}) end)
    elseif kind=="settings" then
        label("Deneyimini kişiselleştir.",28,22,p.w-56,42,22)
        local notifications=create("switch",28,92,p.w-56,40,{text="Bildirimler",value=true})
        local labels=create("switch",28,147,p.w-56,40,{text="Oyuncu etiketleri",value=true})
        label("Ses seviyesi",28,205,p.w-56,26,10)
        local volume=create("slider",28,245,p.w-56,30,{value=70})
        local save=create("button",28,p.h-72,p.w-56,44,{text="Tercihleri kaydet",variant="primary"})
        click(save,function() triggerEvent("onAuraSubmit",root,{notifications=uiGet(notifications,"value"),labels=uiGet(labels,"value"),volume=uiGet(volume,"value")}) end)
    else
        label(kind=="shop" and "Şehir mağazası" or "Eşyaların",28,20,p.w-56,40,23)
        local selected=label("Bir ürün seç.",28,p.h-54,p.w-230,30,10)
        local scroll=create("scroll",20,80,p.w-40,p.h-152,{contentHeight=420,color=Aura.theme.panel})
        local items=p.items or {{name="Sırt çantası",price=250,icon="bag"},{name="Kimlik",price=50,icon="user"},{name="Kilit",price=80,icon="lock"},{name="Telefon",price=1200,icon="grid"},{name="Anahtarlık",price=60,icon="settings"},{name="Radyo",price=350,icon="bell"}}
        local choice
        for i,item in ipairs(items) do
            local cw=(p.w-90)/3; local x=12+((i-1)%3)*(cw+10); local y=12+math.floor((i-1)/3)*135
            local cell=create("button",x,y,cw,122,{text="",tooltip=item.name},scroll)
            create("icon",12,12,28,28,{icon=item.icon or "bag"},cell)
            create("label",12,49,cw-24,28,{text=item.name,bold=true,size=10},cell)
            create("label",12,81,cw-24,25,{text=kind=="shop" and ("$"..item.price) or "Kullanılabilir",textColor=Aura.theme.accent,size=9},cell)
            local index=i
            click(cell,function() choice=index; uiSet(selected,"text",items[index].name.." seçildi") end)
        end
        uiSet(scroll,"contentHeight",math.ceil(#items/3)*135+24)
        local submit=create("button",p.w-192,p.h-60,164,40,{text=kind=="shop" and "Satın al" or "Kullan",variant="primary"})
        click(submit,function() if choice then triggerEvent("onAuraSubmit",root,{index=choice,item=Aura.util.copy(items[choice])}) else uiToast("Önce bir ürün seç","Listeden bir öğeye tıkla.","warning") end end)
    end
    return root
end
