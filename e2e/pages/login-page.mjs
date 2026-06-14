// LoginPage models ONLY the /login route. The Login.vue UI (the Google OAuth
// button) is deliberately unmodeled: E2E auth uses cookie injection and bypasses
// Google entirely (PLAN.test-ui Q5). This object's single `url` matcher is the
// whole contract specs assert — "the app is on /login" — so its anemia is the
// signal that login itself is out of scope here, not an oversight.
export class LoginPage {
  url = /\/login/;
}
