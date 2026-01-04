# Google OAuth Login

1. Go to the [Google API Console](https://console.cloud.google.com/apis/credentials).
2. Create a new project or select an existing one.
3. Configure the [OAuth consent screen](https://developers.google.com/workspace/guides/configure-oauth-consent#configure_oauth_consent).
![](images/google_oauth_consent_screen.png)
4. Create [OAuth 2.0 credentials](https://developers.google.com/workspace/guides/create-credentials#oauth-client-id).
- credentials > create credentials > OAuth client ID
![](images/google_oauth_credentials.png)
- Choose **web application** as the type of project/application's credential
- Add these URLs to **Authorized JavaScript origins**:
  - `http://localhost:8080` (frontend dev server)
  - `http://localhost:9292` (backend server)
![](images/google_authorized_javascript_origins.png)
5. Copy the **Client ID** into your `frontend_app/.env.local` as `VUE_APP_GOOGLE_CLIENT_ID`
