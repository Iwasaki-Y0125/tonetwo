Rails.application.routes.draw do
  # 管理画面は一時的に非公開。再開時は下記ルートを戻す。
  # namespace :admin do
  #   resources :filter_terms
  #   resources :matching_exclusion_terms
  #
  #   root to: "filter_terms#index"
  # end
  resource :session, only: %i[new create destroy]
  resource :sign_up, only: %i[new create]
  get "timeline", to: "timeline#index", as: :timeline
  get "timeline/similar", to: "timeline#similar", as: :similar_timeline
  # TODO(UI): 将来的に個別投稿ページを再導入する場合は :new を戻す。
  # resources :posts, only: %i[new create]

  # 補足）チャットルームとメッセージのルーティング
  # チャットルーム作成のトリガーは「投稿へのメッセージ送信」である
  # そのため、postsリソースのネストとして定義する
  resources :posts, only: %i[create] do
    resource :chat, only: %i[new create], controller: "chats"
  end

  # チャットルームの一覧/詳細閲覧 チャットルーム内でのメッセージ送信のルーティング
  resources :chats, only: %i[index show] do
    patch :read, on: :member
    resources :messages, only: %i[create], module: :chats
  end

  get "settings", to: "settings#show", as: :settings
  get "tos", to: "pages#tos", as: :tos
  get "privacy", to: "pages#privacy", as: :privacy
  get "licenses", to: "pages#licenses", as: :licenses

  # 自分の投稿の一覧/詳細閲覧のルーティング
  namespace :my do
    resources :posts, only: %i[index show]
  end

  get "support" => "support_pages#show", as: :support_page
  get "support/talk" => "support_pages#talk", as: :support_talk_page
  get "symbol" => "symbol_pages#show", as: :symbol_page

  # TODO(Auth): MVP時点ではパスワードリセットは未実装のため非公開。
  # 本リリースまでに下記ルートを有効化する。
  # resource :password, only: %i[new create]
  # resources :passwords, only: %i[edit update], param: :token

  # 監視用ヘルスチェック（正常時200 / 異常時500）
  get "up" => "rails/health#show", as: :rails_health_check

  # 認証保護ページのサンプルルート
  get "protected" => "protected_pages#show", as: :protected_page

  root "home#index"
end
