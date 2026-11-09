import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import logout from '@salesforce/apex/LoginController.logout';
import { LOGIN_PAGE, clearSessionKey, getSessionKey } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = 'ログアウトに失敗しました。時間をおいて再度お試しください。';

export default class Logout extends NavigationMixin(LightningElement) {
  errorMessage = '';
  isLoading = true;

  connectedCallback() {
    this.handleLogout();
  }

  get isLoggedOut() {
    return !this.isLoading && !this.errorMessage;
  }

  async handleLogout() {
    this.errorMessage = '';
    this.isLoading = true;
    this.showSpinner();
    try {
      await logout({
        sessionKey: getSessionKey()
      });
      clearSessionKey();
    } catch {
      // キーを残し、再試行でセッションを無効化できるようにする
      this.errorMessage = SYSTEM_ERROR_MESSAGE;
    }
    this.isLoading = false;
    this.hideSpinner();
  }

  handleGoToLogin() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: LOGIN_PAGE }
    });
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
