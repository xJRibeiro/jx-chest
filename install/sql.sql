    CREATE TABLE IF NOT EXISTS `player_chests` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `chest_uuid` varchar(50) NOT NULL,
      `owner` varchar(50) NOT NULL,
      `coords` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
      `heading` float NOT NULL DEFAULT 0,
      `model` varchar(50) NOT NULL DEFAULT 'p_chest01x',
      `shared_with` longtext DEFAULT NULL,
      `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
      `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
      PRIMARY KEY (`id`),
      UNIQUE KEY `chest_uuid` (`chest_uuid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;