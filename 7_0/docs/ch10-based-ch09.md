# ch10 ユーザーの更新・表示・削除 （from ch09）

## 🔥 はじめに：本章で越えるべき山

この章では、登録済みユーザーの一覧・更新・削除機能を追加し、管理者だけが他ユーザーを削除できるようにします。また、ページネーションやサンプルデータ生成の仕組みも学びます。

## ✅ 学習ポイント一覧

- `before_action` によるアクセス制御
- フレンドリーフォワーディングでログイン後に元のページへリダイレクト
- 管理者属性 `admin` とユーザー削除権限
- `will_paginate` を用いたページネーション
- `faker` による大量のテストデータ生成
- セッションの安全性向上（`session_token`）

## 🔍 ファイル別レビューと解説

### Gemfile

`faker` とページネーション関連のgemを追加しました。
```diff
+gem "faker",                   "2.21.0"
+gem "will_paginate",           "3.3.1"
+gem "bootstrap-will_paginate", "1.0.0"
```
これにより `db/seeds.rb` で大量のユーザーを生成し、ビューで `will_paginate` を使えるようになります。

### app/controllers/sessions_controller.rb

ログイン後にアクセスしようとしたページへ戻すフレンドリーフォワーディングを実装しました。
```diff
-      reset_session
-      params[:session][:remember_me] == '1' ? remember(user) : forget(user)
-      log_in user
-      redirect_to user
+      forwarding_url = session[:forwarding_url]
+      reset_session
+      params[:session][:remember_me] == '1' ? remember(user) : forget(user)
+      log_in user
+      redirect_to forwarding_url || user
```

### app/controllers/users_controller.rb

一覧表示・編集・削除機能を追加し、アクセス制御用のフィルタも定義しました。
```diff
+  before_action :logged_in_user, only: [:index, :edit, :update, :destroy]
+  before_action :correct_user,   only: [:edit, :update]
+  before_action :admin_user,     only: :destroy
+
+  def index
+    @users = User.paginate(page: params[:page])
+  end
...
+  def edit
+  end
+
+  def update
+    if @user.update(user_params)
+      flash[:success] = "Profile updated"
+      redirect_to @user
+    else
+      render 'edit', status: :unprocessable_entity
+    end
+  end
+
+  def destroy
+    User.find(params[:id]).destroy
+    flash[:success] = "User deleted"
+    redirect_to users_url, status: :see_other
+  end
```
また、`logged_in_user`・`correct_user`・`admin_user` を `private` メソッドとして実装し、ログインしていない場合や誤ったユーザーの操作を防ぎます。

### app/helpers/sessions_helper.rb

セッション固定攻撃への対策として `session_token` を扱うように変更し、便利メソッド `current_user?` と `store_location` を追加しました。
```diff
   def log_in(user)
     session[:user_id] = user.id
+    session[:session_token] = user.session_token
   end
...
-      @current_user ||= User.find_by(id: user_id)
+      user = User.find_by(id: user_id)
+      if user && session[:session_token] == user.session_token
+        @current_user = user
+      end
...
+  def current_user?(user)
+    user && user == current_user
+  end
+
+  def store_location
+    session[:forwarding_url] = request.original_url if request.get?
+  end
```

### app/helpers/users_helper.rb

Gravatar画像のサイズ指定に対応しました。
```diff
-  def gravatar_for(user)
-    gravatar_id  = Digest::MD5::hexdigest(user.email.downcase)
-    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}"
-    image_tag(gravatar_url, alt: user.name, class: "gravatar")
+  def gravatar_for(user, options = { size: 80 })
+    size         = options[:size]
+    gravatar_id  = Digest::MD5::hexdigest(user.email.downcase)
+    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}?s=#{size}"
+    image_tag(gravatar_url, alt: user.name, class: "gravatar")
   end
```

### app/models/user.rb

パスワード更新時のバリデーション緩和とセッション用トークンの追加です。
```diff
-  validates :password, presence: true, length: { minimum: 6 }
+  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true
...
   def remember
     self.remember_token = User.new_token
     update_attribute(:remember_digest, User.digest(remember_token))
+    remember_digest
   end
+
+  def session_token
+    remember_digest || remember
+  end
```

### app/views/layouts/_header.html.erb

ナビゲーションにユーザー一覧と設定へのリンクを追加しました。
```diff
-          <li><%= link_to "Users", '#' %></li>
+          <li><%= link_to "Users", users_path %></li>
...
-              <li><%= link_to "Settings", '#' %></li>
+              <li><%= link_to "Settings", edit_user_path(current_user) %></li>
```

### app/assets/stylesheets/custom.scss

ユーザー一覧用のスタイルを追加しています。
```diff
 .dropdown-menu.active {
   display: block;
 }
+
+/* Users index */
+
+.users {
+  list-style: none;
+  margin: 0;
+  li {
+    overflow: auto;
+    padding: 10px 0;
+    border-bottom: 1px solid $gray-lighter;
+  }
+}
```

### app/views/users/_user.html.erb

ユーザー1人分を表示するパーシャルを新規作成しました。管理者には削除リンクを表示します。
```erb
<li>
  <%= gravatar_for user, size: 50 %>
  <%= link_to user.name, user %>
  <% if current_user.admin? && !current_user?(user) %>
    | <%= link_to "delete", user, data: { "turbo-method": :delete,
                                          turbo_confirm: "You sure?" } %>
  <% end %>
</li>
```

### app/views/users/index.html.erb

全ユーザーをページネートして表示するビューです。
```erb
<% provide(:title, 'All users') %>
<h1>All users</h1>

<%= will_paginate %>

<ul class="users">
  <%= render @users %>
</ul>

<%= will_paginate %>
```

### app/views/users/edit.html.erb

ユーザー情報編集フォームを実装しました。エラー表示やGravatar変更リンクも含まれます。
```erb
<%= form_with(model: @user) do |f| %>
  <%= render 'shared/error_messages' %>
  ...
  <%= f.submit "Save changes", class: "btn btn-primary" %>
<% end %>
```

### db/migrate/20231218025948_add_admin_to_users.rb

管理者権限を判定する `admin` カラムを追加するマイグレーションです。
```ruby
add_column :users, :admin, :boolean, default: false
```

### db/seeds.rb

大量のサンプルユーザーを生成するようになりました。
```ruby
User.create!(name:  "Example User",
  email: "example@railstutorial.org",
  password: "foobar",
  password_confirmation: "foobar",
  admin: true)

99.times do |n|
  name  = Faker::Name.name
  email = "example-#{n+1}@railstutorial.org"
  password = "password"
  User.create!(name:  name,
               email: email,
               password: password,
               password_confirmation: password)
end
```

### test/controllers/users_controller_test.rb

未ログイン時や権限のないユーザーが編集・削除を行えないことをテストで保証しています。
```diff
+  def setup
+    @user = users(:michael)
+    @other_user = users(:archer)
+  end
+
+  test "should redirect index when not logged in" do
+    get users_path
+    assert_redirected_to login_url
+  end
+  ...
+  test "should redirect destroy when logged in as a non-admin" do
+    log_in_as(@other_user)
+    assert_no_difference 'User.count' do
+      delete user_path(@user)
+    end
+    assert_response :see_other
+    assert_redirected_to root_url
+  end
```

### test/fixtures/users.yml

テストユーザーが増え、`admin` 属性も付与されました。
```yaml
michael:
  name: Michael Example
  email: michael@example.com
  password_digest: <%= User.digest('password') %>
  admin: true

archer:
  name: Sterling Archer
  email: duchess@example.gov
  password_digest: <%= User.digest('password') %>
...
<% 30.times do |n| %>
user_<%= n %>:
  name:  <%= "User #{n}" %>
  email: <%= "user-#{n}@example.com" %>
  password_digest: <%= User.digest('password') %>
<% end %>
```

### 新規統合テスト

編集画面の挙動とユーザー一覧ページの権限周りを確認するテストを追加しました。
- `test/integration/users_edit_test.rb`
- `test/integration/users_index_test.rb`

## 🧠 まとめ

本章ではユーザーの更新・一覧表示・削除機能を実装し、管理者だけがユーザーを削除できるようにしました。さらに、フレンドリーフォワーディングやセッションの安全性向上、ページネーションといった実践的な機能を学びました。これらの変更により、より本格的なユーザー管理が可能になります。
