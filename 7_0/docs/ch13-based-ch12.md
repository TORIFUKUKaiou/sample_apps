# ch13 マイクロポスト (from ch12)

## 🔥 はじめに：本章で越えるべき山

この章ではユーザーがテキストと画像を投稿できる「マイクロポスト」を実装します。Active Storage を導入し、ユーザーとマイクロポストの関連付けや投稿一覧の表示を学びます。

## ✅ 学習ポイント一覧

- Active Storage による画像アップロード
- `Micropost` モデルと関連付け
- `logged_in_user` フィルタの共通化
- フィード表示用の部分テンプレート
- マイクロポスト用の統合テスト

## 🔍 ファイル別レビューと解説

### app/controllers/application_controller.rb

`logged_in_user` メソッドを ApplicationController に移し、他のコントローラから再利用できるようになりました。
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

ユーザー詳細ページでマイクロポスト一覧を取得します。また `logged_in_user` は ApplicationController に移動しました。
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

ログインしている場合はホーム画面で投稿フォームとフィードを表示します。
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

新たにマイクロポストの作成・削除を管理するコントローラが追加されました。
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

ユーザーは複数のマイクロポストを所有し、簡単なフィードを取得できるようになりました。
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

マイクロポストモデルでは画像添付と基本的なバリデーションを設定しています。
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

マイクロポスト用のルーティングを追加しました。
```diff
@@
   resources :password_resets,     only: [:new, :create, :edit, :update]
+  resources :microposts,          only: [:create, :destroy]
+  get '/microposts', to: 'static_pages#home'
 end
```

### app/views/static_pages/home.html.erb

ログイン状態に応じて投稿フォームとフィードを表示します。
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

プロフィール画面に投稿数と一覧を表示します。
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

`object` 引数を受け取るようにして、ユーザー以外のフォームでも利用可能にしました。
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

新規投稿フォームの部分テンプレートです。
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

画像アップロードサイズを制御する JavaScript を読み込みます。
```diff
@@
 import "@hotwired/turbo-rails"
 import "controllers"
 import "custom/menu"
+import "custom/image_upload"
```

### app/javascript/custom/image_upload.js

5MB を超える画像を選択した場合に警告を表示して投稿を防ぎます。
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
-amazon:
-  service: Disk
-  root: <%= Rails.root.join("storage") %>
+amazon:
+  service: S3
+  access_key_id:     <%= ENV['AWS_ACCESS_KEY_ID'] %>
+  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
+  region:            <%= ENV['AWS_REGION'] %>
+  bucket:            <%= ENV['AWS_BUCKET'] %>
```

## 🧠 まとめ

マイクロポストの追加により、ユーザーは短い投稿と画像をアップロードできるようになりました。Active Storage を導入したことで、ファイルの保存先を簡単に切り替えられます。投稿フォームやフィードの表示には部分テンプレートを活用し、コードの再利用性と可読性が向上しました。
