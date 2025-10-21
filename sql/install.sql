-- Auto-inject SQL for pdrp_scrapping XP system
-- This will be automatically executed when the resource starts

CREATE TABLE IF NOT EXISTS `player_scrapping_xp` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `current_xp` int(11) NOT NULL DEFAULT 0,
    `total_xp_earned` int(11) NOT NULL DEFAULT 0,
    `vehicles_scrapped` int(11) NOT NULL DEFAULT 0,
    `last_scrap_time` timestamp NULL DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_citizenid` (`citizenid`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_current_xp` (`current_xp`),
    KEY `idx_last_scrap_time` (`last_scrap_time`),
    KEY `idx_vehicles_scrapped` (`vehicles_scrapped`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;