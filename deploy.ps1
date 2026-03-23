# ================================================================
#  A2Z COLLECTIVE - Auto Deploy Script (with Auto-Resize)
# ================================================================
#  1. Create a folder: images/gridlife/2025/My Event/
#  2. Drop your full-res JPGs in it
#  3. Double-click deploy.bat
#  4. Script auto-resizes to web quality, then deploys
#
#  Images are resized IN-PLACE to 2400px long edge, 85% quality.
#  KEEP YOUR ORIGINALS ON YOUR NAS / BACKUP DRIVE.
# ================================================================

Set-Location $PSScriptRoot
Add-Type -AssemblyName System.Drawing

$yearGroupedCats = @(
    @{ id = "gridlife"; name = "GRIDLIFE"; description = "Touring Cup racing and the culture of Gridlife" },
    @{ id = "automobiles"; name = "Automobiles"; description = "Automotive photography" },
    @{ id = "wildlife"; name = "Wildlife"; description = "Wildlife encounters through the lens" },
    @{ id = "urban"; name = "Urban"; description = "City life, architecture, and street scenes" },
    @{ id = "lemons"; name = "Lemons"; description = "Lemons Racing" }
)

$flatCats = @()

$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.webp")
$maxLongEdge = 2400
$jpegQuality = 85

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  A2Z Collective - Auto Deploy" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# ── AUTO-RESIZE FUNCTION ──
function Resize-Image($filePath) {
    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
    if ($ext -ne ".jpg" -and $ext -ne ".jpeg") { return $false }

    try {
        $img = [System.Drawing.Image]::FromFile($filePath)
        $w = $img.Width
        $h = $img.Height
        $longEdge = [Math]::Max($w, $h)

        if ($longEdge -le $maxLongEdge) {
            $img.Dispose()
            return $false
        }

        if ($w -ge $h) {
            $newW = $maxLongEdge
            $newH = [int]([Math]::Round($h * ($maxLongEdge / $w)))
        } else {
            $newH = $maxLongEdge
            $newW = [int]([Math]::Round($w * ($maxLongEdge / $h)))
        }

        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.DrawImage($img, 0, 0, $newW, $newH)

        $img.Dispose()

        $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$jpegQuality)

        $tempPath = $filePath + ".tmp"
        $bmp.Save($tempPath, $encoder, $encoderParams)

        $graphics.Dispose()
        $bmp.Dispose()
        $encoderParams.Dispose()

        Remove-Item $filePath -Force
        Rename-Item $tempPath $filePath

        $oldSize = [Math]::Round($longEdge)
        $newSize = $maxLongEdge
        return $true
    } catch {
        Write-Host "    Warning: Could not resize $filePath - $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# ── RESIZE ALL IMAGES ──
Write-Host "  Checking image sizes..." -ForegroundColor Cyan
$resizeCount = 0
$allImageFolders = Get-ChildItem -Path "images" -Recurse -Directory -ErrorAction SilentlyContinue

foreach ($folder in $allImageFolders) {
    foreach ($ext in @("*.jpg", "*.jpeg")) {
        $files = Get-ChildItem -Path $folder.FullName -Filter $ext -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if ($file.Name -eq "_cover.jpg") { 
                $resized = Resize-Image $file.FullName
                if ($resized) {
                    Write-Host "    Resized cover: $($file.FullName)" -ForegroundColor DarkYellow
                    $resizeCount++
                }
                continue 
            }
            $resized = Resize-Image $file.FullName
            if ($resized) {
                Write-Host "    Resized: $($file.Name)" -ForegroundColor DarkYellow
                $resizeCount++
            }
        }
    }
}

if ($resizeCount -gt 0) {
    Write-Host "  Resized $resizeCount images to ${maxLongEdge}px / ${jpegQuality}% quality" -ForegroundColor Green
} else {
    Write-Host "  All images already web-optimized" -ForegroundColor DarkGray
}
Write-Host ""

# ── GENERATE BLUR-UP THUMBNAILS ──
Write-Host "  Generating blur-up thumbnails..." -ForegroundColor Cyan
$thumbCount = 0
$thumbSize = 40

function Generate-Thumbnail($filePath, $thumbPath) {
    try {
        $img = [System.Drawing.Image]::FromFile($filePath)
        $w = $img.Width
        $h = $img.Height
        if ($w -ge $h) {
            $newW = $thumbSize
            $newH = [int]([Math]::Round($h * ($thumbSize / $w)))
        } else {
            $newH = $thumbSize
            $newW = [int]([Math]::Round($w * ($thumbSize / $h)))
        }
        if ($newW -lt 1) { $newW = 1 }
        if ($newH -lt 1) { $newH = 1 }

        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $graphics = [System.Drawing.Graphics]::FromImage($bmp)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::Bilinear
        $graphics.DrawImage($img, 0, 0, $newW, $newH)
        $img.Dispose()

        $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]30)

        $bmp.Save($thumbPath, $encoder, $encoderParams)
        $graphics.Dispose()
        $bmp.Dispose()
        $encoderParams.Dispose()
        return $true
    } catch {
        return $false
    }
}

$allGalleryFolders = Get-ChildItem -Path "images" -Recurse -Directory -ErrorAction SilentlyContinue
foreach ($folder in $allGalleryFolders) {
    if ($folder.Name -eq "_thumbs") { continue }
    if ($folder.Name -match '^\d{4}$') { continue }
    if ($folder.Name -eq "gridlife" -or $folder.Name -eq "automobiles" -or $folder.Name -eq "wildlife" -or $folder.Name -eq "urban") { continue }

    $hasImages = $false
    foreach ($ext in @("*.jpg", "*.jpeg")) {
        if (Get-ChildItem -Path $folder.FullName -Filter $ext -File -ErrorAction SilentlyContinue) { $hasImages = $true; break }
    }
    if (-not $hasImages) { continue }

    $thumbDir = Join-Path $folder.FullName "_thumbs"
    if (-not (Test-Path $thumbDir)) { New-Item -ItemType Directory -Path $thumbDir -Force | Out-Null }

    foreach ($ext in @("*.jpg", "*.jpeg")) {
        $files = Get-ChildItem -Path $folder.FullName -Filter $ext -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $thumbPath = Join-Path $thumbDir $file.Name
            if (Test-Path $thumbPath) { continue }
            $result = Generate-Thumbnail $file.FullName $thumbPath
            if ($result) { $thumbCount++ }
        }
    }
}

if ($thumbCount -gt 0) {
    Write-Host "  Generated $thumbCount blur-up thumbnails" -ForegroundColor Green
} else {
    Write-Host "  All thumbnails up to date" -ForegroundColor DarkGray
}

# ── HELPER FUNCTIONS ──
function Get-CoverFile($path) {
    if (Test-Path "$path/_cover.jpg") { return "$path/_cover.jpg" }
    return "$path/_cover.svg"
}

function Get-GalleryImages($folderPath) {
    $imgs = @()
    foreach ($ext in $imageExtensions) {
        $found = Get-ChildItem -Path $folderPath -Filter $ext -File -ErrorAction SilentlyContinue
        if ($found) { $imgs += $found }
    }
    return ($imgs | Sort-Object Name)
}

function Build-GalleryBlock($catPath, $folder, $images) {
    $folderName = $folder.Name
    $gId = ($folderName -replace '\s+', '-').ToLower()
    $gTitle = $folderName
    $gDate = ""
    $gDesc = ""
    $videoEntries = @()

    $metaPath = Join-Path $folder.FullName "_meta.json"
    if (Test-Path $metaPath) {
        try {
            $meta = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($meta.title) { $gTitle = $meta.title }
            if ($meta.date) { $gDate = $meta.date }
            if ($meta.description) { $gDesc = $meta.description }
            if ($meta.videos) {
                foreach ($v in $meta.videos) {
                    $videoEntries += "{ url: ""$($v.url)"", title: ""$($v.title)"" }"
                }
            }
        } catch {
            Write-Host "  Warning: Could not parse $metaPath" -ForegroundColor Yellow
        }
    }

    $imageList = ($images | ForEach-Object { """$($_.Name)""" }) -join ","
    $folderRef = ($catPath + "/" + $folderName) -replace '\\','/'
    $coverImg = $folderRef + "/" + $images[0].Name
    $videoJs = if ($videoEntries.Count -gt 0) { "[" + ($videoEntries -join ",") + "]" } else { "[]" }
    $dateJs = if ($gDate -ne "") { """$gDate""" } else { """""" }

    $block = "            {`n"
    $block += "              id: ""$gId"",`n"
    $block += "              title: ""$gTitle"",`n"
    $block += "              date: $dateJs,`n"
    $block += "              description: ""$gDesc"",`n"
    $block += "              folder: ""$folderRef"",`n"
    $block += "              cover: ""$coverImg"",`n"
    $block += "              images: [$imageList],`n"
    $block += "              videos: $videoJs`n"
    $block += "            }"
    return $block
}

# ── SCAN AND BUILD CONFIG ──
$categoriesJs = @()

foreach ($cat in $yearGroupedCats) {
    $catId = $cat.id
    $catName = $cat.name
    $catDesc = $cat.description
    $catPath = "images/$catId"
    $coverFile = Get-CoverFile $catPath

    $yearsJs = @()

    if (Test-Path $catPath) {
        $yearFolders = Get-ChildItem -Path $catPath -Directory | Where-Object { $_.Name -match '^\d{4}$' } | Sort-Object Name -Descending
        foreach ($yearFolder in $yearFolders) {
            $yearName = $yearFolder.Name
            $galleriesJs = @()
            $subfolders = Get-ChildItem -Path $yearFolder.FullName -Directory | Sort-Object Name

            foreach ($folder in $subfolders) {
                $images = Get-GalleryImages $folder.FullName
                if ($images.Count -eq 0) { continue }

                $galPath = "$catPath/$yearName"
                $gBlock = Build-GalleryBlock $galPath $folder $images
                $galleriesJs += $gBlock
                Write-Host "  [+] $catName / $yearName / $($folder.Name) - $($images.Count) images" -ForegroundColor Green
            }

            if ($galleriesJs.Count -gt 0) {
                $galInner = "`n" + ($galleriesJs -join ",`n") + "`n          "
            } else {
                $galInner = ""
            }

            $yrBlock = "        {`n"
            $yrBlock += "          year: ""$yearName"",`n"
            $yrBlock += "          galleries: [$galInner]`n"
            $yrBlock += "        }"
            $yearsJs += $yrBlock
        }
    }

    if ($yearsJs.Count -gt 0) {
        $yearsInner = "`n" + ($yearsJs -join ",`n") + "`n      "
    } else {
        $yearsInner = ""
    }

    $catBlock = "    {`n"
    $catBlock += "      id: ""$catId"",`n"
    $catBlock += "      name: ""$catName"",`n"
    $catBlock += "      description: ""$catDesc"",`n"
    $catBlock += "      cover: ""$coverFile"",`n"
    $catBlock += "      yearGrouped: true,`n"
    $catBlock += "      years: [$yearsInner]`n"
    $catBlock += "    }"
    $categoriesJs += $catBlock
}

foreach ($cat in $flatCats) {
    $catId = $cat.id
    $catName = $cat.name
    $catDesc = $cat.description
    $catPath = "images/$catId"
    $coverFile = Get-CoverFile $catPath

    $galleriesJs = @()

    if (Test-Path $catPath) {
        $subfolders = Get-ChildItem -Path $catPath -Directory | Sort-Object Name
        foreach ($folder in $subfolders) {
            $images = Get-GalleryImages $folder.FullName
            if ($images.Count -eq 0) { continue }

            $gBlock = Build-GalleryBlock $catPath $folder $images
            $galleriesJs += $gBlock
            Write-Host "  [+] $catName / $($folder.Name) - $($images.Count) images" -ForegroundColor Green
        }
    }

    if ($galleriesJs.Count -gt 0) {
        $galInner = "`n" + ($galleriesJs -join ",`n") + "`n      "
    } else {
        $galInner = ""
    }

    $catBlock = "    {`n"
    $catBlock += "      id: ""$catId"",`n"
    $catBlock += "      name: ""$catName"",`n"
    $catBlock += "      description: ""$catDesc"",`n"
    $catBlock += "      cover: ""$coverFile"",`n"
    $catBlock += "      yearGrouped: false,`n"
    $catBlock += "      galleries: [$galInner]`n"
    $catBlock += "    }"
    $categoriesJs += $catBlock
}

$newBlock = "  /* AUTO_CATEGORIES_START */`n"
$newBlock += "  categories: [`n"
$newBlock += ($categoriesJs -join ",`n")
$newBlock += "`n  ]`n"
$newBlock += "  /* AUTO_CATEGORIES_END */"

$indexPath = "index.html"
if (-not (Test-Path $indexPath)) {
    Write-Host "ERROR: index.html not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$html = Get-Content $indexPath -Raw -Encoding UTF8

$pattern = '(?s)/\* AUTO_CATEGORIES_START \*/.*?/\* AUTO_CATEGORIES_END \*/'
if ($html -match $pattern) {
    $html = [regex]::Replace($html, $pattern, $newBlock)
    [System.IO.File]::WriteAllText((Resolve-Path $indexPath).Path, $html, [System.Text.UTF8Encoding]::new($false))
    Write-Host ""
    Write-Host "  index.html updated!" -ForegroundColor Green
} else {
    Write-Host "ERROR: AUTO_CATEGORIES markers not found in index.html" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "  Generating sitemap..." -ForegroundColor Cyan

$siteUrl = "https://a2z-collective.pages.dev"
$today = Get-Date -Format "yyyy-MM-dd"
$sitemapLines = @()
$sitemapLines += '<?xml version="1.0" encoding="UTF-8"?>'
$sitemapLines += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
$sitemapLines += "  <url><loc>$siteUrl/</loc><lastmod>$today</lastmod><priority>1.0</priority></url>"
$sitemapLines += "  <url><loc>$siteUrl/#/contact</loc><lastmod>$today</lastmod><priority>0.5</priority></url>"

foreach ($cat in $yearGroupedCats) {
    $catId = $cat.id
    $catPath = "images/$catId"
    $sitemapLines += "  <url><loc>$siteUrl/#/category/$catId</loc><lastmod>$today</lastmod><priority>0.8</priority></url>"

    if (Test-Path $catPath) {
        $yearFolders = Get-ChildItem -Path $catPath -Directory | Where-Object { $_.Name -match '^\d{4}$' } | Sort-Object Name -Descending
        foreach ($yearFolder in $yearFolders) {
            $yearName = $yearFolder.Name
            $sitemapLines += "  <url><loc>$siteUrl/#/category/$catId/$yearName</loc><lastmod>$today</lastmod><priority>0.7</priority></url>"

            $subfolders = Get-ChildItem -Path $yearFolder.FullName -Directory | Sort-Object Name
            foreach ($folder in $subfolders) {
                $gId = ($folder.Name -replace '\s+', '-').ToLower()
                $sitemapLines += "  <url><loc>$siteUrl/#/category/$catId/$yearName/$gId</loc><lastmod>$today</lastmod><priority>0.6</priority></url>"
            }
        }
    }
}

$sitemapLines += '</urlset>'
$sitemapContent = $sitemapLines -join "`n"
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "sitemap.xml"), $sitemapContent, [System.Text.UTF8Encoding]::new($false))

$robotsContent = "User-agent: *`nAllow: /`nSitemap: $siteUrl/sitemap.xml"
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "robots.txt"), $robotsContent, [System.Text.UTF8Encoding]::new($false))

Write-Host "  sitemap.xml and robots.txt updated!" -ForegroundColor Green

Write-Host ""
Write-Host "  Pushing to GitHub..." -ForegroundColor Cyan

git add -A
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "Update galleries - $timestamp"

if ($LASTEXITCODE -eq 0) {
    git push
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=======================================" -ForegroundColor Green
        Write-Host "  Deployed! Site updates in ~30 sec." -ForegroundColor Green
        Write-Host "=======================================" -ForegroundColor Green
    } else {
        Write-Host "  Push failed. Check your internet." -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "  No changes detected - already up to date." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to close"
