class ApplicationController < ActionController::Base
  include Authentication
  include MaintenanceMode
  prepend_before_action :enforce_maintenance_mode
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
