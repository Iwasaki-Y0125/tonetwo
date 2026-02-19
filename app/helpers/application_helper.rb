module ApplicationHelper
  HEADER_ICON_PATHS = %w[
    icons/home.svg
    icons/star_shine.svg
    icons/chat_bubble.svg
    icons/account_circle.svg
  ].freeze

  def tt_header_icon(icon_path)
    # 想定外の入力経路が混ざっても、許可アイコン以外は使わない
    safe_icon_path = HEADER_ICON_PATHS.include?(icon_path) ? icon_path : "icons/home.svg"

    tag.span(
      "",
      class: "tt-header-icon",
      style: "--tt-header-icon-url: url('#{asset_path(safe_icon_path)}')",
      aria: { hidden: true }
    )
  end
end
