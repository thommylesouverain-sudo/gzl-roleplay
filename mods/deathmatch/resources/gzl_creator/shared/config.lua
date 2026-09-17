CreatorConfig = {}

CreatorConfig.MaleSkinID = 170
CreatorConfig.FemaleSkinID = 171

CreatorConfig.Studio = {
    ped = {
        x = 835.5,
        y = -2060.0,
        z = 12.86,
        rot = 180,
        interior = 0
    },
    camera = {
        full = { cx = 833.5, cy = -2064.5, cz = 13.2, tx = 835.5, ty = -2060.0, tz = 13.0 },
        head = { cx = 834.6, cy = -2061.6, cz = 13.62, tx = 835.5, ty = -2060.0, tz = 13.62 },
        body = { cx = 834.2, cy = -2062.8, cz = 13.15, tx = 835.5, ty = -2060.0, tz = 13.05 },
        feet = { cx = 834.4, cy = -2062.2, cz = 12.45, tx = 835.5, ty = -2060.0, tz = 12.35 }
    },
    time = { 21, 0 },
    weather = 0
}

CreatorConfig.SkinTones = {
    [1] = { name = "Açık Beyaz", color = { 1.0, 0.95, 0.92, 1.0 }, hex = "#fde1d2" },
    [2] = { name = "Açık Ten", color = { 0.96, 0.84, 0.73, 1.0 }, hex = "#f1c27d" },
    [3] = { name = "Açık Buğday", color = { 0.90, 0.74, 0.58, 1.0 }, hex = "#e0ac69" },
    [4] = { name = "Koyu Buğday", color = { 0.80, 0.60, 0.42, 1.0 }, hex = "#c68642" },
    [5] = { name = "Esmer", color = { 0.58, 0.40, 0.28, 1.0 }, hex = "#8d5524" },
    [6] = { name = "Siyahi", color = { 0.35, 0.24, 0.17, 1.0 }, hex = "#3c2010" }
}

CreatorConfig.EyeColors = {
    [1] = "Koyu Mavi",
    [2] = "Deniz Mavisi",
    [3] = "Açık Yeşil",
    [4] = "Kahverengi",
    [5] = "Ela / Leylak",
    [6] = "Duman Grisi",
    [7] = "Buz Mavisi"
}

CreatorConfig.Eyebrows = {
    [1] = "Doğal Düz",
    [2] = "Kavisli İnce",
    [3] = "Kalın Doğal",
    [4] = "Belirgin Keskin",
    [5] = "Gür Çizgili",
    [6] = "Modern Çizik",
    [7] = "Açık İnce",
    [8] = "Kavisli Kalın"
}

CreatorConfig.HairColors = {
    [1] = { name = "Kuzguni Siyah", color = { 0.10, 0.10, 0.10, 1.0 }, hex = "#1a1a1a" },
    [2] = { name = "Kestane / Espresso", color = { 0.20, 0.13, 0.09, 1.0 }, hex = "#2b170c" },
    [3] = { name = "Koyu Kahve", color = { 0.30, 0.20, 0.14, 1.0 }, hex = "#3d2314" },
    [4] = { name = "Açık Kahve / Karamel", color = { 0.48, 0.32, 0.20, 1.0 }, hex = "#6b4423" },
    [5] = { name = "Küllü Kumral", color = { 0.55, 0.45, 0.35, 1.0 }, hex = "#8a7057" },
    [6] = { name = "Altın Sarısı", color = { 0.82, 0.68, 0.40, 1.0 }, hex = "#d1ae66" },
    [7] = { name = "Platin Sarı", color = { 0.92, 0.88, 0.72, 1.0 }, hex = "#ebe0b8" },
    [8] = { name = "Bakır / Kızıl", color = { 0.65, 0.22, 0.14, 1.0 }, hex = "#8c2d19" },
    [9] = { name = "Koyu Bordo", color = { 0.42, 0.10, 0.12, 1.0 }, hex = "#520d13" },
    [10] = { name = "Gümüş Gri", color = { 0.78, 0.80, 0.82, 1.0 }, hex = "#c6cbd2" },
    [11] = { name = "Kar Beyazı", color = { 0.95, 0.95, 0.95, 1.0 }, hex = "#f0f0f0" }
}

CreatorConfig.Male = {
    hairs = {
        [0] = { name = "Kel / Saçsız", tex = nil, variants = 0 },
        [1] = { name = "Klasik Kısa", tex = "Cabelo1", variants = 8 },
        [2] = { name = "Modern Fade", tex = "Cabelo2", variants = 13 },
        [3] = { name = "Düz Kesim", tex = "Cabelo3", variants = 6 },
        [4] = { name = "Dalgalı Stil", tex = "Cabelo4", variants = 12 },
        [5] = { name = "Topuz ve Örgü", tex = "Cabelo5", variants = 5 }
    },

    beards = {
        [0] = "Sakal Yok (Sinekkaydı)",
        [1] = "Hafif Kirli Sakal",
        [2] = "Orta Kirli Sakal",
        [3] = "Çene Sakalı (Goatee)",
        [4] = "Yoğun Keçi Sakal",
        [5] = "Tam Sakal (Kısa)",
        [6] = "Tam Sakal (Gür)",
        [7] = "Bıyık ve Keçi Sakal",
        [8] = "Klasik Bıyık",
        [9] = "Gür Bıyık",
        [10] = "Oduncu Sakalı",
        [11] = "Çizgili Sakal",
        [12] = "Modern Sakal 1",
        [13] = "Modern Sakal 2",
        [14] = "Uzun Baba Sakal"
    },

    torso = {
        [1] = { name = "Klasik Tişört", tex = "camisa.padrao", variants = 77, hide_body = { "body.torso", "body.meio" } },
        [2] = { name = "Uzun Kollu Tişört", tex = "mangalonga.stars", variants = 11, hide_body = { "body.torso", "body.arm1", "body.arm2", "body.meio" } },
        [3] = { name = "Takım Elbise Ceketi", tex = "terno.blusa", variants = 5, hide_body = { "body.torso", "body.arm1", "body.arm2", "body.meio" } },
        [4] = { name = "Polis Üniforması", tex = "camisapm.stars", variants = 1, hide_body = { "body.torso", "body.meio" } },
        [5] = { name = "Balistik Taktik Yelek", tex = "colete.stars", variants = 5, hide_body = {} },
        [6] = { name = "Üst Çıplak", tex = nil, variants = 0, hide_body = {} }
    },

    legs = {
        [1] = { name = "Slim-Fit Kot Pantolon", tex = "calca.jeans", variants = 11, hide_body = { "body.legs1", "body.legs2", "body.coxa", "body.cueca" } },
        [2] = { name = "Bol Kargo Pantolon", tex = "calcalarga.stars", variants = 12, hide_body = { "body.legs1", "body.legs2", "body.coxa", "body.cueca" } },
        [3] = { name = "Bermuda Şort", tex = "bermuda.padrao", variants = 18, hide_body = { "body.coxa", "body.cueca" } },
        [4] = { name = "Takım Pantolonu", tex = "terno.calca", variants = 9, hide_body = { "body.legs1", "body.legs2", "body.coxa", "body.cueca" } },
        [5] = { name = "Polis Taktik Pantolonu", tex = "pmcalca.stars", variants = 6, hide_body = { "body.legs1", "body.legs2", "body.coxa", "body.cueca" } },
        [6] = { name = "Boxer (İç Çamaşırı)", tex = "body.cueca", variants = 6, hide_body = {} }
    },

    shoes = {
        [1] = { name = "Nike Air Jordan High", tex = "jordanm.stars", variants = 9, hide_feet = true },
        [2] = { name = "Mizuno Spor Ayakkabı", tex = "mizuno.stars", variants = 12, hide_feet = true },
        [3] = { name = "Ağır Taktik Bot", tex = "bota.stars", variants = 2, hide_feet = true },
        [4] = { name = "Deri Kundura", tex = "pe.sapatosocial", variants = 1, hide_feet = true },
        [5] = { name = "Plaj Terliği", tex = "pe.chinelo", variants = 8, hide_feet = false },
        [6] = { name = "Yazlık Sandalet", tex = "pe.sandalia", variants = 9, hide_feet = false }
    },

    accessories = {

        hat = { name = "Düz Kepli Şapka", icon = "◆", tex = "bone.padrao", category = "head" },
        backhat = { name = "Ters Şapka", icon = "◆", tex = "boneptras.stars", category = "head" },
        boina = { name = "Ressam Beresi", icon = "◆", tex = "boina.stars", category = "head" },
        chapeu = { name = "Tigas Fötr Şapka", icon = "◆", tex = "chapeu.tigas", category = "head" },
        palha = { name = "Hasır Kovboy Şapkası", icon = "◆", tex = "palha.stars", category = "head" },
        casquete = { name = "İngiliz Kasketi", icon = "◆", tex = "casquete.stars", category = "head" },

        glasses = { name = "Juliet Güneş Gözlüğü", icon = "◆", tex = "juju.stars", category = "face" },
        oculos = { name = "Klasik Çerçeveli Gözlük", icon = "◆", tex = "oculos.stars", category = "face" },
        mask = { name = "Balaklava Kar Maskesi", icon = "◆", tex = "balaclava.stars", category = "face" },
        bandana = { name = "Bandana Yüz Maskesi", icon = "◆", tex = "bandana.tigas", category = "face" },
        covid = { name = "Cerrahi Koruma Maskesi", icon = "◆", tex = "covid.stars", category = "face" },

        watch = { name = "Lüks Kol Saati", icon = "◆", tex = "relogio.stars", category = "body" },
        backpack = { name = "Taktik Sırt Çantası", icon = "◆", tex = "mochila.tigas", category = "body" },
        radio = { name = "Omuz Telsizi", icon = "◆", tex = "radinho.stars", category = "body" },
        holster = { name = "Bacak Tabanca Kılıfı", icon = "◆", tex = "coldrecoxa.stars", category = "body" },
        vest = { name = "Balistik Dış Yelek", icon = "◆", tex = "colete.stars", category = "body" },
        cinto = { name = "Taktik Kemer & Palaska", icon = "◆", tex = "cinto.stars", category = "body" },
        badge = { name = "Dedektif Rozeti", icon = "◆", tex = "distintivo.stars", category = "body" },
        bracal = { name = "Taktik Kol Bandı", icon = "◆", tex = "bracal.stars", category = "body" },
        ring = { name = "Lüks Altın Yüzük", icon = "◆", tex = "anel.stars", category = "body" }
    }
}

CreatorConfig.Female = {
    hairs = {
        [0] = { name = "Kel / Saçsız", tex = nil, variants = 0 },
        [1] = { name = "Uzun Dalgalı", tex = "hair.1", variants = 9 },
        [2] = { name = "Kıvırcık", tex = "hair.3", variants = 9 },
        [3] = { name = "At Kuyruğu", tex = "hair.4", variants = 9 },
        [4] = { name = "Örgülü", tex = "hair.6", variants = 1 }
    },

    lipsticks = {
        [0] = "Ruj Yok (Doğal)",
        [1] = "Kırmızı Parlak",
        [2] = "Koyu Bordo",
        [3] = "Gül Kurusu",
        [4] = "Açık Pembe",
        [5] = "Nude Şeftali",
        [6] = "Mercan",
        [7] = "Kahve Nude",
        [8] = "Vişne Çürüğü"
    },

    torso = {
        [1] = { name = "Klasik Kadın Tişörtü", tex = "camisa.padrao", variants = 20, hide_body = { "body.torso", "body.biquinicima" } },
        [2] = { name = "Taktik Çelik Yelek", tex = "coletef.stars", variants = 5, hide_body = {} },
        [3] = { name = "Bikini Üstü", tex = "body.biquinicima", variants = 1, hide_body = {} }
    },

    legs = {
        [1] = { name = "Kadın Pantolonu", tex = "calca.padrao", variants = 10, hide_body = { "body.legs", "body.biquinibaixo" } },
        [2] = { name = "Kargo Kadın Pantolonu", tex = "calcacargo.stars", variants = 6, hide_body = { "body.legs", "body.biquinibaixo" } },
        [3] = { name = "Yırtık Kot Şort", tex = "shortjeans.stars", variants = 10, hide_body = { "body.biquinibaixo" } },
        [4] = { name = "Bikini Altı", tex = "body.biquinibaixo", variants = 1, hide_body = {} }
    },

    shoes = {
        [1] = { name = "Kadın Jordan", tex = "jordan.padrao", variants = 9, hide_feet = true },
        [2] = { name = "Yüksek Bot", tex = "botapm.stars", variants = 2, hide_feet = true },
        [3] = { name = "Yazlık Sandalet", tex = "pe.sandalia", variants = 6, hide_feet = false }
    },

    accessories = {
        glasses = { name = "Juliet Güneş Gözlüğü", icon = "◆", tex = "jujuf.stars", category = "face" },
        mask = { name = "Cerrahi Maske", icon = "◆", tex = "covidf.stars", category = "face" },
        bandana = { name = "Bandana Fular", icon = "◆", tex = "bandanaf.stars", category = "face" },
        watch = { name = "Şık Kadın Kol Saati", icon = "◆", tex = "relogio.padrao", category = "body" },
        backpack = { name = "Deri Sırt Çantası", icon = "◆", tex = "mochila.padrao", category = "body" },
        radio = { name = "Omuz Telsizi", icon = "◆", tex = "radinhof.stars", category = "body" },
        holster = { name = "Bacak Kılıfı", icon = "◆", tex = "coldrecoxaf.stars", category = "body" },
        vest = { name = "Taktik Çelik Yelek", icon = "◆", tex = "coletef.stars", category = "body" },
        cinto = { name = "Deri Kemer", icon = "◆", tex = "cintof.stars", category = "body" },
        badge = { name = "Polis Rozeti", icon = "◆", tex = "distintivof.stars", category = "body" },
        bracal = { name = "Kol Bandı", icon = "◆", tex = "bracalf.stars", category = "body" }
    }
}