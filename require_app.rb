# frozen_string_literal: true

def require_app(folders = %w[domain infrastructure application presentation lib])
  # Load config first (stays at backend_app/config/)
  Dir.glob('./backend_app/config/**/*.rb').each { |file| require_relative file }

  # Load app code (all runtime code lives in backend_app/app/)
  rb_list = Array(folders).flatten.join(',')
  Dir.glob("./backend_app/app/{#{rb_list}}/**/*.rb").each do |file|
    require_relative file
  end
end
