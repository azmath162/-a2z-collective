# ================================================================
#  A2Z COLLECTIVE - Auto Deploy Script
# ================================================================
#  YEAR-GROUPED (gridlife, automobiles):
#    images/gridlife/2024/My Event Name/  (drop JPGs here)
#
#  FLAT (wildlife, urban):
#    images/wildlife/My Gallery Name/  (drop JPGs here)
#
#  Double-click deploy.bat to publish.
# ================================================================

Set-Location $PSScriptRoot

$yearGroupedCats = @(
    @{ id = "gridlife"; name = "GRIDLIFE"; description = "Touring Cup racing and the culture of Gridlife" },
    @{ id = "automobiles"; name = "Automobiles"; description = "Automotive photography" }
)

$flatCats = @(
    @{ id = "wildlife"; name = "Wildlife"; description = "Wildlife encounters through the lens" },
    @{ id = "urban"; name = "Urban"; description = "City life, architecture, and street scenes" }
)

$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.webp")

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  A2Z Collective - Auto Deploy" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

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

$categoriesJs = @()

# ── YEAR-GROUPED CATEGORIES ──
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

# ── FLAT CATEGORIES ──
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
