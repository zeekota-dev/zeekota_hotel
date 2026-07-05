CREATE TABLE IF NOT EXISTS `zeekota_hotel_rooms` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(120) NOT NULL,
    `framework` VARCHAR(20) NOT NULL DEFAULT 'standalone',
    `player_name` VARCHAR(100) NULL,
    `hotel` VARCHAR(64) NOT NULL,
    `room_id` VARCHAR(32) NOT NULL,
    `stash_id` VARCHAR(96) NOT NULL,
    `assigned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier_unique` (`identifier`),
    KEY `hotel_index` (`hotel`),
    KEY `room_index` (`hotel`, `room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `zeekota_hotel_furniture` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(120) NOT NULL,
    `hotel` VARCHAR(64) NOT NULL,
    `room_id` VARCHAR(32) NOT NULL,
    `label` VARCHAR(80) NOT NULL,
    `model` VARCHAR(80) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `owner_room_index` (`identifier`, `hotel`, `room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `zeekota_hotel_stashes` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(120) NOT NULL,
    `hotel` VARCHAR(64) NOT NULL,
    `room_id` VARCHAR(32) NOT NULL,
    `mode` VARCHAR(20) NOT NULL DEFAULT 'marker',
    `model` VARCHAR(80) NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `owner_unique` (`identifier`, `hotel`, `room_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
