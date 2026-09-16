# GZL Roleplay v1.0

MTA:SA için sıfırdan yazılmış, tamamen SQLite tabanlı roleplay altyapısı. XAMPP, MySQL veya Navicat kurmanıza gerek yok; sunucuyu çalıştırdığınız anda veritabanları kendiliğinden oluşur.

**Geliştirici:** thommy

---

## İçindekiler

- [Özellikler](#özellikler)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum)
- [İlk Çalıştırma](#ilk-çalıştırma)
- [Yönetici Yetkisi Alma](#yönetici-yetkisi-alma)
- [Tuşlar ve Komutlar](#tuşlar-ve-komutlar)
- [Klasör Yapısı](#klasör-yapısı)
- [Veritabanları](#veritabanları)
- [Başlatma Sırası](#başlatma-sırası)
- [Sorun Giderme](#sorun-giderme)
- [Güncelleme](#güncelleme)

---

## Özellikler

- **Zero-config SQLite:** Harici veritabanı sunucusu yok, kurulum derdi yok.
- **6 aşamalı launcher:** Scriptler rastgele değil, bağımlılık sırasına göre başlar.
- **Anticheat ve güvenlik:** Event spam, yetkisiz payload, para bugları ve GPS açığı kapalı.
- **OX tarzı CEF envanter:** Sürükle-bırak, yere eşya atma, araç bagajı.
- **FiveM stili karakter oluşturucu**
- **txAdmin DX yönetim menüsü**
- **Meslek ve aktiviteler:** LSPD tablet, EMS, mekanik, cam temizleme, sürücü kursu, blackjack.
- **Araç sistemi:** Dinamik yakıt, vale, gerçekçi motor sesleri, direksiyon fiziği.
- **Cylex telefon** (CEF)
- **GTA V dairesel minimap, GPS ve pause menü haritası**

---

## Gereksinimler

| Gereksinim | Sürüm / Not |
| --- | --- |
| İşletim sistemi | Windows (64 bit) |
| MTA:SA sunucusu | **1.6** (64 bit) — aşağıdan indirilir |
| MTA:SA istemcisi | 1.6 (oyuncuların oyununda da 1.6 olmalı) |
| GTA: San Andreas | v1.0 (MTA'nın standart şartı) |
| Açık portlar | 22003 UDP (oyun), 22005 TCP (HTTP indirme) |

> Depo **script, ayar ve içerik** taşır: `resources/`, `acl.xml` ve hazır ayarlanmış `mtaserver.conf` dâhildir. Sunucu programı (`MTA Server64.exe`), `x64/` DLL'leri ve `.db` veritabanı dosyaları dâhil değildir; sunucu programı aşağıdan indirilir, veritabanları ilk çalıştırmada oluşur.

---

## Kurulum

### 1. MTA sunucusunu indirin

<https://nightly.multitheftauto.com/> adresine gidin.

1. Sayfadaki **"1.6 - Current release version"** bölümünü bulun. (Üstteki "1.7 - Development build only" bölümünü kullanmayın.)
2. Bu bölümdeki **"Windows 64 bit server"** başlığı altından en güncel dosyayı indirin. Dosya adı `mtasa_x64-1.6-rc-XXXXX-YYYYMMDD.exe` biçimindedir.
3. İndirdiğiniz kurulumu çalıştırıp boş bir klasöre kurun. Örnek: `C:\MTA-Server`

Kurulum sonunda o klasörde şunlar olur:

```text
C:\MTA-Server\
  MTA Server64.exe
  x64\              (core.dll, net.dll, deathmatch.dll ...)
  mods\deathmatch\  (varsayılan mtaserver.conf, acl.xml, resources\)
```

### 2. Depoyu klonlayın

```cmd
git clone https://github.com/thommylesouverain-sudo/gzl-roleplay.git
```

### 3. Dosyaları birleştirin

Depodaki `mods` klasörünü, MTA sunucusunu kurduğunuz klasörün üzerine kopyalayın; sorulduğunda **birleştir/üzerine yaz** deyin.

Sonuçta klasör şöyle görünmeli:

```text
C:\MTA-Server\
  MTA Server64.exe          (MTA kurulumundan)
  x64\                      (MTA kurulumundan)
  mods\deathmatch\
    acl.xml                 (depodan)
    mtaserver.conf          (depodan, hazır ayarlı)
    resources\
      gzl_launcher\         (depodan)
      gzl_auth\             (depodan)
      ...                   (diğer gzl_* resource'ları)
```

### 4. Ayarları gözden geçirin (isteğe bağlı)

`mods/deathmatch/mtaserver.conf` hazır ayarlı gelir; başlatma listesi ve portlar çalışır durumdadır. Yalnız kendi sunucunuza göre değiştirmek isterseniz:

```xml
<servername>GZL Roleplay</servername>
<serverport>22003</serverport>
<maxplayers>100</maxplayers>
<httpport>22005</httpport>
```

Resource listesine elle `gzl_*` satırı eklemeyin. Conf yalnız `gzl_loading` ve `gzl_launcher` başlatır; geri kalan her şeyi `gzl_launcher` doğru sırayla kendisi açar, elle eklemek başlatma sırasını bozar.

### 5. Sunucuyu başlatın

`MTA Server64.exe` dosyasını çalıştırın. Konsolda launcher'ın fazları sırayla başlattığını göreceksiniz.

---

## İlk Çalıştırma

İlk açılışta şunlar **kendiliğinden** olur, elle bir şey yapmanız gerekmez:

- Tüm SQLite veritabanları ve tabloları oluşturulur.
- MTA'nın kendi dosyaları (`internal.db`, `registry.db`) üretilir.
- Oyuncular bağlandığında istemci dosyaları HTTP portundan indirilir.

Sunucu ayağa kalktıktan sonra MTA istemcisinden `127.0.0.1:22003` adresine bağlanarak test edebilirsiniz.

---

## Yönetici Yetkisi Alma

Yetki, sunucu konsolundan tek komutla verilir:

```text
setadmin OyuncuNickVeyaID 10
```

- **Seviye 10** = Kurucu (tam yetki).
- Komut oyuncu ID'si, nick veya hesap adıyla çalışır.
- Seviye **8 ve üzeri** yöneticiler oyun içinden `/setadmin` komutunu kullanabilir.
- Yetkiyi aldıktan sonra oyun içinde **Page Up** ile txAdmin panelini açabilirsiniz.

> Oyuncunun önce hesabını oluşturup oyuna girmiş olması gerekir; komut var olmayan bir hesaba yetki veremez.

---

## Tuşlar ve Komutlar

| Tuş | İşlev |
| --- | --- |
| `F1` | Telefon (`/telefon`) |
| `F2` veya `I` | Envanter |
| `Page Up` | txAdmin paneli (yönetici yetkisi gerekir) |
| `M` | İmleç (`/cursor`) |
| `J` | Motor çalıştır/durdur |
| `X` | Eller yukarı |
| `V` veya `Home` | Birinci şahıs kamera |
| `Sol Alt` | Telsiz konuşma |
| `T` | Sohbet |

---

## Klasör Yapısı

```text
mods/deathmatch/
  acl.xml                    MTA yetki listesi
  mtaserver.conf             Sunucu ayarları ve başlatma listesi
  resources/
    gzl_launcher/            Başlatma sırası ve faz yönetimi
    gzl_anticheat/           Event ve veri koruması
    gzl_logs/                Merkezi audit log
    gzl_core/                Ortak RP altyapısı
    gzl_ui/                  Ortak arayüz bileşenleri ve fontlar
    gzl_auth/                Giriş, kayıt, yetki seviyeleri
    gzl_characters/          Karakter, nakit ve banka bakiyesi
    gzl_creator/             Karakter oluşturucu
    gzl_inventory/           CEF envanter
    gzl_vehicles/            Araç, garaj, vale
    gzl_phone/               Telefon
    gzl_hud/  gzl_radar/     HUD ve minimap
    ...                      Diğer meslek ve yan sistemler
```

---

## Veritabanları

Her sistem kendi SQLite dosyasını kendi klasöründe tutar. Bu dosyalar **oyuncu verisidir** ve depoya gönderilmez; yedeklemeyi siz yaparsınız.

| Veri | Dosya |
| --- | --- |
| Hesaplar ve şifreler | `resources/gzl_auth/database.db` |
| Karakterler ve kıyafetler | `resources/gzl_characters/database.db` |
| Araçlar | `resources/gzl_vehicles/database.db` |
| Banka ve ATM işlemleri | `resources/gzl_atm/database.db` |
| Birlikler ve loglar | `databases/global/database.db` |
| Telefon | `resources/gzl_phone/phone.db` |
| Yakıt istasyonları | `resources/gzl_fuel/fuel.db` |
| Polis kayıtları | `resources/gzl_pd/pd_records.db` |
| Envanter içerikleri | `resources/gzl_inventory/data/*.json` |

**Yedekleme:** Sunucuyu kapatın, `resources` klasöründeki `.db` dosyalarını ve `gzl_inventory/data/` klasörünü kopyalayın. Sunucu açıkken kopyalanan veritabanı bozuk olabilir.

---

## Başlatma Sırası

`gzl_launcher` tüm sistemleri altı fazda, bağımlılık sırasına göre başlatır:

| Faz | İçerik |
| --- | --- |
| 1 | Güvenlik, log, core altyapı, yol grafı, harita |
| 2 | Arayüz ve görsel motor |
| 3 | Giriş, karakter oluşturucu, karakter sistemi |
| 4 | Ekonomi, envanter, araçlar, telefon |
| 5 | HUD, radar, sohbet, telsiz |
| 6 | Meslekler ve yan sistemler |

Sıra `resources/gzl_launcher/shared/config.lua` dosyasındaki `Config.Phases` tablosundan okunur. Yeni bir resource eklerken bu tabloya ekleyin, `mtaserver.conf` dosyasına değil.

---

## Sorun Giderme

**Sunucu açılıyor ama hiçbir gzl sistemi başlamıyor**
`mtaserver.conf` içinde `gzl_launcher` satırı var mı ve `startup="1"` mi? Konsolda launcher'ın faz çıktısını göremiyorsanız resource hiç başlamamıştır.

**Konsolda "Couldn't find resource ... Unable to start resource"**
`mods` klasörü yanlış yere kopyalanmış olabilir. Resource'lar tam olarak `mods/deathmatch/resources/` altında olmalı; araya fazladan bir klasör girmemeli.

**Oyuncular bağlanınca dosya indiremiyor / sonsuz yükleniyor**
`httpport` (varsayılan 22005) TCP olarak dışarı açık değildir. Güvenlik duvarı ve modem yönlendirmesini kontrol edin. Oyun portu 22003 **UDP**'dir, ikisi farklı protokoldür.

**`setadmin` çalışmıyor**
Komut sunucu konsolunda büyük/küçük harf duyarsız `setadmin` olarak yazılır; oyun içinde kullanacaksanız `/setadmin` biçiminde ve en az seviye 8 yetkiyle. Hedef oyuncunun hesabı yoksa komut başarısız olur.

**Bir sistemi güncelledim, değişiklik görünmüyor**
`refresh` sonrası ilgili resource'u `restart gzl_xxx` ile yeniden başlatın. İstemci tarafı dosyalar değiştiyse oyuncunun yeniden bağlanması gerekir.

**Veritabanı dosyasını sildim**
Dosya bir sonraki açılışta boş olarak yeniden oluşturulur; içindeki veri geri gelmez. Yedekten dönün.

---

## Güncelleme

```cmd
git pull
```

Ardından sunucuyu yeniden başlatın.

Veritabanı dosyaları depoya dâhil olmadığı için `git pull` oyuncu verinize dokunmaz. Ancak `mtaserver.conf` ve `acl.xml` depoda takip edilir: bu dosyalarda yerel değişiklik yaptıysanız `git pull` çakışma verebilir veya değişikliğinizi geride bırakabilir. Kendi sunucunuza özel ayarları kalıcı tutmak için değişikliği commit'leyin ya da `git stash` ile saklayıp pull sonrası geri uygulayın.
