<template>
  <div>
    <div class="login-container">Login</div>
    <div class="login-btn" @click="handleGoogleAccessTokenLogin">
      <img class="login-icon-img" src="../static/google_icon.png" width="50" height="50"/>
      <div class="login-icon-text">Sign in with Google</div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import Cookies from 'js-cookie'
import { ElNotification } from 'element-plus'
import { googleTokenLogin } from 'vue3-google-login'
export default {
  name: 'LoginPage',

  data() {
    return {
    };
  },
  methods: {
    async fetchLoginToken(accessToken) {
      try {
        const { status, data } = await axios.post('/api/auth/verify_google_token', { accessToken: accessToken });
        if (status === 200 || status === 201) {
          this.setUserInfoCookies(data.user_info);
          if (this.$route.query.redirect && this.$route.query.redirect!='/' ) {
            this.$router.push(this.$route.query.redirect)
          }
          else {
            this.$router.push('/course')
          }
        } 
      } catch (error) {
        console.error('Error:', error.response || error);
        ElNotification({
          title: 'Error',
          message: 'Account not found, please contact your teaching staff.',
          type: 'error',
        })
      }
    },
    async handleGoogleAccessTokenLogin() {
      try {
        const response = await googleTokenLogin({
            clientId: process.env.VUE_APP_GOOGLE_CLIENT_ID,
            scope: 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile'
        })
        this.fetchLoginToken(response.access_token)
      } catch (error) {
          console.error('Login Failed:', error);
      }
    },
    setUserInfoCookies(user_info) {
      const expDay = 180;
      Cookies.set('account_id', user_info.id, { expires: expDay });
      Cookies.set('account_roles', user_info.roles.join(','), { expires: expDay });
      Cookies.set('account_credential', user_info.credential, { expires: expDay });
      Cookies.set('account_img', user_info.avatar, { expires: expDay })
      Cookies.set('account_name', user_info.name, { expires: expDay })
    },
  },
};
</script>

<style scoped>
p {
  margin-top: 12px;
}

.login-container {
  font-size: 2.5rem;
  font-weight: 700;
  margin: 40px 0;
}
.login-btn {
  display: flex;
  justify-content: center;
  background-color: #fff;
  padding: 5px 5px;
  width: 260px;
  margin: auto;
  border-radius: 10px;
  cursor: pointer;
  box-shadow: 0 2px 4px rgba(0, 0, 0, .12), 0 0 6px rgba(0, 0, 0, .04);
}
.login-icon-img {
  display: inline;
}
.login-icon-text {
  display: inline;
  line-height: 50px;
  margin-left: 10px;
}
</style>
