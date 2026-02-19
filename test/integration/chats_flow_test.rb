require "test_helper"

class ChatsFlowTest < ActionDispatch::IntegrationTest
  test "他人投稿からチャット画面を表示できる" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)
    target_post = other_user.posts.create!(body: "チャットしたい投稿")

    get new_post_chat_path(target_post)

    assert_response :success
    assert_includes @response.body, "チャット"
    assert_includes @response.body, "メッセージを入力(140字まで)"
  end

  test "チャット初回送信時にchatroomとmessageを作成して詳細へ遷移する" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)
    target_post = other_user.posts.create!(body: "初回送信テスト")

    assert_difference [ -> { Chatroom.count }, -> { ChatMessage.count } ], 1 do
      post post_chat_path(target_post), params: { chat_message: { body: "はじめまして" } }
    end

    chatroom = Chatroom.find_by!(post: target_post, reply_user: user)
    assert_redirected_to chat_path(chatroom)
  end

  test "同一投稿への再送信でchatroomは重複せずmessageのみ増える" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)
    target_post = other_user.posts.create!(body: "重複防止テスト")

    post post_chat_path(target_post), params: { chat_message: { body: "1通目" } }
    assert_response :redirect

    assert_no_difference -> { Chatroom.count } do
      assert_difference -> { ChatMessage.count }, 1 do
        post post_chat_path(target_post), params: { chat_message: { body: "2通目" } }
      end
    end
  end

  test "自分投稿にはチャット作成できない" do
    user = users(:one)
    sign_in_as(user)
    target_post = user.posts.create!(body: "自分の投稿")

    post post_chat_path(target_post), params: { chat_message: { body: "送れない" } }

    assert_redirected_to my_post_path(target_post)
    assert_equal 0, Chatroom.count
    assert_equal 0, ChatMessage.count
  end

  test "チャット詳細は参加者のみ閲覧できる" do
    owner = users(:one)
    replier = users(:two)
    outsider = build_user(email: "outsider@example.com")
    target_post = owner.posts.create!(body: "閲覧制限テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)
    chatroom.chat_messages.create!(user: replier, body: "参加者メッセージ")

    sign_in_as(outsider)
    get chat_path(chatroom)

    assert_response :not_found
  end

  test "チャット詳細で不正なメッセージ送信時は422でエラーを表示する" do
    owner = users(:one)
    replier = users(:two)
    post = owner.posts.create!(body: "空送信テスト")
    chatroom = Chatroom.create!(post: post, reply_user: replier)
    sign_in_as(replier)

    post chat_messages_path(chatroom), params: { chat_message: { body: "" } }

    assert_response :unprocessable_entity
    assert_includes @response.body, "を入力してください"
  end

  test "チャット初回送信でprohibit語を含む場合は保存せず422を返す" do
    FilterTerm.find_or_create_by!(term: "しね", action: "prohibit")
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)
    target_post = other_user.posts.create!(body: "filter test post")

    assert_no_difference [ -> { Chatroom.count }, -> { ChatMessage.count } ] do
      post post_chat_path(target_post), params: { chat_message: { body: "しね" } }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, ChatMessage::PROHIBIT_MESSAGE
  end

  test "チャット詳細でsupport語を含む場合はサポートページへリダイレクトする" do
    FilterTerm.find_or_create_by!(term: "しにたい", action: "support")
    owner = users(:one)
    replier = users(:two)
    sign_in_as(replier)
    target_post = owner.posts.create!(body: "support test post")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)

    assert_no_difference -> { ChatMessage.count } do
      post chat_messages_path(chatroom), params: { chat_message: { body: "しにたい" } }
    end

    assert_redirected_to support_page_path
  end

  private

  def build_user(email:)
    password = "password12345"

    User.create!(
      email_address: email,
      password: password,
      password_confirmation: password,
      terms_agreed: "1"
    )
  end
end
