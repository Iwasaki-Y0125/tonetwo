class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[tos privacy licenses]

  def tos
    render_policy_page(:terms)
  end

  def privacy
    render_policy_page(:privacy)
  end

  def licenses
    render_policy_page(:licenses)
  end

  private

  def render_policy_page(policy_name)
    @policy = Policies::PolicyDocuments.fetch!(policy_name)
    @policy_version = @policy[:version]
    @policy_revised_on_jst = @policy[:updated_at].in_time_zone("Asia/Tokyo").to_date
    @policy_html = helpers.render_policy_markdown(@policy[:markdown])
    @page_title = "#{@policy[:title]} | ToneTwo"
    render(turbo_frame_request? ? :modal : :show)
  end
end
