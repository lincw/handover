# 使用說明

本文件是完整參考。日常使用你幾乎不會直接碰 script——對 Claude Code 說「交班」「接手」就會觸發 skill 代勞；這裡記錄的是底層行為，供除錯與手動操作。

以下範例以 `$H` 代表本資料夾：

```bash
H="$HOME/Library/CloudStorage/GoogleDrive-<your-email>/My Drive/handover"
```

## 目錄

1. [日常工作流](#日常工作流)
2. [指令參考](#指令參考)
3. [交班單格式規格](#交班單格式規格)
4. [session_type 與摘要深度](#session_type-與摘要深度)
5. [疑難排解](#疑難排解)

---

## 日常工作流

### 交班（session 結束前）

對 Claude 說「交班」或「存一下進度」。Claude 會：

1. 判斷 session_type（不確定會問你一次）
2. 把交班單草稿寫到暫存檔
3. 執行 `save.sh --file <草稿>`，回報交班單 id
4. 建議你 `/clear`——與其讓塞滿的 context 帶著品質衰減繼續跑，不如乾淨重來

### 接手（新 session 開始）

對 Claude 說「接手 <專案>」或「上次做到哪」。Claude 會：

1. 執行 `load.sh --project <專案>` 載入最新一張 open 的單
2. 驗證現況（branch 是否還在、檔案是否被改過），有出入以現況為準
3. 把接手的單標成 `superseded`（之後會存新單）或 `done`

### 交班給其他 agent（Antigravity、ChatGPT⋯⋯）

```bash
"$H/scripts/load.sh" --project <專案> --layer1-only
```

輸出只含通用層（去掉 frontmatter 的環境 metadata），直接整段貼給對方 agent 當開場 context。對方不需要理解本系統的任何格式。

### 換裝置

1. 舊裝置：交班（等 Drive 圖示顯示同步完成再離開）
2. 新裝置：確認 Drive 已同步，然後「接手」

---

## 指令參考

### save.sh — 存一張交班單

```bash
"$H/scripts/save.sh" --file <draft.md>
```

- 草稿必須含 frontmatter（至少 `project`、`session_type`）和一行 `# 標題`。
- 自動補齊：`created_at`（UTC）、`device`（hostname）、`status: open`、`agent: claude-code`、`schema_version`、`working_dir`（呼叫時的 cwd）、`branch`（若 cwd 在 git repo 內）。
- 檔名自動生成：`YYYY-MM-DD-HHMM-<project-slug>.md`（本地時間），重名自動加 `-2`。
- `status` 為 open 但草稿沒有 `## Next steps` 時印出警告（不擋下）。
- 缺必填欄位、session_type 不合法、無標題 → 直接報錯退出。

### load.sh — 載入交班單

```bash
"$H/scripts/load.sh" [--project <名稱>] [--id <id>] [--layer1-only] [--any-status]
```

| 參數 | 行為 |
|---|---|
| （無參數） | 所有專案中最新一張 `open` 的單 |
| `--project` | 限定專案 |
| `--id` | 指定特定單（無視狀態） |
| `--layer1-only` | 去掉 frontmatter，只印通用層內文 |
| `--any-status` | 連 done/superseded 也納入挑選 |

輸出開頭有時效標頭：`寫於 N 小時前｜裝置｜branch｜status｜agent`，以及「接手前先驗證現況」的提醒。

### list.sh — 列出交班單

```bash
"$H/scripts/list.sh" [--project <名稱>] [--all] [--days <N>]
```

預設：近 30 天、`open` 狀態。`--all` 顯示全部狀態、不限日期（上限 50 筆）。

### search.sh — 全文搜尋

```bash
"$H/scripts/search.sh" "關鍵字" [--project <名稱>]
```

SQLite FTS5 語法可用：`parser AND timeout`、`"exact phrase"`、`fail*`。中文可搜，但 FTS5 預設分詞對中文是逐字處理，多字詞建議直接整串輸入。最典型的用途：接到似曾相識的 bug 時搜 attempted approaches——「我之前試過什麼、為什麼不行」。

### mark.sh — 改狀態

```bash
"$H/scripts/mark.sh" <id> <open|done|superseded>
```

- `done`：這件事完結了。
- `superseded`：被更新的一張單取代（接手後存新單前標掉舊的）。
- 原則：**過期的 open 單比沒有單更危險**——未來的 session 會很自信地照著過期的 next steps 做。

### reindex.py — 重建索引

```bash
python3 "$H/scripts/reindex.py" "$H/handovers" ~/.cache/handover/index.db
```

平常不需要手動跑：每支 script 都會在「索引不存在／有 md 比索引新／檔案數不符」時自動重建。索引壞了直接刪 `~/.cache/handover/index.db` 即可。

---

## 交班單格式規格

```markdown
---
schema_version: 1
created_at: 2026-07-03T13:20:35Z
session_type: debug
status: open
project: gmail-billing-scan
agent: claude-code
device: mac-mini
account: personal
branch: fix/parser
working_dir: /Users/me/Git_repo/gmail-billing-scan
test_status: 3 failing in parser_test
---

# 一句話說清楚這張單在做什麼

## Done
## Decisions
## Blocked
## Next steps
## Attempted approaches
## Lessons learned
```

### Frontmatter（Layer 2：環境 metadata，同環境接手才用得到）

| 欄位 | 必填 | 說明 |
|---|---|---|
| `project` | ✓ | 專案代號，list/load 以此過濾 |
| `session_type` | ✓ | `sdd` / `debug` / `discussion` / `admin` |
| `status` | 自動 | `open` / `done` / `superseded`，預設 open |
| `created_at` | 自動 | UTC ISO 8601 |
| `device` / `agent` / `branch` / `working_dir` | 自動 | 交班當下的環境快照 |
| `account` | 建議 | 訂閱帳號代號（personal / team），**只存代號** |
| `test_status` | 建議 | 交班當下測試狀態，接手第一件事就是重跑驗證 |
| `schema_version` | 自動 | 格式版本，目前為 1 |

### 內文（Layer 1：通用層，任何人與任何 agent 可讀）

| 章節 | 說明 |
|---|---|
| `# 標題` | 必填。一句話說清楚這張單在做什麼 |
| `## Done` | 完成了什麼，具體到檔案與函式 |
| `## Decisions` | 決策與理由；討論型記「論點 → 共識/分歧」 |
| `## Blocked` | 卡在哪（沒有就省略） |
| `## Next steps` | 每條可直接執行、含檔案路徑；open 單必備 |
| `## Attempted approaches` | 每條「做法 → 結果 → 為什麼排除」 |
| `## Lessons learned` | 長期有效的教訓；適合的話升級進 memory/CLAUDE.md 後從單中移除 |

### 品質規則

- 寫給**完全沒看過這段對話的接班人**：禁用代名詞與本次對話才懂的簡稱。
- Next steps 禁止「繼續 debug」這種空話——每條要能不回頭問人就直接動手。
- **絕不寫入 token、密碼、憑證**：交班單會被貼進其他 agent 的 prompt，等於離開這台機器。

---

## session_type 與摘要深度

| 型別 | 適用 | 重點 |
|---|---|---|
| `sdd` | 有設計文件的開發 | 只記進度與「偏離設計文件的決策」；設計細節指回文件路徑，不重抄 |
| `debug` | 除錯 | Attempted approaches 是主體，寧可多寫；最終解法反而其次 |
| `discussion` | 討論、coaching、分析 | 論點、共識、分歧；不記對話過程 |
| `admin` | 雜務 | 只需 Next steps 與 Decisions |

---

## 疑難排解

**load 到的是舊單** — Drive 還沒同步完。看選單列 Drive 圖示等它轉完；確認 `handovers/` 資料夾設定為可離線／鏡像，而不是 online-only。

**script 報 `no such file` 或讀到空檔** — 檔案被 Drive evict 成 online-only 了。在 Drive 偏好設定把 handover 資料夾設為鏡像（Mirror files）。

**索引怪怪的（列表少單、搜尋不到）** — 刪掉 `~/.cache/handover/index.db`，任何 script 下次執行會自動重建。索引永遠可拋棄。

**出現 `xxx (1).md` 衝突副本** — 兩台機器在同步完成前都動過同一檔（通常是同時 mark 同一張單）。兩張都會被索引；`cat` 比較後留一張、刪一張即可。

**`sqlite3` 或 `python3` 找不到** — 兩者皆 macOS 內建；若用了自訂 PATH 的精簡 shell，確認 `/usr/bin` 在 PATH 中。無須安裝任何第三方套件（不需要 PyYAML——frontmatter 是手寫解析）。

**git 指令在這個資料夾報錯（其他機器上）** — `.git` 指標檔指向的路徑在這台機器不存在。scripts 不受影響；要在這台機器啟用版本紀錄，見 README「Git 版本紀錄」一節。
