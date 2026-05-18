# Context
使用者想卸載 `claude-mem`。目前它不是只靠單一 plugin 開關存在，還同時涉及 Claude Code 全域設定、plugin 註冊、hooks、MCP server 註冊，以及本機 `~/.claude-mem` 資料目錄與本地 worker/viewer。規劃目標：先辨識整合點，再提供最小停用方案與完整卸載方案，避免殘留 hook、錯誤 base URL、或背景服務仍在跑。

# Recommended approach

## 1. 先區分目標：停用 vs 完整卸載
建議先問清楚使用者要哪一種：
- **最小停用**：不刪資料，只讓 Claude Code 不再載入/呼叫 claude-mem。
- **完整卸載**：停用 plugin，執行 `npx claude-mem uninstall` 清掉 `~/.claude-mem` 下資料，再移除安裝快取/註冊殘留。

本次優先建議：**先停用，再完整卸載**。理由：可先驗證 Claude Code 能正常啟動，避免一步刪光後很難判斷哪個整合點造成問題。

## 2. 關鍵整合點
### 全域設定
- `/Users/re4388/.claude/settings.json`
  - `enabledPlugins["claude-mem@thedotmack"]: true`
  - `env.ANTHROPIC_BASE_URL: "http://127.0.0.1:20128/v1"`

### 安裝註冊
- `/Users/re4388/.claude/plugins/installed_plugins.json`
  - 記錄 `claude-mem@thedotmack` 安裝位置：`/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0`

### Plugin 實體與內建設定
- `/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0`
- `/Users/re4388/.claude/plugins/marketplaces/thedotmack`
- `/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0/hooks/hooks.json`
  - 定義 Setup / SessionStart / UserPromptSubmit / PreToolUse(Read) / PostToolUse / Stop hooks
- `/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0/.mcp.json`
  - 註冊 `mcp-search`

### 本地資料與服務
- `~/.claude-mem`
  - `settings.json`
  - `claude-mem.db`
  - `chroma/`
  - logs / pid / 其他 worker 狀態檔
- 本地 worker/viewer 預設走 per-user port；目前啟動訊息顯示 `http://localhost:37701`

## 3. 建議卸載順序
1. **備份重要資料（若使用者可能還想保留歷史 memory）**
   - 至少確認是否要保留 `~/.claude-mem`
2. **停用 plugin 入口**
   - 在 `/Users/re4388/.claude/settings.json` 將 `enabledPlugins["claude-mem@thedotmack"]` 關掉或移除
3. **檢查並回復 env 代理設定**
   - 確認 `/Users/re4388/.claude/settings.json` 的 `env.ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN` 是否由 claude-mem 需求帶入；若是，回復成原本值或移除
4. **執行官方卸載命令**
   - `npx claude-mem uninstall`
   - 預期清掉 `~/.claude-mem` 下 SQLite / vector index / logs / settings
5. **確認 plugin 註冊與快取是否仍殘留**
   - 檢查 `installed_plugins.json` 是否仍保留 `claude-mem@thedotmack`
   - 視實際卸載器行為，再決定是否清理：
     - `/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0`
     - `/Users/re4388/.claude/plugins/marketplaces/thedotmack`
6. **重啟 Claude Code session**
   - 驗證不再出現 claude-mem 啟動訊息、hook 注入、live activity URL

## 4. 若只想停用、不刪資料
最小方案：
1. 修改 `/Users/re4388/.claude/settings.json`
   - 將 `enabledPlugins["claude-mem@thedotmack"]` 設為 `false` 或移除
2. 視需求移除 `env.ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`
3. 重開 Claude Code

這樣理論上 hooks / MCP 不應再被 plugin 啟用，但 `~/.claude-mem` 資料仍保留，可之後再恢復。

## 5. 驗證清單
### 停用後驗證
- Claude Code 新 session 啟動時，不再出現：
  - `claude-mem status`
  - `This project has no memory yet...`
  - `Live activity: http://localhost:37701`
- `mcp-search` 不再可用
- 不再出現 claude-mem 相關 skills（如 `claude-mem:mem-search`、`claude-mem:learn-codebase`）

### 完整卸載後驗證
- `~/.claude-mem` 已移除或至少不再包含：
  - `settings.json`
  - `claude-mem.db`
  - `chroma/`
- `/Users/re4388/.claude/settings.json` 不再啟用 `claude-mem@thedotmack`
- `/Users/re4388/.claude/plugins/installed_plugins.json` 不再保留 `claude-mem@thedotmack`（若卸載器負責清理）
- 本地 `37701` 不再提供 claude-mem live activity/viewer

## 6. 風險與回滾點
### 風險
- 若直接刪 `~/.claude-mem`，歷史 memory / embeddings / logs 會消失
- 若只刪 plugin 目錄但沒先停用 `settings.json`，下次啟動可能出現 plugin not found / hook 相關錯誤
- 若 `env.ANTHROPIC_BASE_URL` 是其他工具共用，直接移除可能影響非 claude-mem 流程

### 回滾點
- 完整卸載前，備份 `~/.claude-mem`
- 保留 `/Users/re4388/.claude/settings.json` 原始內容
- 保留 `/Users/re4388/.claude/plugins/installed_plugins.json` 原始內容
- 若只是停用，將 `enabledPlugins["claude-mem@thedotmack"]` 改回 `true` 即可先回復

## 7. 執行時優先重用既有機制
- 優先使用官方卸載命令：`npx claude-mem uninstall`
- 手動刪目錄只當補救，不當第一步
- 先改 plugin enable 狀態，再做資料刪除，降低殘留 hook/註冊錯誤

# Critical files to modify
- `/Users/re4388/.claude/settings.json`
- 可能確認但不一定需手改：`/Users/re4388/.claude/plugins/installed_plugins.json`

# Existing functions/utilities to reuse
- 官方卸載機制：`npx claude-mem uninstall`
- plugin 啟用開關來源：`/Users/re4388/.claude/settings.json`
- hooks 定義參考：`/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0/hooks/hooks.json`
- MCP 註冊參考：`/Users/re4388/.claude/plugins/cache/thedotmack/claude-mem/13.1.0/.mcp.json`

# Verification
1. 先讀 `/Users/re4388/.claude/settings.json`，確認 plugin enable 與 env 值
2. 停用後重開 Claude Code，確認啟動訊息已消失
3. 若做完整卸載，執行 `npx claude-mem uninstall`
4. 再檢查 `~/.claude-mem` 是否已清空或刪除
5. 再檢查 claude-mem skills / MCP / localhost:37701 是否都不再出現
