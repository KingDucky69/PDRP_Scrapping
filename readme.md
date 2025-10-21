# qb-scrap

Scrap random NPC cars chosen from a rotating list. Prevents scrapping of vehicles owned in `player_vehicles`.

## Dependencies
- qb-core
- oxmysql
- Standard QBCore database with `player_vehicles` table

## Install
1. Put this folder in `resources/[qb]/qb-scrap`
2. In `server.cfg` (order after qb-core and oxmysql):
   ensure oxmysql
   ensure qb-core
   ensure qb-scrap

## Usage
- /scrapcar — Scrap the nearest NPC vehicle if its model is active and it isn’t owned.
- /scraplist — Shows current active model hashes (server refresh is automatic on resource start).
- /scraprefresh — Admin only. Refreshes the active model list.

## Config
- `Config.VehiclePool` — source list of models.
- `Config.ActiveCount` — how many are active.
- `Config.Reward` — money and optional items.
- `Config.ScrapRange` — distance to check for a vehicle.

Notes:
- Plate check strips spaces and uppercases before querying.
- If your plates in DB are lower/mixed case, ensure case-insensitive collation or adjust the query/normalization to match your setup.