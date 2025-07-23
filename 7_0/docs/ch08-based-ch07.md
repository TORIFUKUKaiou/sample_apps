# ch08 基本的なログイン機構 (from ch07)

## 🔥 はじめに：本章で越えるべき山

この章では、サインアップ機能に加えてログイン／ログアウト機構を整えます。セッション管理を通じてHTTPが持たない「状態」をRailsで扱う方法を学びます。

## ✅ 学習ポイント一覧

- セッションを使ったログイン状態の保持
- `SessionsController` と対応するビューの作成
- ヘルパーメソッド `current_user` などの実装
- レスポンシブ対応したヘッダーとドロップダウンメニュー
- ログイン関連の統合テスト

## 🔍 ファイル別レビューと解説

### app/controllers/application_controller.rb

#### 🧠 解説
`SessionsHelper` を読み込むことで、どのコントローラでも `current_user` などのメソッドが使えるようになります。サンプルアプリ冒頭で定義していた `hello` アクションは削除されました。

```diff
 class ApplicationController < ActionController::Base
-  def hello
-    render html: "hello, world!"
-  end
+  include SessionsHelper
 end
```

### app/controllers/sessions_controller.rb

#### 🧠 解説
ログイン画面表示(`new`)、ログイン処理(`create`)、ログアウト処理(`destroy`)を担うコントローラです。`reset_session` を用いてセッション固定攻撃を防いでから `log_in` を呼び出しています。

```diff
+class SessionsController < ApplicationController
+
+  def new
+  end
+
+  def create
+    user = User.find_by(email: params[:session][:email].downcase)
+    if user && user.authenticate(params[:session][:password])
+      reset_session      # ログインの直前に必ずこれを書くこと
+      log_in user
+      redirect_to user
+    else
+      flash.now[:danger] = 'Invalid email/password combination'
+      render 'new', status: :unprocessable_entity
+    end
+  end
+
+  def destroy
+    log_out
+    redirect_to root_url, status: :see_other
+  end
+end
```

### app/controllers/users_controller.rb

ユーザー登録後に自動でログインするため、`create` アクションに `reset_session` と `log_in @user` を追加しました。

```diff
   def create
     @user = User.new(user_params)
     if @user.save
+      reset_session
+      log_in @user
       flash[:success] = "Welcome to the Sample App!"
       redirect_to @user
     else
```

### app/helpers/sessions_helper.rb

ログイン処理をまとめたヘルパー。`current_user` や `logged_in?`、`log_out` などアプリ全体で利用する機能を提供します。

```diff
+module SessionsHelper
+
+  # 渡されたユーザーでログインする
+  def log_in(user)
+    session[:user_id] = user.id
+  end
+
+  # 現在ログイン中のユーザーを返す（いる場合）
+  def current_user
+    if session[:user_id]
+      @current_user ||= User.find_by(id: session[:user_id])
+    end
+  end
+
+  # ユーザーがログインしていればtrue、その他ならfalseを返す
+  def logged_in?
+    !current_user.nil?
+  end
+
+  # 現在のユーザーをログアウトする
+  def log_out
+    reset_session
+    @current_user = nil   # 安全のため
+  end
+end
```

### app/models/user.rb

パスワードのハッシュ化メソッド `User.digest` を追加し、テストなどから利用できるようになりました。

```diff
   validates :password, presence: true, length: { minimum: 6 }
+
+  # 渡された文字列のハッシュ値を返す
+  def User.digest(string)
+    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
+                                                  BCrypt::Engine.cost
+    BCrypt::Password.create(string, cost: cost)
+  end
 end
```

### app/javascript/application.js

カスタムのJavaScriptを読み込む設定です。

```diff
 import "@hotwired/turbo-rails"
 import "controllers"
+import "custom/menu"
```

### app/javascript/custom/menu.js

ヘッダーのハンバーガーボタンとアカウントメニュー用のJavaScript。クリックでクラスを付け替えて表示状態を切り替えます。

```javascript
// メニュー操作

document.addEventListener("turbo:load", function() {
  let hamburger = document.querySelector("#hamburger");
  if (hamburger){
    hamburger.addEventListener("click", function(event) {
      event.preventDefault();
      let menu = document.querySelector("#navbar-menu");
      menu.classList.toggle("collapse");
    });
  }

  let account = document.querySelector("#account");
  if (account) {
    account.addEventListener("click", function(event) {
      event.preventDefault();
      let menu = document.querySelector("#dropdown-menu");
      menu.classList.toggle("active");
    });
  }
});
```

### app/assets/stylesheets/custom.scss

レスポンシブ対応のフッターとドロップダウンメニューのスタイルを追加しました。

```diff
 @media (max-width: 800px) {
   footer {
     small {
       display: block;
       float: none;
       margin-bottom: 1em;
     }
     ul {
       float: none;
       padding: 0;
       li {
         float: none;
         margin-left: 0;
       }
     }
   }
 }
+
+/* Dropdown menu */
+
+.dropdown-menu.active {
+  display: block;
+}
```

### app/views/layouts/_header.html.erb

ヘッダーにハンバーガーメニューとアカウント用ドロップダウンを追加し、ログイン状態に応じて表示内容が変わるようになりました。

```diff
-      <ul class="nav navbar-nav navbar-right">
-        <li><%= link_to "Home",    root_path %></li>
-        <li><%= link_to "Help",    help_path %></li>
-        <li><%= link_to "Log in", '#' %></li>
+      <div class="navbar-header">
+        <button id="hamburger" type="button" class="navbar-toggle collapsed">
+          <span class="sr-only">Toggle navigation</span>
+          <span class="icon-bar"></span>
+          <span class="icon-bar"></span>
+          <span class="icon-bar"></span>
+        </button>
+      </div>
+      <ul id="navbar-menu"
+          class="nav navbar-nav navbar-right collapse navbar-collapse">
+        <li><%= link_to "Home", root_path %></li>
+        <li><%= link_to "Help", help_path %></li>
+        <% if logged_in? %>
+          <li><%= link_to "Users", '#' %></li>
+          <li class="dropdown">
+            <a href="#" id="account" class="dropdown-toggle">
+              Account <b class="caret"></b>
+            </a>
+            <ul id="dropdown-menu" class="dropdown-menu">
+              <li><%= link_to "Profile", current_user %></li>
+              <li><%= link_to "Settings", '#' %></li>
+              <li class="divider"></li>
+              <li>
+                <%= link_to "Log out", logout_path,
+                                       data: { "turbo-method": :delete } %>
+              </li>
+            </ul>
+          </li>
+        <% else %>
+          <li><%= link_to "Log in", login_path %></li>
+        <% end %>
       </ul>
```

### app/views/sessions/new.html.erb

ログインフォームを提供する新規ビューです。`form_with` を利用し、メールアドレスとパスワードを入力させます。

```erb
<% provide(:title, "Log in") %>
<h1>Log in</h1>

<div class="row">
  <div class="col-md-6 col-md-offset-3">
    <%= form_with(url: login_path, scope: :session) do |f| %>

      <%= f.label :email %>
      <%= f.email_field :email, class: 'form-control' %>

      <%= f.label :password %>
      <%= f.password_field :password, class: 'form-control' %>

      <%= f.submit "Log in", class: "btn btn-primary" %>
    <% end %>

    <p>New user? <%= link_to "Sign up now!", signup_path %></p>
  </div>
</div>
```

### config/importmap.rb

カスタムJavaScriptディレクトリを読み込む設定を追加しました。

```diff
 pin_all_from "app/javascript/controllers", under: "controllers"
+pin_all_from "app/javascript/custom",      under: "custom"
```

### config/routes.rb

ログイン用のルーティングを追加し、`delete` メソッドでログアウトできるようになっています。

```diff
   root   "static_pages#home"
   get    "/help",    to: "static_pages#help"
   get    "/about",   to: "static_pages#about"
   get    "/contact", to: "static_pages#contact"
   get    "/signup",  to: "users#new"
+  get    "/login",   to: "sessions#new"
+  post   "/login",   to: "sessions#create"
+  delete "/logout",  to: "sessions#destroy"
   resources :users
 end
```

### test/fixtures/users.yml

テスト用ユーザーを追加してログインテストで利用します。

```diff
-# 空にする (既存のコードは削除する)
+michael:
+  name: Michael Example
+  email: michael@example.com
+  password_digest: <%= User.digest('password') %>
```

### test/controllers/sessions_controller_test.rb

`SessionsController` の `new` アクションが正しく動くかを確認するテストです。

```ruby
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get login_path
    assert_response :success
  end
end
```

### test/integration/users_login_test.rb

ログイン処理とログアウト処理を網羅的にテストしています。無効なパスワードのときの挙動や、ログアウト後のリンク表示を確認します。

```ruby
class UsersLoginTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
  end

  test "login with valid email/invalid password" do
    get login_path
    assert_template 'sessions/new'
    post login_path, params: { session: { email: @user.email,
                                          password: "invalid" } }
    assert_not is_logged_in?
    assert_response :unprocessable_entity
    assert_template 'sessions/new'
    assert_not flash.empty?
    get root_path
    assert flash.empty?
  end

  test "login with valid information followed by logout" do
    post login_path, params: { session: { email: @user.email,
                                          password: 'password' } }
    assert is_logged_in?
    assert_redirected_to @user
    follow_redirect!
    assert_template 'users/show'
    assert_select "a[href=?]", login_path, count: 0
    assert_select "a[href=?]", logout_path
    assert_select "a[href=?]", user_path(@user)
    delete logout_path
    assert_not is_logged_in?
    assert_response :see_other
    assert_redirected_to root_url
    follow_redirect!
    assert_select "a[href=?]", login_path
    assert_select "a[href=?]", logout_path,      count: 0
    assert_select "a[href=?]", user_path(@user), count: 0
  end
end
```

### test/integration/users_signup_test.rb

ユーザー登録後に自動でログインされることを確認する行が追加されました。

```diff
     follow_redirect!
     assert_template 'users/show'
+    assert is_logged_in?
   end
 end
```

### test/test_helper.rb

`is_logged_in?` ヘルパーを定義し、ログイン状態のテストを簡潔に記述できるようにしました。

```diff
   fixtures :all
 
-  # （すべてのテストで使うその他のヘルパーメソッドは省略）
+  # テストユーザーがログイン中の場合にtrueを返す
+  def is_logged_in?
+    !session[:user_id].nil?
+  end
 end
```

## 🧠 まとめ

ログイン機構を通じて、セッション管理、ヘルパーの活用、レスポンシブなビュー更新、そして統合テストの書き方を学びました。これによりアプリケーションはユーザーの状態を認識し、動的に挙動を変えることができるようになります。
