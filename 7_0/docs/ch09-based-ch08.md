# ch09 発展的なログイン機構（from ch08）

## 🔥 はじめに：本章で越えるべき山

この章では「Remember me」機能を追加し、ブラウザを閉じてもログイン状態を保持できるようにします。ログイン周りのコードを整理しつつ、cookie を活用した永続的セッションを実装していきましょう。

## ✅ 学習ポイント一覧

- 永続的セッション (remember me) の仕組み
- `SessionsHelper` によるログイン状態の管理
- モデルにトークン生成メソッドを追加
- ログインフォームのチェックボックス実装とCSS調整
- テストコードの拡充（ヘルパー・統合テスト）

## 🔍 ファイル別レビューと解説

### app/assets/stylesheets/custom.scss

ログイン画面にチェックボックスを追加したため、見た目を整えるスタイルを定義しています。

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

`remember_me` パラメータに応じて Cookie を操作する処理を追加しました。また、ログアウト時にはログイン状態にあるかを確認します。

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

ログイン中のユーザー取得処理を拡張し、remember me 用のトークン保存・削除メソッドを定義しました。

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

ユーザーモデルに記憶トークンの生成・検証用メソッドを追加しました。`remember_token` は仮想属性として扱います。

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

フォームに「Remember me」チェックボックスを追加しました。

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

Rememberトークンのハッシュ値を保存するカラムを追加するマイグレーションです。

```ruby
class AddRememberDigestToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :remember_digest, :string
  end
end
```

### db/schema.rb

マイグレーション実行後のスキーマでは `remember_digest` カラムが追加されています。

```diff
-ActiveRecord::Schema[7.0].define(version: 2023_12_13_085943) do
+ActiveRecord::Schema[7.0].define(version: 2023_12_18_011905) do
@@
     t.string "password_digest"
+    t.string "remember_digest"
```

### test/helpers/sessions_helper_test.rb

`current_user` の動作を検証するテストを新規作成しました。

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

Remember me 機能に関する統合テストを追加しました。ログアウトの二重実行にも対応しています。

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

`authenticated?` メソッドが `nil` を扱えるか確認するテストを追記しました。

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

テスト環境用のログインヘルパーを拡張し、統合テストからも利用できるようにしました。

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

## 🧠 まとめ

- Cookie を使った永続的セッション機構を導入し、`remember_token` と `remember_digest` でユーザーを識別できるようになりました。
- ログイン／ログアウト処理を整理し、複数ウィンドウからの操作にも耐える実装となっています。
- 新しいテスト群により、remember me 機能の動作を自動で検証できます。

