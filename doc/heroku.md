# Create a Heroku App

1. Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) if you haven't already.
2. Log in to your Heroku account via the CLI:
```
heroku login
```

3. Create a new Heroku app:

```
heroku create [app-name]  # Optional: specify an app name
```

4. Set Up Environment Variables on Heroku
 -  Use the Heroku CLI or dashboard to set any required environment variables.
 -  list the environment variables that are set on Heroku:`heroku config`
 -  set an environment variable on Heroku: `heroku config:set CONFIG_VARIABLES_NAME=value`
 -  more detailed information on setting environment variables on Heroku can be found [here](https://devcenter.heroku.com/articles/config-var)

5. Deploy to Heroku
- Deploy your application to Heroku by pushing your master/main branch to Heroku:

```
bundle config set frozen false
bundle install
npm run prod
git add .
git commit -m "your comment"

git push heroku master

# or if you are using a different branch (recommendation)

git push heroku local_branch_name:master -f

```

- Heroku will detect your Ruby application, install dependencies, run your build scripts, and start your application using the command in the `Procfile`.
- Please note that you should change the environment to the production mode in the `Procfile`. For example, `web: bundle exec puma config.ru -t 1:5 -p ${PORT:-9292} -e ${RACK_ENV:-production}` to run Puma in production mode.

6. Run Database Migrations
```
heroku run rake db:migrate
```

7. Run Database Seeds
```
heroku run rake db:seed
```

8. Wipe the postgres database
  ```
  heroku pg:reset DATABASE
  ```
  - You could get more detailed information on the [Heroku Postgres](https://devcenter.heroku.com/articles/managing-heroku-postgres-using-cli)

9. Open Your App
Once deployed, you can open your app in a browser:
```
heroku open
```
- More detailed information on deploying to Heroku using Ruby can be found [here](https://devcenter.heroku.com/articles/getting-started-with-ruby)
