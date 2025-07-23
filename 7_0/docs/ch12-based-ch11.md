# ch12 パスワードの再設定 (from ch11)

## 🔥 はじめに：本章で越えるべき山

この章では、ユーザーが忘れたパスワードを安全に再設定する機能を実装します。
以下では第11章から第12章への差分をもとに、学習のポイントを整理します。

## ✅ 学習ポイント一覧

- パスワード再設定用のリソース`PasswordResets`の追加
- `User`モデルに再設定トークン関連の属性とメソッドを実装
- 失効期限付きのメール送信処理
- ルーティング・コントローラ・ビューの連携
- パスワード再設定に関する統合テスト

## 🔍 ファイル別レビューと解説

### app/controllers/password_resets_controller.rb

パスワード再設定を扱う新規コントローラです。トークン生成からメール送信、
有効性のチェックまで担当します。

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

パスワード再設定のための属性`reset_token`と関連メソッドが追加されました。
トークンの生成・保存、メール送信、期限切れ判定を担います。

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

`password_resets`リソースを追加し、`new`, `create`, `edit`, `update`の各アクションを有効化しました。

```diff
@@
   resources :users
   resources :account_activations, only: [:edit]
+  resources :password_resets,     only: [:new, :create, :edit, :update]
 end
```

### app/views/sessions/new.html.erb

ログインフォームに「Forgot password」リンクが追加され、
再設定画面へ誘導します。

```diff
@@
-      <%= f.label :password %>
-      <%= f.password_field :password, class: 'form-control' %>
+      <%= f.label :password %>
+      <%= link_to "(forgot password)", new_password_reset_path %>
+      <%= f.password_field :password, class: 'form-control' %>
```

### app/mailers/user_mailer.rb

再設定メール送信用メソッドにユーザーを受け取り、件名を設定しました。

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

メール本文を実際の再設定リンク付きの内容に書き換えています。

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

同様にテキストメール(`password_reset.text.erb`)も更新されています。

### db/migrate/20231218074431_add_reset_to_users.rb

ユーザーテーブルに `reset_digest` と `reset_sent_at` を追加するマイグレーションです。

```diff
+class AddResetToUsers < ActiveRecord::Migration[7.0]
+  def change
+    add_column :users, :reset_digest, :string
+    add_column :users, :reset_sent_at, :datetime
+  end
+end
```

### test/integration/password_resets_test.rb

パスワード再設定の一連のフローを検証する統合テストが新設されました。

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
```

## 🧠 まとめ

- パスワード再設定機能では、ユーザーのメールアドレスから一時的なトークンを生成し、期限付きリンクをメールで送信します。
- 有効性の検証を`before_action`で集中管理し、セキュリティを担保しています。
- テストを通じて、無効な入力やトークン期限切れなどのシナリオを確認することが重要です。

以上が第11章から第12章への主な変更点です。パスワード再設定機能は実用的なアプリ開発に欠かせないため、コードの流れを追いながら理解を深めてください。
