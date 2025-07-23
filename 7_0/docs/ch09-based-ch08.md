# ch09 発展的なログイン機構（from ch08）

## 🔥 はじめに：本章で越えるべき山

この章では「Remember me」機能を追加し、ブラウザを閉じてもログイン状態を保持できるようにします。ログイン周りのコードを整理しつつ、cookie を活用した永続的セッションを実装していきましょう。

**前章との違い**：
- **ch08**: セッション（ブラウザを閉じると消える一時的ログイン）
- **ch09**: クッキー（ブラウザを閉じても残る永続的ログイン）

**学習の核心**：セキュリティを保ちながら、ユーザーの利便性を向上させる実装方法を習得します。

## ✅ 学習ポイント一覧

- **永続的セッション (remember me)** の仕組みと実装
- `SessionsHelper` によるログイン状態の管理強化
- モデルにトークン生成メソッドを追加
- ログインフォームのチェックボックス実装とCSS調整
- **セキュリティ強化**：ダイジェスト化による安全なトークン保存
- テストコードの拡充（ヘルパー・統合テスト）

## 🔧 実装の全体像

```
[一時的セッション（ch08）]              [永続的セッション（ch09）]
session[:user_id] にユーザーID保存        cookies にトークンペア保存
         ↓                                      ↓
ブラウザを閉じると消える                  ブラウザを閉じても残る
         ↓                                      ↓
    毎回ログインが必要                    Remember me で自動ログイン

[セキュリティの仕組み]
1. ランダムトークン生成（remember_token）
2. トークンをハッシュ化（remember_digest）
3. ハッシュ化されたものだけをDBに保存
4. クッキーには元のトークンを保存
5. ログイン時にトークンとハッシュを照合
```

## 🔍 ファイル別レビューと解説

### app/assets/stylesheets/custom.scss

#### 🎯 概要
ログイン画面にチェックボックスを追加したため、見た目を整えるスタイルを定義しています。チェックボックスの位置調整と、ラベルテキストのスタイリングを行います。

#### 🧠 解説
**CSSの工夫点**：
- `.checkbox` でチェックボックス全体のマージンを調整
- `span` 要素でラベルテキストの位置とフォントウェイトを調整
- `#session_remember_me` で特定のチェックボックスの幅と左マージンを個別に調整
- フォーム全体のレイアウトバランスを保つための細かな調整

```diff
@@ -195,6 +195,20 @@ input {
   }
 }

+.checkbox {
+  margin-top: -10px;
+  margin-bottom: 10px;
+  span {
+    margin-left: 20px;
+    font-weight: normal;
+  }
+}
+
+#session_remember_me {
+  width: auto;
+  margin-left: 0;
+}
```

### app/controllers/sessions_controller.rb

#### 🎯 概要
SessionsControllerにRemember me機能を追加し、ログアウト処理の安全性も向上させました。パラメータに応じてクッキーの保存・削除を制御します。

#### 🧠 解説
`remember_me` パラメータに応じて Cookie を操作する処理を追加しました。また、ログアウト時にはログイン状態にあるかを確認します。

**セキュリティ改善点**：
- **チェックボックスの値判定**: `params[:session][:remember_me] == '1'` でユーザーの選択を判断
- **条件分岐**: チェックされた場合は `remember(user)`、そうでなければ `forget(user)` を実行
- **安全なログアウト**: `log_out if logged_in?` でログイン状態を確認してからログアウト処理を実行

**処理の流れ**：
1. ユーザーがログインフォームを送信
2. 認証が成功した場合
3. Remember meがチェックされているかを確認
4. チェックあり → クッキーに永続的トークンを保存
5. チェックなし → 既存のクッキーを削除（前回のremember meを無効化）

```diff
@@
-      reset_session      # ログインの直前に必ずこれを書くこと
+      reset_session
+      params[:session][:remember_me] == '1' ? remember(user) : forget(user)
       log_in user
@@
-    log_out
+    log_out if logged_in?
```

### app/helpers/sessions_helper.rb

#### 🎯 概要
SessionsHelperを大幅に拡張し、一時的セッションと永続的セッションの両方を管理できるようになりました。セキュリティを保ちながらユーザーの利便性を向上させます。

#### 🧠 解説
ログイン中のユーザー取得処理を拡張し、remember me 用のトークン保存・削除メソッドを定義しました。

**重要な技術概念**：

1. **`remember(user)` メソッド**：
   - ユーザーモデルの `remember` メソッドを呼び出してトークンを生成・保存
   - `cookies.permanent.encrypted[:user_id]` で暗号化されたユーザーIDを永続保存
   - `cookies.permanent[:remember_token]` で remember_token を永続保存

2. **`current_user` メソッドの高度化**：
   - **第1段階**: セッションからユーザーIDを取得（一時的ログイン）
   - **第2段階**: クッキーからユーザーIDを取得（永続的ログイン）
   - **セキュリティチェック**: `user.authenticated?` でトークンの正当性を検証
   - **自動ログイン**: 検証成功時に `log_in user` でセッションも設定

3. **`forget(user)` & `log_out` メソッド**：
   - モデルとクッキーの両方からトークン情報を削除
   - 完全なログアウト状態を実現

**セキュリティ強化のポイント**：
- クッキーのユーザーIDは暗号化して保存
- remember_token は平文のまま（照合のため）
- データベースには remember_token のハッシュ値のみ保存
- トークンが一致しない場合は自動的にログアウト

```diff
@@
-  # 現在ログイン中のユーザーを返す（いる場合）
+  # 永続的セッションのためにユーザーをデータベースに記憶する
+  def remember(user)
+    user.remember
+    cookies.permanent.encrypted[:user_id] = user.id
+    cookies.permanent[:remember_token] = user.remember_token
+  end
+
+  # 記憶トークンcookieに対応するユーザーを返す
   def current_user
-    if session[:user_id]
-      @current_user ||= User.find_by(id: session[:user_id])
+    if (user_id = session[:user_id])
+      @current_user ||= User.find_by(id: user_id)
+    elsif (user_id = cookies.encrypted[:user_id])
+      user = User.find_by(id: user_id)
+      if user && user.authenticated?(cookies[:remember_token])
+        log_in user
+        @current_user = user
+      end
     end
   end
@@
-  def log_out
-    reset_session
-    @current_user = nil   # 安全のため
+  def forget(user)
+    user.forget
+    cookies.delete(:user_id)
+    cookies.delete(:remember_token)
+  end
+
+  def log_out
+    forget(current_user)
+    reset_session
+    @current_user = nil
   end
```

### app/models/user.rb

#### 🎯 概要
Userモデルに remember me 機能の核となるメソッド群を追加しました。セキュアなトークン生成・検証・削除の仕組みを実装します。

#### 🧠 解説
ユーザーモデルに記憶トークンの生成・検証用メソッドを追加しました。`remember_token` は仮想属性として扱います。

**実装のポイント**：

1. **`attr_accessor :remember_token`**：
   - データベースには保存されない仮想属性
   - メモリ上でのみ存在し、セキュリティを向上させる

2. **`User.new_token`**：
   - `SecureRandom.urlsafe_base64` で暗号学的に安全なランダム文字列を生成
   - URLセーフな文字のみを使用（Base64エンコーディング）

3. **`remember` メソッド**：
   - 新しいトークンを生成して仮想属性に設定
   - トークンをハッシュ化してデータベースに保存
   - `update_attribute` でバリデーションをスキップして直接更新

4. **`authenticated?` メソッド**：
   - `return false if remember_digest.nil?` でnilガード（セキュリティ対策）
   - BCryptを使って平文トークンとハッシュ値を照合
   - `is_password?` メソッドで安全な比較を実行

5. **`forget` メソッド**：
   - データベースの remember_digest を nil にクリア
   - ログアウト時の完全なクリーンアップを実現

**セキュリティ設計**：
```
[クライアント側]              [サーバー側]
remember_token（平文）   ←→   remember_digest（ハッシュ値）
```

```diff
@@
-class User < ApplicationRecord
+class User < ApplicationRecord
+  attr_accessor :remember_token
@@
   def User.digest(string)
@@
   end
+
+  # ランダムなトークンを返す
+  def User.new_token
+    SecureRandom.urlsafe_base64
+  end
+
+  # 永続的セッションのためにユーザーをデータベースに記憶する
+  def remember
+    self.remember_token = User.new_token
+    update_attribute(:remember_digest, User.digest(remember_token))
+  end
+
+  # 渡されたトークンがダイジェストと一致したら true を返す
+  def authenticated?(remember_token)
+    return false if remember_digest.nil?
+    BCrypt::Password.new(remember_digest).is_password?(remember_token)
+  end
+
+  # ユーザーのログイン情報を破棄する
+  def forget
+    update_attribute(:remember_digest, nil)
+  end
 end
```

### app/views/sessions/new.html.erb

#### 🎯 概要
ログインフォームにRemember meチェックボックスを追加し、ユーザーが永続的ログインを選択できるようにしました。

#### 🧠 解説
フォームに「Remember me」チェックボックスを追加しました。

**UIデザインのポイント**：
- **`class: "checkbox inline"`**: Bootstrapのスタイルクラスを適用
- **`f.check_box :remember_me`**: フォームビルダーでチェックボックスを生成
- **`<span>Remember me on this computer</span>`**: ユーザーフレンドリーなラベルテキスト
- パスワードフィールドの直後に配置して自然なフロー

**フォームデータの送信**：
- チェックされた場合: `params[:session][:remember_me] = "1"`
- チェックされていない場合: `params[:session][:remember_me] = "0"`

```diff
@@
-      <%= f.password_field :password, class: 'form-control' %>
+      <%= f.password_field :password, class: 'form-control' %>
+
+      <%= f.label :remember_me, class: "checkbox inline" do %>
+        <%= f.check_box :remember_me %>
+        <span>Remember me on this computer</span>
+      <% end %>
```

### db/migrate/20231218011905_add_remember_digest_to_users.rb

#### 🎯 概要
remember_token のハッシュ値を保存するためのデータベーススキーマ変更です。セキュリティを考慮したデータ構造を実現します。

#### 🧠 解説
Rememberトークンのハッシュ値を保存するカラムを追加するマイグレーションです。

**設計思想**：
- **remember_digest**: ハッシュ化されたトークンのみをデータベースに保存
- **string型**: 可変長文字列でBCryptハッシュを格納
- 平文のトークンは決してデータベースに保存されない（セキュリティの原則）

**なぜハッシュ化が必要か**：
- データベースが漏洩してもトークンの復元は不可能
- BCryptの一方向ハッシュ関数による堅牢な暗号化
- レインボーテーブル攻撃に対する耐性

```ruby
class AddRememberDigestToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :remember_digest, :string
  end
end
```

### db/schema.rb

#### 🎯 概要
マイグレーション実行後のデータベーススキーマです。usersテーブルにremember_digest列が追加されたことを確認できます。

#### 🧠 解説
マイグレーション実行後のスキーマでは `remember_digest` カラムが追加されています。

**スキーマの更新内容**：
- **version更新**: `2023_12_13_085943` → `2023_12_18_011905`
- **新規カラム**: `t.string "remember_digest"` を追加
- これによりユーザーごとに独立したremember_tokenの管理が可能

```diff
-ActiveRecord::Schema[7.0].define(version: 2023_12_13_085943) do
+ActiveRecord::Schema[7.0].define(version: 2023_12_18_011905) do
@@
     t.string "password_digest"
+    t.string "remember_digest"
```

### test/helpers/sessions_helper_test.rb

#### 🎯 概要
SessionsHelperの新機能をテストする専用テストファイルです。特にcurrent_userメソッドの様々なシナリオを検証します。

#### 🧠 解説
`current_user` の動作を検証するテストを新規作成しました。

**テストシナリオ**：

1. **正常系テスト**: 
   - セッションがnilでもcookieから正しくユーザーを取得
   - ログイン状態が適切に設定されることを確認

2. **セキュリティテスト**:
   - remember_digestが改ざんされた場合
   - current_userがnilを返すことを確認（不正アクセスの防止）

**テストの重要性**：
- remember me機能の核となるロジックの動作保証
- セキュリティ侵害のシミュレーション
- 将来のコード変更時の回帰テスト防止

```diff
+require "test_helper"
+
+class SessionsHelperTest < ActionView::TestCase
+  def setup
+    @user = users(:michael)
+    remember(@user)
+  end
+
+  test "current_user returns right user when session is nil" do
+    assert_equal @user, current_user
+    assert is_logged_in?
+  end
+
+  test "current_user returns nil when remember digest is wrong" do
+    @user.update_attribute(:remember_digest, User.digest(User.new_token))
+    assert_nil current_user
+  end
+end
```

### test/integration/users_login_test.rb

#### 🎯 概要
Remember me機能の統合テストを追加し、ユーザーの実際の操作フローを網羅的に検証します。

#### 🧠 解説
Remember me 機能に関する統合テストを追加しました。ログアウトの二重実行にも対応しています。

**テストケース詳細**：

1. **二重ログアウト対応**:
   - 複数のブラウザタブを想定したテスト
   - 一方でログアウト後、他方でログアウトを試行
   - エラーが発生しないことを確認

2. **Remember me有効時のテスト**:
   - チェックボックスをONにしてログイン
   - cookieにremember_tokenが保存されることを確認

3. **Remember me無効時のテスト**:
   - 一度remember me有効でログイン（cookieに保存）
   - その後remember me無効でログイン
   - 既存のcookieが削除されることを確認

**実用的なシナリオ**：
- 家のPCではremember me有効
- 職場のPCではremember me無効
- セキュリティレベルに応じた使い分け

```diff
@@
     assert_not is_logged_in?
     assert_response :see_other
     assert_redirected_to root_url
+    # 2番目のウィンドウでログアウトをクリックするユーザーをシミュレートする
+    delete logout_path
@@
   test "login with remembering" do
     log_in_as(@user, remember_me: '1')
     assert_not cookies[:remember_token].blank?
   end

   test "login without remembering" do
     # Cookieを保存してログイン
     log_in_as(@user, remember_me: '1')
     # Cookieが削除されていることを検証してからログイン
     log_in_as(@user, remember_me: '0')
     assert cookies[:remember_token].blank?
   end
```

### test/models/user_test.rb

#### 🎯 概要
Userモデルのauthenticated?メソッドの安全性をテストします。特にnil値に対する適切な処理を検証します。

#### 🧠 解説
`authenticated?` メソッドが `nil` を扱えるか確認するテストを追記しました。

**テストの目的**：
- **nilガードテスト**: remember_digestがnilの場合の安全な処理
- **セキュリティテスト**: 不正な状態でのメソッド呼び出しに対する堅牢性
- **回帰テスト**: 将来のコード変更でnilエラーが発生しないことを保証

**なぜこのテストが重要か**：
- ユーザーがログアウト後にcookieが残っている場合
- remember_digestが削除されているがcookieは残存している状況
- このような状況で`authenticated?`がエラーを起こさないことを保証

```diff
@@
   test "password should have a minimum length" do
     @user.password = @user.password_confirmation = "a" * 5
     assert_not @user.valid?
   end
+
+  test "authenticated? should return false for a user with nil digest" do
+    assert_not @user.authenticated?('')
+  end
 end
```

### test/test_helper.rb

#### 🎯 概要
テスト全体で使用するヘルパーメソッドを拡張し、コントローラテストと統合テストの両方でログイン機能をサポートします。

#### 🧠 解説
テスト環境用のログインヘルパーを拡張し、統合テストからも利用できるようにしました。

**ヘルパーメソッドの設計**：

1. **`ActionView::TestCase` 用のlog_in_as**:
   - コントローラテストやヘルパーテストで使用
   - セッションに直接ユーザーIDを設定
   - 高速で軽量なテスト実行

2. **`ActionDispatch::IntegrationTest` 用のlog_in_as**:
   - 統合テストで使用
   - 実際のHTTPリクエストを送信してログイン
   - ブラウザの動作を完全にシミュレート
   - remember_meパラメータの指定が可能

**テストの効率化**：
- DRY原則に従ったヘルパーメソッドの共通化
- テストケースごとの重複コード削減
- remember_me機能の様々なパターンを簡単にテスト

```diff
@@
-  # test/fixtures/*.ymlにあるすべてのfixtureをセットアップする
+  # test/fixtures/*.ymlのfixtureをすべてセットアップする
@@
   def is_logged_in?
     !session[:user_id].nil?
   end
+
+  # テストユーザーとしてログインする
+  def log_in_as(user)
+    session[:user_id] = user.id
+  end
 end

 class ActionDispatch::IntegrationTest
@@
   def log_in_as(user, password: 'password', remember_me: '1')
     post login_path, params: { session: { email: user.email,
                                           password: password,
                                           remember_me: remember_me } }
   end
 end
```

## 💡 学習のコツ

### セッション vs クッキーの理解

**一時的セッション（ch08）**:
```ruby
# サーバー側メモリに保存
session[:user_id] = user.id

# 特徴:
# - ブラウザを閉じると消える
# - サーバー再起動で消える  
# - セキュリティが高い
# - 毎回ログインが必要
```

**永続的セッション（ch09）**:
```ruby
# ブラウザのクッキーに保存
cookies.permanent[:remember_token] = user.remember_token

# 特徴:
# - ブラウザを閉じても残る
# - 期限まで自動ログイン
# - 利便性が高い
# - セキュリティに注意が必要
```

### セキュリティ設計のポイント

1. **トークンの分離**:
   - クライアント側: 平文トークン（remember_token）
   - サーバー側: ハッシュ値（remember_digest）
   - データベース漏洩時でもトークンは安全

2. **暗号化の多層防御**:
   - `cookies.permanent.encrypted[:user_id]`: ユーザーIDの暗号化
   - `User.digest(remember_token)`: トークンのハッシュ化
   - `BCrypt::Password.new`: 安全な比較処理

3. **nilガード**:
   ```ruby
   return false if remember_digest.nil?
   ```
   - 予期しないnilエラーを防止
   - セキュリティホールの閉鎖

### テスト戦略の理解

**テストの階層構造**:
1. **単体テスト（User model）**: メソッド単体の動作確認
2. **ヘルパーテスト（SessionsHelper）**: ヘルパーメソッドの動作確認  
3. **統合テスト（Login flow）**: ユーザー操作フロー全体の確認

**Remember me特有のテスト項目**:
- チェックボックスON/OFFの動作
- クッキーの保存/削除
- 二重ログアウトの安全性
- 不正トークンに対する堅牢性

## 🧠 まとめ

本章では、remember me機能の実装を通じて以下の重要な概念を習得しました。

### 📚 習得した技術概念

**永続的セッション管理**:
- クッキーを使った長期ログイン状態の維持
- セキュリティと利便性のバランス
- トークンベース認証の実装

**セキュリティ強化**:
- ハッシュ化による安全なトークン保存
- 暗号化されたクッキーの使用
- 多層防御によるセキュリティ設計

**テスト駆動開発**:
- 複雑な機能の包括的テストカバレッジ
- セキュリティテストの重要性
- ヘルパーメソッドによるテスト効率化

### 🔐 セキュリティベストプラクティス

1. **データの分離**: 平文とハッシュ値を適切に分離
2. **暗号化**: クライアント側データの暗号化
3. **nilガード**: 予期しない状況への対処
4. **トークン更新**: ログアウト時の完全クリーンアップ

### 🚀 次のステップ

これらの基盤技術により、より高度なユーザー管理機能を実装する準備が整いました：

- **ユーザー一覧・詳細ページ**
- **ユーザープロフィール編集**
- **管理者権限とアクセス制御**
- **パスワードリセット機能**

Remember me機能の実装により、現代的なWebアプリケーションに必須のユーザー体験を提供できるようになりました。セキュリティを維持しながら利便性を向上させる技術は、プロフェッショナルなWeb開発において非常に重要なスキルとなります。

