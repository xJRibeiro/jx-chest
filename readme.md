
# 🔐 Sistema de Baús Persistentes para RedM com RSG-Core

Este recurso oferece um sistema de baús pessoais robusto, seguro, otimizado e com suporte a múltiplos idiomas para servidores RedM com o framework RSG-Core.

---

## ✨ Funcionalidades

- **Baús Persistentes**  
  Os baús e seus conteúdos são salvos no banco de dados.

- **Sistema de Itens**  
  Requer um item configurável para criar o baú.

- **Posicionamento no Mundo**  
  Jogadores podem posicionar os baús com pré-visualização e rotação.

- **Limite de Baús**  
  Defina o número máximo de baús por jogador.

- **Sistema de Compartilhamento**  
  Compartilhe e gerencie o acesso com jogadores próximos.

- **Segurança no Servidor**  
  Interações validadas no lado do servidor.

- **Painel de Administração**  
  Gerencie baús via menu (ox_lib).

- **Logs e Auditoria**  
  Logs no console e Discord com webhooks.

---

## 🔗 Dependências

- `rsg-core`
- `ox_lib`
- `oxmysql`

---

## 🛠️ Instalação

1. **Instale as dependências**
2. **Coloque o recurso** (`jx-chest`) na pasta `resources`.
3. **Execute o SQL**

```sql
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
```

4. **Configure o script** em `shared/config.lua`
5. **Adicione ao `server.cfg`**

```cfg
ensure rsg-core
ensure ox_lib
ensure oxmysql
ensure jx-chest
```

---

## ⚙️ Configuração

Edite `shared/config.lua`:

- `Config.Language`: 'pt-br'
- `Config.Debug`: modo debug
- `Config.Logging`, `Config.LogToDiscord`: logs no console e Discord
- `Config.ChestItem`: nome do item
- `Config.MaxChestsPerPlayer`: limite de baús por jogador
- `Config.ChestSlots`, `Config.ChestWeight`: capacidade e peso do baú

---

## 🌐 Sistema de Idiomas

Para adicionar idioma:

1. Copie `locales/en.lua` e renomeie.
2. Traduza os valores.
3. Adicione ao `fxmanifest.lua` em `shared_scripts`.
4. Altere `Config.Language`.

---

## ⌨️ Comandos

Os comandos são configuráveis no `config.lua`

---

## 📌 Observações

- Seguro e escalável.
- Multi-idioma e totalmente configurável.
- Compatível com `rsg-inventory`.

Contribuições são bem-vindas!

---

# 🔐 Persistent Chest System for RedM with RSG-Core

This resource provides a robust, secure, optimized, and multi-language personal chest system for RedM servers using the RSG-Core framework.

---

## ✨ Features

- **Persistent Chests**  
  Chests and their contents are saved to the database.

- **Item System**  
  Requires a configurable item to create a chest.

- **World Placement**  
  Players can place chests with preview and rotation.

- **Chest Limit**  
  Set the maximum number of chests per player.

- **Sharing System**  
  Share and manage access with nearby players.

- **Server-Side Security**  
  All interactions are validated server-side.

- **Admin Panel**  
  Manage chests via menu (ox_lib).

- **Logs and Auditing**  
  Console and Discord logging with webhooks.

---

## 🔗 Dependencies

- `rsg-core`
- `ox_lib`
- `oxmysql`

---

## 🛠️ Installation

1. **Install dependencies**
2. **Place the resource** (`jx-chest`) in your `resources` folder.
3. **Execute the SQL**

```sql
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
```

4. **Configure the script** in `shared/config.lua`
5. **Add to `server.cfg`**

```cfg
ensure rsg-core
ensure ox_lib
ensure oxmysql
ensure jx-chest
```

---

## ⚙️ Configuration

Edit `shared/config.lua`:

- `Config.Language`: 'en'
- `Config.Debug`: debug mode
- `Config.Logging`, `Config.LogToDiscord`: console and Discord logs
- `Config.ChestItem`: required item name
- `Config.MaxChestsPerPlayer`: max chests per player
- `Config.ChestSlots`, `Config.ChestWeight`: chest capacity and weight

---

## 🌐 Language System

To add a language:

1. Copy `locales/en.lua` and rename it.
2. Translate its values.
3. Add it to `fxmanifest.lua` in `shared_scripts`.
4. Change `Config.Language`.

---

## ⌨️ Commands

Commands are configurable via `config.lua`

---

## 📌 Notes

- Secure and scalable.
- Multi-language and fully configurable.
- Compatible with `rsg-inventory`.

Contributions are welcome!

