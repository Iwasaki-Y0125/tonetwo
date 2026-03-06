module Chats
  class MessagesController < ApplicationController
    def create
      # チャットルームの存在確認と取得
      @chatroom = Chatroom.for_show(id: params[:chat_id], user: Current.user)

      @chat_message = ChatMessage.create_in_room!(chatroom: @chatroom, user: Current.user, body: chat_message_params[:body])
      redirect_to chat_path(@chatroom)
    rescue ActiveRecord::RecordInvalid => e
      @chat_message = e.record if e.record.is_a?(ChatMessage)

      # support語だけは通常エラーではなく専用導線へ送る。
      if @chat_message&.support_required?
        redirect_to support_page_path
        return
      end

      @chat_messages = @chatroom.sorted_messages
      render "chats/show", status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      Rails.logger.warn(
        event: "chat_access_denied",
        user_id: Current.user&.id,
        chat_id: params[:chat_id],
        action: "chats/messages#create"
      )
      redirect_to timeline_path, alert: "このチャットにはアクセスできません。"
    end

    private

    # ストロングパラメータ
    def chat_message_params
      params.require(:chat_message).permit(:body)
    end
  end
end
