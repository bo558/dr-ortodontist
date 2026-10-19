<#
  Dr. Ortodontist - static site builder (no dependencies)
  Runs on Windows PowerShell 5.1 and PowerShell 7+ (Windows, macOS, Linux).

  src/layout.html             page skeleton
  src/partials/*.html         header, footer, cta, treatment template
  src/pages/*.html            pages; first line is <!--META {json} -->
  src/treatments/*.html       treatment bodies; first line is <!--META {json} -->
  src/data/treatments.json    treatment registry (single source for menus, lists, sitemap)
  src/data/organization.jsonld  organisation structured data
  public/                     static assets copied as-is

  Output: dist/   (clean URLs: /tedaviler/<slug>/index.html)

  -Mode preview     (default) every page is noindex, nofollow; no sitemap.
                    Safe for local, GitHub Pages or any other preview host.
  -Mode production  index/follow, canonical URLs, sitemap.xml and robots.txt for the live domain.
  -BasePath         URL prefix when the site is served from a sub-directory,
                    e.g. -BasePath /dr-ortodontist/ for https://<user>.github.io/dr-ortodontist/
  -SiteUrl          (preview only) public URL of the preview, used for og:url / og:image,
                    e.g. https://<user>.github.io/dr-ortodontist
                    Preview builds never emit a canonical link or structured data, so they
                    claim no relationship with the live domain.
  -WithClientPhotos Copy the client's photos from private/photos/ (git-ignored) over the
                    placeholders. For local presentations only.
                    src/data/photos.json controls photo usage:
                      restricted     - never used (e.g. children without parental consent)
                      publicApproved - client-confirmed for public use; real file lives in public/assets/img/

  Examples:
    pwsh -File build.ps1
    pwsh -File build.ps1 -BasePath /dr-ortodontist/ -SiteUrl https://bo558.github.io/dr-ortodontist
    pwsh -File build.ps1 -WithClientPhotos
    pwsh -File build.ps1 -Mode production
    powershell -ExecutionPolicy Bypass -File build.ps1      (Windows PowerShell 5.1)
#>
param(
  [ValidateSet('preview', 'production')]
  [string]$Mode = 'preview',
  [string]$BasePath = '/',
  [string]$SiteUrl = '',
  [switch]$WithClientPhotos,
  # LOCAL review only: also use "restricted" photos from private/photos/ (e.g. pending consent).
  # Rejected for production and public preview (-SiteUrl) builds.
  [switch]$IncludeRestrictedPhotos
)

$ErrorActionPreference = 'Stop'

# Platform-neutral path joining (Join-Path accepts only two segments on PowerShell 5.1).
function Join-Parts { param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Parts) [IO.Path]::Combine([string[]]$Parts) }

$root = $PSScriptRoot
$src  = Join-Parts $root 'src'
$out  = Join-Parts $root 'dist'
$site = 'https://www.drortodontist.com.tr'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$isProduction = $Mode -eq 'production'

# Normalise base path to "/" or "/segment/.../"
$BasePath = '/' + $BasePath.Trim().Trim('/')
if (-not $BasePath.EndsWith('/')) { $BasePath += '/' }
if ($BasePath -notmatch '^/([A-Za-z0-9._~-]+/)*$') { throw "Invalid -BasePath '$BasePath'. Use letters, digits, '.', '_', '~' or '-' segments, e.g. /dr-ortodontist/" }
if ($isProduction -and $BasePath -ne '/') { throw "Production builds are served from the domain root; -BasePath must be '/'." }
$SiteUrl = $SiteUrl.Trim().TrimEnd('/')
if ($SiteUrl -and $SiteUrl -notmatch '^https://[A-Za-z0-9.-]+(/[A-Za-z0-9._~-]+)*$') { throw "Invalid -SiteUrl '$SiteUrl'. Expected e.g. https://user.github.io/dr-ortodontist" }
if ($isProduction -and $SiteUrl) { throw "-SiteUrl is for preview builds only; production always uses $site." }

# Client photos. Unless approved for public use (src/data/photos.json), the repository ships
# placeholders under the same file names; the originals live in private/photos/ (git-ignored).
$clientPhotos = @('berrin-usta', 'mustafa-usta', 'gizem-nur-donmez', 'pelin-dinctorna', 'aleyna-altug',
  'arife-bilbay', 'ceren-altun', 'cansu-erdogan', 'sehri-coban',
  'klinik-karsilama', 'klinik-ekip', 'nefes-egitimi', 'muayene')
$placeholderAlt = 'Yer tutucu g&#246;rsel: onayl&#305; foto&#287;raf eklenecek'   # HTML entities keep this file ASCII-only

$photoPolicy = [IO.File]::ReadAllText([IO.Path]::Combine($root, 'src', 'data', 'photos.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$restricted = @($photoPolicy.restricted)
$approved = @($photoPolicy.publicApproved)
foreach ($n in $restricted + $approved) { if ($clientPhotos -notcontains $n) { throw "photos.json: unknown photo '$n'" } }
foreach ($n in $approved) { if ($restricted -contains $n) { throw "photos.json: '$n' is both restricted and publicApproved" } }

if ($IncludeRestrictedPhotos) {
  if (-not $WithClientPhotos) { throw "-IncludeRestrictedPhotos requires -WithClientPhotos." }
  if ($isProduction -or $SiteUrl) { throw "-IncludeRestrictedPhotos is for local review only; it cannot be combined with -Mode production or -SiteUrl." }
  Write-Warning "Local review build: restricted photos included. Do not publish this dist/ output."
}

# Photos that are real (not placeholders) in this build.
$realPhotos = @($clientPhotos | Where-Object {
  $hasPrivate = $WithClientPhotos -and (Test-Path -LiteralPath ([IO.Path]::Combine($root, 'private', 'photos', "$_.jpg")))
  if ($restricted -contains $_) { $IncludeRestrictedPhotos -and $hasPrivate }
  else { ($approved -contains $_) -or $hasPrivate }
})
$placeholderPhotos = @($clientPhotos | Where-Object { $realPhotos -notcontains $_ })
$placeholderNote = if ($placeholderPhotos.Count -eq $clientPhotos.Count) { ' G&#246;rseller yer tutucudur.' }
  elseif ($placeholderPhotos.Count -gt 0) { ' Baz&#305; g&#246;rseller yer tutucudur.' } else { '' }

function Read-Text([string]$path) { [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) }
function Write-Text([string]$path, [string]$text) {
  $dir = [IO.Path]::GetDirectoryName($path)
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($path, $text, $utf8)
}
function Enc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
function Strip-Tags([string]$s) { [regex]::Replace($s, '<[^>]+>', '') }

function Read-Source([string]$path) {
  $raw = Read-Text $path
  $m = [regex]::Match($raw, '^\s*<!--META\s*(\{.*?\})\s*-->', 'Singleline')
  if (-not $m.Success) { throw "META block missing: $path" }
  return @{
    Meta = ($m.Groups[1].Value | ConvertFrom-Json)
    Body = $raw.Substring($m.Index + $m.Length).Trim("`r", "`n")
  }
}

# Prefix root-relative URLs (href="/...", src="/...", srcset="/...", action="/...") with the base path.
# Protocol-relative URLs ("//host") and absolute URLs are left untouched.
$baseEvaluator = [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + $BasePath }
function Apply-BasePath([string]$html) {
  if ($BasePath -eq '/') { return $html }
  [regex]::Replace($html, '(\s(?:href|src|srcset|action)=")/(?!/)', $baseEvaluator)
}

# ---------- Clean & copy static assets ----------
if (Test-Path -LiteralPath $out) { Get-ChildItem -LiteralPath $out -Force | Remove-Item -Recurse -Force }
else { New-Item -ItemType Directory -Path $out | Out-Null }
Get-ChildItem -LiteralPath (Join-Parts $root 'public') -Force | Copy-Item -Destination $out -Recurse -Force
Write-Text (Join-Parts $out '.nojekyll') ''   # GitHub Pages: serve files as-is
if ($WithClientPhotos) {
  $private = Join-Parts $root 'private' 'photos'
  if (-not (Test-Path -LiteralPath $private)) { throw "-WithClientPhotos: $private not found." }
  # Copy only the photos that may be used; restricted ones keep their placeholder.
  Get-ChildItem -LiteralPath $private -File |
    Where-Object { $realPhotos -contains [IO.Path]::GetFileNameWithoutExtension($_.Name) } |
    Copy-Item -Destination (Join-Parts $out 'assets' 'img') -Force
}
Write-Host ("Photos: {0} real, {1} placeholder ({2})" -f $realPhotos.Count, $placeholderPhotos.Count, ($placeholderPhotos -join ', '))

# ---------- Shared fragments ----------
$layout  = Read-Text (Join-Parts $src 'layout.html')
$header  = Read-Text (Join-Parts $src 'partials' 'header.html')
$footer  = Read-Text (Join-Parts $src 'partials' 'footer.html')
$cta     = Read-Text (Join-Parts $src 'partials' 'cta.html')
$tTpl    = Read-Text (Join-Parts $src 'partials' 'treatment.html')
$orgJson = (Read-Text (Join-Parts $src 'data' 'organization.jsonld')).Replace('{{SITE}}', $site)
$previewNotice = if ($isProduction) { '' } else {
  (Read-Text (Join-Parts $src 'partials' 'preview-notice.html')).Replace('{{PH_NOTE}}', $placeholderNote)
}

# Placeholder images get an honest alt text instead of the person/scene description.
$photoPattern = if ($placeholderPhotos.Count -gt 0) {
  '<img\b[^>]*\bsrc="/assets/img/(?:' + ($placeholderPhotos -join '|') + ')\.(?:jpg|webp)"[^>]*>'
} else { $null }
$altEvaluator = [Text.RegularExpressions.MatchEvaluator]{
  param($m)
  $tag = $m.Value
  if ($tag -match '\balt=""') { return $tag }   # decorative images stay decorative
  [regex]::Replace($tag, '\balt="[^"]*"', "alt=`"$placeholderAlt`"")
}
$data    = Read-Text (Join-Parts $src 'data' 'treatments.json') | ConvertFrom-Json

$iArrow = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'
$logoMark = '<svg class="brand__mark" viewBox="0 0 40 40" aria-hidden="true"><rect width="40" height="40" rx="2" fill="#6ECFF6"/><path d="M7.2 12.4 9.8 14" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round"/><path d="M9.6 14.2C11.6 24.6 20 30 33.4 28.6" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/></svg>'

$categories = @{}
foreach ($c in $data.categories) { $categories[$c.id] = $c }

function Treatment-Row($item, [int]$n) {
  $num = '{0:D2}' -f $n
@"
              <a class="t-row" href="/tedaviler/$($item.slug)/">
                <span class="t-row__num">$num</span>
                <span><span class="t-row__title">$(Enc $item.title)</span><span class="t-row__desc">$(Enc $item.short)</span></span>
                <span class="round-arrow">$iArrow</span>
              </a>
"@
}

# Home: grouped index list
$sb = New-Object Text.StringBuilder
$n = 0
foreach ($c in $data.categories) {
  $items = @($data.items | Where-Object { $_.category -eq $c.id })
  [void]$sb.AppendLine("            <div class=`"t-group`" data-reveal>")
  [void]$sb.AppendLine("              <div class=`"t-group__label`"><span>$(Enc $c.label)</span><span>$($items.Count)</span></div>")
  foreach ($i in $items) { $n++; [void]$sb.Append((Treatment-Row $i $n)) }
  [void]$sb.AppendLine("            </div>")
}
$treatmentIndex = $sb.ToString()

# Treatments page: categories with intro
$sb = New-Object Text.StringBuilder
$n = 0
foreach ($c in $data.categories) {
  $items = @($data.items | Where-Object { $_.category -eq $c.id })
  [void]$sb.AppendLine("      <div class=`"t-category`" id=`"$($c.id)`">")
  [void]$sb.AppendLine("        <div class=`"grid-12 t-category__grid`">")
  [void]$sb.AppendLine("          <div class=`"t-category__head`" data-reveal><p class=`"eyebrow`"><b>$(Enc $c.label)</b></p><h2 class=`"title-sm`">$($c.title)</h2><p>$(Enc $c.intro)</p></div>")
  [void]$sb.AppendLine("          <div class=`"t-category__list`" data-reveal style=`"--d:.1s`"><div class=`"t-group`"><div class=`"t-group__label`"><span>Tedaviler</span><span>$($items.Count)</span></div>")
  foreach ($i in $items) { $n++; [void]$sb.Append((Treatment-Row $i $n)) }
  [void]$sb.AppendLine("          </div></div>")
  [void]$sb.AppendLine("        </div>")
  [void]$sb.AppendLine("      </div>")
}
$treatmentGrid = $sb.ToString()

$footerTreatments = ($data.items | ForEach-Object { "            <li><a href=`"/tedaviler/$($_.slug)/`">$(Enc $_.title)</a></li>" }) -join "`n"

function Breadcrumb-Json($trail) {
  $parts = @()
  $pos = 1
  foreach ($t in $trail) {
    $parts += "{ `"@type`": `"ListItem`", `"position`": $pos, `"name`": `"$($t[0])`", `"item`": `"$site$($t[1])`" }"
    $pos++
  }
  "  <script type=`"application/ld+json`">{ `"@context`": `"https://schema.org`", `"@type`": `"BreadcrumbList`", `"itemListElement`": [ $($parts -join ', ') ] }</script>"
}

# ---------- Renderer ----------
$sitemap = New-Object System.Collections.ArrayList
$pageCount = 0
$year = (Get-Date).Year

function Render([hashtable]$p) {
  $html = $layout.Replace('{{HEADER}}', $header).Replace('{{FOOTER}}', $footer).Replace('{{CONTENT}}', $p.Content)
  $html = $html.Replace('{{> cta}}', $cta)
  $title = if ($p.Path -eq '/') { $p.Title } else { "$($p.Title) | Dr. Ortodontist" }
  $canonical = "$site$($p.Path)"
  if ($isProduction) {
    $canonicalTag = "  <link rel=`"canonical`" href=`"$canonical`">"
    $publicUrl = $canonical; $publicOrigin = $site; $jsonLd = $p.JsonLd
    $robots = if ($p.NoIndex) { 'noindex' } else { 'index, follow' }
  } else {
    # Preview: no canonical and no structured data, so the preview claims no relationship with the live domain.
    $canonicalTag = '  <!-- preview build: no canonical link -->'
    $publicUrl = "$SiteUrl$($p.Path)"; $publicOrigin = $SiteUrl; $jsonLd = ''
    $robots = 'noindex, nofollow'
  }
  $html = $html.Replace('{{TITLE}}', (Enc $title)).Replace('{{DESCRIPTION}}', (Enc $p.Description))
  $html = $html.Replace('{{CANONICAL_TAG}}', $canonicalTag).Replace('{{PUBLIC_URL}}', $publicUrl).Replace('{{PUBLIC_ORIGIN}}', $publicOrigin)
  $html = $html.Replace('{{PREVIEW_NOTICE}}', $previewNotice).Replace('{{SITE}}', $site)
  $html = $html.Replace('{{OG_TYPE}}', $(if ($p.Path -eq '/') { 'website' } else { 'article' }))
  $html = $html.Replace('{{ROBOTS}}', $robots)
  $html = $html.Replace('{{JSONLD}}', $jsonLd).Replace('{{BODYCLASS}}', $p.BodyClass)
  $html = $html.Replace('{{TREATMENT_INDEX}}', $treatmentIndex).Replace('{{TREATMENT_GRID}}', $treatmentGrid)
  $html = $html.Replace('{{FOOTER_TREATMENTS}}', $footerTreatments).Replace('{{YEAR}}', "$year")
  $html = $html.Replace('{{I_ARROW}}', $iArrow).Replace('{{LOGO_MARK}}', $logoMark)
  $nav = $p.Nav
  $html = [regex]::Replace($html, '\{\{ACTIVE:([a-z]+)\}\}', [Text.RegularExpressions.MatchEvaluator]{
    param($m) if ($m.Groups[1].Value -eq $nav) { ' aria-current="page"' } else { '' }
  })
  $left = [regex]::Matches($html, '\{\{[^}]+\}\}')
  if ($left.Count -gt 0) { throw "Unresolved token(s) in $($p.Path): $(($left | ForEach-Object Value) -join ', ')" }
  if ($photoPattern) { $html = [regex]::Replace($html, $photoPattern, $altEvaluator) }
  $html = Apply-BasePath $html

  $relative = $p.Path.TrimStart('/')
  if (-not $relative.EndsWith('.html')) { $relative += 'index.html' }
  $file = [IO.Path]::Combine([string[]](@($out) + ($relative -split '/')))
  Write-Text $file $html
  $script:pageCount++
  if (-not $p.NoIndex) { [void]$sitemap.Add($canonical) }
  Write-Host ("  {0,-60} {1,7:N0} B" -f $p.Path, $utf8.GetByteCount($html))
}

Write-Host "Building pages (mode: $Mode, base path: $BasePath)..."

# ---------- Pages ----------
foreach ($f in Get-ChildItem -LiteralPath (Join-Parts $src 'pages') -Filter *.html) {
  $s = Read-Source $f.FullName
  $m = $s.Meta
  $ld = ''
  if ($m.org) { $ld += $orgJson }
  if ($m.breadcrumb) { $ld += "`n" + (Breadcrumb-Json @(@('Ana Sayfa', '/'), @($m.breadcrumb, $m.path))) }
  if ($m.faqSchema) {
    $qs = [regex]::Matches($s.Body, '<summary>(.*?)<span class="plus".*?</summary>\s*<div class="faq__answer">(.*?)</div>', 'Singleline')
    $entries = foreach ($q in $qs) {
      $qq = (Strip-Tags $q.Groups[1].Value).Trim() -replace '"', '\"'
      $aa = ((Strip-Tags $q.Groups[2].Value) -replace '\s+', ' ').Trim() -replace '"', '\"'
      "{ `"@type`": `"Question`", `"name`": `"$qq`", `"acceptedAnswer`": { `"@type`": `"Answer`", `"text`": `"$aa`" } }"
    }
    $ld += "`n  <script type=`"application/ld+json`">{ `"@context`": `"https://schema.org`", `"@type`": `"FAQPage`", `"mainEntity`": [ $($entries -join ', ') ] }</script>"
  }
  Render @{
    Path = $m.path; Title = $m.title; Description = $m.description; Nav = $m.nav
    BodyClass = "$($m.bodyClass)"; Content = $s.Body; JsonLd = $ld; NoIndex = [bool]$m.noindex
  }
}

# ---------- Treatment pages ----------
foreach ($item in $data.items) {
  $path = Join-Parts $src 'treatments' "$($item.slug).html"
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing treatment body: $path" }
  $s = Read-Source $path
  $cat = $categories[$item.category]

  $toc = ([regex]::Matches($s.Body, '<h2 id="([^"]+)">(.*?)</h2>') | ForEach-Object {
    "                <li><a href=`"#$($_.Groups[1].Value)`">$($_.Groups[2].Value)</a></li>"
  }) -join "`n"

  $same = @($data.items | Where-Object { $_.category -eq $item.category -and $_.slug -ne $item.slug })
  $others = @($data.items | Where-Object { $_.category -ne $item.category })
  $related = @($same + $others)[0..2]
  $k = 0
  $relatedHtml = ($related | ForEach-Object { $k++; Treatment-Row $_ $k }) -join ''

  $content = $tTpl.Replace('{{T_TITLE}}', (Enc $item.title)).Replace('{{T_CATEGORY}}', (Enc $cat.label))
  $content = $content.Replace('{{T_LEAD}}', (Enc $s.Meta.lead)).Replace('{{T_TOC}}', $toc)
  $content = $content.Replace('{{T_BODY}}', $s.Body).Replace('{{T_RELATED}}', $relatedHtml)

  $pagePath = "/tedaviler/$($item.slug)/"
  $ld = (Breadcrumb-Json @(@('Ana Sayfa', '/'), @('Tedaviler', '/tedaviler/'), @($item.title, $pagePath)))
  $ld += "`n  <script type=`"application/ld+json`">{ `"@context`": `"https://schema.org`", `"@type`": `"MedicalWebPage`", `"name`": `"$($item.title)`", `"url`": `"$site$pagePath`", `"inLanguage`": `"tr-TR`", `"about`": { `"@type`": `"MedicalTherapy`", `"name`": `"$($item.title)`" } }</script>"

  Render @{
    Path = $pagePath; Title = $s.Meta.title; Description = $s.Meta.description; Nav = 'tedaviler'
    BodyClass = 'page-treatment'; Content = $content; JsonLd = $ld; NoIndex = $false
  }
}

# ---------- robots.txt & sitemap.xml ----------
if ($isProduction) {
  $today = Get-Date -Format 'yyyy-MM-dd'
  $urls = ($sitemap | Sort-Object | ForEach-Object { "  <url><loc>$_</loc><lastmod>$today</lastmod></url>" }) -join "`n"
  Write-Text (Join-Parts $out 'sitemap.xml') "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n$urls`n</urlset>`n"
  Write-Text (Join-Parts $out 'robots.txt') "User-agent: *`nAllow: /`n`nSitemap: $site/sitemap.xml`n"
  Write-Host ("Done. {0} pages ({1} in sitemap) -> {2}" -f $pageCount, $sitemap.Count, $out)
} else {
  # Crawling stays allowed on purpose: a robots.txt block would hide the noindex tag from crawlers
  # and blocked URLs could still be indexed from external links. Every page carries noindex instead.
  Write-Text (Join-Parts $out 'robots.txt') "# Preview build - every page is marked noindex, nofollow. No sitemap.`nUser-agent: *`nAllow: /`n"
  Write-Host ("Done. {0} pages, PREVIEW (noindex) -> {1}" -f $pageCount, $out)
}
