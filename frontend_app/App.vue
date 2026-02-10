<template>
  <div id="app">
    <el-container>
      <template v-if="account">
        <template v-if="account.roles.includes('admin')">
          <div class="app-meun-bar">
            <el-aside class="aside-container" :width="isCollapse?'60px':'300px'">
              <el-menu
                default-active="/course"
                class="el-menu-vertical"
                :collapse="isCollapse"
                @select="handleSelect"
                background-color="#545c64"
                text-color="#fff"
                active-text-color="#ffd04b"
                style="position: fixed;"
              >
                <el-menu-item @click="isCollapse = !isCollapse">
                  <el-icon><component :is="isCollapse?'Expand':'Fold'" /></el-icon>
                  <template #title>{{ isCollapse?'Expand Menu':'Collapse Menu' }}</template>
                </el-menu-item>
                <el-menu-item v-for="item in menuItems" :key="item.index" :index="item.index">
                  <el-icon><component :is="item.icon" /></el-icon>
                  <template #title>{{ item.title }}</template>
                </el-menu-item>
              </el-menu>
            </el-aside>
          </div>
        </template>
      </template>
      
      <el-container class="app-container">
        <el-header height="80" style="background-color: #EFCD76;" class="noselect">
          <div class="icon-container">
            <div @click="changeRoute('/course')">
              <img class="icon-img" src="./static/icon.png" width="50" height="50"/>
              <span class="icon-text">TYTO</span>
            </div>
            <span class="avatar-name" v-if="!account.img == ''">{{ account.name }} - {{ account.roles.join(", ") }}</span>
            <template v-if="!account.img == ''">
              <el-popover
                trigger="hover"
                >
                <template #reference>
                  <el-avatar class="avatar-btn" :src="account.img"/>
                </template>
                <template #default>
                  <span class="avatar-mobile-name" v-if="!account.img == ''">{{ account.name }} <br> {{ account.roles.join(", ") }}</span>
                  <template v-if="account.roles.includes('admin')">
                    <div v-for="item in menuItems" :key="item.index" :index="item.index" @click="changeRoute(item.index)" class="menu-mobile-btn">{{ item.title }}</div>
                  </template>
                  <div class="logout-btn" @click="logout()">Logout</div>
                </template>
              </el-popover>
            </template>
          </div>
        </el-header>
        <el-container>
          <el-main>
            <router-view v-slot="{ Component }">
              <transition name="fade" mode="out-in">
                <component :is="Component" />
              </transition>
            </router-view>
          </el-main>
          <el-footer>© copyright Tyto Group</el-footer>
        </el-container>
      </el-container>
    </el-container>
  </div>
</template>

<script>
import cookieManager from './lib/cookieManager';
// Debounce function to limit the rate at which a function is executed
const debounce = (callback, delay) => {
  let tid;
  return function (...args) {
    const ctx = this;
    if (tid) clearTimeout(tid);
    tid = setTimeout(() => {
      callback.apply(ctx, args);
    }, delay);
  };
};

const OriginalResizeObserver = window.ResizeObserver;

window.ResizeObserver = class ResizeObserver extends OriginalResizeObserver {
  constructor(callback) {
    super(debounce(callback, 20));
  }
};

export default {
    data() {
        return {
          isCollapse: true,
          menuItems: [
            { index: '/manage-account', icon: 'UserFilled', title: 'Account Management' },
            { index: '/course', icon: 'document', title: 'Course' },
            // { index: '/login', icon: '', title: 'Login' }, // only for test, to be delete before publish
          ],
          account: {
            roles: [],
            credential: '',
            img: ''
          }
        };
    },
    created() {
      this.account = cookieManager.getAccount()
      if(!this.account) {
        this.logout()
        if (window.location.pathname!='/login') {
          this.$router.push({ path: '/login', query: { redirect: window.location.pathname } })
        }
      }
    },
    watch: {
      $route(to, from) {
        if (from.name == 'Login' || to.name == 'Login') {
          this.account = cookieManager.getAccount()
        }
      }
    },
    methods: {
      handleSelect(key, keyPath) {
        this.$router.push(key)
      },
      changeRoute(route) {
        if(this.account) {
          this.$router.push(route)
        }
      },
      logout() {
        cookieManager.onLogout()
        this.$router.push('/login?redirect='+this.$route.fullPath)
      }
    }
  }
</script>

<style lang="css">
@import url('https://fonts.googleapis.com/css2?family=Asap:ital,wght@0,100..900;1,100..900&family=Noto+Sans:ital,wght@0,100..900;1,100..900&family=Roboto:ital,wght@0,100;0,300;0,400;0,500;0,700;0,900;1,100;1,300;1,400;1,500;1,700;1,900&display=swap');
* {
  font-family: Inter, 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', '微软雅黑', Arial, sans-serif;
}
#app {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.app-meun-bar {
  display: block;
}
.el-menu-vertical {
  height: 100vh;
  width: 300px;
}
.el-table--fit  {
  border-radius: 6px; -moz-border-radius: 6px; -webkit-border-radius: 6px;
}

.app-container {
  min-height: 100vh;
}
.aside-container {
  transition: 0.8s;
}

.icon-container {
  display: flex;
  flex-wrap: wrap;
}

.logout-btn, .menu-mobile-btn {
  width: 100%;
  font-weight: 800 !important;
  font-size: 1rem;
  text-align: center;
  padding: 10px 0;
  border-top: 1px solid #e3e3e3;
  border-bottom: 1px solid #e3e3e3;
}
@media screen and (max-width: 640px) {
  .icon-container {
    justify-content: space-between;
  }
  .avatar-name {
    display: none;
  }
  .menu-mobile-btn {
    word-break: break-word;
    display: block;
  }
  .avatar-mobile-name {
    word-break: break-word;
    display: block;
    text-align: center;
    color: #afafaf !important;
  }
  .app-meun-bar {
    display: none;
  }
}
@media screen and (min-width: 640px) {
  .avatar-mobile-name {
    display: none;
  }
  .menu-mobile-btn {
    display: none;
  }
}

.icon-text {
  font-family: Inter, 'Helvetica Neue', Helvetica, 'PingFang SC','Hiragino Sans GB', 'Microsoft YaHei', '微软雅黑', Arial, sans-serif;
  font-size: 2.5rem;
  font-weight: 900;
  line-height: 80px;
  font-style: italic;
  color: #fff;
  -webkit-text-fill-color: #EFCD76;
  -webkit-text-stroke: 3px #fff;
  cursor: pointer;
  transition: 0.8s;
  position: absolute;
}

.icon-img {
  margin: 15px;
  background-color:#EFCD76;
  border-radius: 50%;
  cursor: pointer;
}

.icon-text:hover{
  -webkit-filter: drop-shadow(3px 3px 3px #ffe8a472);
  filter: drop-shadow(3px 3px 3px #b6a77b72);
}
.avatar-btn {
  margin: 20px;
  cursor: pointer;
}
.avatar-btn:hover {
  -webkit-filter: drop-shadow(3px 3px 5px #ffcb47);
  filter: drop-shadow(3px 3px 5px #b8a671fa);
}
.avatar-name {
  color: #fff;
  font-weight: 900;
  line-height: 80px;
  margin-left: auto;
}

.noselect {
  -webkit-touch-callout: none; /* iOS Safari */
    -webkit-user-select: none; /* Safari */
     -khtml-user-select: none; /* Konqueror HTML */
       -moz-user-select: none; /* Old versions of Firefox */
        -ms-user-select: none; /* Internet Explorer/Edge */
            user-select: none; /* Non-prefixed version, currently
                                  supported by Chrome, Edge, Opera and Firefox */
}

.page-title {
  font-size: 3em;
  font-weight: 700;
  padding: 10px 10px 30px 10px;
}

</style>
