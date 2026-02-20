class ChatsController < ApplicationController
  def index
    @chatrooms = Chatroom.for_index(Current.user)
  end

  def show
    @chatroom = Chatroom.for_show(id: params[:id], user: Current.user)
    @chat_messages = @chatroom.sorted_messages
    @chat_message = ChatMessage.new
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

    @chatroom, @chat_message = Chatroom.start_with_message!(
      post: @post,
      reply_user: Current.user,
      body: @chat_message.body
    )

    redirect_to chat_path(@chatroom)

  # メッセージの保存に失敗した時用の例外処理
  rescue ActiveRecord::RecordInvalid => e
    # 失敗したメッセージ作成の情報を画面再表示用に引き継ぐ
    @chat_message = e.record if e.record.is_a?(ChatMessage)
    # サポートワードが含まれる場合はサポートページへ遷移する
    if @chat_message&.support_required?
      redirect_to support_page_path
      return
    end
    # それ以外のエラーの場合は、エラーメッセージをフラッシュに積んで、遷移元に戻す。
    render :new, status: :unprocessable_entity
  end

  private

  # ストロングパラメータ
  def chat_message_params
    params.require(:chat_message).permit(:body)
  end
end
