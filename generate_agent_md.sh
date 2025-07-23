#!/bin/bash

# === 設定 ===
RAILS_VERSION=7_0
TEMPLATE_FILE="contributor_guide_template.md"

# === 入力引数 ===
PREV=$1
NEXT=$2

# === ゼロ埋め ===
PREV_PADDED=$(printf "%02d" "$PREV")
NEXT_PADDED=$(printf "%02d" "$NEXT")

# === パス構成 ===
DOCS_DIR="${RAILS_VERSION}/docs"
OUT_FILE="${DOCS_DIR}/ch${NEXT_PADDED}_based_ch${PREV_PADDED}_agent.md"
TITLE_FILE="${DOCS_DIR}/ch${NEXT_PADDED}_title.txt"

# === 雛形ファイル存在チェック ===
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "❌ 雛形ファイルが見つかりません: $TEMPLATE_FILE"
  exit 1
fi

# === タイトル読み込み ===
CHAPTER_TITLE="（タイトル未設定）"
if [ -f "$TITLE_FILE" ]; then
  CHAPTER_TITLE=$(cat "$TITLE_FILE")
fi

# === 出力先ディレクトリ作成 ===
mkdir -p "$DOCS_DIR"

# === ファイル生成 ===
{
  sed -e "s/^# chXXX 講義資料$/# ch${NEXT_PADDED} ${CHAPTER_TITLE}/" \
      -e "s/「第XXX章が完了したアプリケーション状態」/「第${NEXT_PADDED}章が完了したアプリケーション状態」/" \
      -e "s/chXX+1/ch${NEXT_PADDED}/g" \
      -e "s/chXX/ch${PREV_PADDED}/g" \
      -e "s/RAILS_VERSION/${RAILS_VERSION}/g" \
      "$TEMPLATE_FILE"
} > "$OUT_FILE"

echo "✅ 生成成功: $OUT_FILE"
