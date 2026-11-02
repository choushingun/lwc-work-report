import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import login from '@salesforce/apex/LoginController.login';

const SESSION_STORAGE_KEY = 'workReportSessionKey';
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
    try {
      const sessionKey = await login({
        email: this.email,
        password: this.password
      });
      if (sessionKey) {
        sessionStorage.setItem(SESSION_STORAGE_KEY, sessionKey);
        this[NavigationMixin.Navigate]({
          type: 'comm__namedPage',
          attributes: { name: 'Home' }
        });
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
  }

  validate() {
    return [...this.template.querySelectorAll('lightning-input')].reduce(
      (isValid, input) => input.reportValidity() && isValid,
      true
    );
  }
}
