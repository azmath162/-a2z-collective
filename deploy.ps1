# ================================================================
#  A2Z COLLECTIVE - Auto Deploy Script
# ================================================================
#  1. Create a folder inside any category: images/gridlife/My Event/
#  2. Drop your JPGs in it
#  3. Double-click deploy.bat
# ================================================================

Set-Location $PSScriptRoot

$categories = @(
    @{ id = "gridlife"; name = "GRIDLIFE"; description = "Touring Cup racing and the culture of Gridlife" },
    @{ id = "automobiles"; name = "Automobiles"; description = "Automotive photography" },
    @{ id = "wildlife"; name = "Wildlife"; description = "Wildlife encounters through the lens" },
    @{ id = "urban"; name = "Urban"; description = "City life, architecture, and street scenes" }
)

$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.webp")

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  A2Z Collective - Auto Deploy" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$categoriesJs = @()

foreach ($cat in $categories) {
    $catId = $cat.id
    $catName = $cat.name
    $catDesc = $cat.description
    $catPath = "images/$catId"

    $coverFile = "$catPath/_cover.jpg"
    if (-not (Test-Path $coverFile)) {
        $coverFile = "$catPath/_cover.svg"
    }

    $galleries = @()

    if (Test-Path $catPath) {
        $subfolders = Get-ChildItem -Path $catPath -Directory | Sort-Object Name
        foreach ($folder in $subfolders) {
            $folderName = $folder.Name
            $images = @()
            foreach ($ext in $imageExtensions) {
                $found = Get-ChildItem -Path $folder.FullName -Filter $ext -File
                if ($found) { $images += $found }
            }
            $images = $images | Sort-Object Name

            if ($images.Count -eq 0) { continue }

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
                            $vUrl = $v.url
                            $vTitle = $v.title
                            $videoEntries += "{ url: ""$vUrl"", title: ""$vTitle"" }"
                        }
                    }
                } catch {
                    Write-Host "  Warning: Could not parse $metaPath" -ForegroundColor Yellow
                }
            }

            $imageList = ($images | ForEach-Object { """$($_.Name)""" }) -join ","
            $coverImg = "$catPath/$folderName/$($images[0].Name)"
            $folderRef = "$catPath/$folderName"

            if ($videoEntries.Count -gt 0) {
                $videoJs = "[" + ($videoEntries -join ",") + "]"
            } else {
                $videoJs = "[]"
            }

            if ($gDate -ne "") {
                $dateJs = """$gDate"""
            } else {
                $dateJs = """"""
            }

            $gBlock = "        {`n"
            $gBlock += "          id: ""$gId"",`n"
            $gBlock += "          title: ""$gTitle"",`n"
            $gBlock += "          date: $dateJs,`n"
            $gBlock += "          description: ""$gDesc"",`n"
            $gBlock += "          folder: ""$folderRef"",`n"
            $gBlock += "          cover: ""$coverImg"",`n"
            $gBlock += "          images: [$imageList],`n"
            $gBlock += "          videos: $videoJs`n"
            $gBlock += "        }"

            $galleries += $gBlock

            Write-Host "  [+] $catName / $gTitle - $($images.Count) images" -ForegroundColor Green
        }
    }

    if ($galleries.Count -gt 0) {
        $galleriesInner = "`n" + ($galleries -join ",`n") + "`n      "
    } else {
        $galleriesInner = ""
    }

    $catBlock = "    {`n"
    $catBlock += "      id: ""$catId"",`n"
    $catBlock += "      name: ""$catName"",`n"
    $catBlock += "      description: ""$catDesc"",`n"
    $catBlock += "      cover: ""$coverFile"",`n"
    $catBlock += "      galleries: [$galleriesInner]`n"
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
