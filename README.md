# Demonstration Todo Web App Combining Roda + Vue.js w/ Webpack

This is a small project to demonstrate how to combine Roda and Vue.js with webpack.
Running the application allows you to add/delete a todos the todo list.

# Setting Up and Running the Project in a Devcontainer

## Prerequisites
Before you begin, ensure you have the following installed:

- [Visual Studio Code](https://code.visualstudio.com/)
- [Docker](https://www.docker.com/products/docker-desktop)
- [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) for Visual Studio Code
- [Git](https://git-scm.com/downloads) (optional, for cloning the repository)

## Getting Started

1. Clone the repository, and open the project in visual studio code
2. Reopen in Container
- After opening the project, a popup may appear in the lower right corner asking if you want to reopen the folder in a container. Click "Reopen in Container".
- If the popup does not appear, press `F1` or `Ctrl+Shift+P` to open the command palette, type "Remote-Containers: Reopen in Container", and select it.
3. Wait for the Container to Build
- Visual Studio Code will use the `.devcontainer.json` file to build the container. This process can take some time, especially on the first run.

### Working Inside the Dev Container
- Terminal Access: Use the integrated terminal in VS Code to access the container's shell.
- Install Additional Extensions: If needed, you can install additional VS Code extensions specifically for use in the container.
- Source Control: Continue to use Git, GitGraph or any other version control system as you normally would.

### Exiting the Dev Container
When you're finished working:
- Simply close Visual Studio Code to stop the container.
- To switch back to local development, use the command palette (F1 or Ctrl+Shift+P) and select "Remote-Containers: Reopen Folder Locally".

## Setting Up the Frontend

1. set up the frontend module

  ```shell
  npm i
  ```

2. run the frontend server

  ```shell
  npm run dev
  ```

3. set the backend

  ```shell
  bundle config set --local without 'production'
  bundle install
  ```

4. set the envirnment

- Copy the `./backend_app/config/secrets_example.yml` to `./backend_app/config/secrets.yml`
- Copy the `./backend_app/db/account_seeds_example.rb` to `./backend_app/db/account_seeds.rb` and add admin account information.

1. set the db

  ```shell
  bundle exec rake db:drop
  bundle exec rake db:migrate
  bundle exec rake db:seed
  ```

## Run the Web App

```shell
puma config.ru
#or puma -e development config.ru
```
- You can access through `http://0.0.0.0:9292` for the frontend app and backend API.

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
- [] Add rack spec, style