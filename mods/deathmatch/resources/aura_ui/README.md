# AURA / DX Interface Kit 0.2

Bağımsız MTA:SA 1.6 client resource. CEF, gzl_core veya gzl_ui bağımlılığı yok.
Grafit yüzeyler, Manrope tipografi, değiştirilebilir vurgu renkleri ve çalışan showroom.

Mevcut GZL DX ekranlarının AURA çizim katmanına geçişi ve çalıştırma notları:
[MIGRATION.md](MIGRATION.md). CEF arayüzleri bu geçişin dışındadır.

## Çalıştırma

Sunucu konsolunda `refresh`, ardından `start aura_ui`. Oyunda `/aura` veya **F7**.
Showroom kendi cursor talebini açılış/kapanışta yönetir. Diğer panellerin cursor yönetimi çağıran resource'a aittir.
Showroom açıkken opak tam ekran arka plan çizilir. Render önceliği `low-9999`;
showroom ve arka plan `postGUI` katmanındadır. Kapanınca bu katman kaldırılır.
Başka kök panellerde de `fullscreenBackdrop=true` kullanılabilir.
Bu özellik alttaki arayüzleri görsel olarak örter; diğer resource'ların input handler'larını durdurmaz.
Üretimde showroom istenmiyorsa `meta.xml` içindeki `client/showroom.lua` ve
`client/showroom_pages.lua` satırlarını kaldırın.

## Başka resource içinde kullanım

Çağıran resource'un meta.xml dosyasına `<include resource="aura_ui" />` ekleyin.

```lua
local ui = exports.aura_ui
local window = ui:uiCreate("panel", {
    w = 460, h = 240, centered = true, autoScale = true
})
local name = ui:uiCreate("edit", {
    x = 24, y = 40, w = 412, h = 44, placeholder = "Görünen ad"
}, window)
local save = ui:uiCreate("button", {
    x = 24, y = 112, w = 412, h = 44,
    text = "Kaydet", variant = "primary"
}, window)
addEventHandler("onAuraClick", save, function()
    ui:uiToast("Kaydedildi", ui:uiGet(name, "text"), "success")
end, false)
showCursor(true)
-- Kapanışta: ui:uiDestroy(window); showCursor(false)
```

Elementler client taraflıdır. Ödeme, yetki, envanter gibi işlemlerde sunucunun
isteği ayrıca doğrulaması gerekir. Örnek profil formu yalnızca yerel etkileşim demosudur.

## Bileşenler

| Tür | Özellikler |
| --- | --- |
| panel | color, gradient, radius, border |
| label | text, size, bold, textColor, align |
| button | text, variant: primary / secondary / outline / ghost, tone |
| badge | text, tone |
| edit | text, placeholder, maxLength, password |
| checkbox, switch | text, value (boolean) |
| slider | value, min, max, step |
| progress | value, min, max |
| tabs, select | items (metin dizisi), value (1 tabanlı indeks) |
| divider | w, h |
| scroll | contentHeight, scrollY, scrollStep; çocuklar viewport'a kırpılır |
| memo | text, placeholder, maxLength, readOnly; çok satırlı edit |
| table | columns, rows, query, page, pageSize, sortColumn, sortDescending |
| icon | icon, stroke, textColor, tone |

Ortak: `x, y, w, h, visible, disabled, opacity`. Boyutlar mantıksal pikseldir.
Çocuk koordinatları ebeveyne göredir. Kök `autoScale=true` ile ekrana sığar;
`centered=true` ile ortalanır. Oluşturma sırası çizim sırasıdır.
`visible` ve `disabled` çocuklara da uygulanır. `opacity` bileşene özeldir.

## API

* `uiCreate(kind, properties, parent?) → element | false`
* `uiSet(element, property, value) → boolean` — programatik değişim event üretmez.
* `uiGet(element, property) → value`
* `uiDestroy(element)` — çocukları ve odak durumunu da temizler.
* `uiFocus(element | nil)` — edit odağında oyun bind'leri engellenir, çıkışta önceki mod geri yüklenir.
* `uiSetTheme({accent={201,244,111}, ...})` — global tema token'larını değiştirir.
* `uiToast(title, message, tone?, durationMs?)` — en fazla dört bildirim.
* `uiStats()` — elements, drawCalls (yaklaşık çizim sayısı), shader.
* `uiModal(properties, lifetimeParent?)` — modal panel oluşturur, AURA odağını kilitler. `uiDestroy` veya Escape ile kapanır; önceki odak geri yüklenir. lifetimeParent silinirse modal da silinir.
* `uiExport(element)` — panel/buton yüzey özelliklerinin Lua oluşturma kodunu döndürür; çocuk ağacını veya event handler'ları içermez.
* `uiIcons()` — 14 çizgi ikonunun adlarını döndürür.
* `uiTemplate(kind, properties, parent?)` — `login`, `settings`, `inventory`, `shop`; en az 500×330 mantıksal piksel.
* `uiTableView(tableElement)` — filtrelenmiş/sıralanmış kaynak satır indeksleri; sayfadan bağımsız.

Event'ler: `onAuraClick`, `onAuraChange(value)`, `onAuraSubmit(text)`, `onAuraFocus(boolean)`.
Ek event'ler: `onAuraContext(mouseX, mouseY)`, `onAuraContextSelect(index, label)`,
`onAuraClose()` (modal kapanışı). Tablo seçimi `onAuraChange(sourceRowIndex, rowCopy)` üretir.
Şablonlar `onAuraSubmit(payload)` üretir. Login payload'ı username/password/remember;
ayarlar notifications/labels/volume; envanter ve mağaza index/item alanlarını içerir.
Şablonların sunucu bağlantısı yoktur; giriş, ödeme veya oyun durumu kendiliğinden değişmez.
`source` ilgili bileşendir. Parent üzerinden dinlenebilir; tek bileşende `propagate=false` kullanın.
Resource durduğunda ona ait elementler temizlenir. Harici `destroyElement` de desteklenir.

Tema token'ları: background, panel, surface, border, text, muted, accent, ink,
danger, success, warning, info. RGB veya RGBA (0–255). Açık vurgu renklerinde
`ink` koyu tutulmalıdır. Sabit `color` / `textColor` verilmiş bileşenler o rengi korur.

## Rectangle ve buton stilleri

`panel` ve `button` aynı yüzey seçeneklerini paylaşır:

| style | Görünüm |
| --- | --- |
| solid | Düz dolgu |
| outline | İnce kenarlık, düşük opaklıklı dolgu |
| glass | Üst yansımalı cam görünümü; gerçek sahne blur'u değil |
| gradient | İki renk arasında geçiş |
| modern | Yatay aydınlatmalı katmanlı yüzey |
| glow | Merkezden yayılan yumuşak ışık |
| dashed | Kesik çizgili kenarlık |

`sharp=true` veya `radius=0` **her stilde** keskin köşe verir. Kesik çizgi ve keskin
köşe birbirinden bağımsızdır. Ek seçenekler: `borderColor`, `borderWidth`, `gradient`
(ikinci RGB renk), `direction="horizontal" | "vertical"`, `intensity=0..1`,
`dashLength`, `dashGap`, `fillAlpha=0..255` (outline). Stiller gerçek DX shader ile çizilir.
Shader 3.0 desteklenmiyorsa kare köşeli düz dolgu/kenarlık yedeği kullanılır;
cam, ışık ve gradyan efekti bu yedekte bulunmaz, kesik çizgi korunur.

```lua
local card = exports.aura_ui:uiCreate("panel", {
    x = 24, y = 24, w = 320, h = 150,
    style = "dashed", sharp = true,
    color = {25, 34, 31}, borderColor = {201, 244, 111},
    dashLength = 10, dashGap = 6, borderWidth = 1
}, parent)
```

Showroom **Rectangle stilleri** sayfası yedi stilin yuvarlak/keskin köşelerini ve
buton karşılıklarını gösterir. **Canlı düzenleyici** stil, renk, boyut, radius,
keskin köşe ve çizgi uzunluğunu canlı değiştirir; “Lua kodunu kopyala” ile kod alınır.
Koddaki `parent` değişkenini kendi panelinize bağlayın veya `nil` yapın.

## Liste, tablo ve katmanlar

```lua
local list = ui:uiCreate("scroll", {
    x=20, y=20, w=260, h=300, contentHeight=900
}, parent)
-- Çocukları list içine normal mantıksal koordinatlarla yerleştirin.
local grid = ui:uiCreate("table", {
    x=300, y=20, w=500, h=320, pageSize=6,
    columns={{key="name", label="Ad", width=2}, {key="level", label="Seviye", width=1}},
    rows={{name="Deniz", level=14}, {name="Ece", level=8}}
}, parent)
ui:uiSet(grid, "query", "Deniz")
```

Tabloda sütun başlıkları sıralamayı değiştirir. Sayı değerleri sayısal sıralanır;
eşit değerlerde kaynak sırası korunur. Seçim event'i filtre öncesi satır indeksini döndürür.
`rows`, `columns`, `query` veya sıralama değişince sayfa 1'e döner.
Tablo başına sütun genişlikleri `width` ağırlıklarına göre paylaşılır.

Scroll viewport'u dikdörtgen render target ile kırpılır; iç içe scroll desteklenir.
Kaydırma mouse wheel veya scrollbar sürüklemesiyle çalışır. Görünmeyen öğeler hit-test'e
girmez. İçerik yüksekliğini `contentHeight` ile çağıran taraf belirler.
Render target ayrılamazsa içerik çizilmez/tıklanmaz; hata metni gösterilir.
Normal `panel` çocukları kırpmaz; taşma gereken alanlarda `scroll` kullanın.

Butona `tooltip="Açıklama"` eklemek 500 ms gecikmeli ipucu verir.
`contextItems={"Kopyala", "Kaldır"}` sağ tık menüsü açar. Menüde yön tuşları,
Enter ve Escape kullanılabilir. Seçilen işlemi `onAuraContextSelect` ile bağlayın.
Modal kilidi bu kitin bileşenleri içindir; diğer resource input handler'larını durdurmaz.

## Klavye ve sınırlar

Bir bileşene tıkladıktan sonra Tab / Shift+Tab ile gezinilir. Buton ve anahtarlarda
Enter / Space; slider, select ve tabs üzerinde yön tuşları çalışır. Escape odağı bırakır.
Edit ve memo: UTF-8, fareyle caret/seçim, Shift+yön tuşları, Home/End,
Ctrl+Home/End, Ctrl+A/C/X, yapıştırma, Backspace/Delete, Ctrl+Z/Y ve 32 adımlık undo.
Password alanlarından kesme/kopyalama yapılmaz. `readOnly=true` düzenlemeyi kapatır.
Memo'da Enter satır ekler, Ctrl+Enter gönderir; odaklı memo mouse wheel ile kayar.
Memo açık satır sonlarını korur; otomatik sözcük kaydırma, IME ve sözcük bazlı
Ctrl+yön hareketi yoktur. Select/context listelerini kısa kullanın.
Gizli paneller çizilmez, açık viewport'lar ve metin alanları her kare yenilenir.

Shader bir kez oluşturulur; boyut ve renkler uniform üzerinden verilir. Fontlar boyuta
göre önbelleklenir. Render target'lar yeniden kullanılır, boyut değişince yenilenir,
element silindiğinde serbest bırakılır. Her kare yeniden çizildikleri için alt-tab
sonrası statik içerik kaybı oluşmaz. İkonlar DX çizgileriyle çizilir; harici ikon/font bağımlılığı yoktur.
Gerçek shader derlemesi, GPU görüntüsü ve FPS yalnızca MTA istemcisinde doğrulanabilir.

## Doğrulama

`python aura_ui/tests/check.py` (Python + lupa + Pillow + NumPy). Lua 5.1 yükleme,
caret/seçim/undo, nested clipping, RT hatası/temizliği, modal odak kilidi, tablo,
context menü, dışa aktarılan Lua ve dört şablonun event'lerini sahte MTA ortamında kontrol eder.
`python aura_ui/tests/shader_check.py` Windows D3DCompiler ile gerçek `surface.fx`
pixel shader'ını `ps_3_0` olarak derler. Bu kontrol MTA/GPU çalışma testi değildir.
`tests/*.png` gerçek Lua çizim çağrılarından ve shader'ın CPU yaklaşımından üretilir;
oyun ekran görüntüsü değildir. `rectangles.png`, `studio.png`, `data.png`,
`interaction.png` ve `templates.png` yeni sayfaları gösterir.

Oyunda: `debugscript 3`; `/aura`; tüm sekmeler; Türkçe giriş ve yapıştırma;
slider sürükleme; dropdown; Tab; F7 ile kapatma; `restart aura_ui`.
1280×720 ve 1920×1080'de ayrıca deneyin. Bellek/performans için MTA dxGetStatus
ve resource performans araçlarıyla ölçüm yapılmalıdır; bu sürüm için FPS iddiası yoktur.

## Lisans

Kit kaynak kodu MIT lisanslıdır. Manrope fontu SIL OFL 1.1 lisanslıdır;
`assets/OFL.txt` dağıtımda korunmalıdır. Fontun 500 ve 700 ağırlıkları
[Google Fonts kaynağından](https://github.com/google/fonts/tree/main/ofl/manrope)
statik TTF olarak üretilmiştir. Ücretli/ücretsiz projelerde lisans koşullarıyla kullanılabilir.

Çizim API referansı: [MTA dxDrawImage](https://wiki.multitheftauto.com/wiki/DxDrawImage),
[MTA dxCreateShader](https://wiki.multitheftauto.com/wiki/DxCreateShader).
