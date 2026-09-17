-- Optional showcase. Remove this script entry from meta.xml in production.
local window, page, current, nav = nil, nil, "Genel bakış", {}
local cursorOwned=false
local T=Aura.theme
local function make(kind,x,y,w,h,props,parent)
    props=props or {}; props.x,props.y,props.w,props.h=x,y,w,h
    return uiCreate(kind,props,parent or page)
end
local function label(s,x,y,w,h,size,c,bold,parent)
    return make("label",x,y,w,h,{text=s,size=size or 10,textColor=c or T.text,bold=bold},parent)
end
local function on(el,event,fn) addEventHandler(event,el,fn,false) end
local function button(s,x,y,w,variant,fn,parent,tone)
    local el=make("button",x,y,w,40,{text=s,variant=variant,tone=tone},parent)
    if fn then on(el,"onAuraClick",fn) end
    return el
end
local function card(x,y,w,h,title,subtitle)
    local el=make("panel",x,y,w,h,{radius=14})
    label(title,22,16,w-44,28,12,nil,true,el)
    if subtitle then label(subtitle,22,44,w-44,25,9,T.muted,false,el) end
    return el
end
local function notify() uiToast("Her şey yerli yerinde.","Bu bildirim de kitin bir parçası.","success") end
local function heading(title,subtitle)
    label("BİLEŞEN KÜTÜPHANESİ / "..string.upper(current),0,0,840,24,8,T.muted,true)
    label(title,0,35,840,48,28,T.text,true)
    label(subtitle,0,88,840,26,10,T.muted)
end
local function overview()
    heading("Küçük detaylar. Büyük fark.","Bir tasarım dili. Tüm projelerin. Tamamen DX.")
    local hero=make("panel",0,138,840,164,{color={33,42,31},gradient={21,27,25},radius=16,border=false})
    make("badge",24,20,116,24,{text="AURA / SYSTEM",size=8},hero)
    label("İyi arayüz, hissedilir.",24,54,620,42,23,nil,true,hero)
    label("Tutarlı yüzeyler, canlı durumlar ve düşünülmüş etkileşimler.",24,103,610,26,10,{175,191,169},false,hero)
    label("a",720,12,90,135,72,T.accent,true,hero)
    local c=card(0,320,408,204,"Aksiyonlar","Net bir hiyerarşi. Gerektiği kadar vurgu.")
    button("Projeyi oluştur  +",22,86,190,"primary",notify,c)
    button("Önizle",224,86,162,"outline",notify,c)
    make("badge",22,149,82,25,{text="Aktif",tone="success",size=8},c)
    make("badge",114,149,114,25,{text="Geliştiriliyor",tone="warning",size=8},c)
    make("badge",238,149,148,25,{text="v0.2 / PREVIEW",tone="info",size=8},c)
    c=card(426,320,414,204,"Kontrol sende","Aynı bileşenler. Kendi tercihlerine göre.")
    make("switch",22,83,360,32,{text="Bildirimleri etkinleştir",value=true},c)
    label("Efekt yoğunluğu",22,132,260,24,9,T.muted,false,c)
    local amount=label("64%",339,132,52,24,9,T.accent,true,c)
    local slider=make("slider",22,162,370,22,{value=64},c)
    on(slider,"onAuraChange",function(v) uiSet(amount,"text",v.."%") end)
    local items={{"16","TEMEL BİLEŞEN"},{"07","YÜZEY STİLİ"},{"04","HAZIR EKRAN"}}
    for i,item in ipairs(items) do
        local x=(i-1)*286
        label(item[1],x,549,70,35,22,T.text,true)
        label(item[2],x+78,552,190,30,8,T.muted,true)
    end
end
local function actions()
    heading("Aksiyonun bir dili var.","Ana, ikincil, çizgili ve sessiz aksiyonlar. Aynı ölçü, aynı ritim.")
    local c=card(0,138,840,170,"Butonlar","Hover, basılı, odak ve devre dışı durumları.")
    for i,item in ipairs({{"Devam et  →","primary"},{"İkincil","secondary"},{"Çizgili","outline"},{"Sessiz","ghost"}}) do
        button(item[1],22+(i-1)*201,91,183,item[2],notify,c)
    end
    c=card(0,326,840,158,"Anlam taşıyan renkler","Renk tek başına değil; açıklayıcı metinle birlikte.")
    for i,item in ipairs({{"Kaydedildi","success"},{"Dikkat gerekli","warning"},{"Bağlantı hatası","danger"},{"Yeni sürüm","info"}}) do
        local title,tone=item[1],item[2]
        button(title,22+(i-1)*201,91,183,"outline",function() uiToast(title,"Semantik renk örneği.",tone) end,c,tone)
    end
    local disabled=button("Şu anda kullanılamıyor",0,506,232,"secondary")
    uiSet(disabled,"disabled",true)
    label("TAB ile gezin · ENTER / SPACE ile çalıştır",254,506,570,40,10,T.muted)
end
local function forms()
    heading("Formlar, zahmetsiz.","Metin girişi, seçim ve ayarlar; tutarlı durumlarla bir arada.")
    local c=card(0,138,408,418,"Yeni profil","DX metin girişi · Türkçe karakter · Yapıştırma")
    label("Görünen ad",22,88,360,24,9,T.muted,true,c)
    local name=make("edit",22,119,364,44,{placeholder="Adını yaz…",maxLength=40},c)
    label("Başlangıç bölgesi",22,180,360,24,9,T.muted,true,c)
    make("select",22,211,364,44,{items={"Los Santos","San Fierro","Las Venturas"},value=1},c)
    local consent=make("checkbox",22,280,364,32,{text="Profilimi görünür yap",value=true},c)
    button("Profili oluştur  →",22,346,364,"primary",function()
        local n=uiGet(name,"text")
        if n:match("%S") then uiToast("Profil hazır",n.." · görünürlük: "..(uiGet(consent,"value") and "açık" or "kapalı"))
        else uiToast("Bir ad gerekli","Devam etmek için görünen adını yaz.","warning"); uiFocus(name) end
    end,c)
    c=card(426,138,414,418,"Deneyimini düzenle","Değişiklikler bu oturumdaki örneğe uygulanır.")
    make("switch",22,88,370,40,{text="Arayüz sesleri",value=true},c)
    make("switch",22,140,370,40,{text="Oyuncu etiketleri",value=false},c)
    make("divider",22,202,370,1,{},c)
    label("Ses seviyesi",22,223,290,26,10,nil,true,c)
    local level=label("72%",327,223,64,26,10,T.accent,true,c)
    local control=make("slider",22,267,370,30,{value=72,min=0,max=100,step=1},c)
    on(control,"onAuraChange",function(v) uiSet(level,"text",v.."%") end)
    make("checkbox",22,334,370,40,{text="Deneysel özellikler",disabled=true},c)
end
local function feedback()
    heading("Durumlar anlaşılır olsun.","Bildirimler, rozetler ve ilerleme göstergeleri.")
    local c=card(0,138,840,163,"Durum rozetleri","Sessiz yüzeyler üzerinde anlamlı renkler.")
    for i,v in ipairs({{"Çevrimiçi","success"},{"Beklemede","warning"},{"Bağlantı yok","danger"},{"Güncel","info"},{"Öne çıkan","accent"}}) do
        make("badge",22+(i-1)*162,95,147,30,{text=v[1],tone=v[2],size=9},c)
    end
    c=card(0,319,408,233,"Yükleme durumu","Değer slider ile canlı güncellenir.")
    local status=label("Kaynaklar hazırlanıyor · 68%",22,87,364,25,10,nil,true,c)
    local progress=make("progress",22,125,364,20,{value=68},c)
    local slider=make("slider",22,175,364,28,{value=68},c)
    on(slider,"onAuraChange",function(v) uiSet(progress,"value",v); uiSet(status,"text","Kaynaklar hazırlanıyor · "..v.."%") end)
    c=card(426,319,414,233,"Bildirim merkezi","En fazla dört bildirim; süreli ve animasyonlu.")
    button("Başarılı işlem",22,90,178,"outline",notify,c,"success")
    button("Uyarı göster",212,90,180,"outline",function() uiToast("Değişiklikler bekliyor","Ayrılmadan önce kaydet.","warning") end,c,"warning")
    button("Hata bildirimi",22,148,370,"outline",function() uiToast("Bağlantı kurulamadı","Lütfen tekrar dene.","danger") end,c,"danger")
end
local function navigation()
    heading("Her şeyin bir yeri var.","Segmentli seçimler ve açılır menüler. Fare ya da klavye ile.")
    local c=card(0,138,840,355,"Sekmeler","Seçim değişikliği onAuraChange olayı üzerinden iletilir.")
    local tabs=make("tabs",22,93,796,48,{items={"Genel","Güvenlik","Bildirimler"},value=1},c)
    local title=label("Genel ayarlar",26,174,770,40,20,nil,true,c)
    local desc=label("Profilini ve arayüz tercihlerini burada düzenle.",26,223,770,30,11,T.muted,false,c)
    on(tabs,"onAuraChange",function(v)
        local data={{"Genel ayarlar","Profilini ve arayüz tercihlerini burada düzenle."},{"Güvenlik ayarları","Hesabının erişim tercihlerini burada göster."},{"Bildirim tercihleri","Hangi olayları görmek istediğini seç."}}
        uiSet(title,"text",data[v][1]); uiSet(desc,"text",data[v][2])
    end)
    make("select",26,278,300,44,{items={"Kompakt görünüm","Rahat görünüm","Geniş görünüm"}},c)
    label("İpucu: TAB ile odaklan, yön tuşları ile seçimi değiştir.",0,520,840,36,10,T.muted)
end
local function theme()
    heading("Bir temel. Senin imzan.","Renkleri tek noktadan değiştir; bileşenler aynı dili konuşsun.")
    local c=card(0,138,840,212,"Vurgu rengi","Tema değişikliği tüm aktif bileşenlere uygulanır.")
    for i,v in ipairs({{"Lime",{201,244,111}},{"Buz",{132,205,255}},{"Lavanta",{192,170,255}},{"Şeftali",{255,187,144}}}) do
        local tint=v[2]
        local b=button(v[1],22+(i-1)*201,93,183,"secondary",function() uiSetTheme({accent=tint}); uiToast("Tema güncellendi","Vurgu rengi tüm projeye uygulanabilir.") end,c)
        uiSet(b,"textColor",tint)
    end
    make("progress",22,168,796,12,{value=78},c)
    c=card(0,368,840,184,"Yüzey paleti","Grafit arka plan · Dengeli kontrast · 8 px aralık sistemi")
    for i,v in ipairs({{"Zemin","background"},{"Panel","panel"},{"Yüzey","surface"},{"Kenar","border"},{"Metin","text"},{"Vurgu","accent"}}) do
        local x=22+(i-1)*135
        make("panel",x,88,121,38,{color=T[v[2]],radius=8,border=false},c)
        label(v[1],x,133,121,24,9,T.muted,false,c)
    end
end
local pages={["Genel bakış"]=overview,["Butonlar"]=actions,["Form elemanları"]=forms,["Geri bildirim"]=feedback,["Gezinme"]=navigation,["Tema & yüzeyler"]=theme}
local pageNames={"Genel bakış","Rectangle stilleri","Canlı düzenleyici","Butonlar","Form elemanları","Liste & tablo","Etkileşim & ikon","Geri bildirim","Gezinme","Hazır ekranlar","Tema & yüzeyler"}
for _,entry in ipairs(Aura.showroomPages({make=make,label=label,button=button,card=card,heading=heading,on=on,page=function() return page end})) do pages[entry[1]]=entry[2] end
local function showPage(name)
    current=name
    if page then uiDestroy(page) end
    page=make("panel",250,82,840,600,{color=T.background,border=false,radius=0},window)
    for title,el in pairs(nav) do uiSet(el,"variant",title==name and "primary" or "ghost") end
    pages[name]()
end
local function close()
    if not window then return end
    uiDestroy(window); window,page=nil,nil; nav={}
    if cursorOwned then showCursor(false); cursorOwned=false end
end
local function open()
    if window then close(); return end
    window=uiCreate("panel",{w=1120,h=748,centered=true,autoScale=true,color=T.background,radius=18,fullscreenBackdrop=true})
    make("panel",10,10,212,728,{color=T.panel,radius=12,border=false},window)
    label("aura",30,25,140,54,30,T.text,true,window)
    label("DX INTERFACE SYSTEM",32,82,176,22,8,T.muted,true,window)
    make("divider",32,127,166,1,{},window)
    label("WORKSPACE",32,153,166,25,8,T.muted,true,window)
    for i,title in ipairs(pageNames) do
        local name=title
        nav[title]=button(title,24,188+(i-1)*34,184,"ghost",function() showPage(name) end,window)
        uiSet(nav[title],"h",29); uiSet(nav[title],"size",9)
    end
    make("panel",24,579,184,105,{color={28,34,28},border=false},window)
    label("Projenden bağımsız.",38,592,158,28,10,T.accent,true,window)
    label("Kopyala. Başlat. Tasarla.",38,625,158,24,8,T.muted,false,window)
    label("AURA  /  0.2.0",32,702,166,22,8,T.muted,true,window)
    label("Kütüphane   /   Bileşenler",250,24,580,32,9,T.muted,false,window)
    make("badge",899,25,120,28,{text="DX / PREVIEW",size=8,tone="success"},window)
    button("×",1038,19,52,"ghost",close,window)
    make("divider",250,65,840,1,{},window)
    make("divider",250,695,840,1,{},window)
    label("Tasarım bir bütün. Her bileşen onun parçası.",250,707,660,26,9,T.muted,false,window)
    label("/aura  ·  F7",950,707,140,26,9,T.muted,false,window)
    showPage(current)
    cursorOwned=not isCursorShowing()
    if cursorOwned then showCursor(true) end
end
addCommandHandler("aura",open)
bindKey("F7","down",open)
addEventHandler("onClientResourceStop",resourceRoot,function() if cursorOwned then showCursor(false) end end)
