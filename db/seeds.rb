# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Load shared seed files tracked in Git.
load Rails.root.join("db/seeds/matching_exclusion_terms.rb")

# Load local-only seed files (e.g. sensitive moderation terms) if present.
unless Rails.env.production?
  Dir[Rails.root.join("db/seeds/*.local.rb")].sort.each do |seed_file|
    load seed_file
  end
end
