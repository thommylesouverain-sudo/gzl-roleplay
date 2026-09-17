Config = {}

Config.AutoStartOnResourceStart = true

Config.InitialBootDelayMs = 300

Config.StepDelayMs = 150

Config.PhaseDelayMs = 250

Config.ShowDetailedLogs = true

Config.UseColorCodes = true

Config.ProtectedResources = {
    ["gzl_launcher"] = true,
    ["admin"] = true,
    ["admin2"] = true,
    ["defaultstats"] = true,
    ["webadmin"] = true,
    ["acpanel"] = true,
    ["runcode"] = true,
}

Config.Phases = {
    {
        id = 1,
        name = "Core & Foundation",
        description = "Temel altyapı, veritabanı, yol grafı ve harita yükleyiciler",
        resources = {
            { name = "gzl_anticheat", desc = "Sunucu event ve veri korumasi" },
            { name = "gzl_logs", desc = "Merkezi SQLite Audit Trail & Log Motoru" },
            { name = "gzl_core", desc = "Core RP Altyapısı & Veritabanı" },
            { name = "bone_attach", desc = "Kemik Eklenti (Bone Attach) Altyapısı" },
            { name = "gps", desc = "Yol Ağı & Rota Hesaplama Motoru" },
            { name = "gzl_map", desc = "Özel Los Santos Haritaları & İnteriorlar" },
        }
    },
    {
        id = 2,
        name = "UI & Graphic Engine",
        description = "Liquid Glass DX Framework, SVG & Font Kütüphaneleri",
        resources = {
            { name = "gzl_ui", desc = "Liquid Glass DX Arayüz & Bildirim Motoru" },
        }
    },
    {
        id = 3,
        name = "Auth & Identity Systems",
        description = "Kullanıcı kaydı, giriş ve karakter stüdyosu",
        resources = {
            { name = "gzl_auth", desc = "Giriş/Kayıt & Sinematik Kamera" },
            { name = "gzl_creator", desc = "FiveM Style Karakter Oluşturucu & Özelleştirme" },
            { name = "gzl_characters", desc = "Çoklu Karakter & Karakter Oluşturucu" },
        }
    },
    {
        id = 4,
        name = "Economy, Inventory & World Systems",
        description = "Envanter, araç garajları, telefon ve harici eklentiler",
        resources = {
            { name = "gzl_factions", desc = "Birlik/Fraksiyon Motoru & Gorev Sistemi" },
            { name = "gzl_inventory", desc = "OX-Style CEF Envanter & Eşya Motoru" },
            { name = "gzl_market", desc = "Risk Market V2 1:1 DX Mağaza Sistemi" },
            { name = "gzl_vehicles", desc = "Veritabanı Araç, Garaj & Vale Sistemi" },
            { name = "gzl_fuel", desc = "Detaylı Yakıt & Benzinlik İşletme Sistemi" },
            { name = "gzl_atm", desc = "GZL ATM & Bankacılık DX Sistemi" },
            { name = "gzl_phone", desc = "Akıllı Telefon Sistemi (CEF/HTML)", optional = true },
            { name = "gzl_discord-rpc", desc = "Discord Rich Presence Entegrasyonu", optional = true },
        }
    },
    {
        id = 5,
        name = "HUD, Radar & Communications",
        description = "Kullanıcı göstergeleri, GTA V minimap ve rol sohbeti",
        resources = {
            { name = "gzl_chat", desc = "CEF Rol Chat & Komut Sistemi" },
            { name = "gzl_radio", desc = "CEF Telsiz Kanalı & Ses Yönlendirme Sistemi" },
            { name = "gzl_hud", desc = "CEF Durum & Can/Zırh/Açlık HUD" },
            { name = "gzl_radar", desc = "GTA V Dairesel Minimap, Blip & GPS Navigasyon" },
        }
    },
    {
        id = 6,
        name = "Custom & Addon Scripts",
        description = "Sunucuya sonradan eklenen özel meslek ve yan sistemler",
        resources = {
            { name = "gzl_txadmin", desc = "txAdmin v6.0.2 DX Yönetim Menüsü" },
            { name = "gzl_firstperson", desc = "Gelişmiş Birinci Şahıs (FPS) Kamera Sistemi" },
            { name = "gzl_animations", desc = "YK22 Repacked Özel Karakter & Hareket Animasyonları" },
            { name = "gzl_mods", desc = "Otomatik Arac, Silah & Skin Mod Yukleyicisi" },
            { name = "gzl_weaponsounds", desc = "NextGen EarShot Gercekci Silah Sesleri & Yanki Sistemi" },
            { name = "gzl_steer", desc = "Dinamik Arac Direksiyonu Donus & Fizik Sistemi" },
            { name = "gzl_vehiclesounds", desc = "CarsSoundFX Realistik Arac Motor Sesleri, Turbo & Egzoz Patlatma" },
            { name = "gzl_mechanic", desc = "Benny's Original Motor Works & Gelismis Mekanik Sistemi" },
            { name = "gzl_ems", desc = "Liquid Glass DX EMS & Koma/Yaralanma Sistemi" },
            { name = "gzl_pd", desc = "Polis Departmanı, Tablet & Ceza Sistemi" },
            { name = "gzl_window-cleaning", desc = "Gökdelen Cam Temizleme Mesleği" },
            { name = "gzl_driving", desc = "Sürücü Kursu & Ehliyet Sınavı" },
            { name = "gzl_blackjack", desc = "Diamond Casino Blackjack Masası" },
            { name = "gzl_combat", desc = "Dövüş ve Hasar Efektleri Sistemi" },
            { name = "gzl_weaponswitch", desc = "Silah Çekme ve Geçiş Animasyonları" },
            { name = "gzl_rescpu", desc = "Kaynak Performans & CPU Takip Sistemi" },
        }
    }
}