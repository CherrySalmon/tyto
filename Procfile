release: bundle exec rake db:migrate
web: bundle exec puma config.ru -t 1:5 -p ${PORT:-9292} -e ${RACK_ENV:-production}
