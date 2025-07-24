# ch11 アカウントの有効化 (from ch10)

## 🔥 はじめに：本章で越えるべき山

この章ではメールを使ったアカウント有効化を実装します。登録直後のユーザーは非アクティブ状態とし、届いたメールのリンクを踏むことで初めてログインできるようになります。メール送信の設定やトークン認証の仕組みを学びながら、より実践的なユーザー管理へステップアップします。

## ✅ 学習ポイント一覧

- 有効化用トークンとダイジェストの生成
- `UserMailer` によるメール送信
- 開発・本番環境でのメール設定
- アカウント有効化リンクの処理
- ログイン時のアクティブチェック

## 🔍 ファイル別レビューと解説

### app/controllers/account_activations_controller.rb

新しく追加されたコントローラで、メール内のリンクから呼び出されます。トークンとメールアドレスを確認し、ユーザーを有効化してからログインさせます。
```diff
+class AccountActivationsController < ApplicationController
+
+  def edit
+    user = User.find_by(email: params[:email])
+    if user && !user.activated? && user.authenticated?(:activation, params[:id])
+      user.activate
+      log_in user
+      flash[:success] = "Account activated!"
+      redirect_to user
+    else
+      flash[:danger] = "Invalid activation link"
+      redirect_to root_url
+    end
+  end
+end
```

### app/controllers/sessions_controller.rb

ログイン時にユーザーが有効化済みかどうかを確認します。未有効の場合は警告メッセージを表示してトップページへリダイレクトします。
```diff
@@
-      forwarding_url = session[:forwarding_url]
-      reset_session
-      params[:session][:remember_me] == '1' ? remember(user) : forget(user)
-      log_in user
-      redirect_to forwarding_url || user
+      if user.activated?
+        forwarding_url = session[:forwarding_url]
+        reset_session
+        params[:session][:remember_me] == '1' ? remember(user) : forget(user)
+        log_in user
+        redirect_to forwarding_url || user
+      else
+        message  = "Account not activated. "
+        message += "Check your email for the activation link."
+        flash[:warning] = message
+        redirect_to root_url
+      end
     else
       flash.now[:danger] = 'Invalid email/password combination'
       render 'new', status: :unprocessable_entity
```

### app/controllers/users_controller.rb

ユーザー登録後はすぐにログインさせず、有効化メールを送信してホームへリダイレクトします。
```diff
@@
-      reset_session
-      log_in @user
-      flash[:success] = "Welcome to the Sample App!"
-      redirect_to @user
+      @user.send_activation_email
+      flash[:info] = "Please check your email to activate your account."
+      redirect_to root_url
     else
       render 'new', status: :unprocessable_entity
     end
```

### app/helpers/sessions_helper.rb

`current_user` の実装を一般化し、rememberトークン認証時に `authenticated?` を使うよう修正しました。
```diff
@@
-      if user && session[:session_token] == user.session_token
-        @current_user = user
-      end
+      @current_user ||= user if session[:session_token] == user.session_token
@@
-      if user && user.authenticated?(cookies[:remember_token])
+      if user && user.authenticated?(:remember, cookies[:remember_token])
         log_in user
         @current_user = user
       end
```

### app/mailers/application_mailer.rb

差出人アドレスを実在するドメインに変更しました。
```diff
-  default from: "from@example.com"
+  default from: "user@realdomain.com"
```

### app/mailers/user_mailer.rb

ユーザー有効化メールを送信するためのメイラーです。
```ruby
class UserMailer < ApplicationMailer
  def account_activation(user)
    @user = user
    mail to: user.email, subject: "Account activation"
  end
end
```

### app/models/user.rb

有効化に関する属性とメソッドを追加しました。`authenticated?` は属性名を受け取れるようにし、メール送信前にダイジェストを生成します。
```diff
@@
-  attr_accessor :remember_token
-  before_save { self.email = email.downcase }
+  attr_accessor :remember_token, :activation_token
+  before_save   :downcase_email
+  before_create :create_activation_digest
@@
-  def authenticated?(remember_token)
-    return false if remember_digest.nil?
-    BCrypt::Password.new(remember_digest).is_password?(remember_token)
+  def authenticated?(attribute, token)
+    digest = send("#{attribute}_digest")
+    return false if digest.nil?
+    BCrypt::Password.new(digest).is_password?(token)
   end
@@
   def forget
     update_attribute(:remember_digest, nil)
   end
+
+  def activate
+    update_attribute(:activated,    true)
+    update_attribute(:activated_at, Time.zone.now)
+  end
+
+  def send_activation_email
+    UserMailer.account_activation(self).deliver_now
+  end
+
+  private
+
+    def downcase_email
+      self.email = email.downcase
+    end
+
+    def create_activation_digest
+      self.activation_token  = User.new_token
+      self.activation_digest = User.digest(activation_token)
+    end
 end
```

### app/views/user_mailer/account_activation.html.erb

メール本文に有効化リンクを配置しています。テキストメール版も同様です。
```erb
<%= link_to "Activate", edit_account_activation_url(@user.activation_token,
                                                    email: @user.email) %>
```

### config/environments/development.rb

開発環境でメールリンクのホスト名を設定します。
```diff
+  host = 'example.com' # ここを自分の環境に合わせて変更
+  config.action_mailer.default_url_options = { host: host, protocol: 'https' }
+  # config.action_mailer.default_url_options = { host: host, protocol: 'http' }
```

### config/environments/production.rb

本番用のメール送信設定を追加しました。ここでは Mailgun を利用しています。
```diff
-  # config.action_mailer.raise_delivery_errors = false
+  config.action_mailer.raise_delivery_errors = true
+  config.action_mailer.delivery_method = :smtp
+  host = '<あなたのRenderアプリ名>.onrender.com'
+  config.action_mailer.default_url_options = { host: host }
+  ActionMailer::Base.smtp_settings = {
+    :port           => 587,
+    :address        => 'smtp.mailgun.org',
+    :user_name      => ENV['MAILGUN_SMTP_LOGIN'],
+    :password       => ENV['MAILGUN_SMTP_PASSWORD'],
+    :domain         => host,
+    :authentication => :plain,
+  }
```

### config/environments/test.rb

テスト環境でもURLオプションを設定してメール内リンクを生成します。
```diff
   config.action_mailer.delivery_method = :test
+  config.action_mailer.default_url_options = { host: 'example.com' }
```

### config/routes.rb

有効化リンク用のルーティングを追加しました。
```diff
   resources :users
+  resources :account_activations, only: [:edit]
 end
```

### db/migrate/20231218032814_add_activation_to_users.rb

ユーザーテーブルに有効化関連のカラムを追加するマイグレーションです。
```ruby
add_column :users, :activation_digest, :string
add_column :users, :activated, :boolean, default: false
add_column :users, :activated_at, :datetime
```

### db/schema.rb

スキーマにも新しいカラムが反映されています。
```diff
-ActiveRecord::Schema[7.0].define(version: 2023_12_18_025948) do
+ActiveRecord::Schema[7.0].define(version: 2023_12_18_032814) do
@@
     t.boolean "admin", default: false
+    t.string "activation_digest"
+    t.boolean "activated", default: false
+    t.datetime "activated_at"
```

### db/seeds.rb

サンプルデータを有効化済みの状態で作成するよう更新しました。
```diff
-  admin: true)
+  admin:     true,
+  activated: true,
+  activated_at: Time.zone.now)
@@
-    password_confirmation: password)
+    password_confirmation: password,
+    activated: true,
+    activated_at: Time.zone.now)
```

### test/fixtures/users.yml

fixture データにも `activated` 属性を追加しています。
```diff
@@
   email: michael@example.com
   password_digest: <%= User.digest('password') %>
   admin: true
+  activated: true
+  activated_at: <%= Time.zone.now %>
```

### test/integration/users_login_test.rb

ログイン関連のテストをクラスごとに整理し、二重ログアウトの挙動を確認するテストを追加しました。
```diff
-class UsersLoginTest < ActionDispatch::IntegrationTest
+class UsersLogin < ActionDispatch::IntegrationTest
@@
-class UsersSignupTest < ActionDispatch::IntegrationTest
+class UsersSignup < ActionDispatch::IntegrationTest
@@
-  test "login with valid email/invalid password" do
+  test "login path" do
@@
+class LogoutTest < Logout
+  test "should still work after logout in second window" do
+    delete logout_path
+    assert_redirected_to root_url
+  end
```

### test/integration/users_signup_test.rb

有効化メール送信とリンクによるアカウント有効化をテストします。
```diff
-class UsersSignupTest < ActionDispatch::IntegrationTest
+class UsersSignup < ActionDispatch::IntegrationTest
@@
-  test "valid signup information" do
+  test "valid signup information with account activation" do
@@
-    assert_difference 'User.count', 1 do
+    assert_difference 'User.count', 1 do
       post users_path, params: { user: { name:  "Example User",
                                          email: "user@example.com",
                                          password:              "password",
                                          password_confirmation: "password" } }
     end
-    follow_redirect!
-    assert_template 'users/show'
-    assert is_logged_in?
+    assert_equal 1, ActionMailer::Base.deliveries.size
```
さらに、無効なトークンやメールの場合にログインできないこと、正しいリンクなら有効化されることを細かく検証しています。

### test/mailers/user_mailer_test.rb

メールの内容とヘッダーを確認するテストです。
```ruby
mail = UserMailer.account_activation(user)
assert_equal "Account activation", mail.subject
assert_equal [user.email], mail.to
assert_equal ["user@realdomain.com"], mail.from
```

### test/models/user_test.rb

`authenticated?` の引数が変更されたことに伴うテスト更新です。
```diff
-    assert_not @user.authenticated?('')
+    assert_not @user.authenticated?(:remember, '')
```

## 🧠 まとめ

アカウント有効化により、不正なメールアドレスでの登録やボットによる大量登録を防げるようになりました。メール送信設定やトークン管理など、本番運用を見据えた実装内容が中心となっています。
