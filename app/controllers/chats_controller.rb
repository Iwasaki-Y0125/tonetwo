class ChatsController < ApplicationController
  def index
    @chatrooms = Chatroom.for_index(Current.user)
  end

  def show
    @chatroom = Chatroom.for_show(id: params[:id], user: Current.user)
    @chat_messages = @chatroom.sorted_messages
    @chat_message = ChatMessage.new
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn(
      event: "chat_access_denied",
      user_id: Current.user&.id,
      chat_id: params[:id],
      action: "chats#show"
    )
    redirect_to timeline_path, alert: "このチャットにはアクセスできません。"
  end

  # 新着フラグ変更のためのPATCH
  def read
    chatroom = Chatroom.for_show(id: params[:id], user: Current.user)
    chatroom.clear_unread_for!(Current.user)
    head :no_content
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn(
      event: "chat_access_denied",
      user_id: Current.user&.id,
      chat_id: params[:id],
      action: "chats#read"
    )
    redirect_to timeline_path, alert: "このチャットにはアクセスできません。"
  end

  def new
    @post = Post.find(params[:post_id])
    # 自分の投稿にはチャットを作成できないようにする
    if @post.user_id == Current.user.id
      redirect_to my_post_path(@post), alert: "自分の投稿ではチャットを開始できません。"
      return
    end

    # すでにチャットルームがある場合は、新たに作らずにそのチャットルームの詳細へ遷移する
    existing_chatroom = Chatroom.find_by(post: @post, reply_user: Current.user)
    if existing_chatroom
      redirect_to chat_path(existing_chatroom)
      return
    end

    # 新規チャットルーム作成
    @chat_message = ChatMessage.new
  end

  def create
    @post = Post.find(params[:post_id])
    # 自分の投稿にはチャットを作成できないようにする
    if @post.user_id == Current.user.id
      redirect_to my_post_path(@post), alert: "自分の投稿ではチャットを開始できません。"
      return
    end

    # newからチャットメッセージの内容を受け取る
    @chat_message = ChatMessage.new(chat_message_params)

    # 初回送信は room 作成と message 保存を同一トランザクションで扱う。
    @chatroom, @chat_message = Chatroom.start_with_message!(
      post: @post,
      reply_user: Current.user,
      body: @chat_message.body
    )

    redirect_to chat_path(@chatroom)
  rescue ActiveRecord::RecordInvalid => e
    @chat_message = e.record if e.record.is_a?(ChatMessage)

    # support語だけは通常エラーではなく専用導線へ送る。
    if @chat_message&.support_required?
      redirect_to support_page_path
      return
    end

    render :new, status: :unprocessable_entity
  end

  private

  # ストロングパラメータ
  def chat_message_params
    params.require(:chat_message).permit(:body)
  end
end
