require_relative "boot"

require "rails/all"

# Gemfile に記載されているすべての gem を読み込みます。これには、:test、:development、:production のいずれかに限定されている gem も含まれます。
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Rails の元々のバージョン用に、設定のデフォルト値を初期化します。
    config.load_defaults 8.0

    # .rb ファイルを含まない lib サブディレクトリや、リロードまたは早期ロードされるべきではないディレクトリを ignore リストに追加してください。
    # 例としては、templates、generators、middleware などが一般的です。
    config.autoload_lib(ignore: %w[assets tasks])

    # アプリケーション、エンジン、およびルーティングの各設定をここに記述します。
    #
    # これらの設定は、後で処理される config/environments 内のファイルを使用して、
    # 特定の環境で上書きすることができます。

    # config.autoload_paths << ... | 定数を参照した時に、Rails が必要なファイルを探しに行くディレクトリを増やす
    config.autoload_paths << Rails.root.join("app/services")

    # config.eager_load_paths << ... | 本番で起動時にまとめて全部読み込む対象のディレクトリを増やす
    config.eager_load_paths << Rails.root.join("app/services")
  end
end
