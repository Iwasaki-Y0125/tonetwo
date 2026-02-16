import { Controller } from "@hotwired/stimulus"

const MAX_POLLS = 24

export default class extends Controller {
  // View側のdata-*-valueから受け取る設定値。
  static values = {
    url: String,
    enabled: Boolean,
    interval: Number
  }

  connect() {
    // 解析中以外ではポーリングしない。
    if (!this.enabledValue || !this.urlValue) return

    this.pollCount = 0
    // タブ表示状態の変化に応じてポーリングを開始/停止する。
    this.visibilityHandler = () => this.syncPollingState()
    document.addEventListener("visibilitychange", this.visibilityHandler)
    this.syncPollingState()
  }

  // コントローラが破棄される際に、イベントリスナーとタイマーを確実にクリーンアップする。
  disconnect() {
    document.removeEventListener("visibilitychange", this.visibilityHandler)
    this.visibilityHandler = null
    if (!this.timer) return

    clearInterval(this.timer)
    this.timer = null
  }

  // タブが表示されたときだけポーリングする。非表示のときはタイマーを停止してリソース消費を抑える。
  syncPollingState() {
    if (document.visibilityState !== "visible") {
      if (!this.timer) return
      clearInterval(this.timer)
      this.timer = null
      return
    }

    if (this.timer) return
    const interval = this.intervalValue || 5000
    this.timer = setInterval(() => this.reload(), interval)
  }

  async reload() {
    this.pollCount += 1
    if (this.pollCount > MAX_POLLS) {
      this.stopPolling()
      return
    }

    // timeline_feedフレームとしてリクエストし、部分HTMLだけ取得する。
    const response = await fetch(this.urlValue, {
      headers: { "Turbo-Frame": "timeline_feed" }
    })
    if (!response.ok) return

    // 取得した最新フレームで現在の要素を差し替える。
    const html = await response.text()
    this.element.outerHTML = html
  }

  stopPolling() {
    if (!this.timer) return

    clearInterval(this.timer)
    this.timer = null
  }
}
