# ch13 マイクロポスト (from ch12)

## 🔥 はじめに：本章で越えるべき山

この章ではユーザーがテキストと画像を投稿できる「マイクロポスト」を実装します。Active Storage を導入し、ユーザーとマイクロポストの関連付けや投稿一覧の表示を学びます。

**本章の重要性**：
- **ソーシャル機能の核心**：Twitter的な投稿システムの構築
- **ファイルアップロード**：Modern Webアプリに必須の画像処理
- **関連性の設計**：User ↔ Micropost の適切な関係性
- **スケーラビリティ**：大量投稿に対応するアーキテクチャ

## ✅ 学習ポイント一覧

- **Active Storage による画像アップロード**機能の実装
- **`Micropost` モデル**とユーザーとの関連付け
- **`logged_in_user` フィルタの共通化**による DRY 原則
- **フィード表示用の部分テンプレート**活用
- **マイクロポスト用の統合テスト**によるQA強化

## 🔧 実装の全体像

```
[マイクロポスト機能のアーキテクチャ]

データ層:
  User (1) ←→ (多) Micropost
  ├─ has_many :microposts
  └─ dependent: :destroy

機能層:
  ├─ 投稿作成: MicropostsController#create
  ├─ 投稿削除: MicropostsController#destroy  
  ├─ フィード表示: User#feed
  └─ 画像処理: Active Storage + AWS S3

UI層:
  ├─ ホーム: 投稿フォーム + フィード
  ├─ プロフィール: ユーザーの投稿一覧
  └─ 共通: パーシャルテンプレートによる再利用

[Active Storage の画像処理フロー]
1. ユーザーが画像選択
2. JavaScript でサイズ検証 (5MB以下)
3. サーバーでファイル形式検証
4. 本番環境: AWS S3 に保存
5. 開発環境: ローカルストレージに保存
6. 画像リサイズ: 500x500px 以下に自動調整
```

## 🔍 ファイル別レビューと解説

### app/controllers/application_controller.rb

#### 🎯 概要
`logged_in_user` メソッドを ApplicationController に移し、他のコントローラから再利用できるようになりました。

#### 🧠 解説
共通的なログイン確認処理を基底クラスに移動し、DRY原則を徹底しました。

**設計改善のポイント**：
- **継承の活用**: 全コントローラで利用可能
- **責任の集約**: 認証ロジックの一元管理
- **フレンドリーフォワーディング**: `store_location` でUX向上

**共通化による効果**：
- コードの重複削除
- 認証ロジックの統一
- メンテナンス性の向上

```diff
@@
 class ApplicationController < ActionController::Base
   include SessionsHelper
+
+  private
+
+    # ユーザーのログインを確認する
+    def logged_in_user
+      unless logged_in?
+        store_location
+        flash[:danger] = "Please log in."
+        redirect_to login_url, status: :see_other
+      end
+    end
 end
```

### app/controllers/users_controller.rb

#### 🎯 概要
ユーザー詳細ページでマイクロポスト一覧を取得します。また `logged_in_user` は ApplicationController に移動しました。

#### 🧠 解説
ユーザープロフィールページにマイクロポスト表示機能を追加し、共通メソッドの移動でコードを整理しました。

**機能追加の詳細**：
- **`@microposts`**: ユーザーの投稿をページネーション付きで取得
- **関連読み込み**: `@user.microposts` で効率的なDB検索
- **ページング**: `will_paginate` で大量投稿に対応

**リファクタリングの効果**：
- **DRY原則**: 重複コードの削除
- **保守性向上**: 認証ロジックの一元管理
- **拡張性**: 他のコントローラでも同じメソッドを利用可能

```diff
@@
   def show
     @user = User.find(params[:id])
+    @microposts = @user.microposts.paginate(page: params[:page])
   end
@@
-    def logged_in_user
-      unless logged_in?
-        store_location
-        flash[:danger] = "Please log in."
-        redirect_to login_url, status: :see_other
-      end
-    end
```

### app/controllers/static_pages_controller.rb

#### 🎯 概要
ログインしている場合はホーム画面で投稿フォームとフィードを表示します。

#### 🧠 解説
ホームページをダイナミックにし、ログイン状態に応じて異なるコンテンツを表示するようになりました。

**条件分岐の設計**：
- **ログイン時**: 投稿フォーム + フィード表示
- **未ログイン時**: 従来のウェルカムページ

**データ準備の仕組み**：
- **`@micropost`**: 新規投稿用の空オブジェクト（`build`メソッド）
- **`@feed_items`**: ユーザーのフィードをページネーション付きで取得

**UX設計の考慮**：
- **文脈的な表示**: ユーザーの状態に応じた適切なコンテンツ
- **アクションの促進**: ログイン時は投稿を促す UI

```diff
@@
   def home
-  end
+    if logged_in?
+      @micropost  = current_user.microposts.build
+      @feed_items = current_user.feed.paginate(page: params[:page])
+    end
+  end
```

### app/controllers/microposts_controller.rb

#### 🎯 概要
新たにマイクロポストの作成・削除を管理するコントローラが追加されました。

#### 🧠 解説
マイクロポストのCRUD操作（Create・Delete）を専門的に管理する新規コントローラーです。

**セキュリティ設計**：
- **`logged_in_user`**: 認証必須（投稿・削除）
- **`correct_user`**: 投稿者本人のみ削除可能

**`create` アクションの詳細**：
1. **投稿作成**: `current_user.microposts.build` で関連付け
2. **画像添付**: `image.attach` でActive Storage連携
3. **成功時**: ホームページにリダイレクト
4. **失敗時**: フィードを再取得してホーム画面を再表示

**`destroy` アクションの工夫**：
- **リファラー対応**: 元のページに戻る or ホームページ
- **安全な削除**: `correct_user` フィルタで権限確認
- **適切なステータス**: `:see_other` でブラウザキャッシュ対策

**Strong Parameters**：
- **許可属性**: `:content, :image` のみ受け取り
- **セキュリティ**: 不正な属性の更新を防止

```diff
+class MicropostsController < ApplicationController
+  before_action :logged_in_user, only: [:create, :destroy]
+  before_action :correct_user,   only: :destroy
+
+  def create
+    @micropost = current_user.microposts.build(micropost_params)
+    @micropost.image.attach(params[:micropost][:image])
+    if @micropost.save
+      flash[:success] = "Micropost created!"
+      redirect_to root_url
+    else
+      @feed_items = current_user.feed.paginate(page: params[:page])
+      render 'static_pages/home', status: :unprocessable_entity
+    end
+  end
+
+  def destroy
+    @micropost.destroy
+    flash[:success] = "Micropost deleted"
+    if request.referrer.nil? || request.referrer == microposts_url
+      redirect_to root_url, status: :see_other
+    else
+      redirect_to request.referrer, status: :see_other
+    end
+  end
+
+  private
+
+    def micropost_params
+      params.require(:micropost).permit(:content, :image)
+    end
+
+    def correct_user
+      @micropost = current_user.microposts.find_by(id: params[:id])
+      redirect_to root_url, status: :see_other if @micropost.nil?
+    end
+end
```

### app/models/user.rb

#### 🎯 概要
ユーザーは複数のマイクロポストを所有し、簡単なフィードを取得できるようになりました。

#### 🧠 解説
UserモデルにMicropostとの関連付けとフィード機能を追加しました。

**関連付けの設計**：
- **`has_many :microposts`**: 1ユーザー → 多投稿
- **`dependent: :destroy`**: ユーザー削除時に投稿も削除

**フィード機能（第1版）**：
- **現在の実装**: 自分の投稿のみ表示
- **将来の拡張**: フォロー機能追加時にフォロー先の投稿も含める
- **SQL最適化**: WHERE句で効率的な検索

**設計の思想**：
- **段階的実装**: まず基本機能、後で拡張
- **拡張性考慮**: フォロー機能実装時の準備
- **パフォーマンス**: SQLクエリの最適化

```diff
@@
 class User < ApplicationRecord
+  has_many :microposts, dependent: :destroy
@@
   def password_reset_expired?
     reset_sent_at < 2.hours.ago
   end
+
+  # 試作feedの定義
+  # 完全な実装は次章の「ユーザーをフォローする」を参照
+  def feed
+    Micropost.where("user_id = ?", id)
+  end
```

### app/models/micropost.rb

#### 🎯 概要
マイクロポストモデルでは画像添付と基本的なバリデーションを設定しています。

#### 🧠 解説
Micropostモデルの完全な実装で、Active Storage、バリデーション、並び順を定義しています。

**Active Storage の活用**：
- **`has_one_attached :image`**: 1投稿に1画像を添付
- **`variant :display`**: 500x500px以下にリサイズ
- **画像最適化**: 表示時の自動リサイズ

**バリデーション設計**：
- **`user_id`**: 投稿者の必須指定
- **`content`**: 1-140文字の投稿内容
- **`image`**: JPEG/GIF/PNG、5MB以下

**デフォルトスコープ**：
- **時系列順**: 新しい投稿から表示
- **`order(created_at: :desc)`**: 降順ソート

**セキュリティ考慮**：
- **ファイル形式制限**: 安全な画像形式のみ
- **サイズ制限**: サーバー負荷軽減
- **適切なエラーメッセージ**: ユーザーへの明確な指示

```diff
+class Micropost < ApplicationRecord
+  belongs_to :user
+  has_one_attached :image do |attachable|
+    attachable.variant :display, resize_to_limit: [500, 500]
+  end
+  default_scope -> { order(created_at: :desc) }
+  validates :user_id, presence: true
+  validates :content, presence: true, length: { maximum: 140 }
+  validates :image,   content_type: { in: %w[image/jpeg image/gif image/png],
+                                      message: "must be a valid image format" },
+                      size:         { less_than: 5.megabytes,
+                                      message:   "should be less than 5MB" }
+end
```

### config/routes.rb

#### 🎯 概要
マイクロポスト用のルーティングを追加しました。

#### 🧠 解説
RESTfulなマイクロポストルーティングを追加し、適切なアクセス制御を実現しています。

**ルーティング設計**：
- **`only: [:create, :destroy]`**: 必要な操作のみ提供
- **セキュリティ**: 編集・一覧表示は提供しない

**特別なルーティング**：
- **`get '/microposts'`**: static_pages#home へリダイレクト
- **用途**: 直接 `/microposts` アクセス時の適切な誘導

**RESTful設計の考慮**：
- 投稿は個別表示せず、フィードやプロフィールで表示
- 編集機能は提供せず、削除・再投稿のシンプルなUX

```diff
@@
   resources :password_resets,     only: [:new, :create, :edit, :update]
+  resources :microposts,          only: [:create, :destroy]
+  get '/microposts', to: 'static_pages#home'
 end
```

### app/views/static_pages/home.html.erb

#### 🎯 概要
ログイン状態に応じて投稿フォームとフィードを表示します。

#### 🧠 解説
ホームページをパーソナライズし、ログイン状態に応じて動的にコンテンツを切り替えるようになりました。

**条件分岐の設計**：
- **ログイン時**: パーソナライズされたダッシュボード
- **未ログイン時**: マーケティング用のランディングページ

**ログイン時のレイアウト**：
- **左サイドバー（4列）**: 
  - ユーザー情報（`shared/user_info`）
  - 投稿フォーム（`shared/micropost_form`）
- **メインコンテンツ（8列）**: 
  - フィード表示（`shared/feed`）

**未ログイン時の改善**：
- **画像属性修正**: `width: "200px"` で適切なサイズ指定
- **レスポンシブ対応**: Bootstrapのグリッドシステム活用

**UX設計のポイント**：
- **文脈適応**: ユーザーの状態に応じた最適なコンテンツ
- **アクション誘導**: ログイン時は投稿を促進、未ログイン時は登録を促進

```diff
@@
-<div class="center jumbotron">
-  <h1>Welcome to the Sample App</h1>
+<% if logged_in? %>
+  <div class="row">
+    <aside class="col-md-4">
+      <section class="user_info">
+        <%= render 'shared/user_info' %>
+      </section>
+      <section class="micropost_form">
+        <%= render 'shared/micropost_form' %>
+      </section>
+    </aside>
+    <div class="col-md-8">
+      <h3>Micropost Feed</h3>
+      <%= render 'shared/feed' %>
+    </div>
+  </div>
+<% else %>
+  <div class="center jumbotron">
+    <h1>Welcome to the Sample App</h1>
     <h2>
       This is the home page for the
       <a href="https://railstutorial.jp/">Ruby on Rails Tutorial</a>
       sample application.
     </h2>
-  <%= link_to "Sign up now!", signup_path, class: "btn btn-lg btn-primary" %>
-</div>
-<%= link_to image_tag("rails.svg", alt: "Rails logo", width: "200"),
-                      "https://rubyonrails.org/" %>
+    <%= link_to "Sign up now!", signup_path, class: "btn btn-lg btn-primary" %>
+  </div>
+  <%= link_to image_tag("rails.svg", alt: "Rails logo", width: "200px"),
+              "https://rubyonrails.org/" %>
+<% end %>
```

### app/views/users/show.html.erb

#### 🎯 概要
プロフィール画面に投稿数と一覧を表示します。

#### 🧠 解説
ユーザープロフィールページにマイクロポスト一覧機能を追加し、包括的なユーザー情報を表示するようになりました。

**情報表示の設計**：
- **投稿数表示**: `@user.microposts.count` で統計情報
- **条件分岐**: `@user.microposts.any?` で投稿があるかチェック
- **ページネーション**: `will_paginate @microposts` で大量投稿対応

**レイアウトの改善**：
- **8列グリッド**: メインコンテンツエリアの拡張
- **順序リスト**: `<ol>` で投稿の順序性を明示
- **パーシャル活用**: `render @microposts` で効率的な表示

**UX配慮**：
- **投稿がない場合**: 何も表示しない（空状態の適切な処理）
- **投稿がある場合**: 数と一覧を明確に表示
- **ナビゲーション**: ページングによる快適な閲覧

```diff
@@
   </aside>
+  <div class="col-md-8">
+    <% if @user.microposts.any? %>
+      <h3>Microposts (<%= @user.microposts.count %>)</h3>
+      <ol class="microposts">
+        <%= render @microposts %>
+      </ol>
+      <%= will_paginate @microposts %>
+    <% end %>
+  </div>
 </div>
```

### app/views/shared/_error_messages.html.erb

#### 🎯 概要
`object` 引数を受け取るようにして、ユーザー以外のフォームでも利用可能にしました。

#### 🧠 解説
エラーメッセージ表示を汎用化し、ユーザーフォーム以外でも再利用できるようになりました。

**汎用化の効果**：
- **再利用性向上**: Micropost、User、その他のモデルで共通利用
- **DRY原則**: 同じコードの重複を削除
- **保守性**: エラー表示ロジックの一元管理

**使用例**：
```erb
<!-- ユーザーフォーム -->
<%= render 'shared/error_messages', object: @user %>

<!-- マイクロポストフォーム -->
<%= render 'shared/error_messages', object: f.object %>
```

**設計の改善**：
- **引数化**: `@user` から `object` への抽象化
- **柔軟性**: 任意のActive Recordオブジェクトに対応
- **統一性**: 全フォームで一貫したエラー表示

```diff
-<% if @user.errors.any? %>
+<% if object.errors.any? %>
@@
-      The form contains <%= pluralize(@user.errors.count, "error") %>.
+      The form contains <%= pluralize(object.errors.count, "error") %>.
@@
-    <% @user.errors.full_messages.each do |msg| %>
+    <% object.errors.full_messages.each do |msg| %>
```

### app/views/shared/_micropost_form.html.erb

#### 🎯 概要
新規投稿フォームの部分テンプレートです。

#### 🧠 解説
マイクロポスト投稿用の専用フォームを実装しました。テキストと画像の両方に対応しています。

**フォームの構成要素**：
- **`form_with`**: Rails 7対応の最新フォームヘルパー
- **エラー表示**: 汎用化された `error_messages` パーシャル
- **テキストエリア**: `placeholder` でユーザーガイダンス
- **ファイル選択**: `accept` 属性で画像ファイルのみ受け付け

**ユーザビリティの工夫**：
- **プレースホルダー**: "Compose new micropost..." で操作誘導
- **ファイル制限**: JPEG、GIF、PNG のみ受け付け
- **視覚的配置**: 投稿ボタンと画像選択の適切な配置

**セキュリティ考慮**：
- **ファイル形式制限**: `accept` 属性でクライアント側フィルタ
- **サーバー側検証**: モデルレベルでの二重チェック

```diff
+<%= form_with(model: @micropost) do |f| %>
+  <%= render 'shared/error_messages', object: f.object %>
+  <div class="field">
+    <%= f.text_area :content, placeholder: "Compose new micropost..." %>
+  </div>
+  <%= f.submit "Post", class: "btn btn-primary" %>
+  <span class="image">
+    <%= f.file_field :image, accept: "image/jpeg,image/gif,image/png" %>
+  </span>
+<% end %>
```

### app/javascript/application.js

#### 🎯 概要
画像アップロードサイズを制御する JavaScript を読み込みます。

#### 🧠 解説
JavaScript モジュールを追加し、画像アップロード機能を強化しました。

**モジュール管理の改善**：
- **`import "custom/image_upload"`**: 画像アップロード専用JS
- **モジュール分離**: 機能ごとの適切な分割
- **保守性**: 各機能の独立管理

**従来機能との統合**：
- **Turbo**: SPA的な動作
- **Stimulus**: コントローラー管理
- **カスタムメニュー**: ナビゲーション機能

```diff
@@
 import "@hotwired/turbo-rails"
 import "controllers"
 import "custom/menu"
+import "custom/image_upload"
```

### app/javascript/custom/image_upload.js

#### 🎯 概要
5MB を超える画像を選択した場合に警告を表示して投稿を防ぎます。

#### 🧠 解説
クライアント側での画像サイズ検証を実装し、大容量ファイルのアップロードを事前に防止します。

**JavaScript の仕組み**：
- **`turbo:load`**: Turbo対応のDOMContentLoaded
- **`change` イベント**: ファイル選択時の自動検証
- **サイズ計算**: `files[0].size/1024/1024` でMB変換

**ユーザビリティの向上**：
- **即座のフィードバック**: ファイル選択と同時に検証
- **明確なメッセージ**: "Maximum file size is 5MB..."
- **操作の取り消し**: `image_upload.value = ""` でフィールドクリア

**パフォーマンス考慮**：
- **サーバー負荷軽減**: 大容量ファイルの送信前チェック
- **帯域幅節約**: 不要な通信の削減
- **UX向上**: 待ち時間の短縮

**セキュリティの多層防御**：
- **クライアント側**: JavaScript による事前チェック
- **サーバー側**: モデルバリデーションによる確実なチェック

```javascript
// 巨大画像のアップロードを防止する
document.addEventListener("turbo:load", function() {
  document.addEventListener("change", function(event) {
    let image_upload = document.querySelector('#micropost_image');
    if (image_upload && image_upload.files.length > 0) {
      const size_in_megabytes = image_upload.files[0].size/1024/1024;
      if (size_in_megabytes > 5) {
        alert("Maximum file size is 5MB. Please choose a smaller file.");
        image_upload.value = "";
      }
    }
  });
});
```

### db/seeds.rb

初期データとして各ユーザーに複数のマイクロポストを生成します。
```diff
@@
 User.create!(name:  name,
@@
 end
+
+# ユーザーの一部を対象にマイクロポストを生成する
+users = User.order(:created_at).take(6)
+50.times do
+  content = Faker::Lorem.sentence(word_count: 5)
+  users.each { |user| user.microposts.create!(content: content) }
+end
```

### config/environments/production.rb

本番環境では画像を AWS S3 に保存します。
```diff
-  # Store uploaded files on the local file system (see config/storage.yml for options).
-  config.active_storage.service = :local
+  # アップロードされたファイルをAWSに保存する
+  config.active_storage.service = :amazon
```

### config/storage.yml

S3 用の設定を追加しました。

```diff
--- 7_0/ch12/config/storage.yml	2025-07-23 14:14:02
+++ 7_0/ch13/config/storage.yml	2025-07-23 14:14:02
@@ -6,29 +6,9 @@
   service: Disk
   root: <%= Rails.root.join("storage") %>
 
-# Use bin/rails credentials:edit to set the AWS secrets (as aws:access_key_id|secret_access_key)
-# amazon:
-#   service: S3
-#   access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
-#   secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
-#   region: us-east-1
-#   bucket: your_own_bucket-<%= Rails.env %>
-
-# Remember not to checkin your GCS keyfile to a repository
-# google:
-#   service: GCS
-#   project: your_project
-#   credentials: <%= Rails.root.join("path/to/gcs.keyfile") %>
-#   bucket: your_own_bucket-<%= Rails.env %>
-
-# Use bin/rails credentials:edit to set the Azure Storage secret (as azure_storage:storage_access_key)
-# microsoft:
-#   service: AzureStorage
-#   storage_account_name: your_account_name
-#   storage_access_key: <%= Rails.application.credentials.dig(:azure_storage, :storage_access_key) %>
-#   container: your_container_name-<%= Rails.env %>
-
-# mirror:
-#   service: Mirror
-#   primary: local
-#   mirrors: [ amazon, google, microsoft ]
+amazon:
+  service: S3
+  access_key_id:     <%= ENV['AWS_ACCESS_KEY_ID'] %>
+  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
+  region:            <%= ENV['AWS_REGION'] %>
+  bucket:            <%= ENV['AWS_BUCKET'] %>
```

## 🧠 まとめ

マイクロポストの追加により、ユーザーは短い投稿と画像をアップロードできるようになりました。Active Storage を導入したことで、ファイルの保存先を簡単に切り替えられます。投稿フォームやフィードの表示には部分テンプレートを活用し、コードの再利用性と可読性が向上しました。
