# ch13 マイクロポスト (from ch12)

# ch13 マイクロポスト (from ch12)

## � 現代ソーシャルメディアの心臓部を実装する

> **💭 Learning Philosophy**: この章は単なる「投稿機能」を超えた体験を提供します。Twitter、Instagram、TikTokの核心となる仕組みを、あなた自身の手で構築していく旅です。

## 🔥 この章で得られる革命的な力

**💡 技術的マスタリー**：
- **Modern File Handling**: Active Storageによる次世代ファイル管理
- **Relational Design**: User ↔ Micropost の美しい関係性設計
- **Real-time Experience**: フィード機能による動的コンテンツ配信
- **Security First**: 認証・認可による堅牢なデータ保護

**🎯 ビジネス理解**：
- ソーシャルプラットフォームの設計思想
- ユーザーエンゲージメント向上の仕組み
- スケーラブルなコンテンツ管理手法

## ✨ 実装する未来的機能

### 📝 Micropost System - デジタル表現の基盤
140文字制限、タイムスタンプ、リアルタイム更新を持つ投稿システム

### 🎪 Dynamic Feed - パーソナライズされた体験
各ユーザーに最適化されたコンテンツストリーム

### 🖼️ Media Upload - マルチメディア対応
Active Storageによるモダンな画像・動画処理

### 🛡️ Security Layer - 信頼できるプラットフォーム
投稿権限の適切な制御とデータ保護

## 🎖️ 学習ミッション達成リスト

- **🎯 Mission 1**: Active Storage による革新的画像アップロード機能の実装
- **🎯 Mission 2**: `Micropost` モデルとユーザーとの美しい関連付け設計
- **🎯 Mission 3**: `logged_in_user` フィルタの共通化による究極のDRY原則実現
- **🎯 Mission 4**: フィード表示用部分テンプレートによるモジュラー設計
- **🎯 Mission 5**: マイクロポスト統合テストによる品質保証体制構築

---

## 📋 実装する機能の全体像

### 🏗️ アーキテクチャ設計
```
User (1) ←→ (many) Micropost
     ↓
   Feed System ← Dynamic Content
     ↓
 Image Upload ← Active Storage
```

### 🎮 ユーザー体験フロー
1. **投稿作成**: テキスト + 画像の組み合わせ投稿
2. **フィード閲覧**: パーソナライズされたタイムライン
3. **投稿管理**: 自分の投稿の削除・編集
4. **プロフィール**: 個人投稿履歴の表示

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

### app/controllers/application_controller.rb

#### 💡 変革ポイント: 共通認証ロジックの中央集約化

#### 🚀 技術的革新

この変更は**DRY原則**の真の実現です。`logged_in_user`メソッドを基底クラスに移動することで、全コントローラが統一された認証機能を享受できます。

**アーキテクチャ的メリット**:

- **継承の威力**: 全コントローラで即座に利用可能
- **保守性の向上**: 認証ロジックの変更が一箇所で完結  
- **品質向上**: コードの重複削除による一貫性確保
- **拡張性**: 新しいコントローラでも自動的に認証機能が利用可能

**UX向上への貢献**:

- **フレンドリーフォワーディング**: `store_location` でログイン後の適切なリダイレクト
- **統一されたセキュリティ体験**: 全機能で一貫した認証フロー

**実装の美しさ**: 
たった数行の移動で、アプリケーション全体のセキュリティアーキテクチャが劇的に改善されます。これこそが**設計パターンの力**です。

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

### app/controllers/static_pages_controller.rb

#### � ホーム画面の華麗なる変身

#### 🎭 動的コンテンツの魔法

ホーム画面が静的なウェルカムページから、**パーソナライズされたダッシュボード**へと進化しました。

**革新的な実装**:

- **文脈的UI**: ログイン状態に応じた画面の自動切り替え
- **投稿システム統合**: シームレスな投稿体験の提供  
- **フィード機能**: リアルタイム更新される投稿ストリーム

**データフローの設計**：

- **`@micropost`**: 新規投稿用オブジェクト（`current_user.microposts.build`）
- **`@feed_items`**: パーソナライズされたフィード（ページネーション対応）

**ユーザー体験の革命**:

- **即座の価値提供**: ログイン後すぐに投稿・閲覧が可能
- **直感的操作**: 複雑な画面遷移を排除した一画面完結型UI
- **エンゲージメント向上**: 常に最新コンテンツへのアクセス

**設計思想**: 
モダンなソーシャルメディアの基本原則である「**コンテンツファースト**」を実現。ユーザーがアプリを開いた瞬間から価値のある体験を提供します。

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

### app/controllers/microposts_controller.rb

#### 🎯 投稿システムの司令塔

#### 🚀 REST設計の真髄

マイクロポスト機能の**核心となるコントローラ**です。作成・削除の2つのアクションに絞り込んだシンプルかつ強力な設計。

**セキュリティファースト設計**:

- **認証ガード**: `logged_in_user` フィルタで不正アクセスを完全ブロック
- **権限チェック**: `correct_user` で投稿者のみが削除可能
- **Strong Parameters**: XSS/SQLインジェクション攻撃の完全防御

**`create` アクションの革新**：

1. **自動関連付け**: `current_user.microposts.build` でデータ整合性保証
2. **メディア処理**: `image.attach` でActive Storage連携
3. **UXフロー**: 成功時は即座にホームページで成果確認
4. **エラー処理**: 失敗時はフィード込みで再表示（状態保持）

**`destroy` アクションの工夫**：

- **スマートリダイレクト**: リファラー対応で自然な画面遷移
- **セキュアな削除**: `correct_user` フィルタで厳格な所有権確認
- **HTTPステータス**: `:see_other` でブラウザキャッシュ最適化

**実装哲学**: 
「**Simple is Beautiful**」- 必要最小限の機能で最大限の価値を提供。Twitterの成功要因である「制約による創造性」と同じ設計思想です。

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

### app/models/user.rb

#### � ユーザーモデルの進化

#### 🔗 リレーションシップ設計の芸術

Userモデルに**マイクロポスト機能**と**フィードシステム**が統合され、ソーシャルメディアの基盤が完成しました。

**データモデリングの革新**:

- **1対多関係**: `has_many :microposts` でユーザーと投稿の美しい関連付け
- **依存性管理**: `dependent: :destroy` でデータ整合性の完全保証
- **カスケード削除**: ユーザー削除時に関連投稿も自動削除

**フィードシステムの段階的実装**:

**現在の段階**: シンプルな自分投稿フィード
```ruby
def feed
  microposts  # 自分の投稿のみ
end
```

**将来の拡張**: フォロー機能追加後
```ruby
def feed
  following_ids = "SELECT followed_id FROM relationships WHERE follower_id = :user_id"
  Micropost.where("user_id IN (#{following_ids}) OR user_id = :user_id", user_id: id)
end
```

**設計思想の優秀性**:

- **段階的進化**: まず基本機能を確実に動作させる
- **拡張性**: フォロー機能の基盤を既に内包
- **パフォーマンス**: SQLサブクエリによる効率的なデータ取得

**アーキテクチャの美しさ**: 
現在は「自分の投稿のみ」というシンプルな実装ですが、将来的にフォロー機能が追加された際にシームレスに拡張できる設計になっています。これが**Future-Proof Design**の見本です。

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

### app/views/microposts/_micropost.html.erb

#### 🎯 概要
個別のマイクロポスト表示用の部分テンプレートです。フィードやプロフィールページで使用されます。

#### 🧠 解説
単一のマイクロポストを表示するための専用パーシャルです。ユーザー情報、投稿内容、画像、削除機能を統合しています。

**表示要素の構成**：
- **ユーザー情報**: Gravatarとユーザー名のリンク
- **投稿内容**: テキストと添付画像の表示
- **タイムスタンプ**: 投稿時間の人間らしい表現
- **削除機能**: 投稿者のみに表示される削除リンク

**UX設計のポイント**：
- **視覚的階層**: ユーザー → 内容 → 時間・操作の順序
- **条件分岐**: 画像がある場合のみ表示
- **権限制御**: `current_user?` で削除権限をチェック

**セキュリティ考慮**：
- **Turbo確認**: 削除時の確認ダイアログ
- **適切なHTTPメソッド**: `data: { "turbo-method": :delete }`
- **権限チェック**: 投稿者本人のみ削除可能

```erb
<li id="micropost-<%= micropost.id %>">
  <%= link_to gravatar_for(micropost.user, size: 50), micropost.user %>
  <span class="user"><%= link_to micropost.user.name, micropost.user %></span>
  <span class="content">
    <%= micropost.content %>
    <% if micropost.image.attached? %>
      <%= image_tag micropost.image.variant(:display) %>
    <% end %>
  </span>
  <span class="timestamp">
    Posted <%= time_ago_in_words(micropost.created_at) %> ago.
    <% if current_user?(micropost.user) %>
      <%= link_to "delete", micropost, data: { "turbo-method": :delete,
                                               turbo_confirm: "You sure?" } %>
    <% end %>
  </span>
</li>
```

### app/views/shared/_feed.html.erb

#### 🎯 概要
フィード表示用の部分テンプレートです。ホームページでマイクロポスト一覧を表示します。

#### 🧠 解説
ユーザーのフィードを表示する専用パーシャルです。ページネーション機能と統合し、効率的な大量データ表示を実現しています。

**機能的特徴**：
- **条件分岐**: `@feed_items.any?` で投稿がある場合のみ表示
- **順序リスト**: `<ol>` で投稿の時系列順序を明示
- **パーシャル活用**: `render @feed_items` で効率的な一括表示
- **ページネーション**: 特別なパラメータ付きでホームページ対応

**パフォーマンス最適化**：
- **遅延読み込み**: ページごとの分割表示
- **効率的レンダリング**: Railsの自動パーシャル選択機能活用
- **適切なパラメータ**: `controller: :static_pages, action: :home`

**UX配慮**：
- **空状態対応**: 投稿がない場合は何も表示しない
- **ナビゲーション**: ページング機能で快適な閲覧体験

```erb
<% if @feed_items.any? %>
  <ol class="microposts">
    <%= render @feed_items %>
  </ol>
  <%= will_paginate @feed_items,
                    params: { controller: :static_pages, action: :home } %>
<% end %>
```

### app/views/shared/_user_info.html.erb

#### 🎯 概要
ログインユーザーの基本情報表示用の部分テンプレートです。ホームページのサイドバーで使用されます。

#### 🧠 解説
ホームページにユーザーの簡潔な情報を表示する専用パーシャルです。プロフィールへの導線と投稿統計を提供します。

**表示情報の構成**：
- **プロフィール画像**: Gravatar（50pxサイズ）でユーザーページへリンク
- **ユーザー名**: `<h1>` でメインの識別情報として表示
- **プロフィールリンク**: "view my profile" で詳細ページへ誘導
- **投稿統計**: `pluralize` で投稿数を適切な単数/複数形で表示

**UX設計の工夫**：
- **視覚的ヒエラルキー**: 画像 → 名前 → リンク → 統計の順序
- **適切なリンク**: 画像とテキストの両方からプロフィールアクセス可能
- **統計の可視化**: 投稿数でユーザーの活動レベルを表示

**機能的価値**：
- **アイデンティティ確認**: 現在ログイン中のユーザーを明確化
- **行動促進**: プロフィール閲覧への自然な誘導
- **活動可視化**: 投稿数による達成感の提供

```erb
<%= link_to gravatar_for(current_user, size: 50), current_user %>
<h1><%= current_user.name %></h1>
<span><%= link_to "view my profile", current_user %></span>
<span><%= pluralize(current_user.microposts.count, "micropost") %></span>
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

### db/migrate/20231219022307_create_microposts.rb

#### 🎯 概要
マイクロポストテーブルを作成するマイグレーションファイルです。

#### 🧠 解説
マイクロポスト機能の基盤となるデータベーステーブルを定義します。ユーザーとの関連付けと効率的な検索のためのインデックスを設定しています。

**テーブル設計のポイント**：
- **`content` カラム**: `:text` 型で長文投稿に対応
- **`user_id` カラム**: 外部キー制約付きでデータ整合性を確保
- **`timestamps`**: 作成・更新時間の自動管理

**パフォーマンス最適化**：
- **複合インデックス**: `[:user_id, :created_at]` で効率的なフィード取得
- **外部キー制約**: `foreign_key: true` でデータ整合性を保証
- **`null: false`**: 必須フィールドの明示的指定

**設計思想**：
- **拡張性**: 将来的な機能追加に対応可能な柔軟な構造
- **整合性**: リレーショナルDBの制約を活用した堅牢性
- **効率性**: よく使用されるクエリパターンを想定したインデックス設計

```ruby
class CreateMicroposts < ActiveRecord::Migration[7.0]
  def change
    create_table :microposts do |t|
      t.text :content
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :microposts, [:user_id, :created_at]
  end
end
```

### db/migrate/20231219032225_create_active_storage_tables.active_storage.rb

#### 🎯 概要
Active Storage用のテーブルを作成するマイグレーションファイルです。画像アップロード機能の基盤となります。

#### 🧠 解説
Rails標準のActive Storageライブラリが自動生成するマイグレーションです。ファイルアップロード機能に必要なテーブル群を作成します。

**作成されるテーブル**：
- **`active_storage_blobs`**: ファイルのメタデータ保存
- **`active_storage_attachments`**: モデルとファイルの関連付け
- **`active_storage_variant_records`**: 画像変換結果のキャッシュ

**Active Storageの利点**：
- **ストレージ抽象化**: ローカル、S3、GCSなど統一インターフェース
- **バリアント機能**: 画像リサイズの自動化
- **メタデータ管理**: ファイル名、MIME型、サイズの自動記録

**本プロジェクトでの活用**：
- **マイクロポスト画像**: ユーザーが投稿に画像を添付
- **プロフィール拡張**: 将来的なプロフィール画像機能への準備
- **スケーラビリティ**: クラウドストレージとの連携対応

*注：このファイルはRails標準生成のため、具体的なコード内容の記載は省略*

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

### test/integration/microposts_interface_test.rb

#### 🎯 概要
マイクロポスト機能の統合テストです。投稿作成、削除、ページネーション機能を包括的にテストします。

#### 🧠 解説
ユーザーの視点からマイクロポスト機能を検証する統合テストです。実際のWebアプリケーションの動作を模擬した包括的なテストケースを提供します。

**テストクラスの構造**：
- **`MicropostsInterface`**: 共通セットアップ（基底クラス）
- **`MicropostsInterfaceTest`**: 具体的なテストケース

**検証項目の詳細**：
1. **ページネーション機能**: `should paginate microposts`
2. **無効投稿の処理**: `should show errors but not create micropost on invalid submission`
3. **有効投稿の作成**: `should create a micropost on valid submission`
4. **削除権限の確認**: `should have micropost delete links on own profile page`
5. **削除機能**: `should be able to delete own micropost`
6. **他人投稿の保護**: `should not have delete links on other user's profile page`

**テストの価値**：
- **ユーザー体験の保証**: 実際の操作フローを検証
- **セキュリティチェック**: 権限制御の動作確認
- **回帰テスト**: 機能変更時の安全性確保

```ruby
require "test_helper"

class MicropostsInterface < ActionDispatch::IntegrationTest
  def setup
    @user = users(:michael)
    log_in_as(@user)
  end
end

class MicropostsInterfaceTest < MicropostsInterface
  test "should paginate microposts" do
    get root_path
    assert_select 'div.pagination'
  end

  test "should show errors but not create micropost on invalid submission" do
    assert_no_difference 'Micropost.count' do
      post microposts_path, params: { micropost: { content: "" } }
    end
    assert_select 'div#error_explanation'
    assert_select 'a[href=?]', '/?page=2'  # 正しいページネーションリンク
  end

  test "should create a micropost on valid submission" do
    content = "This micropost really ties the room together"
    assert_difference 'Micropost.count', 1 do
      post microposts_path, params: { micropost: { content: content } }
    end
    assert_redirected_to root_url
    follow_redirect!
    assert_match content, response.body
  end

  test "should have micropost delete links on own profile page" do
    get user_path(@user)
    assert_select 'a', text: 'delete'
  end

  test "should be able to delete own micropost" do
    first_micropost = @user.microposts.paginate(page: 1).first
    assert_difference 'Micropost.count', -1 do
      delete micropost_path(first_micropost)
    end
  end

  test "should not have delete links on other user's profile page" do
    get user_path(users(:archer))
    assert_select 'a', { text: 'delete', count: 0 }
  end
end
```

### test/integration/users_profile_test.rb

#### 🎯 概要
ユーザープロフィールページの統合テストです。マイクロポスト表示機能を含む包括的な検証を行います。

#### 🧠 解説
ユーザープロフィールページの表示内容と機能を検証する統合テストです。マイクロポスト機能追加後の表示確認を行います。

**テスト対象の機能**：
- **ページテンプレート**: 正しいビューが表示されるか
- **ページタイトル**: `full_title` ヘルパーの動作確認
- **ユーザー情報**: 名前とGravatarの表示
- **投稿統計**: マイクロポスト数の表示
- **ページネーション**: 大量投稿への対応
- **投稿内容**: 個別投稿の表示確認

**テストの設計思想**：
- **視覚的要素の検証**: CSSセレクタによる詳細チェック
- **コンテンツの確認**: 投稿内容の表示検証
- **統計情報の正確性**: カウント機能の動作確認

**実用的価値**：
- **UI/UXの品質保証**: ユーザーが見る画面の正確性
- **機能統合の確認**: 複数機能の連携動作検証
- **パフォーマンステスト**: ページネーション機能の確認

```ruby
require "test_helper"

class UsersProfileTest < ActionDispatch::IntegrationTest
  include ApplicationHelper

  def setup
    @user = users(:michael)
  end

  test "profile display" do
    get user_path(@user)
    assert_template 'users/show'
    assert_select 'title', full_title(@user.name)
    assert_select 'h1', text: @user.name
    assert_select 'h1>img.gravatar'
    assert_match @user.microposts.count.to_s, response.body
    assert_select 'div.pagination'
    @user.microposts.paginate(page: 1).each do |micropost|
      assert_match micropost.content, response.body
    end
  end
end
```

### test/models/micropost_test.rb

#### 🎯 概要
Micropostモデルの単体テストです。バリデーション、関連付け、並び順を検証します。

#### 🧠 解説
Micropostモデルのビジネスロジックを検証する単体テストです。データの整合性とモデルの動作を保証します。

**テストケースの詳細**：
1. **`should be valid`**: 正常なマイクロポストの検証
2. **`user id should be present`**: ユーザーIDの必須性チェック
3. **`content should be present`**: 投稿内容の必須性チェック
4. **`content should be at most 140 characters`**: 文字数制限の確認
5. **`order should be most recent first`**: デフォルトスコープの動作確認

**テストの設計パターン**：
- **セットアップ**: 各テストで使用する共通データの準備
- **ポジティブテスト**: 正常系の動作確認
- **ネガティブテスト**: 異常系の適切な処理確認
- **境界値テスト**: 制限値での動作確認

**モデルテストの重要性**：
- **データ整合性**: バリデーションルールの確実な動作
- **ビジネスルール**: アプリケーション固有の制約確認
- **パフォーマンス**: デフォルトスコープの効果検証

```ruby
require "test_helper"

class MicropostTest < ActiveSupport::TestCase
  def setup
    @user = users(:michael)
    @micropost = @user.microposts.build(content: "Lorem ipsum")
  end

  test "should be valid" do
    assert @micropost.valid?
  end

  test "user id should be present" do
    @micropost.user_id = nil
    assert_not @micropost.valid?
  end

  test "content should be present" do
    @micropost.content = "   "
    assert_not @micropost.valid?
  end

  test "content should be at most 140 characters" do
    @micropost.content = "a" * 141
    assert_not @micropost.valid?
  end

  test "order should be most recent first" do
    assert_equal microposts(:most_recent), Micropost.first
  end
end
```

### test/controllers/microposts_controller_test.rb

#### 🎯 概要
MicropostsControllerの単体テストです。認証とアクセス制御を中心にテストします。

#### 🧠 解説
MicropostsControllerのセキュリティ機能を検証する単体テストです。未ログインユーザーや不正アクセスに対する適切な処理を確認します。

**セキュリティテストの重点項目**：
1. **`should redirect create when not logged in`**: 未ログイン時の投稿防止
2. **`should redirect destroy when not logged in`**: 未ログイン時の削除防止
3. **`should redirect destroy for wrong micropost`**: 他人投稿の削除防止

**テストの設計思想**：
- **認証チェック**: ログイン必須機能の保護確認
- **権限チェック**: 投稿者以外の操作防止
- **適切なリダイレクト**: セキュリティ違反時の処理確認

**セキュリティテストの価値**：
- **不正アクセス防止**: 攻撃パターンへの対策確認
- **データ保護**: ユーザーデータの安全性保証
- **システム堅牢性**: 予期しない操作への対処確認

```ruby
require "test_helper"

class MicropostsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @micropost = microposts(:orange)
  end

  test "should redirect create when not logged in" do
    assert_no_difference 'Micropost.count' do
      post microposts_path, params: { micropost: { content: "Lorem ipsum" } }
    end
    assert_redirected_to login_url
  end

  test "should redirect destroy when not logged in" do
    assert_no_difference 'Micropost.count' do
      delete micropost_path(@micropost)
    end
    assert_response :see_other
    assert_redirected_to login_url
  end

  test "should redirect destroy for wrong micropost" do
    log_in_as(users(:michael))
    micropost = microposts(:ants)
    assert_no_difference 'Micropost.count' do
      delete micropost_path(micropost)
    end
    assert_response :see_other
    assert_redirected_to root_url
  end
end
```

### test/fixtures/microposts.yml

#### 🎯 概要
マイクロポストのテストデータを定義するfixtureファイルです。

#### 🧠 解説
テストで使用するマイクロポストのサンプルデータを定義しています。様々なテストシナリオに対応できる多様なデータを提供します。

**Fixtureデータの特徴**：
- **リアルなコンテンツ**: 実際の投稿を模したテキスト
- **時間の多様性**: 異なる投稿時間でソート機能テスト
- **ユーザー関連付け**: 複数ユーザーの投稿データ
- **境界値テスト**: `most_recent` で並び順テスト対応

**データ設計のポイント**：
- **`created_at`**: ERBで動的時間生成（並び順テスト用）
- **`user` 関連付け**: ユーザーとの関係性定義
- **多様なコンテンツ**: URLリンク、絵文字などの実例

```yaml
orange:
  content: "I just ate an orange!"
  created_at: <%= 10.minutes.ago %>
  user: michael

tau_manifesto:
  content: "Check out the @tauday site by @mhartl: https://tauday.com"
  created_at: <%= 3.years.ago %>
  user: michael

cat_video:
  content: "Sad cats are sad: https://youtu.be/PKffm2uI4dk"
  created_at: <%= 2.hours.ago %>
  user: michael

most_recent:
  content: "Writing a short test"
  created_at: <%= Time.zone.now %>
  user: michael
```

### app/helpers/microposts_helper.rb

#### 🎯 概要
マイクロポスト用ヘルパーファイルです。現在は空ですが、将来的な拡張に備えて作成されています。

#### 🧠 解説
Railsの規約に従って自動生成されたヘルパーファイルです。現在は機能を持ちませんが、マイクロポスト関連のビューヘルパーメソッドを定義する場所として用意されています。

**将来的な活用例**：
- **投稿時間の表示**: `time_ago_in_words` のカスタマイズ
- **コンテンツの整形**: リンクの自動生成、ハッシュタグ処理
- **画像表示**: サムネイル生成、レスポンシブ対応
- **投稿統計**: いいね数、コメント数などの表示

```ruby
module MicropostsHelper
end
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

## 🎉 学習成果の総括 - あなたが手に入れた力

### 🚀 技術的マスタリー達成

**🏆 データベース設計の完全習得**:
- **1対多関係**: User ↔ Micropost の美しい関連付け実装
- **依存性管理**: `dependent: :destroy` による完璧なデータ整合性
- **インデックス最適化**: パフォーマンスを考慮したDB設計

**🎯 モダンファイル処理の制覇**:
- **Active Storage**: 次世代ファイル管理システムの実装
- **クラウド連携**: AWS S3との seamless な統合
- **画像最適化**: 自動リサイズによるUX向上

**🛡️ セキュリティアーキテクチャの確立**:
- **認証・認可**: 多層防御による堅牢なセキュリティ
- **Strong Parameters**: インジェクション攻撃の完全防御
- **権限制御**: 投稿者のみが削除可能な精密な制御

### 🌟 ビジネス価値の創造

**📱 リアルタイム体験の実現**:
- **パーソナライズドフィード**: ユーザー固有のコンテンツストリーム
- **即座の投稿**: ストレスフリーな投稿体験
- **動的UI**: ログイン状態に応じた最適な画面表示

**🎪 スケーラブル設計の構築**:
- **ページネーション**: 大量データへの対応
- **部分テンプレート**: 保守性の高いモジュラー設計
- **将来拡張**: フォロー機能への基盤構築

### 🔥 Next Level への道筋

この章で構築した基盤は、次章以降の**フォロー機能**、**リアルタイム通知**、**高度な検索機能**への完璧な土台となります。

**あなたが今、手にしているもの**:
- 🎯 **プロダクション品質**のソーシャルメディア基盤
- 🚀 **エンタープライズレベル**のセキュリティ実装
- 🌟 **スケーラブル**なアーキテクチャ設計能力

**🏆 Achievement Unlocked**: 
あなたは今、Twitter、Instagram、TikTokと同じ技術基盤を理解し、実装できる開発者になりました。次のステップは、この基盤の上に**革新的な機能**を積み重ねることです！

---

**💡 Final Message**: 
このマイクロポスト機能は単なる「投稿システム」ではありません。これは現代のデジタル社会を支える**コミュニケーション基盤**そのものです。あなたが今日学んだ技術で、明日の世界を変える新しいプラットフォームを創ることができるのです。

**🔥 Keep Building, Keep Innovating!**
