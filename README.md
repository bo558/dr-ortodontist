# Dr. Ortodontist — Web Sitesi Tasarım Önizlemesi

Müşteri sunumu için hazırlanan, çalışan statik web sitesi. Paket bağımlılığı yoktur; build ve yerel sunucu PowerShell betikleridir.

## Gereksinimler

| Ortam | Komut |
|---|---|
| Windows | Yerleşik Windows PowerShell 5.1 (`powershell`) veya PowerShell 7+ (`pwsh`) |
| macOS / Linux | PowerShell 7+ — [kurulum](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |

## Build

```bash
pwsh -File build.ps1                                 # önizleme (varsayılan) → dist/
pwsh -File build.ps1 -BasePath /dr-ortodontist/      # alt dizinde önizleme (ör. GitHub Pages proje sitesi)
pwsh -File build.ps1 -Mode production                # canlı domain (www.drortodontist.com.tr)
```

Windows PowerShell 5.1: `powershell -ExecutionPolicy Bypass -File build.ps1 ...`

> **Git Bash kullanıcıları:** Git Bash, `/dr-ortodontist/` gibi argümanları Windows yoluna çevirir. Komutun başına `MSYS_NO_PATHCONV=1` ekleyin ya da komutu PowerShell'den çalıştırın. (Betik geçersiz bir yolu algılayıp durur.)

### Modlar

| | `preview` (varsayılan) | `production` |
|---|---|---|
| `<meta name="robots">` | `noindex, nofollow` (tüm sayfalar) | `index, follow` (404: `noindex`) |
| `robots.txt` | Taramaya izin verir; sayfalar `noindex` olduğu için dizine eklenmez | `Allow: /` + sitemap |
| `sitemap.xml` | Üretilmez | Üretilir |
| Canonical | Her zaman canlı domain | Canlı domain |
| `-BasePath` | Serbest (`/`, `/dr-ortodontist/` …) | Yalnızca `/` |

Varsayılan mod bilerek `preview` seçildi: yanlışlıkla yayınlanan bir önizleme arama motorlarında görünmez. **Canlıya alırken `-Mode production` kullanılmalıdır.**

## Yerel önizleme

```bash
pwsh -File serve.ps1                                 # http://localhost:4173/
pwsh -File serve.ps1 -BasePath /dr-ortodontist/      # build ile aynı base path
```

Sunucu yalnızca `localhost`'u dinler ve her yanıta `X-Robots-Tag: noindex` ekler.

## Yapı

```
src/
  layout.html              Sayfa iskeleti (SEO meta, OG, fontlar)
  partials/                header, footer, cta (randevu bandı), treatment (tedavi şablonu)
  pages/                   Sayfalar; ilk satırda <!--META {json} -->
  treatments/              9 tedavi içeriği (META + gövde)
  data/treatments.json     Tedavi kayıtları: menü, listeler, footer, sitemap tek kaynaktan
  data/organization.jsonld Kurum yapılandırılmış verisi
public/                    Statik dosyalar (CSS, JS, optimize görseller) — olduğu gibi kopyalanır
                           (Araştırma ve strateji notları private/docs/ altında; git'e eklenmez)
.github/workflows/         Build doğrulaması (Windows/macOS/Linux) — yayın YAPMAZ
dist/                      Build çıktısı (git'e eklenmez)
```

## GitHub Pages önizlemesi

`main` dalına her push'ta [deploy-pages.yml](.github/workflows/deploy-pages.yml) önizlemeyi `-BasePath /<repo>/` ile derler, güvenlik kontrollerini (noindex, canonical yok, yapılandırılmış veri yok, yol öneki) çalıştırır ve GitHub Pages'e yayınlar. Canlı klinik domainine dokunmaz.

Önizleme sayfaları:
- `noindex, nofollow` taşır; sitemap üretilmez.
- Canonical bağlantı ve yapılandırılmış veri içermez (canlı domainle ilişki kurmaz); `og:url` önizleme adresini gösterir.
- Ekranın altında "resmî site değildir" bilgi notu gösterir.

## Görseller ve gizlilik

- Fotoğraf kullanımı [src/data/photos.json](src/data/photos.json) ile yönetilir:
  - `publicApproved`: markanın yeni web sitesi ve herkese açık önizleme için onay verdiği fotoğraflar (12 hekim, çalışan ve klinik fotoğrafı). Gerçek dosyalar `public/assets/img/` altındadır.
  - `restricted`: gerekli izin teyit edilene kadar hiçbir build'de kullanılmaz (çocukların bulunduğu nefes eğitimi fotoğrafı; yerinde yer tutucu vardır).
- Orijinal dosyalar ayrıca `private/photos/` klasöründe durur ve git'e eklenmez. `-WithClientPhotos` yalnızca yerelde, kısıtlı olmayan fotoğrafları kopyalar.
- Müşteri belgeleri (`*.docx`, `*.pdf` vb.) `.gitignore` ile hariç tutulur; brief **repoya eklenmemelidir.**
- Randevu formu hiçbir sisteme bağlı değildir; veri göndermez ve saklamaz.

## Yayın notları

- Eski `/service/<slug>` adresleri `/tedaviler/<slug>/` adreslerine 301 ile yönlendirilmeli.
- Google Fonts yayında self-host edilmeli (KVKK/performans).
- Next.js'e taşınırsa `partials/` bileşenlere birebir karşılık gelir.
