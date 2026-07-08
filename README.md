# Dota2Hub - Rainmeter Skin

A live Dota 2 Tier 1 scoreboard for [Rainmeter](https://www.rainmeter.net/), displaying upcoming and completed matches from [Liquipedia](https://liquipedia.net/dota2/).

![Dota2Hub Preview](https://img.shields.io/badge/Version-1.0.0-blue) ![License](https://img.shields.io/badge/License-MIT-green) ![Author](https://img.shields.io/badge/Author-Parsa%20Rasouli-orange)

---

## Features

- **Live Match Tracking** - See real-time scores for ongoing matches
- **Tier 1 Only** - Automatically filters to show only Tier 1 tournaments
- **Auto-Refresh** - Updates every 5 minutes automatically
- **Team Logos** - Displays official team logos from Liquipedia
- **Score Display** - Shows current scores for completed and live matches
- **Resizable** - Scroll mouse wheel to resize the skin
- **Dark Theme** - Beautiful dark theme designed for Dota 2 fans

---

## Supported Tournaments

The skin automatically detects Tier 1 tournaments from Liquipedia, including:

- Esports World Cup (EWC)
- The International (TI)
- BLAST Slam
- PGL Wallachia
- Esports Nations Cup
- And more...

---

## Requirements

- **Windows 10/11**
- **[Rainmeter](https://www.rainmeter.net/) 4.5+** (recommended)
- **Internet connection** (for fetching match data)

---

## Installation

### Method 1: Manual Installation

1. **Download** the latest release from [Releases](https://github.com/Parsoulini/Dota2Hub/releases)
2. **Extract** the ZIP file
3. **Copy** the `Dota2Hub` folder to:
   ```
   C:\Users\<YourUsername>\Documents\Rainmeter\Skins\
   ```
4. **Right-click** the Rainmeter tray icon → **Refresh all**
5. **Load** the skin: Right-click tray → **Skins** → **Dota2Hub** → **Dota2Hub**

### Method 2: Git Clone

```bash
cd "C:\Users\<YourUsername>\Documents\Rainmeter\Skins\"
git clone https://github.com/Parsoulini/Dota2Hub.git
```

Then refresh Rainmeter and load the skin.

---

## Usage

### Basic Controls

| Action | Description |
|--------|-------------|
| **Scroll Up** | Increase skin size |
| **Scroll Down** | Decrease skin size |
| **Right-click** | Open context menu |
| **Drag** | Move skin around the desktop |

### Understanding the Display

#### LIVE & UPCOMING Section
- Shows matches that are currently live or scheduled
- Live matches display the current score (e.g., `1-0`)
- Upcoming matches display the scheduled time (e.g., `20:30`)
- Tournament name is shown below each match

#### COMPLETED Section
- Shows recently completed matches
- Displays the final score (e.g., `2-1`)
- Sorted by most recent first

### Resizing the Skin

The skin supports dynamic resizing for different screen resolutions:

1. **Default Size** - Optimized for 1440p (2K) displays
2. **For 1080p** - Scroll down to reduce size
3. **For 4K** - Scroll up to increase size

The scale factor is saved automatically and persists across restarts.

---

## Configuration

### Variables File

Edit `Data.inc` to customize match data (auto-generated):

```ini
[Variables]
LastUpdated=Updated 18:30
PanelH=500
UpcomingY=76
CompletedY=400
```

### Main Skin File

Edit `Dota2Hub.ini` to customize appearance:

```ini
[Variables]
Scale=1.0          ; Resize factor (0.5 to 2.0)
FontMain=Segoe UI  ; Main font
FontBold=Segoe UI Semibold  ; Bold font
Text=245,247,250,255  ; Text color (RGBA)
Accent=255,120,50,255  ; Accent color
```

### Color Scheme

| Variable | Color | Usage |
|----------|-------|-------|
| `Text` | White | Team names, scores |
| `Muted` | Gray | Tournament names, times |
| `Accent` | Orange | Section titles |
| `Card` | Dark Blue | Card backgrounds |
| `Panel` | Darker Blue | Main panel background |

---

## Auto-Refresh

The skin automatically refreshes every 5 minutes:

1. **Data Fetching** - Fetches latest matches from Liquipedia
2. **Tier Filtering** - Filters to show only Tier 1 tournaments
3. **Score Updates** - Updates live scores
4. **Logo Download** - Downloads team logos (first time only)

### Manual Refresh

To manually refresh:
1. Right-click the skin
2. Select **Refresh skin**

Or click the refresh icon in the skin header.

---

## Tier 1 Detection

The skin automatically detects Tier 1 tournaments:

1. **Daily Update** - Fetches tournament list from Liquipedia Portal:Tournaments
2. **Caching** - Stores tier information for 24 hours
3. **Filtering** - Only shows matches from Tier 1 tournaments

### Manually Adding Tournaments

To add a tournament manually:

1. Edit `Cache\tier1_leagues.txt`
2. Add the tournament URL path:
   ```
   Esports_World_Cup/2026
   The_International/2025
   ```
3. Save the file

---

## File Structure

```
Dota2Hub/
├── Dota2Hub.ini              ; Main skin file
├── Data.inc                  ; Generated match data
├── @Resources/
│   ├── Generate-Dota2Hub.ps1 ; Data generation script
│   ├── Refresh-Dota2Hub.vbs  ; Auto-refresh script
│   └── logo_default.png      ; Default team logo
└── Cache/
    ├── matches_page.html     ; Cached matches page
    ├── portal_tournaments.html ; Cached tournaments page
    ├── tier1_leagues.txt     ; Tier 1 tournament list
    ├── tier_cache.json       ; Tier cache
    ├── tier_last_update.txt  ; Last update timestamp
    └── logo_*.png            ; Downloaded team logos
```

---

## Troubleshooting

### Skin Not Loading

1. Ensure Rainmeter is running
2. Right-click tray → **Refresh all**
3. Check if `Dota2Hub.ini` exists in the skin folder

### No Matches Showing

1. Check internet connection
2. Verify Liquipedia is accessible
3. Check `Cache\matches_page.html` for errors

### Wrong Time Display

The skin shows times in **IRST (Iran Standard Time, UTC+3:30)**:

- CEST (UTC+2) → IRST = CEST + 1:30
- CET (UTC+1) → IRST = CET + 2:30

### Rate Limiting

If you see "Rate Limited" errors:

1. Wait a few minutes
2. The skin caches data to minimize requests
3. Tier list updates once per day only

---

## Updating

### To Update the Skin

1. Download the latest release
2. Replace files in the skin folder
3. Refresh Rainmeter

### To Update Tier List

The tier list updates automatically every 24 hours. To force update:

1. Delete `Cache\tier_last_update.txt`
2. Refresh the skin

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Liquipedia](https://liquipedia.net/dota2/) - Match data and team logos
- [Rainmeter](https://www.rainmeter.net/) - Desktop customization platform
- [Dota 2](https://www.dota2.com/) - The game we all love

---

## Author

**Parsa Rasouli**

- GitHub: [@Parsoulini](https://github.com/Parsoulini)

---

## Support

If you find this skin useful, consider:

- Starring the repository
- Reporting bugs
- Suggesting new features
- Sharing with friends

---

**Made with ❤️ for the Dota 2 community**
