require "application_system_test_case"

class ChatMessageSystemTest < ApplicationSystemTestCase
  setup do
    @owner = users(:one)
    @replier = users(:two)
    @post = @owner.posts.create!(body: "system chat target")
    @chatroom, = Chatroom.start_with_message!(post: @post, reply_user: @replier, body: "先行メッセージ")
  end

  test "チャット詳細でメッセージを送信できる" do
    login_as(@owner)

    visit chat_path(@chatroom)

    assert_selector "h1", text: "チャット"
    find("form[action='#{chat_messages_path(@chatroom)}'] textarea[name='chat_message[body]']").set("system返信")
    find("form[action='#{chat_messages_path(@chatroom)}'] button[type='submit']").click

    assert_current_path chat_path(@chatroom)
    assert_text "system返信"
  end

  test "連続送信不可のときは送信ボタンが無効化される" do
    login_as(@replier)

    visit chat_path(@chatroom)

    assert_text ChatMessage::CONSECUTIVE_SEND_MESSAGE
    assert_selector "form[action='#{chat_messages_path(@chatroom)}'] textarea[name='chat_message[body]'][disabled]"
    assert_selector "form[action='#{chat_messages_path(@chatroom)}'] button.btn-disabled"
  end

  test "チャットフォームで140字超過時は送信が無効化される" do
    login_as(@owner)

    visit chat_path(@chatroom)

    form_selector = "form[action='#{chat_messages_path(@chatroom)}']"
    textarea = find("#{form_selector} textarea[name='chat_message[body]']")
    textarea.set("c" * 141)
    page.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", textarea)

    assert_text "140字を超えているため送信できません。"
    assert page.evaluate_script("arguments[0].disabled", find("#{form_selector} button[type='submit']"))
  end

  test "チャットフォームで140字ちょうどは送信できる" do
    login_as(@owner)

    visit chat_path(@chatroom)

    body = "d" * 140
    form_selector = "form[action='#{chat_messages_path(@chatroom)}']"
    textarea = find("#{form_selector} textarea[name='chat_message[body]']")
    textarea.set(body)
    page.execute_script("arguments[0].dispatchEvent(new Event('input', { bubbles: true }))", textarea)
    assert_equal false, page.evaluate_script("arguments[0].disabled", find("#{form_selector} button[type='submit']"))

    find("#{form_selector} button[type='submit']").click
    assert_current_path chat_path(@chatroom)
    assert_text body
  end

  test "チャット一覧の新着/返信待ちバッジが送信で遷移する" do
    login_as(@owner)

    visit chats_path
    within("a[href='#{chat_path(@chatroom)}']") do
      assert_text "新着"
    end

    visit chat_path(@chatroom)
    find("form[action='#{chat_messages_path(@chatroom)}'] textarea[name='chat_message[body]']").set("バッジ遷移確認")
    find("form[action='#{chat_messages_path(@chatroom)}'] button[type='submit']").click
    assert_current_path chat_path(@chatroom)
    assert_text "バッジ遷移確認"

    visit chats_path
    within("a[href='#{chat_path(@chatroom)}']") do
      assert_text "返信待ち"
      assert_no_text "新着"
    end

    Capybara.reset_sessions!
    login_as(@replier)
    visit chats_path
    within("a[href='#{chat_path(@chatroom)}']") do
      assert_text "新着"
      assert_no_text "返信待ち"
    end
  end

  test "チャット詳細表示時に既読送信され新着バッジが消える" do
    login_as(@owner)

    visit chats_path
    within("a[href='#{chat_path(@chatroom)}']") do
      assert_text "新着"
    end

    visit chat_path(@chatroom)
    wait_for { @chatroom.reload.has_unread == false }

    visit chats_path
    within("a[href='#{chat_path(@chatroom)}']") do
      assert_no_text "新着"
    end
  end

  test "チャット詳細表示時にメッセージ一覧が最下部へスクロールされる" do
    append_messages_for_scroll_test!
    login_as(@owner)

    visit chat_path(@chatroom)
    assert_selector "[data-chat-scroll-target='messages']"

    scroll_gap = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-chat-scroll-target='messages']")
        return el.scrollHeight - el.scrollTop - el.clientHeight
      })()
    JS

    assert_operator scroll_gap, :<=, 2
  end

  test "非参加ユーザーでチャット詳細へ直アクセスすると拒否される" do
    outsider = User.create!(
      email_address: "outsider-system@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      terms_agreed: "1"
    )
    login_as(outsider)

    visit chat_path(@chatroom)

    assert_current_path timeline_path
    assert_text "このチャットにはアクセスできません。"
  end

  test "未ログインでチャット詳細へ直アクセスするとログイン画面へ遷移する" do
    visit chat_path(@chatroom)

    assert_current_path new_session_path
  end

  private

  def append_messages_for_scroll_test!
    room_id = @chatroom.id
    sender = @owner

    24.times do |i|
      room = Chatroom.find(room_id)
      ChatMessage.create_in_room!(chatroom: room, user: sender, body: "scroll-message-#{i}")
      sender = (sender == @owner ? @replier : @owner)
    end

    @chatroom.reload
  end

  def wait_for(timeout: Capybara.default_max_wait_time)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    loop do
      return if yield

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      raise "wait_for timeout" if elapsed > timeout

      sleep 0.05
    end
  end
end
