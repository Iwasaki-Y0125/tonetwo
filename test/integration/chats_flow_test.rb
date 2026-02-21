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

  test "同一投稿への連続送信は初回送信導線でも保存されない" do
    user = users(:one)
    other_user = users(:two)
    sign_in_as(user)
    target_post = other_user.posts.create!(body: "連投防止テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: user)
    chatroom.chat_messages.create!(user: user, body: "1通目")

    assert_no_difference [ -> { Chatroom.count }, -> { ChatMessage.count } ] do
      post post_chat_path(target_post), params: { chat_message: { body: "2通目" } }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, ChatMessage::CONSECUTIVE_SEND_MESSAGE
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

  test "チャット詳細は参加者以外だとタイムラインへリダイレクトする" do
    owner = users(:one)
    replier = users(:two)
    outsider = build_user(email: "outsider@example.com")
    target_post = owner.posts.create!(body: "閲覧制限テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)
    chatroom.chat_messages.create!(user: replier, body: "参加者メッセージ")

    sign_in_as(outsider)
    get chat_path(chatroom)

    assert_redirected_to timeline_path
    assert_equal "このチャットにはアクセスできません。", flash[:alert]
  end

  test "チャット送信エンドポイントに参加者以外がアクセスした場合はタイムラインへリダイレクトする" do
    owner = users(:one)
    replier = users(:two)
    outsider = build_user(email: "outsider2@example.com")
    target_post = owner.posts.create!(body: "送信制限テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)
    chatroom.chat_messages.create!(user: replier, body: "参加者メッセージ")

    sign_in_as(outsider)
    assert_no_difference -> { ChatMessage.count } do
      post chat_messages_path(chatroom), params: { chat_message: { body: "不正送信" } }
    end

    assert_redirected_to timeline_path
    assert_equal "このチャットにはアクセスできません。", flash[:alert]
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

  test "相手が送信した後は再度送信できる" do
    owner = users(:one)
    replier = users(:two)
    target_post = owner.posts.create!(body: "交互送信テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)
    chatroom.chat_messages.create!(user: replier, body: "1通目")

    sign_in_as(owner)
    assert_difference -> { ChatMessage.count }, 1 do
      post chat_messages_path(chatroom), params: { chat_message: { body: "返信します" } }
    end
    assert_redirected_to chat_path(chatroom)

    sign_in_as(replier)
    assert_no_difference -> { Chatroom.count } do
      assert_difference -> { ChatMessage.count }, 1 do
        post post_chat_path(target_post), params: { chat_message: { body: "再送信できます" } }
      end
    end
    assert_redirected_to chat_path(chatroom)
  end

  test "連続送信不可のときは理由を表示し送信UIを無効化する" do
    owner = users(:one)
    replier = users(:two)
    target_post = owner.posts.create!(body: "UI制御テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)
    chatroom.chat_messages.create!(user: replier, body: "直前メッセージ")
    sign_in_as(replier)

    get chat_path(chatroom)

    assert_response :success
    assert_includes @response.body, ChatMessage::CONSECUTIVE_SEND_MESSAGE
    assert_includes @response.body, 'disabled="disabled"'
  end

  test "チャット詳細のメッセージ一覧にスクロール用DOM属性が付与される" do
    owner = users(:one)
    replier = users(:two)
    target_post = owner.posts.create!(body: "スクロール属性テスト")
    chatroom = Chatroom.create!(post: target_post, reply_user: replier)
    chatroom.chat_messages.create!(user: owner, body: "1通目")
    sign_in_as(replier)

    get chat_path(chatroom)

    assert_response :success
    assert_includes @response.body, 'data-controller="compose-focus chat-scroll"'
    assert_includes @response.body, 'data-chat-scroll-target="messages"'
    assert_includes @response.body, "max-h-[50vh]"
    assert_includes @response.body, "overflow-y-auto"
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

  test "受信側がチャット詳細を開くと一覧の新着バッジが消える" do
    owner = users(:one)
    replier = users(:two)
    target_post = owner.posts.create!(body: "新着確認テスト")
    chatroom, = Chatroom.start_with_message!(post: target_post, reply_user: replier, body: "最初のメッセージ")

    sign_in_as(owner)
    get chats_path
    assert_response :success
    assert_match(/>\s*新着\s*</, @response.body)

    get chat_path(chatroom)
    assert_response :success
    assert_equal true, chatroom.reload.has_unread
    assert_includes @response.body, read_chat_path(chatroom)
    assert_includes @response.body, 'data-controller="chat-read"'

    patch read_chat_path(chatroom)
    assert_response :no_content
    assert_equal false, chatroom.reload.has_unread

    get chats_path
    assert_response :success
    assert_no_match(/>\s*新着\s*</, @response.body)
    assert_no_match(/>\s*返信待ち\s*</, @response.body)
  end

  test "送信後は送信者が返信待ちになり相手側は新着になる" do
    owner = users(:one)
    replier = users(:two)
    target_post = owner.posts.create!(body: "バッジ遷移テスト")
    chatroom, = Chatroom.start_with_message!(post: target_post, reply_user: replier, body: "初回メッセージ")

    sign_in_as(owner)
    get chat_path(chatroom)
    assert_response :success
    patch read_chat_path(chatroom)
    assert_response :no_content
    assert_equal false, chatroom.reload.has_unread

    assert_difference -> { ChatMessage.count }, 1 do
      post chat_messages_path(chatroom), params: { chat_message: { body: "返信します" } }
    end
    assert_redirected_to chat_path(chatroom)
    chatroom.reload
    assert_equal owner.id, chatroom.last_sender_id
    assert_equal true, chatroom.has_unread

    get chats_path
    assert_response :success
    assert_match(/>\s*返信待ち\s*</, @response.body)
    assert_no_match(/>\s*新着\s*</, @response.body)

    sign_in_as(replier)
    get chats_path
    assert_response :success
    assert_match(/>\s*新着\s*</, @response.body)
    assert_no_match(/>\s*返信待ち\s*</, @response.body)
  end

  test "readエンドポイントは参加者以外だとタイムラインへリダイレクトする" do
    owner = users(:one)
    replier = users(:two)
    outsider = build_user(email: "outsider-read@example.com")
    target_post = owner.posts.create!(body: "既読権限テスト")
    chatroom, = Chatroom.start_with_message!(post: target_post, reply_user: replier, body: "1通目")

    sign_in_as(outsider)
    patch read_chat_path(chatroom)

    assert_redirected_to timeline_path
    assert_equal "このチャットにはアクセスできません。", flash[:alert]
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
