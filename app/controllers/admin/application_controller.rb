# Administrate 配下の controller はこの `Admin::ApplicationController` を継承する。
# そのため、管理画面共通の認証や before_action を置く場所として使う。
#
# 一覧のページネーションなど、controller 共通の振る舞いを追加したい場合は
# 標準の RESTful アクションを必要に応じて上書きできる。
module Admin
  class ApplicationController < Administrate::ApplicationController
    include Authentication

    before_action :authenticate_admin

    def authenticate_admin
      # ログイン済みでなければログイン画面へリダイレクト
      return request_authentication unless resume_session

      # 管理者権限でなければrootへリダイレクト
      redirect_to root_path unless Current.session.user.admin?
    end

    # 一覧画面の1ページあたり表示件数を変えたい場合は、このメソッドを定義する。
    # デフォルトは 20 件。
    # def records_per_page
    #   params[:per_page] || 20
    # end
  end
end
