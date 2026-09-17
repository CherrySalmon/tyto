import Cookies from 'js-cookie';
import api from './tytoApi';

// The session cookies hold what the header, nav, and route guard display.
// They are written at login and refreshed from the server on navigation, so
// a role change made while someone is logged in shows up without re-login.
// The server never trusts them: it reads roles from the database per request.
const COOKIE_DAYS = 180;

function writeAccount(user_info, credential) {
    const options = { expires: COOKIE_DAYS };
    Cookies.set('account_id', user_info.id, options);
    Cookies.set('account_roles', (user_info.roles || []).join(','), options);
    Cookies.set('account_credential', credential, options);
    Cookies.set('account_img', user_info.avatar ?? '', options);
    Cookies.set('account_name', user_info.name ?? '', options);
}

export default {
    // Login: store the whole payload, credential included.
    applyAccount(user_info) {
        writeAccount(user_info, user_info.credential);
    },

    // Re-read roles, name, and avatar from the server; the credential stays.
    // Resolves to the (possibly updated) account, or what was there on failure.
    async refresh() {
        const current = this.getAccount();
        if (!current) return false;
        try {
            const { data } = await api.get('/auth/session');
            writeAccount(data.data, current.credential);
        } catch (error) {
            console.error('Could not refresh session', error);
        }
        return this.getAccount();
    },

    getCookie(name) {
        return Cookies.get(name);
    },

    setCookie(name, value, options) {
        Cookies.set(name, value, options);
    },

    removeCookie(name) {
        Cookies.remove(name);
    },

    getAccount() {
        let account = {}

        try {
            account.id = Cookies.get('account_id') ? Cookies.get('account_id') : false
            account.roles = Cookies.get('account_roles') ? Cookies.get('account_roles').split(',') : [];
            account.credential = Cookies.get('account_credential') ? Cookies.get('account_credential') : false
            account.img = Cookies.get('account_img') ? Cookies.get('account_img') : false
            account.name = Cookies.get('account_name') ? Cookies.get('account_name') : false
            if (account.credential) {
                return account
            }
            else {
                return false
            }
        }
        catch (e) {
            console.log(e)
        }
    },
    isLogout() {
        return Cookies.get('account_credential') ? Cookies.get('account_credential') : false
    },
    onLogout() {
        Cookies.remove("account_id");
        Cookies.remove("account_roles");
        Cookies.remove("account_credential");
        Cookies.remove("account_img");
        Cookies.remove("account_name");
    }
};
