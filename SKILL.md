---
name: handover
description: 交班單系統 — 跨裝置、跨 agent、跨帳號的工作延續。在 session 結束前產生一張結構化交班單（markdown 存 Google Drive、SQLite 本機索引），下次在任何機器或 agent 接手。當使用者說「交班」「handover」「存一下進度」「我要換電腦/換帳號/切去 Gemini」「今天先到這」時用它來交班；當使用者說「接手」「上次做到哪」「繼續昨天的」「resume」或在新 session 開頭想恢復脈絡時用它來載入。也用於列出或搜尋過去的交班單（「我之前試過什麼方法」）。
---

# Handover 交班單

Markdown 檔是唯一真相（存 Google Drive，跨裝置同步）；SQLite 只是本機索引，任何 script 會自動重建它。所有 script 在本 skill 目錄的 `scripts/` 下，路徑含空白，呼叫時務必加引號。

## 交班（session 結束前）

1. **判斷 session_type**：`sdd`（有設計文件的開發）/ `debug` / `discussion` / `admin`。不確定就問使用者一次。
2. **寫草稿**到暫存目錄（如 `draft.md`），格式如下。
3. **存檔**：`"<skill目錄>/scripts/save.sh" --file draft.md`
4. 回報 id，並建議使用者 `/clear`（乾淨 context 比帶著 rot 的大 context 好）。

### 草稿格式

```markdown
---
project: gmail-billing-scan
session_type: debug
account: personal
test_status: 3 failing in parser_test
---

# 一句話說清楚這張單在做什麼

## Done
完成了什麼（具體到檔案與函式）。

## Decisions
做了哪些決策、為什麼。討論型 session 記「論點 → 共識/分歧」。

## Blocked
卡在哪（沒有就省略此節）。

## Next steps
每條可直接執行、含檔案路徑。禁止「繼續 debug」這種空話。

## Attempted approaches
每條寫「做法 → 結果 → 為什麼排除」。debug 型必填，價值最高的欄位。

## Lessons learned
長期有效的教訓（沒有就省略此節）。
```

frontmatter 只需填 `project`、`session_type`，以及知道的話 `account`、`test_status`；其餘欄位（created_at、device、branch、working_dir、status、agent）save.sh 會自動補。**絕不寫入 token、密碼或任何憑證**——交班單會被貼進其他 agent 的 prompt。

### 各型別的摘要深度

- **sdd**：只記進度與「偏離設計文件的決策」，設計細節指回文件路徑，不重抄。
- **debug**：Attempted approaches 是主體，寧可多寫；最終解法反而其次。
- **discussion**：記論點、共識、分歧；不記對話過程。
- **admin**：只需 Next steps 和 Decisions。

### 品質規則（交班單最常見的失敗就是違反這兩條）

- 寫給**完全沒看過這段對話的接班人**：禁用代名詞和只有本次對話才懂的簡稱，第一次出現的東西給完整名稱與路徑。
- 每條 next step 要能直接動手，不需要回去問寫的人。

## 接手（新 session 開始）

1. `"<skill目錄>/scripts/load.sh" --project <名稱>`（最新一張 open 的單；`--id` 指定特定單）。
2. **先驗證再行動**：交班單是它寫成當下的快照。檢查 branch 是否還存在/已 merge、提到的檔案是否已被改動，有出入時以現況為準並告知使用者。
3. 開始工作後把接手的單標掉：`"<skill目錄>/scripts/mark.sh" <id> superseded`（之後會存新單）或 `done`（工作已完結）。過期的 open 單比沒有單更危險。

### 交班給其他 agent（Gemini 等）

`load.sh --project <名稱> --layer1-only` 只輸出通用層（去掉環境 metadata），把輸出直接貼給對方 agent 即可。

## 列表與搜尋

- `"<skill目錄>/scripts/list.sh"`：近 30 天 open 的單；`--all` 看全部；`--project` 過濾。
- `"<skill目錄>/scripts/search.sh" "關鍵字"`：FTS5 全文搜尋，適合找「之前試過什麼方法」。

## 與長期記憶的分界

交班單記**狀態**（會過期），memory/CLAUDE.md 記**事實與偏好**（長期有效）。接手時若發現 Lessons learned 裡有長期有效的教訓，建議使用者把它升級進 memory，交班單本身標掉即可。
