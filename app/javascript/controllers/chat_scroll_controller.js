import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // スクロール対象（メッセージ一覧コンテナ）
  static targets = ["messages"]

  connect() {
    this.turboLoadHandler = () => this.scrollToBottom()
    document.addEventListener("turbo:load", this.turboLoadHandler)

    this.scrollAfterRender()
  }

  disconnect() {
    // turbo:load の購読を解除し、離脱後にハンドラが呼ばれないようにする。
    document.removeEventListener("turbo:load", this.turboLoadHandler)
    if (!this.frameId) return

    // scrollAfterRenderのrequestAnimationFrameの予約処理が残ってたら取り消す。
    cancelAnimationFrame(this.frameId)
    this.frameId = null
  }

  // 関数宣言

  // スクロール位置を最下部へ動かす
  scrollToBottom() {
    if (!this.hasMessagesTarget) return
    // 全体の高さと同じ分スクロールする => 一番下までスクロールする
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  // スクロールするタイミングを指定
  scrollAfterRender() {
    // 初回スクロール
    this.scrollToBottom()
    // レイアウトズレ防止（レイアウト確定後に再実行）
    this.frameId = requestAnimationFrame(() => this.scrollToBottom())
  }
}
