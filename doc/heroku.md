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

4. Configure Buildpacks

The app uses both Node.js (for frontend build) and Ruby (for backend). Configure buildpacks in this order:

```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby
```

5. Set Up Environment Variables on Heroku

Required config vars:
```bash
# Allow devDependencies to be installed (needed for webpack build)
heroku config:set NPM_CONFIG_PRODUCTION=false

# Google OAuth client ID for production (NOT the localhost one from .env.local)
heroku config:set VUE_APP_GOOGLE_CLIENT_ID=<your-production-client-id>
```

Other useful commands:
- List environment variables: `heroku config`
- Set an environment variable: `heroku config:set CONFIG_VARIABLE_NAME=value`
- More info: [Heroku Config Vars](https://devcenter.heroku.com/articles/config-var)

6. Deploy to Heroku

Deploy your application by pushing to Heroku:

```bash
git push heroku main

# or if you are using a different branch
git push heroku local_branch_name:main
```

The Node.js buildpack will automatically run `npm install` and then `npm run heroku-postbuild` to build the frontend. The Ruby buildpack then starts the server.

7. Setup Database (migrate and seed)
```
heroku run rake db:setup
```

8. Wipe the postgres database (if needed)
```
heroku pg:reset DATABASE
```
More info: [Heroku Postgres CLI](https://devcenter.heroku.com/articles/managing-heroku-postgres-using-cli)

9. Open Your App
Once deployed, you can open your app in a browser:
```
heroku open
```

More info: [Getting Started with Ruby on Heroku](https://devcenter.heroku.com/articles/getting-started-with-ruby)

## Rebuilding After Config Changes

Frontend environment variables (like `VUE_APP_GOOGLE_CLIENT_ID` and `VUE_APP_GOOGLE_MAP_KEY`) are baked into the JavaScript bundle at build time. Changing a config var alone does **not** update the bundle - you must trigger a rebuild.

**Option 1: Push a commit**
```bash
git commit --allow-empty -m "Trigger rebuild"
git push heroku main
```

**Option 2: Use heroku-builds plugin** (recommended)
```bash
# Install plugin (one-time)
heroku plugins:install heroku-builds

# Trigger rebuild without a new commit
heroku builds:create
```

After rebuilding, do a hard refresh in your browser (`Cmd+Shift+R` or `Ctrl+Shift+R`) to clear cached JavaScript.
