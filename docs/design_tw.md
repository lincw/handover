# 設計理念與取捨

記錄這個系統為什麼長這樣，讓未來的修改不會在不知情下推翻當初有理由的決定。

## 要解決的問題

跨裝置、跨 agent、跨帳號的工作延續性。Claude Code 的 `--resume`、auto memory 都限於同一台機器同一個 agent；`/compact` 是有損壓縮且不受控。而且 context 塞滿時有兩個實證問題：context rot（越滿、對早期 token 的注意力越衰減）與 context anxiety（模型自覺空間不足時走捷徑、草草收尾）。所以策略是：**把值得記的寫出來（handover），然後用乾淨的 context 重啟**，而不是帶著 80k 的舊 context 繼續跑。

## 核心決策

### Markdown 為真、SQLite 為索引

真相是 `handovers/` 裡一張一個的 md 檔；SQLite 只提供列表與 FTS5 搜尋，放本機 `~/.cache/`，可隨時重建。理由：

- 二進位資料庫走雲端同步有損毀風險（WAL 附屬檔、部分同步），純文字沒有。
- Drive 衝突發生時，每單一檔的設計把影響範圍鎖在單一張單，且衝突副本人眼可讀可裁決。
- 交班單的主要讀者是 LLM 與人，markdown 對兩者都是原生格式；JSON 的「機器好解析」在這裡沒有消費者。
- 量級是個人使用（一年數百張），grep/FTS5 都綽綽有餘，不需要真正的資料庫。

### 兩層 schema

- **Layer 1（內文）**：純文字通用層，任何 agent 可讀。跨 agent 交班只給這層（`load.sh --layer1-only`）。
- **Layer 2（frontmatter）**：環境 metadata（device、branch、working_dir、account、test_status），只有回到同環境才有用。

### 集中存放，不分散進各專案 repo

用 `project` 欄位區分，而非把交班單放進各專案。因為一半的 session（討論、coaching、admin）根本沒有 repo，且「列出我所有 open 的單」這種跨專案查詢是換裝置時的第一個動作。

### 同步用 Google Drive，git 只做本機版本紀錄

使用者的明確選擇：單人多裝置，同時寫入幾乎不會發生，Drive 的便利勝過 git 的顯性同步。代價（已知並接受）：同步延遲時的沉默過期——所以 load.sh 印時效標頭、README 提醒換裝置先看同步狀態。git 目錄放 Drive 之外（`~/Git_repo/handover.git`），因為 `.git` 的海量小檔不適合雲端同步；git 的角色是誤刪救援與歷史，不是同步。

### session_type 決定摘要深度

sdd / debug / discussion / admin 四型。關鍵洞察：debug 型最有價值的欄位是 attempted_approaches——「試過什麼、為什麼不行」比最終解法更值得留；sdd 型有設計文件可還原，交班單只記進度與偏離。

### 沒有 hibernate

曾考慮過「暫存大 context 之後回來」的 hibernate 指令，推導後放棄：cache miss 只是多花錢不會丟資訊，而保留大 context 反而承受 context rot。hibernate 想保留的欄位（conversation_summary、lessons_learned、attempted_approaches）全部併入 Layer 1。任何情境下 handover + 乾淨重啟都不劣於暫存。

### 狀態機：open → done / superseded

「過期的 open 單比沒有單更危險」——接手的 agent 會自信地執行過期的 next steps。所以接手後必須標掉舊單（mark.sh），load 預設只挑 open。

## 與其他機制的分界

| 機制 | 記什麼 | 壽命 |
|---|---|---|
| handover | 狀態（做到哪、下一步） | 會過期，用完標掉 |
| memory / CLAUDE.md | 事實、偏好、專案慣例 | 長期有效 |
| session transcript | 逐字過程 | 本機、不可攜 |

Lessons learned 是兩者的橋：交班單裡發現長期有效的教訓，升級進 memory，然後從單中移除。

## 刻意不做的事

- **SessionStart hook 自動注入**：容易撈錯單、瑣碎 session 不需要。若日後要做，只注入一行「有 N 張 open 單」的提示，載入仍由人觸發。
- **SessionEnd 自動交班**：強制產出的摘要品質差、垃圾卡片污染索引。什麼值得被記住，這個判斷留在人身上。
- **加密／權限**：定位是個人工具；規則是從源頭不寫入機密，而非事後保護。
