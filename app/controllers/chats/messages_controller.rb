module Chats
  class MessagesController < ApplicationController
    def create
      # チャットルームの存在確認と取得
      @chatroom = Chatroom.for_show(id: params[:chat_id], user: Current.user)

      # チャットメッセージの保存
      @chat_message = @chatroom.chat_messages.new(chat_message_params.merge(user: Current.user))
      if @chat_message.save
        redirect_to chat_path(@chatroom)
        return
      end
      # サポートワードが含まれる場合はサポートページへ遷移する
      if @chat_message.support_required?
        redirect_to support_page_path, notice: ChatMessage::SUPPORT_MESSAGE
        return
      end

      # 保存失敗時はチャット詳細に戻し、フォーム上でバリデーションエラーを表示する
      @chat_messages = @chatroom.sorted_messages
      render "chats/show", status: :unprocessable_entity
    end

    private

    # ストロングパラメータ
    def chat_message_params
      params.require(:chat_message).permit(:body)
    end
  end
end
