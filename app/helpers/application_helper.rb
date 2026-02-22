module ApplicationHelper
  HEADER_ICON_PATHS = %w[
    icons/home.svg
    icons/star_shine.svg
    icons/chat_bubble.svg
    icons/account_circle.svg
    icons/settings.svg
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

  # 日時を「2024/01/01 12:00」や「12:00 Today」の形式で表示するユーティリティ関数
  def tt_datetime_label(datetime)
    return "-" if datetime.blank?

    datetime.today? ? datetime.strftime("%H:%M Today") : datetime.strftime("%Y/%m/%d %H:%M")
  end

  # メールアドレスを「abc***@ex***」のようにマスクするユーティリティ関数
  def tt_masked_email(email_address)
    return "---" if email_address.blank?

    local_part, domain_part = email_address.to_s.split("@", 2)
    return "---" if local_part.blank? || domain_part.blank?

    masked_local = "#{local_part.first(3)}***"
    masked_domain = "#{domain_part.split(".").first.to_s.first(3)}***"

    "#{masked_local}@#{masked_domain}"
  end
end
