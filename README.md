# Demonstration Todo Web App Combining Roda + Vue.js w/ Webpack

This is a small project to demonstrate how to combine Roda and Vue.js with webpack.
Running the application allows you to add/delete a todos the todo list.

## Quick Start with DevContainer (Recommended)

The DevContainer provides a pre-configured Ruby 3.2 + Node.js environment with all required tools.

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Docker](https://www.docker.com/products/docker-desktop)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Getting Started

1. Clone the repository and open in VS Code
2. Click "Reopen in Container" when prompted (or use Command Palette: `Dev Containers: Reopen in Container`)
3. Wait for container to build - `rake setup` runs automatically, installing dependencies and generating config files
4. Configure your environment:
   - Set `ADMIN_EMAIL` in `backend_app/config/secrets.yml` (your Google account email)
   - Set `VUE_APP_GOOGLE_CLIENT_ID` in `frontend_app/.env.local` (see [doc/google.md](doc/google.md))
5. Setup the database:

   ```shell
   bundle exec rake db:setup
   ```

### Exiting the DevContainer

- Close VS Code to stop the container
- Use Command Palette: `Dev Containers: Reopen Folder Locally` to switch back

## Manual Setup (Without DevContainer)

If not using DevContainer, ensure you have Ruby 3.2+ and Node.js installed, then:

```shell
rake setup                     # Install dependencies, generate secrets
# Edit backend_app/config/secrets.yml - set ADMIN_EMAIL
# Edit frontend_app/.env.local - set VUE_APP_GOOGLE_CLIENT_ID (see doc/google.md)
bundle exec rake db:setup      # Setup database
```

## Running the Application

Start both frontend and backend servers:

```shell
# Terminal 1: Frontend dev server (http://localhost:8080)
npm run dev

# Terminal 2: Backend server (http://localhost:9292)
puma config.ru
#or puma -e development config.ru
```

In production, access `http://0.0.0.0:9292` for the combined frontend and backend.

## Testing

```shell
bundle exec rake spec
```

## Deployment
- Deploy your project to heroku. [Check out](doc/heroku.md)

## System Architecture

The application is split into files/folders for back-end and front-end. See the relevant files for each part of the application below.

### Frontend

```text
[dist]
    ├── favicon.ico
    ├── index.html
    ├── main.bundle.js
    └── main.bundle.js.LICENSE.txt

[frontend_app]
    ├── App.vue
    ├── main.js
    ├── [pages]
        ├── AboutPage.Vue
        ├── HomePage copy.vue
        └── HomePage.vue
    ├── [router]
        └── index.js
    ├── [static]
        ├── favicon.ico
        ├── global.css
        └── images.png
    └── [templates]
        └── index.html

[node_modules]

package-lock.json
package.json

[webpack]
    ├── webpack.common.js
    ├── webpack.dev.js
    └── webpack.prod.js
```

### Backend

```text
.ruby-version
Gemfile
Gemfile.lock
Procfile
Procfile.dev
Rakefile

[backend_app]
    ├── [config]
        ├── envirnoment.rb
        └── secrets_example.yml
    ├── [controllers]
        └── App.rb
    ├── [db]
        ├── [migration]
            └── 001_todos_create.rb
        └── [store]
            └── development.db
    └── [models]
        └── todo.rb
    
config.ru
require_app.rb
```

## To-dos
- [ ] Add more test coverage