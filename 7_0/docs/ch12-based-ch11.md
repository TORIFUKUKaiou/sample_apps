# ch12 パスワードの再設定 (from ch11)

## 🔥 はじめに：本章で越えるべき山

この章では、ユーザーが忘れたパスワードを安全に再設定する機能を実装します。
以下では第11章から第12章への差分をもとに、学習のポイントを整理します。

**本章の重要性**：
- **セキュリティ**：安全なトークンベース認証システムの構築
- **ユーザビリティ**：忘れがちなパスワードの救済手段を提供
- **実用性**：現代のWebアプリケーションに必須の機能
- **アーキテクチャ**：時間制限付きトークンシステムの設計

## ✅ 学習ポイント一覧

- **パスワード再設定リソース `PasswordResets`** の追加
- **`User`モデル**に再設定トークン関連の属性とメソッドを実装
- **失効期限付きメール送信処理**とセキュリティ対策
- **ルーティング・コントローラ・ビューの連携**
- **パスワード再設定に関する統合テスト**

## 🔧 実装の全体像

```
[パスワード再設定フロー]

1. ユーザーがメールアドレスを入力
   ↓
2. システムがリセットトークンを生成・保存
   ↓  
3. 期限付きリンクをメール送信
   ↓
4. ユーザーがメール内のリンクをクリック
   ↓
5. トークンの有効性を検証
   ├─ 有効 → 新パスワード入力フォーム表示
   └─ 無効 → エラーメッセージ表示
   ↓
6. 新しいパスワードを設定・保存
   ↓
7. 自動ログイン・リダイレクト

[セキュリティの仕組み]
- ランダムトークン生成（reset_token）
- トークンのハッシュ化（reset_digest）
- 時間制限（2時間で失効）
- ワンタイム使用（使用後は無効化）
```

## 🔍 ファイル別レビューと解説

### app/controllers/password_resets_controller.rb

#### 🎯 概要
パスワード再設定を扱う新規コントローラです。トークン生成からメール送信、有効性のチェックまで担当します。

#### 🧠 解説
パスワード再設定の全フローを管理する専用コントローラーです。3つの`before_action`フィルタによりセキュリティを多層化しています。

**セキュリティ設計のポイント**：

1. **`get_user`**: パラメータからユーザーを取得
2. **`valid_user`**: ユーザーの有効性・トークンの正当性を確認  
3. **`check_expiration`**: トークンの期限切れをチェック

**各アクションの詳細**：

- **`new`**: メールアドレス入力フォームを表示
- **`create`**: 
  - メールアドレスでユーザー検索
  - 見つかった場合：リセットトークン生成→メール送信
  - 見つからない場合：エラーメッセージ表示
- **`edit`**: 新パスワード入力フォームを表示（トークン検証済み）
- **`update`**:
  - 空パスワードのバリデーション
  - パスワード更新処理
  - 成功時：自動ログイン→プロフィールページ

**エラーハンドリングの工夫**：
- **（1）期限切れ対応**: `check_expiration`で2時間制限を実施
- **（2）バリデーション失敗**: 編集フォームを再表示
- **（3）空パスワード対応**: has_secure_passwordでは検証されないため独自チェック
- **（4）正常更新**: セッションリセット後にログイン

```diff
@@
+class PasswordResetsController < ApplicationController
+  before_action :get_user,         only: [:edit, :update]
+  before_action :valid_user,       only: [:edit, :update]
+  before_action :check_expiration, only: [:edit, :update]    # （1）への対応
+
+  def new
+  end
+
+  def create
+    @user = User.find_by(email: params[:password_reset][:email].downcase)
+    if @user
+      @user.create_reset_digest
+      @user.send_password_reset_email
+      flash[:info] = "Email sent with password reset instructions"
+      redirect_to root_url
+    else
+      flash.now[:danger] = "Email address not found"
+      render 'new', status: :unprocessable_entity
+    end
+  end
+
+  def edit
+  end
+
+  def update
+    if params[:user][:password].empty?                  # （3）への対応
+      @user.errors.add(:password, "can't be empty")
+      render 'edit', status: :unprocessable_entity
+    elsif @user.update(user_params)                     # （4）への対応
+      reset_session
+      log_in @user
+      flash[:success] = "Password has been reset."
+      redirect_to @user
+    else
+      render 'edit', status: :unprocessable_entity      # （2）への対応
+    end
+  end
+
+  private
+
+    def user_params
+      params.require(:user).permit(:password, :password_confirmation)
+    end
+
+    # beforeフィルタ
+
+    def get_user
+      @user = User.find_by(email: params[:email])
+    end
+
+    # 有効なユーザーかどうか確認する
+    def valid_user
+      unless (@user && @user.activated? &&
+              @user.authenticated?(:reset, params[:id]))
+        redirect_to root_url
+      end
+    end
+
+    # トークンが期限切れかどうか確認する
+    def check_expiration
+      if @user.password_reset_expired?
+        flash[:danger] = "Password reset has expired."
+        redirect_to new_password_reset_url
+      end
+    end
+end
```

### app/models/user.rb

#### 🎯 概要
パスワード再設定のための属性`reset_token`と関連メソッドが追加されました。トークンの生成・保存、メール送信、期限切れ判定を担います。

#### 🧠 解説
Userモデルにパスワード再設定機能の核となるメソッド群を追加しました。

**仮想属性の拡張**：
```ruby
attr_accessor :remember_token, :activation_token, :reset_token
```
- `reset_token`：メモリ上でのみ保持される平文トークン
- データベースには暗号化されたダイジェストのみ保存

**重要なメソッドの詳細**：

1. **`create_reset_digest`**：
   - 新しいリセットトークンを生成
   - ダイジェスト化してデータベースに保存
   - 送信時刻も記録（期限管理のため）

2. **`send_password_reset_email`**：
   - UserMailerを通じてリセットメールを送信
   - トークン生成と送信を分離（単一責任原則）

3. **`password_reset_expired?`**：
   - 送信から2時間経過で期限切れと判定
   - セキュリティとユーザビリティのバランス

**セキュリティ設計**：
- トークンとダイジェストの分離保存
- 時間制限による自動無効化
- ワンタイム使用の実現

```diff
@@
-class User < ApplicationRecord
-  attr_accessor :remember_token, :activation_token
+class User < ApplicationRecord
+  attr_accessor :remember_token, :activation_token, :reset_token
@@
   def send_activation_email
     UserMailer.account_activation(self).deliver_now
   end
+
+  # パスワード再設定の属性を設定する
+  def create_reset_digest
+    self.reset_token = User.new_token
+    update_attribute(:reset_digest,  User.digest(reset_token))
+    update_attribute(:reset_sent_at, Time.zone.now)
+  end
+
+  # パスワード再設定のメールを送信する
+  def send_password_reset_email
+    UserMailer.password_reset(self).deliver_now
+  end
+
+  # パスワード再設定の期限が切れている場合はtrueを返す
+  def password_reset_expired?
+    reset_sent_at < 2.hours.ago
+  end
```

### config/routes.rb

#### 🎯 概要
`password_resets`リソースを追加し、`new`, `create`, `edit`, `update`の各アクションを有効化しました。

#### 🧠 解説
RESTfulなパスワード再設定リソースを追加しました。

**ルーティング設計**：
- **`only: [:new, :create, :edit, :update]`**：必要なアクションのみを有効化
- **`show`と`destroy`は不要**：セキュリティとシンプルさを重視

**生成されるルート**：
```ruby
# GET    /password_resets/new     → password_resets#new
# POST   /password_resets         → password_resets#create  
# GET    /password_resets/:id/edit → password_resets#edit
# PATCH  /password_resets/:id     → password_resets#update
```

```diff
@@
   resources :users
   resources :account_activations, only: [:edit]
+  resources :password_resets,     only: [:new, :create, :edit, :update]
 end
```

### app/views/sessions/new.html.erb

#### 🎯 概要
ログインフォームに「Forgot password」リンクが追加され、再設定画面へ誘導します。

#### 🧠 解説
ログインフォームにパスワード再設定への導線を追加しました。

**UX設計のポイント**：
- **位置**: パスワードフィールドのラベル横に配置
- **表現**: `(forgot password)` で控えめながら目立つ表示
- **アクセシビリティ**: パスワード入力で困った時に自然に目に入る位置

**ユーザビリティ向上**：
- ログインに失敗したユーザーへの救済手段
- パスワードを思い出せない状況での適切な誘導
- 直感的でわかりやすいリンク配置

```diff
@@
-      <%= f.label :password %>
-      <%= f.password_field :password, class: 'form-control' %>
+      <%= f.label :password %>
+      <%= link_to "(forgot password)", new_password_reset_path %>
+      <%= f.password_field :password, class: 'form-control' %>
```

### app/mailers/user_mailer.rb

#### 🎯 概要
再設定メール送信用メソッドにユーザーを受け取り、件名を設定しました。

#### 🧠 解説
パスワード再設定メール送信機能を実装しました。

**メイラー設計の改善**：
- **パラメータ**: `password_reset(user)` でユーザーオブジェクトを受け取り
- **件名**: `"Password reset"` で明確な目的を表示
- **宛先**: `user.email` で確実な配信

**実用的な改良**：
- 汎用的なコードから実際に使える機能への変換
- ユーザー情報を活用したパーソナライズ
- 適切な件名によるメール管理の向上

```diff
@@
-  def password_reset
-    @greeting = "Hi"
-
-    mail to: "to@example.org"
+  def password_reset(user)
+    @user = user
+    mail to: user.email, subject: "Password reset"
   end
 end
```

### app/views/user_mailer/password_reset.html.erb

#### 🎯 概要
メール本文を実際の再設定リンク付きの内容に書き換えています。

#### 🧠 解説
パスワード再設定メールのHTML版テンプレートを実装しました。

**メールテンプレート設計**：

1. **明確な件名**: `<h1>Password reset</h1>`
2. **行動指示**: "To reset your password click the link below:"
3. **機能的なリンク**: `edit_password_reset_url` で適切なURLを生成
4. **期限告知**: "This link will expire in two hours."
5. **安全性注意**: 意図しないリクエストへの対処方法を明記

**URLパラメータの設計**：
```ruby
edit_password_reset_url(@user.reset_token, email: @user.email)
```
- **`:id`**: reset_token（一意のトークン）
- **`email`**: ユーザーのメールアドレス（二重確認）

**セキュリティ考慮**：
- 期限を明示してユーザーの緊急性を促す
- 意図しないリクエストの場合の指示を提供
- フィッシング詐欺への注意喚起

```diff
@@
-<h1>User#password_reset</h1>
+<h1>Password reset</h1>
+
+<p>To reset your password click the link below:</p>
+
+<%= link_to "Reset password", edit_password_reset_url(@user.reset_token,
+                                                      email: @user.email) %>
+
+<p>This link will expire in two hours.</p>
 
 <p>
-  <%= @greeting %>, find me in app/views/user_mailer/password_reset.html.erb
+If you did not request your password to be reset, please ignore this email and
+your password will stay as it is.
 </p>
```

### app/views/user_mailer/password_reset.text.erb

#### 🎯 概要
HTML版に対応するテキスト形式のパスワードリセットメールテンプレートです。メールクライアントの互換性確保のために必要です。

#### 🧠 解説
シンプルなテキスト形式でパスワードリセットメールを実装しました。

**テキストメールの重要性**：
- **互換性**: 古いメールクライアントやテキスト専用設定への対応
- **アクセシビリティ**: スクリーンリーダーや視覚障害者への配慮
- **セキュリティ**: 企業環境でHTMLメールが無効化されている場合への対応

**設計のポイント**：
- **明確な説明**: HTMLリンクがないため、URLの目的を明確に説明
- **コピー&ペースト対応**: URLを手動でコピーできる形式
- **セキュリティ注意事項**: 意図しないリクエストへの対処方法を明記
- **期限告知**: "This link will expire in two hours." で緊急性を促す

```erb
To reset your password click the link below:

<%= edit_password_reset_url(@user.reset_token, email: @user.email) %>

This link will expire in two hours.

If you did not request your password to be reset, please ignore this email and
your password will stay as it is.
```

### app/views/password_resets/new.html.erb

#### 🎯 概要
パスワード再設定のメールアドレス入力フォームです。シンプルで直感的なUIを提供します。

#### 🧠 解説
パスワード再設定の最初のステップとなるフォームを実装しました。

**フォーム設計のポイント**：
- **目的の明確化**: タイトルで機能を明示
- **必要最小限の入力**: メールアドレスのみ
- **適切なフィールドタイプ**: `email_field` でバリデーション強化
- **明確なCTA**: "Submit" ボタンで次のアクションを促す

**ユーザビリティ**：
- 迷いのないシンプルな操作
- 一般的なパスワードリセットフォームの形式
- レスポンシブ対応（Bootstrap）

```erb
<% provide(:title, "Forgot password") %>
<h1>Forgot password</h1>

<div class="row">
  <div class="col-md-6 col-md-offset-3">
    <%= form_with(url: password_resets_path, scope: :password_reset) do |f| %>
      <%= f.label :email %>
      <%= f.email_field :email, class: 'form-control' %>

      <%= f.submit "Submit", class: "btn btn-primary" %>
    <% end %>
  </div>
</div>
```

### app/views/password_resets/edit.html.erb

#### 🎯 概要
新しいパスワードを入力・確認するフォームです。セキュリティとユーザビリティを両立したデザインとなっています。

#### 🧠 解説
パスワード再設定の最終ステップとなるフォームを実装しました。

**セキュリティ設計**：
- **hidden_field**: メールアドレスとトークンを隠しフィールドで維持
- **password_confirmation**: パスワード確認によるタイプミス防止
- **エラー表示**: バリデーション失敗時の適切なフィードバック

**フォーム設計**：
- **二重入力**: パスワードと確認パスワード
- **隠しパラメータ**: email（ユーザー特定用）
- **適切なHTTPメソッド**: PATCHでRESTful更新

```erb
<% provide(:title, 'Reset password') %>
<h1>Reset password</h1>

<div class="row">
  <div class="col-md-6 col-md-offset-3">
    <%= form_with(model: @user, url: password_reset_path(params[:id])) do |f| %>
      <%= render 'shared/error_messages' %>

      <%= hidden_field_tag :email, @user.email %>

      <%= f.label :password %>
      <%= f.password_field :password, class: 'form-control' %>

      <%= f.label :password_confirmation, "Confirmation" %>
      <%= f.password_field :password_confirmation, class: 'form-control' %>

      <%= f.submit "Update password", class: "btn btn-primary" %>
    <% end %>
  </div>
</div>
```

### db/migrate/20231218074431_add_reset_to_users.rb

#### 🎯 概要
ユーザーテーブルに `reset_digest` と `reset_sent_at` を追加するマイグレーションです。

#### 🧠 解説
パスワード再設定機能に必要なデータベーススキーマを追加しました。

**カラム設計**：
- **`reset_digest`**: ハッシュ化されたリセットトークンを保存（string型）
- **`reset_sent_at`**: メール送信時刻を記録（datetime型）

**セキュリティ設計**：
- 平文トークンは保存せず、ダイジェストのみ保存
- 時刻記録により期限管理を実現
- 既存データへの影響なし（カラム追加のみ）

```diff
+class AddResetToUsers < ActiveRecord::Migration[7.0]
+  def change
+    add_column :users, :reset_digest, :string
+    add_column :users, :reset_sent_at, :datetime
+  end
+end
```

### db/schema.rb

#### 🎯 概要
マイグレーション実行後のデータベーススキーマです。usersテーブルに新しいカラムが追加されたことを確認できます。

#### 🧠 解説
マイグレーション実行後のスキーマ更新を確認します。

**スキーマの変更**：
- **バージョン更新**: `2023_12_18_065831` → `2023_12_18_074431`
- **新規カラム**: `reset_digest`と`reset_sent_at`が追加
- **データ型**: string と datetime で適切な型を使用

```diff
-ActiveRecord::Schema[7.0].define(version: 2023_12_18_065831) do
+ActiveRecord::Schema[7.0].define(version: 2023_12_18_074431) do
@@
     t.string "activation_digest"
     t.datetime "activated_at"
+    t.string "reset_digest"
+    t.datetime "reset_sent_at"
```

### test/mailers/user_mailer_test.rb

#### 🎯 概要
UserMailerのパスワード再設定メール送信機能をテストします。メール内容とリンクの正当性を検証します。

#### 🧠 解説
パスワード再設定メールの内容を検証するテストを実装しました。

**テスト項目**：
- **宛先**: 正しいユーザーのメールアドレス
- **件名**: "Password reset"
- **本文チェック**: 
  - ユーザーのリセットトークンが含まれている
  - メールアドレスがURLパラメータに含まれている
  - 適切なドメインが使用されている

**テストの重要性**：
- メールテンプレートの正確性確認
- URL生成ロジックの検証
- 本番環境での送信失敗リスク軽減

```diff
@@
-  test "password_reset" do
-    mail = UserMailer.password_reset
-    assert_equal "Password reset", mail.subject
-    assert_equal ["to@example.org"], mail.to
-    assert_equal ["noreply@example.com"], mail.from
-    assert_match "Hi", mail.body.encoded
+  test "password_reset" do
+    user = users(:michael)
+    user.reset_token = User.new_token
+    mail = UserMailer.password_reset(user)
+    assert_equal "Password reset", mail.subject
+    assert_equal [user.email], mail.to
+    assert_equal ["noreply@example.com"], mail.from
+    assert_match user.reset_token,        mail.body.encoded
+    assert_match CGI.escape(user.email),  mail.body.encoded
```

### test/mailers/previews/user_mailer_preview.rb

#### 🎯 概要
パスワードリセット機能のメールプレビューメソッドが更新されました。開発環境でメールの外観を確認できます。

#### 🧠 解説
UserMailerPreviewクラスのpassword_resetメソッドが実際に機能するよう更新されました。

**更新されたメソッドの詳細**：
- **ユーザー取得**: `User.first` で既存ユーザーを使用
- **トークン生成**: `User.new_token` で実際のリセットトークンを生成
- **メイラー呼び出し**: `UserMailer.password_reset(user)` で正しいパラメータを渡す

**プレビュー機能の価値**：
- **開発効率**: 実際にメール送信せずに外観確認
- **デザイン確認**: パスワードリセットメールのレイアウト検証
- **リンク検証**: 生成されるURLの正確性確認
- **両形式対応**: HTMLとテキスト両方の表示確認

**プレビューURL**：
```
開発サーバー起動時のアクセス先：
http://localhost:3000/rails/mailers/user_mailer/password_reset
```

```diff
@@
   # Preview this email at
   # http://localhost:3000/rails/mailers/user_mailer/password_reset
   def password_reset
-    UserMailer.password_reset
+    user = User.first
+    user.reset_token = User.new_token
+    UserMailer.password_reset(user)
   end
 end
```

### test/integration/password_resets_test.rb

#### 🎯 概要
パスワード再設定の一連のフローを検証する統合テストが新設されました。

#### 🧠 解説
パスワード再設定機能の包括的な統合テストを実装しました。

**テストクラスの構造**：
- **基底クラス**: `PasswordResets`（共通セットアップ）
- **機能別クラス**: 
  - `ForgotPasswordFormTest`: フォーム表示テスト
  - `PasswordResetCreateTest`: リセット要求処理テスト
  - `PasswordResetEditUpdateTest`: パスワード更新テスト

**テストシナリオ**：

1. **フォーム表示テスト**:
   - パスワード再設定ページが正しく表示される
   - 適切なフォーム要素が存在する

2. **リセット要求テスト**:
   - 有効なメールアドレス：メール送信・成功メッセージ
   - 無効なメールアドレス：エラーメッセージ・メール未送信

3. **パスワード更新テスト**:
   - 無効なトークン・期限切れ・空パスワード：エラー処理
   - 有効な更新：成功・自動ログイン

**テストの価値**：
- ユーザーフローの完全な検証
- セキュリティホールの発見
- リファクタリング時の安全性確保

```diff
+class PasswordResets < ActionDispatch::IntegrationTest
+  def setup
+    ActionMailer::Base.deliveries.clear
+  end
+end
+
+class ForgotPasswordFormTest < PasswordResets
+  test "password reset path" do
+    get new_password_reset_path
+    assert_template 'password_resets/new'
+    assert_select 'input[name=?]', 'password_reset[email]'
+  end
+  ...
+end
+
+class PasswordResetCreateTest < PasswordResets
+  def setup
+    super
+    @user = users(:michael)
+  end
+
+  test "reset path with valid email" do
+    get new_password_reset_path
+    post password_resets_path, 
+         params: { password_reset: { email: @user.email } }
+    assert_not_equal @user.reset_digest, @user.reload.reset_digest
+    assert_equal 1, ActionMailer::Base.deliveries.size
+    assert_not flash.empty?
+    assert_redirected_to root_url
+  end
+
+  test "reset path with invalid email" do
+    get new_password_reset_path
+    post password_resets_path, 
+         params: { password_reset: { email: "" } }
+    assert_not flash.empty?
+    assert_template 'password_resets/new'
+  end
+end
+
+class PasswordResetEditUpdateTest < PasswordResets
+  def setup
+    super
+    @user = users(:michael)
+    @user.create_reset_digest
+  end
+
+  test "reset with valid info" do
+    get edit_password_reset_path(@user.reset_token, email: @user.email)
+    assert_template 'password_resets/edit'
+    password = "foobaz"
+    patch password_reset_path(@user.reset_token),
+          params: { email: @user.email,
+                    user: { password: password,
+                            password_confirmation: password } }
+    assert is_logged_in?
+    assert_not flash.empty?
+    assert_redirected_to @user
+  end
+  ...
+end
```

## 💡 学習のコツ

### セキュリティ設計の理解

**トークンベース認証の仕組み**：
```ruby
# 1. トークン生成（ランダム・一意）
reset_token = User.new_token

# 2. ダイジェスト化（一方向ハッシュ）
reset_digest = User.digest(reset_token)

# 3. 分離保存
# クライアント（メール）: 平文トークン
# サーバー（DB）: ハッシュ化トークン

# 4. 認証時の照合
BCrypt::Password.new(reset_digest).is_password?(reset_token)
```

**時間制限によるセキュリティ**：
- **期限設定**: 2時間で自動失効
- **用途**: 使い捨てトークンの実現
- **効果**: 長期間有効なトークンの悪用防止

### メール送信アーキテクチャ

**役割分担の明確化**：
```ruby
# Model: ビジネスロジック
def create_reset_digest
  # トークン生成・保存
end

def send_password_reset_email  
  # メール送信の委譲
end

# Mailer: メール送信専門
def password_reset(user)
  # メール作成・送信
end

# Controller: フロー制御
def create
  @user.create_reset_digest
  @user.send_password_reset_email
end
```

### エラーハンドリングパターン

**段階的なバリデーション**：
1. **ユーザー存在チェック**: メールアドレスでユーザー検索
2. **アクティベーション確認**: 有効化済みユーザーのみ
3. **トークン検証**: 正しいトークンかチェック
4. **期限確認**: 2時間以内の送信か確認
5. **パスワード検証**: 空でない・形式正しいパスワード

### テスト戦略

**テストの分類と目的**：
```ruby
# 単体テスト（Model）
- メソッドの戻り値検証
- バリデーション動作確認

# メイラーテスト  
- メール内容・宛先の確認
- テンプレートの正確性検証

# 統合テスト
- ユーザーフロー全体の動作確認
- セキュリティテストの重要性
- メールテストの実装方法
```

## 🧠 まとめ

本章では、パスワード再設定機能の実装を通じて以下の重要な概念を習得しました。

### 📚 習得した技術概念

**セキュリティ設計**:
- トークンベース認証システムの構築
- 時間制限付きワンタイムトークンの実装
- 多層防御によるセキュリティ強化

**メール送信システム**:
- Rails Mailerの実用的な活用
- HTMLとテキスト両対応のテンプレート
- 外部サービス連携の基礎

**RESTfulアーキテクチャ**:
- リソースベースの設計思想
- 適切なHTTPメソッドの使用
- エラーハンドリングのベストプラクティス

**テスト駆動開発**:
- 統合テストによる包括的な検証
- セキュリティテストの重要性
- メールテストの実装方法

### 🔐 セキュリティベストプラクティス

1. **トークン管理**: 平文とハッシュの分離保存
2. **時間制限**: 適切な期限設定（2時間）
3. **多層検証**: ユーザー・トークン・期限の段階的チェック
4. **ワンタイム使用**: トークンの使い回し防止

### 🚀 次のステップ

これらの基盤技術により、より高度なセキュリティ機能を実装する準備が整いました：

- **二要素認証（2FA）**
- **OAuth連携ログイン**
- **APIトークン管理**
- **セキュリティログ機能**

パスワード再設定機能は、現代のWebアプリケーションにおいて必須の機能です。セキュリティを保ちながらユーザビリティを向上させる本実装は、実用的なWebサービス開発の重要な基礎となります。コードの流れを追いながら、セキュリティ設計の思想を理解することが重要です。
