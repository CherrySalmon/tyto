# frozen_string_literal: true

def require_app(folders = %w[lib domain infrastructure application presentation])
  # 1. Load config (defines Tyto::Api, runs Figaro.load, connects DB).
  #    Top-level config files only — initializers/ runs last.
  Dir.glob('./backend_app/config/*.rb').each { |file| require_relative file }

  # 2. Load app code (all runtime code lives in backend_app/app/).
  rb_list = Array(folders).flatten.join(',')
  Dir.glob("./backend_app/app/{#{rb_list}}/**/*.rb").each do |file|
    require_relative file
  end

  # 3. Run initializers — depend on both config and app code being loaded.
  Dir.glob('./backend_app/config/initializers/*.rb').each { |file| require_relative file }
end
