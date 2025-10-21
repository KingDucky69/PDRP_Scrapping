fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'qb-scrap'
description 'Scrap NPC cars from a rotating list; blocks player-owned vehicles'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.svg',
    'html/images/*.webp',
    'sql/install.sql'
}

dependencies {
    'qb-core',
    'oxmysql',
    'ox_lib'
}