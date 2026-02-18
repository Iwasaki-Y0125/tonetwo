Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :sign_up, only: %i[new create]
  get "timeline", to: "timeline#index", as: :timeline
  get "timeline/similar", to: "timeline#similar", as: :similar_timeline
  # TODO(UI): 将来的に個別投稿ページを再導入する場合は :new を戻す。
  # resources :posts, only: %i[new create]
  resources :posts, only: %i[create]
  namespace :my do
    resources :posts, only: %i[index show]
  end
  get "support" => "support_pages#show", as: :support_page

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
