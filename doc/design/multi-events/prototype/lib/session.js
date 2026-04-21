import Cookies from 'js-cookie';

export default {
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
