CREATE TABLE IF NOT EXISTS `user` (
    `account` TEXT NOT NULL PRIMARY KEY,
    `password` TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS `todo` (
    `id` INTEGER PRIMARY KEY AUTOINCINCEMENT,
    `account` TEXT NOT NULL,
    `due_date` TIMESTAMP NOT NULL,
    `content` TEXT NOT NULL,
    `complete` BOOLEAN
);