# ch11 アカウントの有効化 (from ch10)

## 🔥 はじめに：本章で越えるべき山

この章ではユーザー登録時に送信される「アカウント有効化メール」を実装します。認証トークンを扱うことで、メールアドレスの確認プロセスを学びます。

## ✅ 学習ポイント一覧

- 新しい `AccountActivationsController` による有効化処理
- `User` モデルにトークン生成と有効化メソッドを追加
- サインアップ時に有効化メールを送信
- 有効化されたユーザーだけがログイン可能に
- メール送信設定 (development / test / production)
- 有効化用のマイグレーションとサンプルデータの更新
- 各種テストの拡充

## 🔍 ファイル別レビューと解説

### app/controllers/account_activations_controller.rb

新規追加されたコントローラで、メール内リンクからの有効化を受け付けます。

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

有効化済みかどうかを確認してからログインさせます。

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
```

### app/controllers/users_controller.rb

登録後すぐにログインさせるのではなく、メール送信を行います。

```diff
@@
-      reset_session
-      log_in @user
-      flash[:success] = "Welcome to the Sample App!"
-      redirect_to @user
+      @user.send_activation_email
+      flash[:info] = "Please check your email to activate your account."
+      redirect_to root_url
```

### app/helpers/sessions_helper.rb

`authenticated?` の仕様変更に合わせて記述を簡潔化しています。

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

### app/models/user.rb

トークン関連の属性とコールバックを追加し、アカウント有効化機能を実装します。

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
+    digest = send("\#{attribute}_digest")
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
```

### app/mailers/application_mailer.rb

送信元アドレスを実在するドメインに変更しました。

```diff
-  default from: "from@example.com"
+  default from: "user@realdomain.com"
```

### app/mailers/user_mailer.rb

有効化メールを送るためのメイラーを新規作成しています。

```ruby
class UserMailer < ApplicationMailer
  def account_activation(user)
    @user = user
    mail to: user.email, subject: "Account activation"
  end
end
```

### app/views/user_mailer/account_activation.html.erb

メール本文に有効化リンクを含めます。

```erb
<%= link_to "Activate", edit_account_activation_url(@user.activation_token,
                                                    email: @user.email) %>
```

### config/routes.rb

有効化リンク用のルーティングを追加。

```diff
   resources :users
+  resources :account_activations, only: [:edit]
 end
```

### config/environments/development.rb

開発環境でのメール用URLを設定します。

```diff
   config.action_mailer.raise_delivery_errors = false
+
+  host = 'example.com'
+  config.action_mailer.default_url_options = { host: host, protocol: 'https' }
+  # config.action_mailer.default_url_options = { host: host, protocol: 'http' }
```

### config/environments/test.rb

テスト環境でもURLオプションを指定。

```diff
   config.action_mailer.delivery_method = :test
+  config.action_mailer.default_url_options = { host: 'example.com' }
```

### config/environments/production.rb

本番環境ではSMTPを利用してメールを送信します。

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

### db/migrate/20231218032814_add_activation_to_users.rb

ユーザーに有効化関連のカラムを追加するマイグレーションです。

```ruby
add_column :users, :activation_digest, :string
add_column :users, :activated, :boolean, default: false
add_column :users, :activated_at, :datetime
```

### db/seeds.rb

サンプルユーザーを有効化済みとして作成します。

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

### test/integration/users_login_test.rb

テストを複数のクラスに分割し、ログインの挙動を細かく確認します。

```diff
-class UsersLoginTest < ActionDispatch::IntegrationTest
+class UsersLogin < ActionDispatch::IntegrationTest
@@
-class InvalidPasswordTest < ActionDispatch::IntegrationTest
+class InvalidPasswordTest < UsersLogin
@@
-class ValidLoginTest < ActionDispatch::IntegrationTest
+class ValidLoginTest < ValidLogin
```

### test/integration/users_signup_test.rb

アカウント有効化のフローをテストに追加しました。

```diff
-class UsersSignupTest < ActionDispatch::IntegrationTest
+class UsersSignup < ActionDispatch::IntegrationTest
@@
-  test "valid signup information" do
+  test "valid signup information with account activation" do
@@
-    follow_redirect!
-    assert_template 'users/show'
-    assert is_logged_in?
+    assert_equal 1, ActionMailer::Base.deliveries.size
```

### test/mailers/user_mailer_test.rb

送信される有効化メールの内容を検証します。

```diff
+class UserMailerTest < ActionMailer::TestCase
+  test "account_activation" do
+    user = users(:michael)
+    user.activation_token = User.new_token
+    mail = UserMailer.account_activation(user)
+    assert_equal "Account activation", mail.subject
+    assert_equal [user.email], mail.to
+    assert_match user.activation_token, mail.body.encoded
+  end
+end
```

### test/models/user_test.rb

`authenticated?` の引数変更に対応しています。

```diff
-    assert_not @user.authenticated?("")
+    assert_not @user.authenticated?(:remember, "")
```

## 🧠 まとめ

この章ではメールを利用したアカウント有効化機能を実装しました。登録時にメールを送り、リンクを踏むことで初めてログインが可能になります。これに伴いモデル・コントローラ・テストの多くが更新され、メール設定も追加されました。メール送信の流れとトークン管理は、今後のパスワード再設定機能などにも応用できる重要な要素です。
