namespace :quality do
  desc "Run rubocop, brakeman, importmap audit, and test suite"
  task all: :environment do
    steps = [
      [ "RuboCop", "bin/rubocop -f github" ],
      [ "Brakeman", "bin/brakeman --no-pager" ],
      [ "Importmap audit", "bin/importmap audit" ],
      # .env.dev の DATABASE_URL(development) が test 実行に混ざるのを防ぐ
      [ "Tests", "env -u DATABASE_URL RAILS_ENV=test bin/rails db:test:prepare test test:system" ]
    ]

    steps.each do |name, command|
      puts "\n==> #{name}"
      sh command
    end
  end
end
