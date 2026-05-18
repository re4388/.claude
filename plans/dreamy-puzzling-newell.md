## Context
使用者要建立一個最小可用 Chrome extension，在載入 `x.com` 時自動點擊頁面中的繁中按鈕「顯示更多」，避免手動操作。專案目前為空，只有 `.git/`，沒有既有 extension 骨架、建置設定、或測試框架。使用者已確認採用最小原生方案，且只支援 `x.com`。

## Recommended approach
採用不需 build 的原生 Manifest V3 extension。核心邏輯放在 content script，於 `x.com` 頁面載入後掃描可見按鈕/元素，找到文字完全等於 `顯示更多` 的可點擊節點後自動點擊。因 X 頁面為 SPA，除了初次載入，也要在 DOM 更新時持續處理，因此會用 `MutationObserver` 搭配節流/去重，避免重複狂點同一元素。

### Files to create or modify
- `manifest.json`
  - 定義 Manifest V3
  - 設定 `content_scripts`
  - `matches` 限定 `https://x.com/*`
  - 載入 `content.js`
- `content.js`
  - 實作自動尋找並點擊 `顯示更多`
  - 初次執行一次
  - 監聽後續 DOM 變動
  - 避免重複點擊同一節點
- `package.json`
  - 僅加入測試所需腳本與依賴
- 測試檔，例如 `content.test.js`
  - 驗證文字匹配、點擊行為、忽略非目標元素、避免重複點擊

## Implementation details
1. 在 `content.js` 拆出可測試純函式
   - 例如：尋找候選元素、判斷文字是否為 `顯示更多`、執行點擊流程
   - DOM 啟動與 `MutationObserver` 維持薄層，方便測試
2. 候選元素策略
   - 掃描常見可點擊節點，例如 `button`, `[role="button"]`, `div`, `span`
   - 只對 `textContent.trim() === "顯示更多"` 的元素處理
   - 往上找最近可點擊祖先，避免點到純文字節點
3. 去重策略
   - 用 `WeakSet` 記錄已點擊元素，避免同一節點被 observer 重複觸發
4. 測試策略
   - 使用輕量測試框架加 jsdom 模擬 DOM
   - 每次新增程式碼都附對應單元測試，符合專案規則

## Notes from exploration
- 專案目前為空；`Glob` 只找到 `.git/` 內容，沒有任何原始碼或設定檔可沿用。
- 因無既有工具鏈，最小原生方案比加入 Vite/webpack 更符合需求。
- 目前無既有函式或工具可重用。

## Verification
1. 安裝測試依賴並執行單元測試
2. 在 Chrome 載入 unpacked extension
3. 開啟 `https://x.com/*` 頁面
4. 確認出現 `顯示更多` 時會自動被點擊
5. 確認非 `顯示更多` 按鈕不受影響
6. 確認動態載入新內容後仍會自動處理，且不會對同一元素重複狂點
