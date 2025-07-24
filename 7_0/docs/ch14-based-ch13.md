# ch14 ユーザーをフォローする (from ch13)

## 🔥 はじめに：本章で越えるべき山

第14章では、ユーザー同士をフォローしてタイムラインを拡充する機能を実装します。フォロー関係を扱う`Relationship`モデルを中心に、複数のコントローラ・ビューが追加されました。データの関連付けを理解し、Hotwireによる非同期フォロー/アンフォロー体験を学びます。

**本章の重要性**：
- **ソーシャルネットワークの核心**：Twitter/Instagram的なフォロー機能の構築
- **複雑な関連性**：自己参照型の多対多関係の設計と実装
- **パフォーマンス**：効率的なSQLクエリによるスケーラブルなフィード
- **モダンUX**：Hotwireによる非同期処理とリアルタイム更新

## ✅ 学習ポイント一覧

- **`Relationship`モデル**の新規作成と自己参照型関連付け
- **`follow`/`unfollow`メソッド**によるユーザー操作の抽象化
- **フォロー・フォロワー用のルーティングとコントローラ**設計
- **ステータスフィード(`User#feed`)**の実装拡張と最適化
- **Hotwireを用いたフォロー処理**による非同期UX

## 🔧 実装の全体像

```
[フォロー機能のアーキテクチャ]

データ関係図:
  User ←→ Relationship ←→ User
  ├─ active_relationships (フォロー中の関係)
  ├─ passive_relationships (フォロワーからの関係)
  ├─ following (フォロー中のユーザー)
  └─ followers (フォロワーユーザー)

フィードシステム:
  ┌─ 自分の投稿
  ├─ フォロー中ユーザーの投稿
  └─ サブクエリによる効率的な取得

UI/UXフロー:
  1. ユーザープロフィール表示
  2. Follow/Unfollowボタンクリック
  3. Hotwire による非同期処理
  4. ボタン状態の即座の更新
  5. カウント数の自動更新

[複雑な関連性の理解]
Relationship テーブル:
+-------------+-------------+
| follower_id | followed_id |
+-------------+-------------+
|      1      |      2      | ← User1 が User2 をフォロー
|      1      |      3      | ← User1 が User3 をフォロー  
|      2      |      1      | ← User2 が User1 をフォロー
+-------------+-------------+
```

## 🔍 ファイル別レビューと解説

### config/routes.rb

#### 🎯 概要
フォロー・フォロワー表示用のルーティングを追加し、`relationships`リソースを作成しました。

#### 🧠 解説
ユーザーリソースを拡張し、フォロー機能専用のルーティングを追加しました。

**ルーティング設計の工夫**：
- **`member do`**: 個別ユーザーに対するアクション
- **`get :following, :followers`**: フォロー中・フォロワー一覧表示
- **`relationships`リソース**: フォロー関係の作成・削除

**生成されるルート**：
```ruby
# ユーザー関連
GET    /users/:id/following  → users#following
GET    /users/:id/followers  → users#followers

# フォロー関係
POST   /relationships        → relationships#create
DELETE /relationships/:id    → relationships#destroy
```

**設計の理由**：
- **RESTful**: リソースベースの明確な設計
- **直感的**: URL構造が機能を表現
- **拡張性**: 将来的な機能追加に対応

```diff
@@
-  resources :users
+  resources :users do
+    member do
+      get :following, :followers
+    end
+  end
+  resources :relationships,       only: [:create, :destroy]
```

### app/models/user.rb

#### 🎯 概要
フォロー機能に必要な関連付けとメソッドが追加されています。`feed`メソッドはフォロー中ユーザーの投稿も取得するように変更されました。

#### 🧠 解説
Userモデルに自己参照型の多対多関係を実装し、効率的なフィードシステムを構築しました。

**複雑な関連付けの詳細**：

1. **`active_relationships`**:
   - **意味**: このユーザーが"フォローしている"関係
   - **外部キー**: `follower_id`（フォローする側）
   - **用途**: 「誰をフォローしているか」を取得

2. **`passive_relationships`**:
   - **意味**: このユーザーが"フォローされている"関係
   - **外部キー**: `followed_id`（フォローされる側）
   - **用途**: 「誰にフォローされているか」を取得

3. **`following` & `followers`**:
   - **`through`**: 中間テーブルを経由したユーザー取得
   - **`source`**: 関連先のカラムを明示的に指定

**フィードの高度な実装**：
- **サブクエリ活用**: SQLの効率化
- **`includes`**: N+1問題の解決
- **複合条件**: 自分 + フォロー中ユーザーの投稿

**メソッドの設計思想**：
- **`follow(user)`**: 直感的なフォロー操作
- **`unfollow(user)`**: 明確なアンフォロー操作
- **`following?(user)`**: 状態確認の簡潔なAPI

```diff
@@
 class User < ApplicationRecord
   has_many :microposts, dependent: :destroy
+  has_many :active_relationships,  class_name:  "Relationship",
+                                   foreign_key: "follower_id",
+                                   dependent:   :destroy
+  has_many :passive_relationships, class_name:  "Relationship",
+                                   foreign_key: "followed_id",
+                                   dependent:   :destroy
+  has_many :following, through: :active_relationships,  source: :followed
+  has_many :followers, through: :passive_relationships, source: :follower
   attr_accessor :remember_token, :activation_token, :reset_token
   before_save   :downcase_email
   before_create :create_activation_digest
@@ -76,12 +84,30 @@
     reset_sent_at < 2.hours.ago
   end
 
-  # 試作feedの定義
-  # 完全な実装は次章の「ユーザーをフォローする」を参照
+  # ユーザーのステータスフィードを返す
   def feed
-    Micropost.where("user_id = ?", id)
+    following_ids = "SELECT followed_id FROM relationships
+                     WHERE  follower_id = :user_id"
+    Micropost.where("user_id IN (#{following_ids})
+                     OR user_id = :user_id", user_id: id)
+             .includes(:user, image_attachment: :blob)
   end
 
+  # ユーザーをフォローする
+  def follow(other_user)
+    following << other_user unless self == other_user
+  end
+
+  # ユーザーをフォロー解除する
+  def unfollow(other_user)
+    following.delete(other_user)
+  end
+
+  # 現在のユーザーが他のユーザーをフォローしていればtrueを返す
+  def following?(other_user)
+    following.include?(other_user)
+  end
+
   private
 
     # メールアドレスをすべて小文字にする
```

### app/models/relationship.rb

#### 🎯 概要
フォロー関係を管理する新規モデルです。バリデーションと適切なインデックスにより、データの整合性と検索性能を確保しています。

#### 🧠 解説
フォロー関係の中間テーブルを管理する専用モデルです。

**モデル設計のポイント**：
- **`belongs_to :follower`**: フォローする側のユーザー
- **`belongs_to :followed`**: フォローされる側のユーザー
- **バリデーション**: 必須項目の確実な設定

**データベース最適化**：
- **複合インデックス**: `[:follower_id, :followed_id]`
- **一意制約**: 重複フォローの防止
- **個別インデックス**: 高速な検索性能

```ruby
class Relationship < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followed, class_name: "User"
  validates :follower_id, presence: true
  validates :followed_id, presence: true
end
```

### app/controllers/users_controller.rb

#### 🎯 概要
フォロー中・フォロワーユーザーの一覧表示アクションが追加されました。

#### 🧠 解説
既存のUsersControllerにフォロー関連のアクションを追加し、ページネーション付きで一覧表示します。

**新規アクションの詳細**：

1. **`following`アクション**:
   - **取得データ**: `@user.following`（フォロー中ユーザー）
   - **タイトル**: "Following"
   - **テンプレート**: `show_follow`

2. **`followers`アクション**:
   - **取得データ**: `@user.followers`（フォロワーユーザー）
   - **タイトル**: "Followers"  
   - **テンプレート**: `show_follow`

**共通設計のメリット**：
- **DRY原則**: `show_follow`テンプレートの共有
- **ページネーション**: 大量フォローに対応
- **一貫性**: 同じUIパターンの使用

```diff
@@
  private
@@
+  def following
+    @title = "Following"
+    @user  = User.find(params[:id])
+    @users = @user.following.paginate(page: params[:page])
+    render 'show_follow'
+  end
+
+  def followers
+    @title = "Followers"
+    @user  = User.find(params[:id])
+    @users = @user.followers.paginate(page: params[:page])
+    render 'show_follow'
+  end
```

### app/controllers/relationships_controller.rb

#### 🎯 概要
新規に生成されたコントローラで、ログイン済みユーザーによるフォロー/アンフォロー処理を担います。

#### 🧠 解説
フォロー・アンフォロー機能を専門的に管理する新規コントローラーです。

**コントローラー設計の特徴**：
- **認証必須**: `before_action :logged_in_user`
- **非同期対応**: `respond_to`でHTML/Turbo Stream両対応
- **安全性**: 適切なパラメータ処理

**`create`アクションの流れ**：
1. **ユーザー取得**: `params[:followed_id]`からフォロー対象を特定
2. **フォロー実行**: `current_user.follow(@user)`
3. **レスポンス分岐**: HTML（リダイレクト） / Turbo Stream（部分更新）

**`destroy`アクションの工夫**：
- **関係性からユーザー取得**: `Relationship.find(params[:id]).followed`
- **アンフォロー実行**: `current_user.unfollow(@user)`
- **適切なステータス**: `:see_other`でキャッシュ問題を回避

**Hotwire連携のポイント**：
- **HTML**: 従来のページ遷移（JavaScript無効時の互換性）
- **Turbo Stream**: 非同期での部分更新（モダンUX）

```ruby
class RelationshipsController < ApplicationController
  before_action :logged_in_user

  def create
    @user = User.find(params[:followed_id])
    current_user.follow(@user)
    respond_to do |format|
      format.html { redirect_to @user }
      format.turbo_stream
    end
  end

  def destroy
    @user = Relationship.find(params[:id]).followed
    current_user.unfollow(@user)
    respond_to do |format|
      format.html { redirect_to @user, status: :see_other }
      format.turbo_stream
    end
  end
end
```

### app/views/users/show_follow.html.erb

#### 🎯 概要
フォロー中・フォロワー一覧を表示する共通テンプレートです。

#### 🧠 解説
フォロー関連の一覧表示用の新規テンプレートを実装しました。

**テンプレート設計の工夫**：
- **`@title`変数**: "Following" / "Followers" の動的表示
- **ユーザー情報**: Gravatar + 名前のコンパクト表示
- **ページネーション**: 大量データへの対応

**レイアウト構造**：
- **左サイドバー**: ユーザー情報とステータス
- **メインエリア**: フォロー/フォロワーリスト
- **レスポンシブ**: Bootstrap グリッドシステム

```erb
<% provide(:title, @title) %>
<div class="row">
  <aside class="col-md-4">
    <section class="user_info">
      <%= gravatar_for @user %>
      <h1><%= @user.name %></h1>
      <span><%= link_to "view my profile", @user %></span>
      <span><b>Microposts:</b> <%= @user.microposts.count %></span>
    </section>
    <section class="stats">
      <%= render 'shared/stats', user: @user %>
    </section>
  </aside>
  <div class="col-md-8">
    <h3><%= @title %></h3>
    <% if @users.any? %>
      <ul class="users follow">
        <%= render @users %>
      </ul>
      <%= will_paginate %>
    <% end %>
  </div>
</div>
```

### app/views/shared/_stats.html.erb

#### 🎯 概要
プロフィールやホーム画面に表示するフォロー数・フォロワー数をまとめた部分テンプレートです。

#### 🧠 解説
フォロー・フォロワー数を表示する汎用パーシャルテンプレートです。

**デザインの特徴**：
- **統計表示**: フォロー中・フォロワー数の明確な表示
- **リンク機能**: クリックで詳細一覧へ遷移
- **デフォルト値**: `@user ||= current_user`で柔軟な利用

**CSS/ID設計**：
- **`id="following"`**: JavaScript での動的更新対応
- **`id="followers"`**: Hotwire による非同期更新
- **`class="stat"`**: 統一されたスタイリング

**再利用性**：
- **ホーム画面**: ログインユーザーの統計
- **プロフィール**: 他ユーザーの統計
- **フォロー一覧**: サイドバーでの統計表示

```erb
<% @user ||= current_user %>
<div class="stats">
  <a href="<%= following_user_path(@user) %>">
    <strong id="following" class="stat">
      <%= @user.following.count %>
    </strong>
    following
  </a>
  <a href="<%= followers_user_path(@user) %>">
    <strong id="followers" class="stat">
      <%= @user.followers.count %>
    </strong>
    followers
  </a>
</div>
```

### app/views/users/_follow_form.html.erb

#### 🎯 概要
フォロー・アンフォローボタンを表示する部分テンプレートです。

#### 🧠 解説
ユーザープロフィールページで使用するフォロー操作用のパーシャルテンプレートです。

**条件分岐の設計**：
- **フォロー中**: アンフォローボタン表示
- **未フォロー**: フォローボタン表示
- **本人**: ボタン非表示（自分をフォローできない）

**Hotwire対応**：
- **`data: { turbo_stream: true }`**: 非同期処理の有効化
- **部分更新**: ページ遷移なしでボタン状態変更
- **フォールバック**: JavaScript無効時のHTML遷移

```erb
<div id="follow_form">
<% unless current_user?(@user) %>
  <% if current_user.following?(@user) %>
    <%= render 'unfollow' %>
  <% else %>
    <%= render 'follow' %>
  <% end %>
<% end %>
</div>
```

### app/views/users/_follow.html.erb & _unfollow.html.erb

#### 🎯 概要
フォロー・アンフォローボタンの個別テンプレートです。

#### 🧠 解説
フォローボタンとアンフォローボタンの個別実装です。

**フォローボタンの設計**：
- **`form_with`**: Rails 7 対応のフォームヘルパー
- **`hidden_field`**: フォロー対象ユーザーIDの送信
- **`data-turbo-stream`**: 非同期処理の指定

**アンフォローボタンの特徴**：
- **関係性ID**: 削除対象の`relationship.id`を送信
- **DELETEメソッド**: RESTful な削除操作
- **視覚的差別化**: 異なるCSSクラスでの表示

```erb
<!-- _follow.html.erb -->
<%= form_with(model: current_user.active_relationships.build, data: { turbo_stream: true }) do |f| %>
  <div><%= hidden_field_tag :followed_id, @user.id %></div>
  <%= f.submit "Follow", class: "btn btn-primary" %>
<% end %>

<!-- _unfollow.html.erb -->
<%= form_with(model: current_user.active_relationships.find_by(followed_id: @user.id), 
              html: { method: :delete }, data: { turbo_stream: true }) do |f| %>
  <%= f.submit "Unfollow", class: "btn btn-outline-primary" %>
<% end %>
```

### app/views/relationships/create.turbo_stream.erb & destroy.turbo_stream.erb

#### 🎯 概要
Turbo Stream によるフォロー・アンフォロー時の部分更新テンプレートです。

#### 🧠 解説
非同期でのフォロー状態更新を行うTurbo Stream専用テンプレートです。

**Turbo Stream の活用**：
- **`turbo_stream.replace`**: 要素の置き換え
- **対象ID**: `"follow_form"`でピンポイント更新
- **部分テンプレート**: `follow_form`の再描画

**ユーザー体験の向上**：
- **即座の反映**: ページ遷移なしでボタン状態変更
- **軽量**: 最小限のデータ通信
- **自然**: スムーズなインタラクション

```erb
<!-- create.turbo_stream.erb -->
<%= turbo_stream.replace "follow_form" do %>
  <%= render 'users/follow_form' %>
<% end %>

<!-- destroy.turbo_stream.erb -->
<%= turbo_stream.replace "follow_form" do %>
  <%= render 'users/follow_form' %>
<% end %>
```

### db/migrate/20231227074320_create_relationships.rb

#### 🎯 概要
フォロー関係を保持する`relationships`テーブルを作成しました。

#### 🧠 解説
フォロー機能の基盤となるデータベーステーブルを作成するマイグレーションです。

**テーブル設計の詳細**：
- **`follower_id`**: フォローする側のユーザーID
- **`followed_id`**: フォローされる側のユーザーID
- **`timestamps`**: 作成・更新日時の記録

**インデックス戦略**：
1. **個別インデックス**: `follower_id`, `followed_id`（高速検索）
2. **複合インデックス**: `[:follower_id, :followed_id]`（一意制約）
3. **一意制約**: 重複フォローの防止

**パフォーマンス考慮**：
- **検索最適化**: フォロー・フォロワー取得の高速化
- **整合性**: 同じ関係の重複防止
- **スケーラビリティ**: 大量フォローにも対応

```ruby
class CreateRelationships < ActiveRecord::Migration[7.0]
  def change
    create_table :relationships do |t|
      t.integer :follower_id
      t.integer :followed_id

      t.timestamps
    end
    add_index :relationships, :follower_id
    add_index :relationships, :followed_id
    add_index :relationships, [:follower_id, :followed_id], unique: true
  end
end
```

### test/models/relationship_test.rb

#### 🎯 概要
Relationshipモデルの基本的な動作をテストします。

#### 🧠 解説
フォロー関係モデルの妥当性を検証するテストを実装しました。

**テスト項目**：
- **有効性**: 正常なフォロー関係の作成
- **バリデーション**: 必須項目（follower_id, followed_id）の確認
- **関連性**: User モデルとの適切な関連付け

```ruby
require "test_helper"

class RelationshipTest < ActiveSupport::TestCase

  def setup
    @relationship = Relationship.new(follower_id: users(:michael).id,
                                     followed_id: users(:archer).id)
  end

  test "should be valid" do
    assert @relationship.valid?
  end

  test "should require a follower_id" do
    @relationship.follower_id = nil
    assert_not @relationship.valid?
  end

  test "should require a followed_id" do
    @relationship.followed_id = nil
    assert_not @relationship.valid?
  end
end
```

### test/models/user_test.rb

#### 🎯 概要
ユーザーのフォロー機能とフィード内容を検証するテストが追加されています。

#### 🧠 解説
Userモデルに追加されたフォロー機能とフィード機能を包括的にテストしています。

**フォロー機能のテスト**：
- **フォロー操作**: `follow`メソッドの動作確認
- **アンフォロー操作**: `unfollow`メソッドの動作確認
- **状態確認**: `following?`メソッドの正確性
- **自己フォロー防止**: セルフフォローの適切な制御

**フィード機能のテスト**：
- **自分の投稿**: フィードに含まれることを確認
- **フォロー中の投稿**: フィードに含まれることを確認
- **未フォローの投稿**: フィードに含まれないことを確認

**テストの重要性**：
- **ビジネスロジック**: 複雑な関連性の正確な動作確認
- **データ整合性**: フォロー関係の適切な管理
- **パフォーマンス**: フィード取得の効率性確認

```diff
@@
   test "should follow and unfollow a user" do
     michael = users(:michael)
     archer  = users(:archer)
     assert_not michael.following?(archer)
     michael.follow(archer)
     assert michael.following?(archer)
     assert archer.followers.include?(michael)
     michael.unfollow(archer)
     assert_not michael.following?(archer)
     michael.follow(michael)
     assert_not michael.following?(michael)
   end
@@
   test "feed should have the right posts" do
     michael = users(:michael)
     archer  = users(:archer)
     lana    = users(:lana)
     lana.microposts.each do |post_following|
       assert michael.feed.include?(post_following)
     end
     michael.microposts.each do |post_self|
       assert michael.feed.include?(post_self)
     end
     archer.microposts.each do |post_unfollowed|
       assert_not michael.feed.include?(post_unfollowed)
     end
   end
```

### test/fixtures/relationships.yml

#### 🎯 概要
テスト用のフォロー関係データを定義します。

#### 🧠 解説
テストで使用するフォロー関係のサンプルデータを定義しました。

**Fixture設計**：
- **realistic relationships**: 現実的なフォロー関係の模擬
- **テストシナリオ**: 様々なフォロー状態のテスト
- **データ一貫性**: users.yml との適切な関連付け

```yaml
one:
  follower: michael
  followed: lana

two:
  follower: michael  
  followed: malory

three:
  follower: lana
  followed: michael

four:
  follower: archer
  followed: michael
```

## 💡 学習のコツ

### 自己参照型関連付けの理解

**複雑な関連性の整理**：
```ruby
# User モデルから見た関連性
user.active_relationships   # このユーザーがフォローしている関係
user.passive_relationships  # このユーザーがフォローされている関係
user.following              # フォロー中のユーザー一覧
user.followers              # フォロワーユーザー一覧

# Relationship モデルの視点
relationship.follower       # フォローする側のユーザー
relationship.followed       # フォローされる側のユーザー
```

### SQL最適化の理解

**効率的なフィードクエリの仕組み**：
```sql
-- 従来の非効率なクエリ（N+1問題）
SELECT * FROM microposts WHERE user_id = 1;
SELECT * FROM microposts WHERE user_id = 2;  
SELECT * FROM microposts WHERE user_id = 3;
-- ... (フォロー中ユーザー数分のクエリ)

-- 最適化されたサブクエリ
SELECT * FROM microposts 
WHERE user_id IN (
  SELECT followed_id FROM relationships WHERE follower_id = 1
) OR user_id = 1
ORDER BY created_at DESC;
```

### Hotwire/Turbo Stream パターン

**非同期UIの実装パターン**：
```erb
<!-- コントローラー -->
respond_to do |format|
  format.html { redirect_to @user }      # 従来の同期処理
  format.turbo_stream                    # 非同期処理
end

<!-- ビューテンプレート -->
<%= form_with data: { turbo_stream: true } do |f| %>
<!-- フォーム -->
<% end %>

<!-- Turbo Stream テンプレート -->
<%= turbo_stream.replace "target_id" do %>
  <%= render 'partial_template' %>
<% end %>
```

### テスト戦略の設計

**包括的なテストの考え方**：
1. **単体テスト**: モデルメソッドの個別動作確認
2. **関連テスト**: 複数モデル間の連携確認
3. **統合テスト**: ユーザーフローの全体動作確認
4. **パフォーマンステスト**: スケーラビリティの確認

## 🧠 まとめ

本章では、フォロー機能の実装を通じて以下の重要な概念を習得しました。

### 📚 習得した技術概念

**複雑な関連性設計**：
- 自己参照型多対多関係の実装
- through オプションによる柔軟な関連付け
- 効率的なSQL生成とパフォーマンス最適化

**モダンフロントエンド**：
- Hotwire/Turbo Stream による非同期処理
- プログレッシブエンハンスメントの実装
- ユーザー体験を損なわない段階的機能向上

**スケーラブルアーキテクチャ**：
- 適切なデータベースインデックス設計
- サブクエリによる効率的なデータ取得
- N+1問題の回避とパフォーマンス最適化

**テスト駆動開発**：
- 複雑なビジネスロジックの確実なテスト
- Fixture設計によるリアルなテストデータ
- エッジケースを含む包括的な検証

### 🔐 セキュリティベストプラクティス

1. **認証・認可**: ログイン必須のフォロー操作
2. **データ整合性**: 一意制約による重複防止
3. **自己参照制御**: セルフフォローの適切な制限
4. **パラメータ検証**: Strong Parameters による安全性確保

### 🚀 次のステップ

これらの基盤技術により、さらに高度なソーシャル機能を実装する準備が整いました：

- **高度なフィードアルゴリズム**（人気度・関連性）
- **リアルタイム通知システム**
- **グループ・コミュニティ機能**
- **推薦システム・ディスカバリー機能**

フォロー機能は、現代のソーシャルWebアプリケーションの中核となる機能です。自己参照型の複雑な関連性を理解し、パフォーマンスを考慮した実装により、スケーラブルで実用的なソーシャルネットワークの基盤を構築できました。Hotwireによる非同期処理により、モダンで快適なユーザー体験も実現
