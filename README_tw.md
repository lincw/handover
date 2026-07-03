# Handover 交班單系統

跨裝置、跨 agent、跨帳號的工作延續工具，做成一個 Claude Code skill。

核心設計：**markdown 為真、SQLite 為索引**。交班單是一張一個的 `.md` 檔（本資料夾由 Google Drive 同步到所有裝置）；SQLite FTS5 索引放在本機 `~/.cache/handover/index.db`，可隨時從 md 檔重建，刻意不進 Drive——二進位資料庫走雲端同步有損毀風險，而索引丟了毫無損失。

## 結構

```
handover/
├── SKILL.md          # Claude Code skill 本體（觸發與工作流指示）
├── README.md
├── docs/
│   ├── usage.md      # 詳細使用說明：工作流、指令參考、格式規格、疑難排解
│   └── design.md     # 設計理念與取捨
├── handovers/        # 交班單（一張一個 .md，唯一真相）
└── scripts/
    ├── save.sh       # 存一張交班單（從草稿檔）
    ├── load.sh       # 載入交班單（--layer1-only 給跨 agent 用）
    ├── list.sh       # 列出交班單
    ├── search.sh     # FTS5 全文搜尋
    ├── mark.sh       # 改狀態 open/done/superseded
    └── reindex.py    # 從 md 重建索引（各 script 自動呼叫）
```

## 快速開始

```bash
# 交班（Claude 通常代勞：寫好草稿後呼叫）
scripts/save.sh --file draft.md

# 接手
scripts/load.sh --project gmail-billing-scan

# 交班給其他 agent（只輸出通用層）
scripts/load.sh --project gmail-billing-scan --layer1-only

# 列表與搜尋
scripts/list.sh
scripts/search.sh "parser"
```

完整說明見 [docs/usage.md](docs/usage.md)。

## 新裝置設定

1. 裝好 Google Drive 桌面版，等本資料夾同步下來，並在 Drive 偏好設定把它設為**可離線／鏡像**（避免檔案被 evict 成 online-only）。
2. 把 skill 連進 Claude Code：

```bash
ln -s "$HOME/Library/CloudStorage/GoogleDrive-<your-email>/My Drive/handover" \
      "$HOME/.claude/skills/handover"
```

3. （可選）本機 git 版本紀錄，見下節。

## Git 版本紀錄

本資料夾是一個 git 工作樹，但 git 目錄放在 Drive 之外的 `~/Git_repo/handover.git`（`.git` 只是一個指標檔），因為 `.git` 裡成千上萬個小物件檔不適合走雲端同步。

git 在這裡的角色是**本機版本歷史／誤刪救援**，不是同步機制——同步始終由 Google Drive 負責。因此每台機器的 git 歷史是各自獨立的。在其他機器上若也要版本紀錄：

```bash
cd "$HOME/Library/CloudStorage/GoogleDrive-<your-email>/My Drive/handover"
rm .git   # 移除指向別台機器路徑的指標檔（會經 Drive 同步回來，屬預期）
git init --separate-git-dir "$HOME/Git_repo/handover.git"
git add -A && git commit -m "init on this machine"
```

注意 `.git` 指標檔會被 Drive 同步：它指向 `/Users/<你>/Git_repo/handover.git`，只要各機器使用者名稱與路徑相同就都能用；路徑不存在的機器上 git 指令會報錯，但 scripts 完全不受影響。

## 注意事項

- 交班單會被貼進其他 agent 的 prompt：**永遠不要在單裡寫 token、密碼、憑證**。
- Drive 同步有延遲：換裝置後先確認 Drive 圖示顯示同步完成再 `load`，否則讀到的是舊單。
- 出現 Drive 衝突副本（`xxx (1).md`）時兩張都會被索引，人工挑一張留下即可——每單一檔的設計讓衝突永遠只影響單一張單。

## License

[MIT](LICENSE)
