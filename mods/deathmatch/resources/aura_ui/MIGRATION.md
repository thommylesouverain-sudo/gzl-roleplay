# GZL DX ekranlarının AURA geçişi

Bu geçiş mevcut ekranların **çizim katmanını** AURA'ya taşır. Ekran düzenleri,
hitbox koordinatları, input kimlikleri, client event'leri ve sunucu işlemleri korunur.
Her ekran retained `uiCreate` ağacına yeniden yazılmadı: mevcut DX döngüleri
AURA'nın anlık çizim API'sini çağırır. Böylece market/yakıt render target önbellekleri
ve mevcut input davranışları korunurken ortak yüzey/font altyapısı kullanılır.

## Kapsam

* Account/giriş/kayıt (`gzl_auth`)
* Idlewood Petrol dahil yakıt ve işletme ekranları (`gzl_fuel`)
* Market ürün/kategori/sepet ekranı (`gzl_market`)
* ATM, karakter seçimi ve karakter oluşturucu
* EMS, fraksiyonlar ve polis MDC
* Mekanik, blackjack ve cam temizleme işi
* Harita/radar menüleri, yönetim paneli ve kaynak performans ekranları

`gzl_ui` export isimleri uyumluluk için korunur; panel, buton, edit yüzeyi, sekme,
bildirim yüzeyi, daire, border ve font export'ları AURA'ya yönlendirilir.
Eski edit veri/odak yönetimi, bildirim kuyruğu ve ilerleme süreleri kendi resource'unda
kalır. Alanlara yeni bir input listener eklenmez; aynı tıklama iki defa işlenmez.
İlerleme çubuğunun segmentleri de AURA ile çizilir.
Resource'a özgü ikonlar, logolar, ürün resimleri, harita dokuları ve 3D çizimler korunur.

CEF resource'ları (`gzl_chat`, `gzl_hud`, `gzl_inventory`, `gzl_phone`, `gzl_radio`,
`gzl_loading`) ve HTML/JS/CSS dosyaları değiştirilmedi. Market'in `web` dizini
ürün resimleri için kullanılmaya devam eder; oradaki dosyalar da değiştirilmedi.

## Çalıştırma

Bu değişiklikler dosyalardadır; çalışan sunucu otomatik yeniden başlatılmadı.
`refresh` ardından `start aura_ui`, `restart gzl_ui` ve ilgili ekran resource'larının
yeniden başlatılması gerekir. Açık işlem/oyun oturumlarında toplu restart yerine
bakım zamanında normal sunucu açılışı tercih edin. `meta.xml` bağımlılıkları eklendi.
AURA'nın yeniden başlatılması paylaşılan fontları geçersiz kılacağı için tüketicileri
de yeniden başlatın. Mevcut font elemanını önbellekleyen eski ekranlar bunu gerektirir.

## API

`uiDrawSurface(x,y,w,h,options,postGUI)` diğer resource'un **kendi render callback'i**
içinden çağrılır. Render target veya blend mode değiştirmez. Showroom'un `postGUI`
ve viewport koordinatlarını miras almaz. AURA shader'ı ve tema token'larını kullanır.

Uyarlama fonksiyonları: `uiDrawRectangle`, `uiDrawRoundedRectangle`, `uiDrawBorder`,
`uiDrawPanel`, `uiDrawButtonSurface`, `uiDrawEditSurface`, `uiDrawTabsSurface`,
`uiDrawNotificationSurface`, `uiDrawText`, `uiTextWidth`, `uiFontHeight`, `uiGetFont`.
Packed MTA ARGB renkleri kabul edilir; alfa korunur. Sade karanlık mavi/gri
yüzeyler grafit temaya uyarlanır, marka/semantik renkler korunur.
İnce çizgiler ve radius=0 dolgular native rectangle hızlı yolunu kullanır.
`uiGetFont` paylaşılan font döndürür; tüketici bu fontu destroy etmemelidir.
Kendi font lifecycle'ı olan ekranlar AURA TTF dosyalarını kendi resource'larında yükler.
`gzl_ui:getFont` da Manrope fontlarını kendi resource'unda tutar; AURA fontlarının
silinmesi bu ortak font handle'larını geçersiz kılmaz. Doğrudan `uiGetFont` kullanan
tüketiciler AURA yeniden başladıktan sonra handle'larını yeniden almalıdır.

Eski `gzl_ui` edit alanları ve AURA bileşenleri yerel `onAuraInputClaim` eventiyle
odağı birbirinden devralır. Eski alan odağı bırakırken önceki input mode/enabled
değerlerini geri yükler; odağı yokken bu değerleri değiştirmez. Bu mekanizma
CEF odağını veya diğer resource'ların pencere sıralamasını yönetmez.

## Kontroller

* `python aura_ui/tests/check_migration.py`: korunan dosyaların hash'leri, Lua 5.1
  sözdizimi, export/bağımlılık kayıtları, event sözleşmeleri.
* `python aura_ui/tests/check.py`: kit davranışı ve anlık çizimde RT/postGUI/ARGB izolasyonu.
* `python aura_ui/tests/shader_check.py`: eşleşen vertex/pixel shader derlemesi.

Bu kontroller oyun içi akış testinin yerine geçmez. Giriş/kayıt, market sepet ve satın alma,
yakıt seçimi/durdurma, işletme işlemleri, ATM transferi ve farklı ekran boyutları
MTA istemcisinde ayrıca doğrulanmalıdır. Henüz oyun içi doğrulama veya FPS ölçümü yapılmadı.
