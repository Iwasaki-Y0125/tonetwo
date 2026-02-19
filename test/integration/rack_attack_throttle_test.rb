require "test_helper"

class RackAttackThrottleTest < ActionDispatch::IntegrationTest
  # Rack::Attackの動作を検証するためのテストセットアップ
  setup do
    @original_enabled = Rack::Attack.enabled
    @original_cache_store = Rack::Attack.cache.store
    @original_controller_cache_store = ActionController::Base.cache_store
    @rate_limit_callback_stores = {}

    Rack::Attack.enabled = true
    Rails.cache.clear
    # E2E経路を担保するため、Rack::Attackもtest環境の実ストア（SolidCache）を使う
    Rack::Attack.cache.store = Rails.cache
    # middleware層だけを検証するため、controller層rate_limitは無効化する
    ActionController::Base.cache_store = ActiveSupport::Cache::NullStore.new
    disable_controller_rate_limit_for_middleware_test(SessionsController)
    disable_controller_rate_limit_for_middleware_test(SignUpsController)
    disable_controller_rate_limit_for_middleware_test(PostsController)
  end

  # Rack::Attackテスト終了後、ほかのテストに影響しないようにRack::Attackの有効設定を元の状態に戻す
  teardown do
    Rails.cache.clear
    Rack::Attack.enabled = @original_enabled
    Rack::Attack.cache.store = @original_cache_store
    ActionController::Base.cache_store = @original_controller_cache_store
    restore_controller_rate_limit_store
  end

  test "basic auth付きリクエストは上限超過で429を返す" do
    headers = { "HTTP_AUTHORIZATION" => "Basic dGVzdDp0ZXN0" }

    20.times do
      get new_session_path, headers: headers
      assert_response :success
    end

    get new_session_path, headers: headers
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "通常リクエストは上限超過で429を返す" do
    240.times do
      get new_session_path
      assert_response :success
    end

    get new_session_path
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "POST /session は上限超過で抑止される" do
    20.times do
      post session_path, params: { email_address: "one@example.com", password: "wrong-password" }
      assert_redirected_to new_session_path
      assert_equal "メールアドレスまたはパスワードが異なります。", flash[:alert]
    end

    post session_path, params: { email_address: "one@example.com", password: "wrong-password" }
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "POST /sign_up は上限超過で429を返す" do
    20.times do
      post sign_up_path, params: {
        user: {
          email_address: "",
          password: "Password1!",
          password_confirmation: "Password1!"
        }
      }
      assert_response :unprocessable_entity
    end

    post sign_up_path, params: {
      user: {
        email_address: "",
        password: "Password1!",
        password_confirmation: "Password1!"
      }
    }
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "POST /posts は上限超過で429を返す" do
    20.times do
      post posts_path, params: { post: { body: "rack attack test" } }
      assert_redirected_to new_session_path
    end

    post posts_path, params: { post: { body: "rack attack test over limit" } }
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "POST /posts/:post_id/chat は上限超過で429を返す" do
    20.times do
      post "/posts/1/chat", params: { chat_message: { body: "rack attack start chat test" } }
      assert_redirected_to new_session_path
    end

    post "/posts/1/chat", params: { chat_message: { body: "rack attack start chat test over limit" } }
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  test "POST /chats/:chat_id/messages は上限超過で429を返す" do
    20.times do
      post "/chats/1/messages", params: { chat_message: { body: "rack attack chat test" } }
      assert_redirected_to new_session_path
    end

    post "/chats/1/messages", params: { chat_message: { body: "rack attack chat test over limit" } }
    assert_response :too_many_requests
    assert_equal "Too Many Requests", response.body
  end

  private

  # Rack::Attack本体は実ストア（SolidCache）で動かしたまま、
  # controller側 rate_limit callback の store だけを対象テスト中に NullStore へ差し替える
  def disable_controller_rate_limit_for_middleware_test(controller_class)
    # controllerに定義済みの rate_limit before_action を1つ特定する
    rate_limit_callback = controller_class._process_action_callbacks.to_a.find do |callback|
      callback.kind == :before &&
        callback.filter.is_a?(Proc) &&
        callback.filter.source_location&.first&.include?("rate_limiting.rb")
    end
    raise "rate_limit callback not found for #{controller_class.name}" unless rate_limit_callback

    # callbackが抱えているローカル変数(store)を書き換えるため、Procのbindingを取り出す
    callback_binding = rate_limit_callback.filter.binding
    @rate_limit_callback_stores[controller_class.name] = {
      binding: callback_binding,
      # teardownで必ず戻せるよう、元のstoreを退避
      original_store: callback_binding.local_variable_get(:store)
    }
    # middleware層の検証を優先するため、controller層のrate_limitカウントを無効化
    callback_binding.local_variable_set(:store, ActiveSupport::Cache::NullStore.new)
  end

  def restore_controller_rate_limit_store
    # テスト後にstoreを元へ戻し、他テストへの汚染を防ぐ
    @rate_limit_callback_stores.each_value do |entry|
      entry[:binding].local_variable_set(:store, entry[:original_store])
    end
  end
end
