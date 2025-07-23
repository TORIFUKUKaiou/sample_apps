# ch14 ユーザーをフォローする (from ch13)

## 🔥 はじめに：本章で越えるべき山

第14章では、ユーザー同士をフォローしてタイムラインを拡充する機能を実装します。フォロー関係を扱う`Relationship`モデルを中心に、複数のコントローラ・ビューが追加されました。データの関連付けを理解し、Hotwireによる非同期フォロー/アンフォロー体験を学びます。

## ✅ 学習ポイント一覧

- `Relationship`モデルの新規作成と関連付け
- `follow`/`unfollow`メソッドによるユーザー操作
- フォロー・フォロワー用のルーティングとコントローラ
- ステータスフィード(`User#feed`)の実装拡張
- Hotwireを用いたフォロー処理

## 🔍 ファイル別レビューと解説

### config/routes.rb

フォロー・フォロワー表示用のルーティングを追加し、`relationships`リソースを作成しました。
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

フォロー機能に必要な関連付けとメソッドが追加されています。`feed`メソッドはフォロー中ユーザーの投稿も取得するように変更されました。
```diff
@@
-  has_many :microposts, dependent: :destroy
+  has_many :microposts, dependent: :destroy
+  has_many :active_relationships,  class_name:  "Relationship",
+                                   foreign_key: "follower_id",
+                                   dependent:   :destroy
+  has_many :passive_relationships, class_name:  "Relationship",
+                                   foreign_key: "followed_id",
+                                   dependent:   :destroy
+  has_many :following, through: :active_relationships,  source: :followed
+  has_many :followers, through: :passive_relationships, source: :follower
@@
-  def feed
-    Micropost.where("user_id = ?", id)
+  def feed
+    following_ids = "SELECT followed_id FROM relationships
+                     WHERE  follower_id = :user_id"
+    Micropost.where("user_id IN (#{following_ids})
+                     OR user_id = :user_id", user_id: id)
+             .includes(:user, image_attachment: :blob)
   end
+
+  def follow(other_user)
+    following << other_user unless self == other_user
+  end
+
+  def unfollow(other_user)
+    following.delete(other_user)
+  end
+
+  def following?(other_user)
+    following.include?(other_user)
+  end
```

### app/controllers/relationships_controller.rb

新規に生成されたコントローラで、ログイン済みユーザーによるフォロー/アンフォロー処理を担います。
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

### app/views/shared/_stats.html.erb

プロフィールやホーム画面に表示するフォロー数・フォロワー数をまとめた部分テンプレートです。
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

### db/migrate/20231227074320_create_relationships.rb

フォロー関係を保持する`relationships`テーブルを作成しました。
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

### test/models/user_test.rb

ユーザーのフォロー機能とフィード内容を検証するテストが追加されています。
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

## 🧠 まとめ

- フォロー機能では`Relationship`モデルを介した自己参照型関連付けを理解することが重要です。
- ルーティングやビューを通じて、ユーザー同士のつながりをUIに反映させました。
- Hotwireを利用することで、ページ遷移なしにフォロー・アンフォローができる洗練された体験を提供します。
