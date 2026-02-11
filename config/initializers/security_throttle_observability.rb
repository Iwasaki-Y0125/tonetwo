unless Rails.configuration.x.security_throttle_subscriber_registered
  Rails.configuration.x.security_throttle_subscriber_registered = true

  # 詳細パスをそのまま残さず、先頭セグメントだけを観測用途で保持する
  def mask_path(path)
    return "unknown" unless path.is_a?(String)

    clean_path = path.split("?", 2).first.to_s
    segments = clean_path.split("/").reject(&:empty?)
    segments.empty? ? "/" : "/#{segments.first}"
  end

  THROTTLE_WINDOW_SECONDS = 60
  WARN_THRESHOLD = 20
  ERROR_THRESHOLD = 100

  def throttle_bucket
    Time.current.to_i / THROTTLE_WINDOW_SECONDS
  end

  def throttle_counter_key(payload)
    bucket = throttle_bucket
    layer = payload[:layer] || "unknown"
    rule = payload[:rule] || "unknown"
    "security.throttle.count:#{bucket}:#{layer}:#{rule}"
  end

  def increment_throttle_count(counter_key)
    Rails.cache.increment(counter_key, 1, initial: 0, expires_in: 2.minutes) || 1
  end

  def should_emit_throttle_log?(count)
    count == WARN_THRESHOLD || count == ERROR_THRESHOLD || (count > ERROR_THRESHOLD && (count % ERROR_THRESHOLD).zero?)
  end

  def throttle_log_level(count)
    count >= ERROR_THRESHOLD ? :error : :warn
  end

  # layer を必須キーにして、middleware/controller の抑止シグナルを同一イベントで集計する
  ActiveSupport::Notifications.subscribe("security.throttle") do |_name, _start, _finish, _id, payload|
    counter_key = throttle_counter_key(payload)
    count = increment_throttle_count(counter_key)
    next unless should_emit_throttle_log?(count)

    Rails.logger.public_send(
      throttle_log_level(count),
      [
        "security.throttle.summary",
        "layer=#{payload[:layer] || 'unknown'}",
        "rule=#{payload[:rule] || 'unknown'}",
        "count=#{count}",
        "window=#{THROTTLE_WINDOW_SECONDS}s",
        "status=#{payload[:status] || 'unknown'}",
        "method=#{payload[:method] || 'unknown'}",
        "path=#{mask_path(payload[:path])}"
      ].join(" ")
    )
  end
end
