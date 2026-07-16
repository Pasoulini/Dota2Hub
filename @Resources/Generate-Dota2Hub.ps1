param(
    [switch]$RefreshRainmeter,
    [int]$ThrottleSeconds = 0
)

$ErrorActionPreference = "SilentlyContinue"

$SkinDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CacheDir = Join-Path $SkinDir "Cache"
$DataFile = Join-Path $SkinDir "Data.inc"
$RunStamp = Join-Path $CacheDir "last-run.txt"

if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null }

if ($ThrottleSeconds -gt 0 -and (Test-Path $RunStamp)) {
    $lastRun = (Get-Item $RunStamp).LastWriteTime
    if (((Get-Date) - $lastRun).TotalSeconds -lt $ThrottleSeconds) {
        Write-Output "THROTTLED"
        exit 0
    }
}

function Update-TierList {
    param($CacheDir)
    
    $tier1File = Join-Path $CacheDir "tier1_leagues.txt"
    $lastUpdateFile = Join-Path $CacheDir "tier_last_update.txt"
    
    $shouldUpdate = $true
    if (Test-Path $lastUpdateFile) {
        $lastUpdate = Get-Content $lastUpdateFile -Raw
        $lastUpdateDate = [DateTime]::MinValue
        if ([DateTime]::TryParse($lastUpdate, [ref]$lastUpdateDate)) {
            $hoursSinceUpdate = (([DateTime]::Now - $lastUpdateDate).TotalHours)
            if ($hoursSinceUpdate -lt 24) {
                $shouldUpdate = $false
                Write-Output "Tier list updated $([math]::Round($hoursSinceUpdate, 1)) hours ago, skipping..."
            }
        }
    }
    
    if ($shouldUpdate) {
        Write-Output "Updating tier list from Portal:Tournaments..."
        
        $portalFile = Join-Path $CacheDir "portal_tournaments.html"
        $portalTemp = Join-Path $CacheDir "portal_temp.html"
        
        & "C:\Windows\System32\curl.exe" -s -L --compressed -H "Api-User-Agent: Dota2Hub/1.0 (contact: your@email.com)" -o $portalTemp "https://liquipedia.net/dota2/Portal:Tournaments"
        
        if (Test-Path $portalTemp) {
            $tempHtml = Get-Content $portalTemp -Raw
            if ($tempHtml -match 'id="Upcoming"' -or $tempHtml -match 'id="Ongoing"') {
                Copy-Item $portalTemp $portalFile -Force
                Write-Output "Portal download OK"
            } else {
                Write-Output "Portal download FAILED - using cache"
            }
            Remove-Item $portalTemp -Force -ErrorAction SilentlyContinue
        }
        
        if (-not (Test-Path $portalFile)) {
            Write-Output "No cached portal file - skipping tier update"
            return
        }
        
        $html = Get-Content $portalFile -Raw
        $html = $html -replace '&#95;','_'
        
        $upcomingIdx = $html.IndexOf('id="Upcoming"')
        $ongoingIdx = $html.IndexOf('id="Ongoing"')
        $recentIdx = $html.IndexOf('id="Most_Recent"')
        
        $tier1Urls = @()
        
        function Extract-Tier1($sectionHtml) {
            $results = @()
            $rowPattern = '<tr class="table2__row--body">(.*?)</tr>'
            $rows = [regex]::Matches($sectionHtml, $rowPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            
            foreach ($row in $rows) {
                $rowHtml = $row.Groups[1].Value
                if ($rowHtml -match 'Tier\s+1') {
                    $urlPattern = 'href="/dota2/([^"]+)"'
                    $urlMatches = [regex]::Matches($rowHtml, $urlPattern)
                    foreach ($um in $urlMatches) {
                        $url = $um.Groups[1].Value
                        if ($url -notmatch 'Tier_|Tournaments$|Category:' -and $url -match '/') {
                            $results += $url
                            break
                        }
                    }
                }
            }
            return $results
        }
        
        if ($upcomingIdx -gt 0 -and $ongoingIdx -gt $upcomingIdx) {
            $section = $html.Substring($upcomingIdx, $ongoingIdx - $upcomingIdx)
            $tier1Urls += Extract-Tier1 $section
        }
        
        if ($ongoingIdx -gt 0 -and $recentIdx -gt $ongoingIdx) {
            $section = $html.Substring($ongoingIdx, $recentIdx - $ongoingIdx)
            $tier1Urls += Extract-Tier1 $section
        }
        
        $tier1Urls = $tier1Urls | Select-Object -Unique
        
        $content = @("# Tier 1 Leagues - Dota 2")
        $content += "# Auto-updated from https://liquipedia.net/dota2/Portal:Tournaments"
        $content += "# Last updated: $((Get-Date).ToString('yyyy-MM-dd'))"
        $content += "#"
        $content += ""
        
        foreach ($url in $tier1Urls) {
            $content += $url
        }
        
        $content | Set-Content $tier1File -Encoding UTF8
        (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') | Set-Content $lastUpdateFile -Encoding UTF8
        
        Write-Output "Saved $($tier1Urls.Count) Tier 1 tournaments"
    }
}

Update-TierList $CacheDir

$DefaultLogo = Join-Path $CacheDir "logo_default.png"
if (-not (Test-Path $DefaultLogo) -or (Get-Item $DefaultLogo).Length -lt 100) {
    & "C:\Windows\System32\curl.exe" -s -L --compressed -o $DefaultLogo "https://liquipedia.net/commons/images/thumb/f/f4/Dota_2_default_allmode.png/50px-Dota_2_default_allmode.png"
}

$BlankPng = Join-Path $CacheDir "blank.png"
if (-not (Test-Path $BlankPng)) {
    $bytes = [byte[]]@(137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,0,1,0,0,0,1,8,2,0,0,0,144,119,83,222,0,0,0,12,73,68,65,84,120,156,99,248,207,192,0,0,0,3,0,1,54,216,102,222,0,0,0,0,73,69,78,68,174,66,96,130)
    [IO.File]::WriteAllBytes($BlankPng, $bytes)
}

function SafeText($txt) {
    if ($null -eq $txt) { return "" }
    $result = ([string]$txt).Trim()
    $result = $result -replace '^_', ''
    return $result
}

function ShortName($txt) {
    $name = SafeText $txt
    $abbreviations = @{
        "Inner Circle x Insanity" = "ICxI"
        "Team Nemesis" = "Nemesis"
        "Poor Rangers" = "PR"
        "Xtreme Gaming" = "Xtreme"
        "Aurora Gaming" = "Aurora"
        "Nigma Galaxy" = "Nigma"
        "Team Falcons" = "Falcons"
        "Team Liquid" = "Liquid"
        "Team Spirit" = "Spirit"
        "Virtus.pro" = "VP"
        "Vici Gaming" = "VG"
        "Rune Eaters" = "RE"
        "Level UP" = "LvlUp"
        "Level UP esports" = "LvlUp"
        "BB Team" = "BB"
        "L1 TEAM" = "L1"
        "REKONIX" = "REK"
        "Team Spirit Academy" = "SpiritAc"
    }
    foreach ($key in $abbreviations.Keys) {
        if ($name -eq $key) { return $abbreviations[$key] }
    }
    return $name
}

Write-Output "Fetching matches page from Liquipedia..."

$matchesPageFile = Join-Path $CacheDir "matches_page.html"
$tempFile = Join-Path $CacheDir "matches_temp.html"

$downloadOk = $false
& "C:\Windows\System32\curl.exe" -s -L --compressed -H "Api-User-Agent: Dota2Hub/1.0 (contact: your@email.com)" -o $tempFile "https://liquipedia.net/dota2/Liquipedia:Matches"

if (Test-Path $tempFile) {
    $tempContent = [IO.File]::ReadAllText($tempFile)
    if ($tempContent -match 'class="match-info"') {
        Copy-Item $tempFile $matchesPageFile -Force
        $downloadOk = $true
        Write-Output "Download OK ($([math]::Round($tempContent.Length/1KB))KB)"
    } else {
        Write-Output "Download FAILED - no match-info found, using cache"
    }
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

if (-not $downloadOk) {
    if (Test-Path $matchesPageFile) {
        Write-Output "Using cached matches page"
    } else {
        Write-Output "No cached file available - cannot continue"
        return
    }
}

$html = [IO.File]::ReadAllText($matchesPageFile)

$logoMap = @{}
$imgPattern = 'src="(/commons/images/thumb/[^"]+)"'
$allMatches = [regex]::Matches($html, $imgPattern)

foreach ($m in $allMatches) {
    $imgSrc = $m.Groups[1].Value
    if ($imgSrc -match '/([^/]+)$') {
        $fileName = $Matches[1]
        $fullUrl = "https://liquipedia.net$imgSrc"
        
        if (-not $logoMap.ContainsKey($fileName)) {
            $logoMap[$fileName] = $fullUrl
        }
    }
}

Write-Output "Found $($logoMap.Count) image URLs from matches page"

function Find-TeamLogoUrl($teamName) {
    $name = $teamName.Trim()
    
    $searchTerms = @()
    
    switch -Wildcard ($name) {
        "*Inner Circle*" { $searchTerms += @("Inner_Circle_2025", "Inner Circle 2025", "ICxI") }
        "*Nemesis*" { $searchTerms += @("Team_Nem_lightmode", "Team_Nem") }
        "*Poor Rangers*" { $searchTerms += @("Power_Rangers", "Power Rangers", "Poor_Rangers", "Arcade.PowerRangers") }
        "*BB Team*" { $searchTerms += @("BetBoom_Team", "BetBoom Team", "BB_Team", "BetBoom") }
        "*L1*" { $searchTerms += @("L1GA_TEAM", "L1GA TEAM", "L1_Team") }
        "*PTime*" { $searchTerms += @("PlayTime_allmode", "PlayTime") }
        "*PVISION*" { $searchTerms += @("PARIVISION_allmode", "PARIVISION") }
        "*LGD*" { $searchTerms += @("LGD_Gaming", "LGD Gaming") }
        "*Yandex*" { $searchTerms += @("Team_Yandex", "Team Yandex") }
        "*Xtreme*" { $searchTerms += @("Xtreme_Gaming", "Xtreme Gaming") }
        "*GamerLegion*" { $searchTerms += @("GamerLegion", "Gamer Legion") }
        "*Falcons*" { $searchTerms += @("Team_Falcons", "Team Falcons") }
        "*Nigma*" { $searchTerms += @("Nigma_Galaxy", "Nigma Galaxy") }
        "*Aurora*" { $searchTerms += @("Aurora_Gaming", "Aurora Gaming") }
        "*MOUZ*" { $searchTerms += @("MOUZ") }
        "*REKONIX*" { $searchTerms += @("REKONIX") }
        "*OG*" { $searchTerms += @("OG_2026", "OG") }
        "*Spirit Academy*" { $searchTerms += @("Team_Spirit_Academy", "Spirit Academy") }
        "*Spirit*" { $searchTerms += @("Team_Spirit_2022", "Team_Spirit_2021", "Team_Spirit") }
        "*Virtus*" { $searchTerms += @("Virtus.pro") }
        "*1w*" { $searchTerms += @("1win", "1w", "Gorgc_Team") }
        "*Liquid*" { $searchTerms += @("Team_Liquid", "Team Liquid") }
        "*Level*" { $searchTerms += @("Level_UP", "Level UP") }
        "*Vici*" { $searchTerms += @("VICI_Gaming", "Vici Gaming") }
        "*Ilbirs*" { $searchTerms += @("Ilbirs", "Ilbirs eSports") }
        "*Summer Bear*" { $searchTerms += @("Summer_Bear", "Summer Bear") }
        default { $searchTerms += @($name, $name -replace ' ', '_') }
    }
    
    foreach ($term in $searchTerms) {
        $termLower = $term.ToLower()
        foreach ($fileName in $logoMap.Keys) {
            $fileNameLower = $fileName.ToLower()
            if ($fileNameLower -like "*$termLower*") {
                return $logoMap[$fileName]
            }
        }
    }
    
    foreach ($term in $searchTerms) {
        $termNoSpace = $term -replace ' ', '' -replace '_', ''
        foreach ($fileName in $logoMap.Keys) {
            $fileNameNoSpace = $fileName -replace ' ', '' -replace '_', '' -replace '\d+px-', ''
            if ($fileNameNoSpace -like "*$termNoSpace*") {
                return $logoMap[$fileName]
            }
        }
    }
    
    return $null
}

$FallbackLogos = @{
    "Poor Rangers" = "https://liquipedia.net/commons/images/thumb/4/4c/Arcade.PowerRangers_std.png/100px-Arcade.PowerRangers_std.png"
}

function Download-Logo($teamName, $logoUrl) {
    $safeName = $teamName.Trim() -replace ' ', '_'
    $logoFile = Join-Path $CacheDir "logo_$safeName.png"
    
    if ((Test-Path $logoFile) -and (Get-Item $logoFile).Length -gt 200) {
        return $logoFile
    }
    
    if ((Test-Path $logoFile) -and (Get-Item $logoFile).Length -le 200) {
        Remove-Item $logoFile -Force -ErrorAction SilentlyContinue
    }
    
    try {
        Start-Sleep -Milliseconds 500
        & "C:\Windows\System32\curl.exe" -s -L --compressed -H "Api-User-Agent: Dota2Hub/1.0 (contact: your@email.com)" -o $logoFile $logoUrl
        if ((Test-Path $logoFile) -and (Get-Item $logoFile).Length -gt 200) {
            return $logoFile
        }
    } catch {}
    
    if (Test-Path $logoFile) { Remove-Item $logoFile -Force -ErrorAction SilentlyContinue }
    return $DefaultLogo
}

Write-Output "Loading tier list from file..."

$tier1File = Join-Path $CacheDir "tier1_leagues.txt"
$knownTier1 = @()
if (Test-Path $tier1File) {
    $knownTier1 = Get-Content $tier1File | Where-Object { $_ -notmatch '^#' -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
}
Write-Output "Known Tier 1 leagues: $($knownTier1.Count)"

Write-Output "Parsing matches from HTML..."

$now = [DateTime]::UtcNow
$iranOffset = [TimeSpan]::FromHours(3).Add([TimeSpan]::FromMinutes(30))

$upcomingResults = @()
$completedResults = @()

$matchInfoPattern = '<div class="match-info">'
$matchStarts = [regex]::Matches($html, $matchInfoPattern)

Write-Output "Found $($matchStarts.Count) match info blocks"

$allTournamentUrls = @()

foreach ($matchStart in $matchStarts) {
    $startIdx = $matchStart.Index
    
    $depth = 1
    $pos = $startIdx + $matchInfoPattern.Length
    $blockHtml = ""
    
    while ($depth -gt 0 -and $pos -lt $html.Length) {
        $openIdx = $html.IndexOf('<div', $pos)
        $closeIdx = $html.IndexOf('</div>', $pos)
        
        if ($closeIdx -eq -1) { break }
        
        if ($openIdx -ne -1 -and $openIdx -lt $closeIdx) {
            $depth++
            $pos = $openIdx + 4
        } else {
            $depth--
            if ($depth -eq 0) {
                $blockHtml = $html.Substring($startIdx, $closeIdx + 6 - $startIdx)
                break
            }
            $pos = $closeIdx + 6
        }
    }
    
    if ($blockHtml.Length -eq 0) { continue }
    
    $teamPattern = 'class="block-team[^"]*">(.*?)</div>'
    $teamMatches = [regex]::Matches($blockHtml, $teamPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    $timestampPattern = 'data-timestamp="(\d+)"'
    $timestampMatch = [regex]::Match($blockHtml, $timestampPattern)
    
    if ($teamMatches.Count -lt 2 -or -not $timestampMatch.Success) { continue }
    
    function Extract-TeamName($block) {
        $titleMatch = [regex]::Match($block, 'title="([^"]+)"')
        if ($titleMatch.Success) { return $titleMatch.Groups[1].Value }
        $nameMatch = [regex]::Match($block, 'class="name"[^>]*>([^<]+)<')
        if ($nameMatch.Success) { return $nameMatch.Groups[1].Value }
        return "TBD"
    }
    
    $team1 = Extract-TeamName $teamMatches[0].Groups[1].Value
    $team2 = Extract-TeamName $teamMatches[1].Groups[1].Value
    
    $ts = [long]$timestampMatch.Groups[1].Value
    $utcTime = [DateTimeOffset]::FromUnixTimeSeconds($ts).UtcDateTime
    $matchTime = $utcTime.Add($iranOffset)
    
    $isCompleted = $false
    $isLive = $false
    
    $score1 = ""
    $score2 = ""
    
    $scorePattern = 'match-info-header-scoreholder-score[^>]*>(\d+)</span>'
    $scoreMatches = [regex]::Matches($blockHtml, $scorePattern)
    if ($scoreMatches.Count -ge 2) {
        $score1 = $scoreMatches[0].Groups[1].Value
        $score2 = $scoreMatches[1].Groups[1].Value
    }
    
    $boPattern = '\(Bo(\d+)\)'
    $boMatch = [regex]::Match($blockHtml, $boPattern)
    $bo = if ($boMatch.Success) { "BO$($boMatch.Groups[1].Value)" } else { "BO1" }
    
    if ($utcTime -lt $now) {
        $hoursPast = ($now - $utcTime).TotalHours
        
        if ($score1 -ne "" -and $score2 -ne "") {
            $s1 = [int]$score1
            $s2 = [int]$score2
            
            if ($bo -eq "BO1") {
                $isCompleted = ($s1 -ge 1 -or $s2 -ge 1)
            } elseif ($bo -eq "BO2") {
                $isCompleted = ($s1 -ge 2 -or $s2 -ge 2 -or ($s1 + $s2) -ge 2)
            } elseif ($bo -eq "BO3") {
                $isCompleted = ($s1 -ge 2 -or $s2 -ge 2)
            } else {
                $isCompleted = ($s1 -ge 3 -or $s2 -ge 3)
            }
            
            if (-not $isCompleted -and $hoursPast -ge 6) {
                $isCompleted = $true
            }
            
            if (-not $isCompleted) { $isLive = $true }
        } else {
            if ($hoursPast -ge 4) {
                $isCompleted = $true
            } else {
                $isLive = $true
            }
        }
    }
    
    $tournamentTitlePattern = 'class="match-info-tournament".*?href="(/dota2/[^"]+)"'
    $tournamentTitleMatch = [regex]::Match($blockHtml, $tournamentTitlePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $tournamentUrl = if ($tournamentTitleMatch.Success) { "https://liquipedia.net$($tournamentTitleMatch.Groups[1].Value)" } else { "" }
    
    $tournamentTitleNamePattern = 'class="match-info-tournament".*?title="([^"]+)"'
    $tournamentTitleNameMatch = [regex]::Match($blockHtml, $tournamentTitleNamePattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $tournament = if ($tournamentTitleNameMatch.Success) {
        $t = $tournamentTitleNameMatch.Groups[1].Value
        $t = $t -replace '#.*$', ''
        $t = $t -replace 'Esports World Cup/', 'EWC '
        $t = $t -replace 'The International/', 'TI '
        $t = $t -replace 'European Pro League/', 'EPL '
        $t = $t -replace '/', ' '
        $t
    } else { "Tier 1" }
    
    if ($tournamentUrl -and -not $allTournamentUrls.Contains($tournamentUrl)) {
        $allTournamentUrls += $tournamentUrl
    }
    
    $timeDisplay = $matchTime.ToString("HH:mm")
    if (-not $isCompleted -and -not $isLive) {
        $today = (Get-Date).Date
        $matchDate = $matchTime.Date
        $daysUntil = ($matchDate - $today).Days
        if ($daysUntil -ge 1) {
            $timeDisplay = "${daysUntil}d $($matchTime.ToString('HH:mm'))"
        }
    }
    
    $result = [PSCustomObject]@{
        Team1 = SafeText $team1
        Team2 = SafeText $team2
        Score1 = $score1
        Score2 = $score2
        BO = $bo
        Tournament = $tournament
        Time = if ($isLive -and $score1 -ne "" -and $score2 -ne "") { "$score1-$score2" } else { $timeDisplay }
        Status = if ($isCompleted) { "completed" } elseif ($isLive) { "live" } else { "upcoming" }
        Timestamp = $ts
        TournamentUrl = $tournamentUrl
    }
    
    if ($isCompleted) {
        $completedResults += $result
    } else {
        $upcomingResults += $result
    }
}

Write-Output "Checking tier for $($allTournamentUrls.Count) tournaments..."

$tierMap = @{}

foreach ($url in $allTournamentUrls) {
    $cacheKey = ($url -replace 'https://liquipedia.net/dota2/', '' -replace '#.*$', '')
    $pagePath = ($cacheKey -split '#')[0]
    
    $isKnownTier1 = $false
    foreach ($t1 in $knownTier1) {
        if ($pagePath -like "*$t1*") {
            $isKnownTier1 = $true
            break
        }
    }
    
    if ($isKnownTier1) {
        $tierMap[$url] = 1
        Write-Output "  Tier 1: $cacheKey"
    } else {
        $tierMap[$url] = 0
        Write-Output "  Not Tier 1: $cacheKey"
    }
}

$filteredUpcoming = @()
foreach ($m in $upcomingResults) {
    $tier = if ($tierMap.ContainsKey($m.TournamentUrl)) { $tierMap[$m.TournamentUrl] } else { 0 }
    if ($tier -eq 1) { $filteredUpcoming += $m }
}

$filteredCompleted = @()
foreach ($m in $completedResults) {
    $tier = if ($tierMap.ContainsKey($m.TournamentUrl)) { $tierMap[$m.TournamentUrl] } else { 0 }
    if ($tier -eq 1) { $filteredCompleted += $m }
}

$upcomingResults = $filteredUpcoming
$completedResults = $filteredCompleted

Write-Output "Upcoming: $($upcomingResults.Count), Completed: $($completedResults.Count)"

Write-Output "Checking for TBD teams and scraping tournament pages..."

$tbdTournaments = @()
foreach ($m in $upcomingResults) {
    if (($m.Team1 -eq "TBD" -or $m.Team2 -eq "TBD") -and $m.TournamentUrl -and -not $tbdTournaments.Contains($m.TournamentUrl)) {
        $tbdTournaments += $m.TournamentUrl
    }
}

function Extract-BlockTeamName($block) {
    $titleMatch = [regex]::Match($block, 'title="([^"]+)"')
    if ($titleMatch.Success) { return $titleMatch.Groups[1].Value }
    $nameMatch = [regex]::Match($block, 'class="name"[^>]*>([^<]+)<')
    if ($nameMatch.Success) { return $nameMatch.Groups[1].Value }
    return "TBD"
}

function Parse-TournamentPage($url) {
    $pagePath = ($url -replace 'https://liquipedia.net/dota2/', '' -replace '#.*$', '')
    $fragment = ""
    if ($url -match '#(.+)$') { $fragment = $Matches[1] }
    $baseUrl = "https://liquipedia.net/dota2/$pagePath"
    
    $tempFile = Join-Path $CacheDir "tournament_temp.html"
    
    & "C:\Windows\System32\curl.exe" -s -L --compressed -H "Api-User-Agent: Dota2Hub/1.0 (contact: your@email.com)" -o $tempFile $baseUrl
    
    if (-not (Test-Path $tempFile)) { return @() }
    
    $content = Get-Content $tempFile -Raw -Encoding UTF8
    if ($content.Length -lt 1000) { Remove-Item $tempFile -Force; return @() }
    
    Remove-Item $tempFile -Force
    
    if ($fragment) {
        $sectionStart = $content.IndexOf("id=`"$fragment`"")
        if ($sectionStart -gt 0) {
            $nextSection = $content.Substring($sectionStart + 100).IndexOf('id="')
            if ($nextSection -gt 0) {
                $content = $content.Substring($sectionStart, $nextSection)
            } else {
                $content = $content.Substring($sectionStart)
            }
        }
    }
    
    $matchInfoPattern = '<div class="match-info'
    $matchStarts = [regex]::Matches($content, $matchInfoPattern)
    
    $results = @()
    
    foreach ($matchStart in $matchStarts) {
        $startIdx = $matchStart.Index
        $depth = 1
        $pos = $startIdx + $matchInfoPattern.Length
        $blockHtml = ""
        
        while ($depth -gt 0 -and $pos -lt $content.Length) {
            $openIdx = $content.IndexOf('<div', $pos)
            $closeIdx = $content.IndexOf('</div>', $pos)
            if ($closeIdx -eq -1) { break }
            if ($openIdx -ne -1 -and $openIdx -lt $closeIdx) {
                $depth++
                $pos = $openIdx + 4
            } else {
                $depth--
                if ($depth -eq 0) {
                    $blockHtml = $content.Substring($startIdx, $closeIdx + 6 - $startIdx)
                    break
                }
                $pos = $closeIdx + 6
            }
        }
        
        if ($blockHtml.Length -eq 0) { continue }
        
        $teamPattern = 'class="block-team[^"]*">(.*?)</div>'
        $teamMatches = [regex]::Matches($blockHtml, $teamPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if ($teamMatches.Count -lt 2) { continue }
        
        $t1 = Extract-BlockTeamName $teamMatches[0].Groups[1].Value
        $t2 = Extract-BlockTeamName $teamMatches[1].Groups[1].Value
        
        if ($t1 -ne "???" -and $t2 -ne "???" -and ($t1 -ne "TBD" -or $t2 -ne "TBD")) {
            $pair = if ($t1 -lt $t2) { "${t1}_vs_${t2}" } else { "${t2}_vs_${t1}" }
            $isDupe = $false
            foreach ($r in $results) {
                $rp = if ($r.Team1 -lt $r.Team2) { "$($r.Team1)_vs_$($r.Team2)" } else { "$($r.Team2)_vs_$($r.Team1)" }
                if ($pair -eq $rp) { $isDupe = $true; break }
            }
            if (-not $isDupe) {
                $results += [PSCustomObject]@{ Team1 = $t1; Team2 = $t2 }
            }
        }
    }
    
    return $results
}

foreach ($tUrl in $tbdTournaments) {
    Write-Output "  Scraping tournament page for: $tUrl"
    $bracketData = Parse-TournamentPage $tUrl
    Write-Output "    Found $($bracketData.Count) matchups from tournament page"
    
    $bracketIdx = 0
    for ($i = 0; $i -lt $upcomingResults.Count; $i++) {
        $m = $upcomingResults[$i]
        if ($m.TournamentUrl -ne $tUrl) { continue }
        if ($m.Team1 -ne "TBD" -and $m.Team2 -ne "TBD") { continue }
        if ($bracketIdx -ge $bracketData.Count) { break }
        
        $lookup = $bracketData[$bracketIdx]
        if ($lookup.Team1 -ne "TBD") { $upcomingResults[$i].Team1 = $lookup.Team1 }
        if ($lookup.Team2 -ne "TBD") { $upcomingResults[$i].Team2 = $lookup.Team2 }
        Write-Output "    Matched: $($lookup.Team1) vs $($lookup.Team2)"
        $bracketIdx++
    }
}

Write-Output "Deduplicating upcoming matches..."
$dedupedUpcoming = @()
$seenMatches = @{}
foreach ($m in ($upcomingResults | Sort-Object Timestamp)) {
    $t1 = $m.Team1.Trim()
    $t2 = $m.Team2.Trim()
    $pair = if ($t1 -lt $t2) { "${t1}_vs_${t2}" } else { "${t2}_vs_${t1}" }
    if (-not $seenMatches.ContainsKey($pair)) {
        $seenMatches[$pair] = $true
        $dedupedUpcoming += $m
    }
}
$upcomingResults = $dedupedUpcoming
Write-Output "After dedup: $($upcomingResults.Count) upcoming matches"

$displayUpcoming = $upcomingResults | Sort-Object Timestamp | Select-Object -First 8
$displayCompleted = $completedResults | Sort-Object Timestamp -Descending | Select-Object -First 8

Write-Output "Matching team logos from scraped data..."

$logoCache = @{}

foreach ($match in ($displayUpcoming + $displayCompleted)) {
    foreach ($teamName in @($match.Team1, $match.Team2)) {
        $trimmedName = $teamName.Trim()
        if (-not $logoCache.ContainsKey($trimmedName)) {
            $logoUrl = Find-TeamLogoUrl $trimmedName
            if (-not $logoUrl -and $FallbackLogos.ContainsKey($trimmedName)) {
                $logoUrl = $FallbackLogos[$trimmedName]
            }
            if ($logoUrl) {
                $logoFile = Download-Logo $trimmedName $logoUrl
                if ($logoFile -eq $DefaultLogo) {
                    Write-Output "  $trimmedName -> FAILED (using default)"
                } else {
                    Write-Output "  $trimmedName -> OK"
                }
                $logoCache[$trimmedName] = $logoFile
            } else {
                Write-Output "  $trimmedName -> DEFAULT"
                $logoCache[$trimmedName] = $DefaultLogo
            }
        }
    }
}

$updated = "Updated " + (Get-Date).ToString("HH:mm")
$cardHeight = 48
$cardGap = 4
$sectionGap = 24

$upcomingY = 76
$completedY = $upcomingY + ($displayUpcoming.Count * ($cardHeight + $cardGap)) + $sectionGap
$panelH = $completedY + ($displayCompleted.Count * ($cardHeight + $cardGap)) + 20

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("[Variables]")
$lines.Add("LastUpdated=" + (SafeText $updated))
$lines.Add("IconBlank=" + (SafeText $DefaultLogo))
$lines.Add("PanelH=" + $panelH)
$lines.Add("UpcomingY=" + $upcomingY)
$lines.Add("CompletedY=" + $completedY)

for ($i = 1; $i -le 8; $i++) {
    if ($i -le $displayUpcoming.Count) {
        $m = $displayUpcoming[$i - 1]
        $t1Logo = if ($logoCache.ContainsKey($m.Team1.Trim())) { $logoCache[$m.Team1.Trim()] } else { $DefaultLogo }
        $t2Logo = if ($logoCache.ContainsKey($m.Team2.Trim())) { $logoCache[$m.Team2.Trim()] } else { $DefaultLogo }
        
        $lines.Add("Upcoming${i}Hidden=0")
        $lines.Add("Upcoming${i}Team1=" + (ShortName $m.Team1))
        $lines.Add("Upcoming${i}Team2=" + (ShortName $m.Team2))
        $lines.Add("Upcoming${i}Time=" + (SafeText $m.Time))
        $lines.Add("Upcoming${i}BO=" + (SafeText $m.BO))
        $lines.Add("Upcoming${i}Score1=")
        $lines.Add("Upcoming${i}Score2=")
        $lines.Add("Upcoming${i}Tournament=" + (SafeText $m.Tournament))
        $lines.Add("Upcoming${i}Status=" + (SafeText $m.Status))
        $lines.Add("Upcoming${i}Team1Logo=" + (SafeText $t1Logo))
        $lines.Add("Upcoming${i}Team2Logo=" + (SafeText $t2Logo))
    } else {
        $lines.Add("Upcoming${i}Hidden=1")
        $lines.Add("Upcoming${i}Team1=")
        $lines.Add("Upcoming${i}Team2=")
        $lines.Add("Upcoming${i}Time=")
        $lines.Add("Upcoming${i}BO=")
        $lines.Add("Upcoming${i}Score1=")
        $lines.Add("Upcoming${i}Score2=")
        $lines.Add("Upcoming${i}Tournament=")
        $lines.Add("Upcoming${i}Status=")
        $lines.Add("Upcoming${i}Team1Logo=" + (SafeText $DefaultLogo))
        $lines.Add("Upcoming${i}Team2Logo=" + (SafeText $DefaultLogo))
    }
}

for ($i = 1; $i -le 8; $i++) {
    if ($i -le $displayCompleted.Count) {
        $m = $displayCompleted[$i - 1]
        $t1Logo = if ($logoCache.ContainsKey($m.Team1.Trim())) { $logoCache[$m.Team1.Trim()] } else { $DefaultLogo }
        $t2Logo = if ($logoCache.ContainsKey($m.Team2.Trim())) { $logoCache[$m.Team2.Trim()] } else { $DefaultLogo }
        
        $lines.Add("Completed${i}Hidden=0")
        $lines.Add("Completed${i}Team1=" + (ShortName $m.Team1))
        $lines.Add("Completed${i}Team2=" + (ShortName $m.Team2))
        $lines.Add("Completed${i}Score1=" + $m.Score1)
        $lines.Add("Completed${i}Score2=" + $m.Score2)
        $lines.Add("Completed${i}BO=" + (SafeText $m.BO))
        $lines.Add("Completed${i}Tournament=" + (SafeText $m.Tournament))
        $lines.Add("Completed${i}Status=" + (SafeText $m.Status))
        $lines.Add("Completed${i}Team1Logo=" + (SafeText $t1Logo))
        $lines.Add("Completed${i}Team2Logo=" + (SafeText $t2Logo))
    } else {
        $lines.Add("Completed${i}Hidden=1")
        $lines.Add("Completed${i}Team1=")
        $lines.Add("Completed${i}Team2=")
        $lines.Add("Completed${i}Score1=")
        $lines.Add("Completed${i}Score2=")
        $lines.Add("Completed${i}BO=")
        $lines.Add("Completed${i}Tournament=")
        $lines.Add("Completed${i}Status=")
        $lines.Add("Completed${i}Team1Logo=" + (SafeText $DefaultLogo))
        $lines.Add("Completed${i}Team2Logo=" + (SafeText $DefaultLogo))
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllLines($DataFile, $lines, $utf8NoBom)

(Get-Date) | Set-Content $RunStamp -Force

if ($RefreshRainmeter) {
    Start-Sleep -Milliseconds 500
    $rainmeterExe = "C:\Program Files\Rainmeter\Rainmeter.exe"
    if (Test-Path $rainmeterExe) {
        & $rainmeterExe "!Refresh" "Dota2Hub"
    }
}

Write-Output "OK"
