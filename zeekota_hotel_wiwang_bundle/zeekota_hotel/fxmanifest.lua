fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ZeeKota'
description 'Wiwang Hotel room assignment, storage, door, and furniture system'
version '3.1.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/keys/*.svg'
}

dependencies {
    'oxmysql',
    'ox_inventory'
}
