Config = {}

-- Temizlik Şirketi Merkezi (Depo & Araç Garajı - Willowfield / Commerce)
Config.DepotLocation = {
    marker = { x = 1798.50, y = -1705.20, z = 13.50 },
    ped = { x = 1798.50, y = -1705.20, z = 13.50, rot = 90.0, skin = 260 },
    vehicleSpawn = { x = 1805.20, y = -1709.50, z = 13.50, rot = 90.0 },
    vehicleReturn = { x = 1805.20, y = -1709.50, z = 13.50, radius = 6.0 }
}

-- İş Araç Modeli (552 = Utility Van)
Config.JobVehicleModel = 552

Config.MaxGroupMembers = 4
Config.CleanDurationMs = 3500 -- Cam başına silme süresi (milisaniye)

-- Ekonomi ve Kazanç
Config.Economy = {
    basePayPerWindow = 450,        -- Cam başına taban kazanç ($)
    completionBonus = 1800,       -- Sözleşme bitirme ikramiyesi ($)
    groupMultiplierPerMember = 0.20 -- Ekipteki her ekstra oyuncu için +%20 prim
}

-- Ekipman Ayarları
Config.Equipment = {
    trunkDistance = 3.2,          -- Araç arkasından ekipman alma mesafesi
    propModel = 2712,             -- Cam silme fırçası / paspası (CJ_MOP - GTA SA Orijinal Temizlik Prop'u)
    propBone = 12,                -- Sağ El (Right Hand)
    propOffset = { x = 0.05, y = 0.02, z = -0.05, rx = 0, ry = 180, rz = 0 },
    animBlock = "INT_SHOP",       -- Silme animasyonu kütüphanesi
    animName = "shop_shelf"       -- Silme animasyonu adı
}

-- Gerçekçi Vitrin & Cam Lokasyonları (Tamamen Açık Hava / Kaldırım ve Sokak Seviyesi)
Config.Buildings = {
    {
        id = "pershing_boulevard",
        name = "Pershing Square & Belediye Vitrinleri",
        description1 = "Şehir merkezindeki meydan ve belediye çevresindeki",
        description2 = "cadde mağazalarının geniş dış vitrin temizliği.",
        difficulty = "Kolay",
        zone = "Pershing Square, Los Santos",
        vehicleParking = { x = 1485.00, y = -1762.00, z = 18.70, radius = 7.0 },
        windows = {
            { id = 1, x = 1475.00, y = -1768.50, z = 18.70, label = "Meydan Mağazası Vitrini A" },
            { id = 2, x = 1479.50, y = -1768.50, z = 18.70, label = "Meydan Mağazası Vitrini B" },
            { id = 3, x = 1484.00, y = -1768.50, z = 18.70, label = "Köşe Kafe Giriş Camı" },
            { id = 4, x = 1488.50, y = -1768.50, z = 18.70, label = "Elektronik Mağazası Vitrini" },
            { id = 5, x = 1493.00, y = -1768.50, z = 18.70, label = "Cadde Kiosk Vitrini" }
        }
    },
    {
        id = "verona_boardwalk",
        name = "Verona Beach Sahil & Kafe Vitrinleri",
        description1 = "Verona sahil yürüyüş yolu boyunca uzanan deniz manzaralı",
        description2 = "restoran ve dondurmacıların cam vitrin temizliği.",
        difficulty = "Orta",
        zone = "Verona Beach, Los Santos",
        vehicleParking = { x = 384.50, y = -2070.00, z = 7.80, radius = 7.0 },
        windows = {
            { id = 1, x = 388.00, y = -2078.50, z = 7.80, label = "Sahil Kafe Vitrini 1" },
            { id = 2, x = 393.00, y = -2078.50, z = 7.80, label = "Sahil Kafe Vitrini 2" },
            { id = 3, x = 398.00, y = -2078.50, z = 7.80, label = "Dondurmacı Giriş Camı" },
            { id = 4, x = 403.00, y = -2078.50, z = 7.80, label = "Hediyelik Eşya Vitrini" },
            { id = 5, x = 408.00, y = -2078.50, z = 7.80, label = "Sörf Dükkanı Vitrini" }
        }
    },
    {
        id = "lsx_terminal",
        name = "Los Santos Havalimanı Dış Cephesi",
        description1 = "LSX Uluslararası Terminali yolcu giriş kapıları boyunca",
        description2 = "uzanan panoramik cam panellerin rutin temizliği.",
        difficulty = "Zor",
        zone = "LS International Airport",
        vehicleParking = { x = 1680.00, y = -2252.00, z = 13.50, radius = 7.0 },
        windows = {
            { id = 1, x = 1668.00, y = -2240.00, z = 13.50, label = "Terminal Cam Paneli 1" },
            { id = 2, x = 1673.00, y = -2240.00, z = 13.50, label = "Terminal Cam Paneli 2" },
            { id = 3, x = 1678.00, y = -2240.00, z = 13.50, label = "Gidiş Kapısı Camı" },
            { id = 4, x = 1683.00, y = -2240.00, z = 13.50, label = "Geliş Kapısı Camı" },
            { id = 5, x = 1688.00, y = -2240.00, z = 13.50, label = "Terminal Cam Paneli 3" },
            { id = 6, x = 1693.00, y = -2240.00, z = 13.50, label = "Terminal Cam Paneli 4" }
        }
    },
    {
        id = "rodeo_boutiques",
        name = "Rodeo Lüks Butik & Showroomlar",
        description1 = "Rodeo Drive boyunca sıralanan lüks mağazaların,",
        description2 = "mücevherat ve tasarım vitrinlerinin temizliği.",
        difficulty = "Uzman",
        zone = "Rodeo, Los Santos",
        vehicleParking = { x = 545.00, y = -1260.00, z = 16.50, radius = 7.0 },
        windows = {
            { id = 1, x = 550.00, y = -1252.00, z = 16.50, label = "Didier Sachs Vitrini" },
            { id = 2, x = 555.00, y = -1252.00, z = 16.50, label = "Mücevherat Vitrini" },
            { id = 3, x = 560.00, y = -1252.00, z = 16.50, label = "Lüks Butik Giriş Camı" },
            { id = 4, x = 565.00, y = -1252.00, z = 16.50, label = "Parfüm Mağazası Vitrini" },
            { id = 5, x = 570.00, y = -1252.00, z = 16.50, label = "Saat & Aksesuar Vitrini" },
            { id = 6, x = 575.00, y = -1252.00, z = 16.50, label = "Köşe Showroom Vitrini" }
        }
    }
}