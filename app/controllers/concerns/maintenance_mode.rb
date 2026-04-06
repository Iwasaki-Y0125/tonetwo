module MaintenanceMode
  extend ActiveSupport::Concern

  private
    def enforce_maintenance_mode
      return unless maintenance_mode_enabled?
      return if maintenance_allowed_path?(request.path)

      # service_unavailable => 503 Service Unavailable
      render template: "layouts/maintenance",
      layout: false,
      status: :service_unavailable
    end

    def maintenance_mode_enabled?
      ENV.key?("MAINTENANCE_MODE")
    end

    def maintenance_allowed_path?(path)
      request_path = path.to_s
      return true if request_path == "/up"
      return true if request_path == "/favicon.ico"
      return true if request_path == "/robots.txt"
      return true if request_path.start_with?("/assets/")

      false
    end
end
