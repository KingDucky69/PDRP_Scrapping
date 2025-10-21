# PDRP Scrapping - Enhanced Vehicle Scrap System

A modern vehicle scrapping script that allows players to scrap NPC vehicles from a rotating list. Features a beautiful UI with vehicle images and prevents scrapping of player-owned vehicles.

## ✨ Features

- **🎨 Beautiful Modern UI** with vehicle images and responsive design
- **🔄 Daily rotating list** of scrap vehicles with visual display
- **🛡️ Prevents scrapping** of player-owned vehicles
- **💰 Configurable rewards** (money + optional items)
- **🚫 Duplicate prevention** - can't scrap same vehicle twice
- **📱 Mobile-friendly** responsive interface
- **⌨️ Keybind support** for quick access
- **🖱️ Click-to-copy** vehicle names from UI

## 🔧 Dependencies
- qb-core
- oxmysql
- Standard QBCore database with `player_vehicles` table

## 📦 Installation
1. Put this folder in `resources/[qb]/pdrp_scrapping`
2. In `server.cfg` (order after qb-core and oxmysql):
   ```
   ensure oxmysql
   ensure qb-core
   ensure pdrp_scrapping
   ```
3. Restart server or use `refresh` and `start pdrp_scrapping`

## 🎮 Usage

### Commands
- **`/scrapcar`** — Scrap the nearest NPC vehicle if it's on the active list
- **`/scraplist`** — Opens the modern vehicle UI with images and details
- **`/scraplisttext`** — Shows vehicle list in chat (legacy method)
- **`/scrapclose`** — Emergency command to force close UI if stuck
- **`/scraprefresh`** — Admin only. Refreshes the active vehicle list

### Keybinds
- **`F6`** — Open scrap vehicle list UI (configurable)
- **`ESC`** — Close the UI when open

### UI Features
- **Visual Gallery**: See images of all vehicles you need to find
- **Interactive Cards**: Click any vehicle to copy its model name
- **Real-time Data**: Always shows current active scrap vehicles
- **Reward Info**: Clear display of potential rewards
- **Smooth Animations**: Modern transitions and hover effects

## ⚙️ Configuration

Edit `config.lua` to customize:

```lua
Config.ActiveCount = 6                    -- How many vehicles active at once
Config.VehiclePool = { ... }             -- Available vehicle models
Config.Reward.min = 200                  -- Minimum reward
Config.Reward.max = 500                  -- Maximum reward
Config.ScrapRange = 5.0                  -- Distance to target vehicles
Config.UI.openKey = 'F6'                 -- Keybind to open UI
```

## 🎯 How It Works

1. **Random Selection**: Server picks random vehicles from the pool each restart/refresh
2. **Visual Display**: Players use `/scraplist` or `F6` to see needed vehicles with images
3. **Proximity Scrapping**: Walk near a target vehicle and use `/scrapcar`
4. **Validation**: System checks if vehicle is owned, already scrapped, or on the list
5. **Rewards**: Players receive money and optional items for successful scraps

## 📝 Notes
- Plate checking strips spaces and converts to uppercase before database queries
- Vehicle images are loaded from external sources with fallback placeholders
- UI is fully responsive and works on all screen sizes
- All player-owned vehicles are automatically protected from scrapping

## 🎨 UI Preview
The modern interface features:
- Gradient backgrounds with blur effects
- Animated vehicle cards with hover effects
- Real-time vehicle image loading
- Click-to-copy functionality for easy reference
- Professional typography and spacing
- Mobile-responsive grid layout

## 🔄 Version History
- **v1.1.0**: Added beautiful UI with vehicle images, keybind support, and enhanced user experience
- **v1.0.0**: Basic scrapping functionality with chat-based vehicle list