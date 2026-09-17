-- Extended showroom pages, registered before showroom.lua.
Aura.showroomPages=function(H)
    local make,label,button,card,heading,on=H.make,H.label,H.button,H.card,H.heading,H.on
    local T=Aura.theme
    local styleNames={"Normal","Kenarlıklı","Likit cam","Gradyan","Modern","Işıltılı","Kesik çizgi"}
    local styles={"solid","outline","glass","gradient","modern","glow","dashed"}
    local function rectangles()
        heading("Yüzeyin karakteri.","Yedi stil. Yuvarlak ya da keskin köşeler. Ortak renk ve boyut sistemi.")
        label("01 / YUVARLAK YÜZEYLER",0,134,840,26,9,T.muted,true)
        for i,style in ipairs(styles) do
            local x=(i-1)*121
            make("panel",x,178,112,112,{style=style,color={43,51,65},borderColor={114,133,156},radius=16,intensity=0.9,dashLength=9,dashGap=5})
            label(styleNames[i],x,302,112,24,9,T.text,true)
        end
        label("02 / KESKİN KÖŞELER",0,352,840,26,9,T.muted,true)
        for i,style in ipairs(styles) do
            local x=(i-1)*121
            make("panel",x,395,112,80,{style=style,color={35,54,49},borderColor=T.accent,sharp=true,intensity=0.8})
        end
        label("03 / BUTONLARDA AYNI STİLLER",0,505,840,24,9,T.muted,true)
        for i,style in ipairs(styles) do
            local b=button(styleNames[i],(i-1)*121,548,112,"secondary",function() uiToast("Stil hazır",style.." · radius veya sharp ile köşeleri değiştir.") end)
            uiSet(b,"style",style); uiSet(b,"borderColor",T.accent); uiSet(b,"color",{36,46,37}); uiSet(b,"size",8)
        end
    end
    local function studio()
        heading("Tasarla. Kopyala. Kullan.","Değişiklikleri canlı gör; bileşenin Lua kodunu panoya al.")
        local controls=card(0,135,280,458,"Yüzey stüdyosu",nil)
        local preview=make("panel",302,135,538,236,{color={19,22,26},border=true})
        label("CANLI ÖNİZLEME",20,13,470,26,8,T.muted,true,preview)
        local sample=make("button",44,90,450,76,{text="Yeni bir şey oluştur  +",style="glass",color={46,59,43},borderColor=T.accent,radius=14},preview)
        local code=make("memo",302,389,538,150,{readOnly=true,size=8,text="",maxLength=8192})
        local function sync()
            uiSet(sample,"x",(538-uiGet(sample,"w"))/2)
            uiSet(sample,"y",60+(150-uiGet(sample,"h"))/2)
            uiSet(code,"text",uiExport(sample))
        end
        local select=make("select",18,58,244,38,{items=styleNames,value=3},controls)
        on(select,"onAuraChange",function(v) uiSet(sample,"style",styles[v]); sync() end)
        local function knob(title,key,y,value,min,max)
            local text=label(title.."  /  "..value,18,y,244,22,9,T.muted,false,controls)
            local el=make("slider",18,y+25,244,24,{value=value,min=min,max=max,step=1},controls)
            on(el,"onAuraChange",function(v) uiSet(sample,key,v); uiSet(text,"text",title.."  /  "..v); sync() end)
        end
        knob("Köşe yarıçapı","radius",110,14,0,38)
        knob("Genişlik","w",171,450,140,490)
        knob("Yükseklik","h",232,76,36,125)
        knob("Çizgi uzunluğu","dashLength",293,8,2,24)
        local sharp=make("switch",18,359,244,32,{text="Keskin köşeler",value=false},controls)
        on(sharp,"onAuraChange",function(v) uiSet(sample,"sharp",v); sync() end)
        for i,c in ipairs({{46,59,43},{38,53,76},{62,42,69},{76,48,36}}) do
            local tint=c
            local b=button("",18+(i-1)*63,407,55,"secondary",function() uiSet(sample,"color",tint); sync() end,controls)
            uiSet(b,"color",tint); uiSet(b,"h",28); uiSet(b,"tooltip","Yüzey rengini uygula")
        end
        button("Lua kodunu kopyala",302,553,538,"primary",function()
            if setClipboard(uiExport(sample)) then uiToast("Kod kopyalandı","Kendi resource'unda parent değişkenini tanımla.") end
        end)
        sync()
    end
    local function data()
        heading("İçerik büyüsün. Düzen kalsın.","Sınırda kırpılan listeler; aranabilir, sıralanabilir ve sayfalanabilir tablo.")
        local scroll=make("scroll",0,138,244,453,{contentHeight=1000})
        for i=1,18 do
            local el=make("button",12,12+(i-1)*52,210,42,{text=string.format("%02d  /  Kaynak öğesi",i),tooltip="Panelin dışındaki öğeler tıklanamaz."},scroll)
            on(el,"onAuraClick",function() uiToast("Öğe seçildi",uiGet(el,"text")) end)
        end
        local search=make("edit",266,138,574,42,{placeholder="Oyuncu, rol veya ID ara…"})
        local rows={}
        for i=1,37 do rows[i]={id=i,name=({"Deniz","Ece","Mert","Selin","Arda","İpek"})[(i-1)%6+1].." "..i,role=i%3==0 and "Yönetici" or "Oyuncu",level=(i*7)%80} end
        local tableEl=make("table",266,196,574,395,{columns={{key="id",label="ID",width=0.4},{key="name",label="Oyuncu",width=1.7},{key="role",label="Rol",width=1},{key="level",label="Seviye",width=0.7}},rows=rows,pageSize=8})
        on(search,"onAuraChange",function(v) uiSet(tableEl,"query",v) end)
        on(tableEl,"onAuraChange",function(_,row) uiToast("Oyuncu seçildi",row.name.." · "..row.role) end)
    end
    local function interaction()
        heading("Detaylarda akış var.","Metin seçimi, odaklı modal, tooltip, bağlam menüsü ve çizgi ikonlar.")
        local c=card(0,138,408,306,"Gelişmiş metin alanı","Ctrl+A/C/X · Ctrl+Z/Y · Shift + yön tuşları")
        make("memo",20,88,368,196,{text="AURA ile yeni bir başlangıç.\n\nMetni seç, düzenle veya geri al.\nTürkçe karakterler: ığüşöç İĞÜŞÖÇ\n\nEnter yeni satır, Ctrl+Enter gönderir.",size=10},c)
        c=card(426,138,414,306,"Katmanlar ve eylemler","Modal açıkken alttaki AURA kontrolleri kilitlenir.")
        local launch=button("Modal pencereyi aç",20,88,374,"primary",function()
            local modal=uiModal({w=440,h=252},H.page())
            label("Değişiklikler kaydedilsin mi?",24,24,392,42,18,T.text,true,modal)
            label("Bu örnek yalnızca bir bildirim gösterir.",24,80,392,28,10,T.muted,false,modal)
            local cancel=button("Vazgeç",24,174,184,"secondary",function() uiDestroy(modal) end,modal)
            button("Kaydet",222,174,194,"primary",function() uiDestroy(modal); uiToast("Kaydedildi","Örnek işlem tamamlandı.") end,modal)
            uiFocus(cancel)
        end,c)
        uiSet(launch,"tooltip","Açmak için tıkla; kapatmak için Escape.")
        local context=button("Sağ tıkla / seçenekler",20,146,374,"outline",nil,c)
        uiSet(context,"contextItems",{"Bağlantıyı kopyala","Favorilere ekle","Öğeyi kaldır"})
        on(context,"onAuraContextSelect",function(_,label) uiToast("Seçenek çalıştı",label) end)
        local tooltip=button("İpucu için üzerinde bekle",20,204,374,"ghost",nil,c)
        uiSet(tooltip,"tooltip","İpuçları 500 ms sonra görünür.")
        label("ÇİZGİ İKONLAR / 14 ADET",0,466,840,25,9,T.muted,true)
        for i,name in ipairs(uiIcons()) do
            local x=(i-1)*60
            make("icon",x+12,507,30,30,{icon=name})
            label(name,x,550,58,24,7,T.muted,false)
        end
    end
    local function templates()
        heading("İlk ekranın hazır.","Giriş, ayarlar, envanter ve mağaza için yeniden kullanılabilir başlangıçlar.")
        local tabs=make("tabs",0,136,840,44,{items={"Giriş","Ayarlar","Envanter","Mağaza"},value=1})
        local template
        local function choose(index)
            if template then uiDestroy(template) end
            template=uiTemplate(({"login","settings","inventory","shop"})[index],{x=0,y=200,w=840,h=394},H.page())
            on(template,"onAuraSubmit",function() uiToast("Şablon olayı alındı","onAuraSubmit üzerinden kendi sistemine bağla.") end)
        end
        on(tabs,"onAuraChange",choose); choose(1)
    end
    return { {"Rectangle stilleri",rectangles},{"Canlı düzenleyici",studio},{"Liste & tablo",data},{"Etkileşim & ikon",interaction},{"Hazır ekranlar",templates} }
end
