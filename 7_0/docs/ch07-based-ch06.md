# ch07 ユーザー登録 (from ch06)

## 🔥 はじめに：本章で越えるべき山

第6章ではユーザーモデルを作成し、データベースにユーザーを登録できるようになりました。本章では実際にユーザーがWeb画面から登録できる仕組みを実装します。フォーム送信から登録完了までの一連の流れを理解することが目標です。

**学習の流れ：** モデル（ch06）→ ビュー・コントローラー（本章）→ 完全なWebアプリケーション

## ✅ 学習ポイント一覧

- `resources :users` でRESTfulルーティングを設定
- `UsersController` に `show` と `create` アクションを追加
- **Strong Parameters** を使った安全な属性受け取り
- `flash` を利用したメッセージ表示
- `form_with` によるサインアップフォーム
- ユーザー詳細ページ (`show`) の作成とGravatar表示
- エラーメッセージ表示用部分テンプレートの導入
- サインアップの統合テスト

## 🔧 実装の全体像

```
ユーザーがフォーム入力 
    ↓
UsersController#create でバリデーション
    ↓ (成功)        ↓ (失敗)
ユーザー詳細ページ   エラー表示付きフォーム
```

## 🔍 ファイル別レビューと解説

### app/controllers/users_controller.rb

#### 🎯 概要
ユーザーの表示(`show`)と登録(`create`)処理を実装し、**Strong Parameters** を導入しました。

**📝 解説ポイント：**
- `show`: URLのIDから特定ユーザーを取得・表示
- `create`: フォームデータを受け取り、バリデーション後に保存
- `user_params`: セキュリティのため許可する属性を明示的に指定

```diff
 class UsersController < ApplicationController
+
+  def show
+    @user = User.find(params[:id])
+  end
+
   def new
+    @user = User.new
   end
+
+  def create
+    @user = User.new(user_params)
+    if @user.save
+      flash[:success] = "Welcome to the Sample App!"
+      redirect_to @user
+    else
+      render 'new', status: :unprocessable_entity
+    end
+  end
+
+  private
+
+    def user_params
+      params.require(:user).permit(:name, :email, :password,
+                                   :password_confirmation)
+    end
 end
```

**🔑 キーポイント：**
- `redirect_to @user` は `user_path(@user)` の省略形
- `render 'new'` は新しいリクエストを送らず、フォームを再表示
- `:unprocessable_entity`（422）はバリデーションエラー時の適切なHTTPステータス

### app/helpers/users_helper.rb

#### 🎯 概要
ユーザーのメールアドレスからGravatar画像を取得する `gravatar_for` ヘルパーを追加しました。

**📝 解説ポイント：**
- **Gravatar**: メールアドレスに紐づくアバター画像サービス
- MD5ハッシュ化により、メールアドレスを安全にGravatarのURLに変換

```diff
 module UsersHelper
+
+  # 引数で与えられたユーザーのGravatar画像を返す
+  def gravatar_for(user)
+    gravatar_id  = Digest::MD5::hexdigest(user.email.downcase)
+    gravatar_url = "https://secure.gravatar.com/avatar/#{gravatar_id}"
+    image_tag(gravatar_url, alt: user.name, class: "gravatar")
+  end
 end
```

**🔑 キーポイント：**
- `downcase` でメールアドレスを小文字に統一（Gravatarの仕様）
- `image_tag` はRailsのHTMLヘルパー、`<img>`タグを生成

### app/views/layouts/application.html.erb

#### 🎯 概要
レイアウトに `flash` 表示とデバッグ用の `debug(params)` を追加しました。

**📝 解説ポイント：**
- **Flash**: 一度だけ表示されるメッセージ（リダイレクト後に自動削除）
- Bootstrap の `alert-success`、`alert-danger` クラスでスタイリング

```diff
     <%= render 'layouts/header' %>
     <div class="container">
+      <% flash.each do |message_type, message| %>
+        <div class="alert alert-<%= message_type %>"><%= message %></div>
+      <% end %>
       <%= yield %>
       <%= render 'layouts/footer' %>
+      <%= debug(params) if Rails.env.development? %>
     </div>
```

**🔑 キーポイント：**
- `flash[:success]` → `alert-success`、`flash[:danger]` → `alert-danger`
- デバッグ情報は開発環境でのみ表示

### app/views/shared/_error_messages.html.erb

#### 🎯 概要
フォーム送信時のバリデーションエラーをまとめて表示する**部分テンプレート**を新設しました。

**📝 解説ポイント：**
- **部分テンプレート**: 再利用可能なビューの断片（ファイル名は`_`で始まる）
- `pluralize`ヘルパーで単数形・複数形を自動調整

```diff
+<% if @user.errors.any? %>
+  <div id="error_explanation">
+    <div class="alert alert-danger">
+      The form contains <%= pluralize(@user.errors.count, "error") %>.
+    </div>
+    <ul>
+    <% @user.errors.full_messages.each do |msg| %>
+      <li><%= msg %></li>
+    <% end %>
+    </ul>
+  </div>
+<% end %>
```

**🔑 キーポイント：**
- `@user.errors.any?` でエラーの存在を確認
- `full_messages` で「Name can't be blank」形式のメッセージを取得

### app/views/users/new.html.erb

#### 🎯 概要
`form_with` を利用してユーザー登録フォームを作成し、エラー表示にも対応しました。

**📝 解説ポイント：**
- **`form_with`**: Rails 5.1以降の推奨フォームヘルパー
- `model: @user` でRESTfulな送信先（POST /users）を自動設定

```diff
 <% provide(:title, 'Sign up') %>
 <h1>Sign up</h1>
-
-<p>This will be a signup page for new users.</p>
+
+<div class="row">
+  <div class="col-md-6 col-md-offset-3">
+    <%= form_with(model: @user) do |f| %>
+      <%= render 'shared/error_messages' %>
+
+      <%= f.label :name %>
+      <%= f.text_field :name, class: 'form-control' %>
+
+      <%= f.label :email %>
+      <%= f.email_field :email, class: 'form-control' %>
+
+      <%= f.label :password %>
+      <%= f.password_field :password, class: 'form-control' %>
+
+      <%= f.label :password_confirmation, "Confirmation" %>
+      <%= f.password_field :password_confirmation, class: 'form-control' %>
+
+      <%= f.submit "Create my account", class: "btn btn-primary" %>
+    <% end %>
+  </div>
+</div>
```

**🔑 キーポイント：**
- `email_field` でHTML5のemailバリデーションが有効
- `password_field` で入力文字が隠される
- Bootstrapの`form-control`クラスで統一されたスタイル

### app/views/users/show.html.erb

#### 🎯 概要
登録完了後にユーザー情報を表示するページです。Gravatarとユーザー名を表示します。

**📝 解説ポイント：**
- 登録成功時のリダイレクト先
- `gravatar_for` ヘルパーでプロフィール画像を表示

```diff
+<% provide(:title, @user.name) %>
+<div class="row">
+  <aside class="col-md-4">
+    <section class="user_info">
+      <h1>
+        <%= gravatar_for @user %>
+        <%= @user.name %>
+      </h1>
+    </section>
+  </aside>
+</div>
```

**🔑 キーポイント：**
- `provide(:title, @user.name)` でページタイトルを動的設定
- `<aside>` でサイドバー領域を定義

### config/routes.rb

#### 🎯 概要
ユーザー関連の**RESTfulルーティング**を有効にしました。

**📝 解説ポイント：**
- `resources :users` で7つのRESTfulアクションを一括定義
- 現在使用するのは `show`、`new`、`create` のみ

```diff
   get  "/contact", to: "static_pages#contact"
   get  "/signup",  to: "users#new"
+  resources :users
 end
```

**🔑 キーポイント：**
- `POST /users` → `users#create`
- `GET /users/:id` → `users#show`
- `rails routes` コマンドで全ルートを確認可能

### test/integration/users_signup_test.rb

#### 🎯 概要
サインアップ処理の成功・失敗を検証する**統合テスト**を追加しました。

**📝 解説ポイント：**
- **統合テスト**: 複数のコントローラーやビューをまたいだテスト
- ユーザーの操作フローを実際に再現

```diff
+require "test_helper"
+
+class UsersSignupTest < ActionDispatch::IntegrationTest
+
+  test "invalid signup information" do
+    get signup_path
+    assert_no_difference 'User.count' do
+      post users_path, params: { user: { name:  "",
+                                         email: "user@invalid",
+                                         password:              "foo",
+                                         password_confirmation: "bar" } }
+    end
+    assert_response :unprocessable_entity
+    assert_template 'users/new'
+  end
+
+  test "valid signup information" do
+    assert_difference 'User.count', 1 do
+      post users_path, params: { user: { name:  "Example User",
+                                         email: "user@example.com",
+                                         password:              "password",
+                                         password_confirmation: "password" } }
+    end
+    follow_redirect!
+    assert_template 'users/show'
+  end
+end
```

**🔑 キーポイント：**
- `assert_no_difference` / `assert_difference` でデータベースの変化を検証
- `follow_redirect!` でリダイレクト先のページをテスト
- `assert_template` で正しいビューが表示されているか確認

### app/assets/stylesheets/custom.scss

#### 🎯 概要
フォームやサイドバーのスタイルを整えるため多くのスタイルを追加しました。代表的な追加部分を抜粋します。

**📝 解説ポイント：**
- **Sass mixin**: CSS関数のような再利用可能なスタイル
- レスポンシブデザインに対応したレイアウト

```diff
 $gray-medium-light: #eaeaea;
 
+@mixin box_sizing {
+  -moz-box-sizing:    border-box;
+  -webkit-box-sizing: border-box;
+  box-sizing:         border-box;
+}
@@
 footer {
@@
 }
+
+/* miscellaneous */
+
+.debug_dump {
+  clear: both;
+  float: left;
+  width: 100%;
+  margin-top: 45px;
+}
+
+/* sidebar */
+
+aside {
+  section.user_info {
+    margin-top: 20px;
+  }
+  section {
+    padding: 10px 0;
+    margin-top: 20px;
+    &:first-child {
+      border: 0;
+      padding-top: 0;
+    }
+    span {
+      display: block;
+      margin-bottom: 3px;
+      line-height: 1;
+    }
+    h1 {
+      font-size: 1.4em;
+      text-align: left;
+      letter-spacing: -1px;
+      margin-bottom: 3px;
+      margin-top: 0px;
+    }
+  }
+}
+
+.gravatar {
+  float: left;
+  margin-right: 10px;
+}
+
+.gravatar_edit {
+  margin-top: 15px;
+}
+
+/* forms */
+
+input, textarea {
+  border: 1px solid #bbb;
+  width: 100%;
+  margin-bottom: 15px;
+  @include box_sizing;
+}
+
+input {
+  height: auto !important;
+}
+
+#error_explanation {
+  color: red;
+  ul {
+    color: red;
+    margin: 0 0 30px 0;
+  }
+}
+
+.field_with_errors {
+  @extend .has-error;
+  .form-control {
+    color: $state-danger-text;
+  }
+}
```

## 💡 学習のコツ

### 実装順序を理解しよう
1. **ルーティング設定** → どのURLがどのアクションに対応するか
2. **コントローラー** → リクエストを受けてどう処理するか  
3. **ビュー** → ユーザーに何を表示するか
4. **テスト** → 実装が正しく動作するか検証

### よくあるエラーと対処法
- **NoMethodError** → コントローラーでインスタンス変数を設定し忘れ
- **UnknownAttributeError** → Strong Parametersの設定漏れ
- **Template is missing** → ビューファイルの作成し忘れ

## 🧠 まとめ

ユーザー登録機能の追加により、モデルだけだったユーザー情報が画面から作成できるようになりました。**MVCアーキテクチャ**の全体像を理解し、以下の重要概念を押さえましょう：

- **RESTfulルーティング**: 標準的なWebアプリケーションのURL設計
- **Strong Parameters**: セキュリティを考慮した安全なデータ受け取り
- **Flash**: ユーザーへの一時的なメッセージ表示
- **統合テスト**: 実際のユーザー操作をシミュレートした品質保証

次章では、ログイン・ログアウト機能でセッション管理を学びます。
