import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import login from '@salesforce/apex/LoginController.login';
import { navigateAfterLogin, setSessionKey } from 'c/workReportAuth';

const LOGIN_FAILED_MESSAGE = 'メールアドレスまたはパスワードが正しくありません。';
const SYSTEM_ERROR_MESSAGE = 'ログインに失敗しました。時間をおいて再度お試しください。';

export default class WorkReportLogin extends NavigationMixin(LightningElement) {
  email = '';
  password = '';
  errorMessage = '';
  isLoading = false;

  handleEmailChange(event) {
    this.email = event.target.value;
  }

  handlePasswordChange(event) {
    this.password = event.target.value;
  }

  handleKeyDown(event) {
    if (event.key === 'Enter') {
      this.handleLogin();
    }
  }

  async handleLogin() {
    if (this.isLoading || !this.validate()) {
      return;
    }

    this.errorMessage = '';
    this.isLoading = true;
    this.showSpinner();
    try {
      const sessionKey = await login({
        email: this.email,
        password: this.password
      });
      if (sessionKey) {
        setSessionKey(sessionKey);
        // 未ログインで直接アクセスした画面があれば、その画面へ戻る
        navigateAfterLogin(this);
        return;
      }
      this.showError(LOGIN_FAILED_MESSAGE);
    } catch {
      this.showError(SYSTEM_ERROR_MESSAGE);
    }
  }

  showError(message) {
    this.errorMessage = message;
    this.password = '';
    this.isLoading = false;
    this.hideSpinner();
  }

  validate() {
    return [...this.template.querySelectorAll('lightning-input')].reduce(
      (isValid, input) => input.reportValidity() && isValid,
      true
    );
  }

  // スピナーは描画後でないと取得できないため、描画を待ってから操作する
  async showSpinner() {
    await Promise.resolve();
    this.template.querySelector('c-spinner')?.showSpinner();
  }

  async hideSpinner() {
    await Promise.resolve();
    this.template.querySelector('c-spinner')?.hideSpinner();
  }
}
