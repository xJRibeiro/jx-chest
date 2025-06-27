-- shared/config.lua
Config = {}
--------------------------------------------------------------------------------
-- CONFIGURAÇÃO DE IDIOMA | LANGUAGE CONFIGURATION
--------------------------------------------------------------------------------
-- Defina o idioma do script. Opções disponíveis: 'pt-br', 'en'
-- Set the script language. Available options: 'pt-br', 'en'
Config.Language = 'pt-br'

--------------------------------------------------------------------------------
-- CONFIGURAÇÕES DE DEBUG E LOG | DEBUG AND LOG SETTINGS
--------------------------------------------------------------------------------
-- Habilita/desabilita as mensagens de debug no console do servidor.
-- Enables/disables debug messages in the server console.
Config.Debug = true
-- Nível de Debug: | Debug Level:
-- 1: Apenas informações críticas de erro. | Critical error information only.
-- 2: Ações importantes (ex: jogador colocou/removeu baú). | Important actions (e.g., player placed/removed chest).
-- 3: Informações muito verbosas para depuração (ex: checagens de permissão, loops). | Very verbose information for debugging (e.g., permission checks, loops).
Config.DebugLevel = 3

-- Habilita/desabilita o sistema de logs de ações importantes. | Enables/disables the action logging system.
Config.Logging = true
-- Nível de Log: | Log Level:
-- 1: Apenas ações críticas (criação/remoção de baú, ações de admin). | Critical actions only (chest creation/removal, admin actions).
-- 2: Logs detalhados (compartilhamento, abertura). | Detailed logs (sharing, opening).
Config.LogLevel = 3

-- Habilita/desabilita o envio de logs para o Discord via Webhook. | Enables/disables sending logs to Discord via Webhook.
Config.LogToDiscord = true
-- URL do Webhook do Discord. SÓ SERÁ USADO SE Config.LogToDiscord FOR TRUE. | Discord Webhook URL. ONLY USED IF Config.LogToDiscord IS TRUE.
Config.DiscordWebhook = 'https://discord.com/api/webhooks/1387010524960653332/CC6AG-Wrv3gnrasvnccr_BcNE0QrsNjL5TtX4pdOZgNAM46EHWCkfKBvBz5CsP3s4eS1'

-- Habilita/desabilita o envio de ações administrativas para o Discord via Webhook. | Enables/disables sending admin actions to Discord via Webhook.
Config.LogAdminActionsToDiscord = false 
-- URL do Webhook do Discord para ações administrativas. SÓ SERÁ USADO SE Config.LogAdminActionsToDiscord FOR TRUE. | Discord Webhook URL for admin actions. ONLY USED IF Config.LogAdminActionsToDiscord IS TRUE.
Config.DiscordWebhookAdmin = ''

--------------------------------------------------------------------------------
-- CONFIGURAÇÕES GERAIS DO BAÚ | GENERAL CHEST SETTINGS
--------------------------------------------------------------------------------
Config.ChestItem = 'personal_chest' -- Item necessário para colocar o baú. | Item required to place the chest.
Config.ChestProp = 'p_chest01x'      -- Modelo do prop do baú. | Chest prop model.
Config.MaxDistance = 2.0             -- Distância mínima entre baús. | Minimum distance between chests.
Config.PlacementDistance = 5.0       -- Distância máxima que o jogador pode colocar o baú a partir de sua posição. | Maximum distance the player can place the chest from their position.
Config.MaxChestsPerPlayer = 5        -- Máximo de baús que um jogador pode ter. 0 para ilimitado. | Maximum number of chests a player can have. 0 for unlimited.
Config.MaxSharedPlayers = 5          -- Máximo de jogadores que podem compartilhar o baú. 0 para ilimitado | Set to 0 for unlimited
Config.BlipDuration = 300 -- Duração do blip no mapa em segundos. | Duration of the map blip in seconds.

-- Configurações do Inventário (usado pelo rsg-inventory) | Inventory settings (used by rsg-inventory)
Config.ChestSlots = 50
Config.ChestWeight = 100000 -- 100kg

-- Configurações de Permissões | Permissions settings
Config.MaxSharedPlayers = 5

-- Configurações de Animação e Tempo | Animation and Timing Settings
Config.PlacementTime = 3000 -- 3 segundos | Time to place the chest 3 seconds
Config.RemovalTime = 2000   -- 2 segundos | Time to remove the chest 2 seconds

-- Cooldown em milissegundos para evitar spam de ações | Action cooldown in milliseconds to prevent action spamming
Config.ActionCooldown = 2000 -- 2 segundos | Action cooldown in milliseconds to prevent action spamming 2 seconds

-- Distância em que os baús serão renderizados para o jogador. Valores muito altos podem impactar o cliente.
-- Distance at which chests will be rendered for the player. Very high values can impact the client.
Config.StreamDistance = 25.0

--------------------------------------------------------------------------------
-- COMANDOS DO BAÚ | CHEST COMMANDS
--------------------------------------------------------------------------------
Config.CommandAdminChest = 'adminchest' -- Comando para abrir o painel administrativo de baús. | Command to open the admin chest panel.
Config.CommandMyChests = 'mychests' -- Comando para mostrar os baús do jogador no mapa. | Command to show the player's chests on the map.
Config.CommandCleanOrphanChests = 'cleanorphanchests' -- Comando para limpar baús órfãos de jogadores que não existem mais. | Command to clean orphaned chests from players that no longer exist.
Config.CommandRemoveAllChests = 'removeallchests' -- Comando para remover todos os baús do servidor. | Command to remove all chests from the server.

--------------------------------------------------------------------------------

Config.Lang = {}
