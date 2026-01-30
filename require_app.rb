# frozen_string_literal: true

def require_app(folders = %w[domain config infrastructure/database/orm infrastructure/auth controllers application/services lib])
  rb_list = Array(folders).flatten.join(',')
  Dir.glob("./backend_app/{#{rb_list}}/**/*.rb").each do |file|
    require_relative file
  end
end
