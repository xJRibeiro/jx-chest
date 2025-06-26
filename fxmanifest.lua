fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'jx.dev'
description 'Sistema de Baús Persistentes e Compartilháves | Persistent and Shareable Chest System'
version '1.0'

lua54 'yes'

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locales/en.lua',
    'shared/locales/pt-br.lua',
    'shared/main_locale.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/cache.lua',
    'server/main.lua', 
    'server/admin.lua'  
}

client_scripts {
    'client/admin.lua',
    'client/main.lua'
}
