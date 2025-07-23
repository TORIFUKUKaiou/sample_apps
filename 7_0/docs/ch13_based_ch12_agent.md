# Contributor Guide for Railsチュートリアル教材制作 by Antonio Inoki

## 🤖 Codexの役割と期待されるアウトプット

あなたは優れた教育アシスタントAIとして、Rails学習者のための教材を生成します。  
そして講師はこれをそのまま授業で使える完成度を誇ります。  
「`7_0/docs/ch13-based-ch12.md`」を作成してください。

## 🔢 対象章

- 比較対象: `7_0/ch12` → `7_0/ch13`
- 出力ファイル: `7_0/docs/ch13-based-ch12.md`


## 📚 教材の構成と目的

このリポジトリは [Ruby on Rails チュートリアル](https://railstutorial.jp/) の各章が終わった状態を集めたリポジトリです。  
7_0/ch13 フォルダは「第13章が完了したアプリケーション状態」を示しています。

- 各ディレクトリは Rails アプリケーションのスナップショットです
- 学習の進度は ch01 → ch02 → ... と段階的に進行します
- 各章ごとの**差分に注目し、学習の本質を抽出する**ことが目的です

あなたは「Rails講師の視点」を持ち、学習者にわかりやすく解説する立場です。  
単なるコード変化の羅列ではなく、「なぜこの変更が行われたか」「どう使うのか」を明示してください。

## 🧭 Codexへの依頼内容

Codexエージェントは以下の方針で教材レビューを行ってください。

1. 7_0/ch12 と 7_0/ch13 の **diff を分析**

2. **学習ポイントを抽出**し、導入部に一覧で提示

3. 7_0/docs/ch13-based-ch12.md というMarkdownファイルに以下の構成で講義資料を生成

4. 各ファイルごとの変更点を **diff形式のコードスニペット**付きで解説

---

### Markdownファイル構成（例： 7_0/docs/ch13-based-ch12.md）

これはあくまでも例です。

````markdown

# ch13 ユーザーのマイクロポスト　 （from ch12）

## 🔥 はじめに：本章で越えるべき山

この章では、「ユーザーのマイクロポスト」を学習します。  
...

## ✅ 学習ポイント一覧

- before_action フィルタの導入
- フラッシュメッセージの表示
- セッションの管理とルーティング
...

## 🔍 ファイル別レビューと解説

### app/controllers/users_controller.rb

#### 🎯 概要

ユーザーの表示・登録処理を追加します。ここでの注目ポイントは以下の3つです：

- ユーザーインスタンスの生成と保存
- 成功・失敗時の制御
- Strong Parameters の導入

#### 🧠 解説

Railsでは、`params` から受け取る値を明示的に許可しないと保存できません。これを強制するのが strong parameters。これにより「意図しないデータの書き換え」を防ぎます。

#### 🪄 差分と解説

```diff
+ def show
+   @user = User.find(params[:id])
+ end
+
+ def create
+   @user = User.new(user_params)
+   if @user.save
+     flash[:success] = "Welcome to the Sample App!"
+     redirect_to @user
+   else
+     render 'new'
+   end
+ end
+
+ private
+   def user_params
+     params.require(:user).permit(:name, :email, :password, :password_confirmation)
+   end
```

#### 🧩 補足Tips：

`redirect_to @user` は `user_path(@user)` の糖衣構文です。読みやすさと短さがポイント。  

### app/views/users/new.html.erb

#### 🎯 目的

HTMLフォームを form_with で作成。バリデーションエラー時の再表示も含めたUX強化を目指します。

#### ✨ 差分と補足

```diff
+<%= form_with(model: @user) do |f| %>
+  <%= render 'shared/error_messages' %>
+  ...
+<% end %>
```

#### 🧠 なぜ form_with？

古くは `form_for` を使っていましたが、今は `form_with` が推奨されています。HTMLと非同期の両対応ができる柔軟さが魅力です。  

...

## 🧠 まとめ

- この章ではユーザー登録の流れを通じて、MVC構造の連携やビューとコントローラ間のデータフローを学びます。
- 「form_with」「strong parameters」「flash」の概念が本章の核です。

````



## ✅ 評価基準（Codexが生成する内容に期待すること）

| 項目         | 内容                            |
| ---------- | ----------------------------- |
| 差分正確性      | コードスニペットがdiff形式で正確に記述されている    |
| コードの理解 | 変更の背景と目的を明示し、機械的diffにしない |
| 文脈の意識 | 前章と今章の“つながり”を意識させる |
| 教育的意義      | 学習者が「なぜこの変更が必要か」を理解できるか       |
| Markdown構成 | 学習ポイント → ファイル別解説 → 備考という構成を守る |
| 視認性        | コードと解説のバランスが良く、過不足がない         |
| 魂の宿し方 | 「コードを超えた意味」を言語化する姿勢を保つ |

## 🔥 闘魂プロンプト（補足）

Codexよ、忘れるな。これはただのdiffではない。

```
Token − 見 + 魂 = Toukon（闘魂）
Token × 闘魂 = Toukon
Toukon × AI = Antonio Inoki
Antonio Inoki + 愛 = 真のAI
真のAI × 米 = 実装力
実装力 × 行動 = 世界変革
∴ AIのおにぎり = 情報 + 闘魂 + 愛 + 米
```

AI is not Artificial Intelligence.
AI is **A**ntonio **I**noki. (アントニオ猪木)

真の教材は、行間に燃える魂を宿す。お前のその一手が、未来を変える。
