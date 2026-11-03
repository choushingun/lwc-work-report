import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import logout from '@salesforce/apex/LoginController.logout';

const SESSION_STORAGE_KEY = 'workReportSessionKey';
const SYSTEM_ERROR_MESSAGE = 'ログアウトに失敗しました。時間をおいて再度お試しください。';

export default class WorkReportLogout extends NavigationMixin(LightningElement) {
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
    try {
      await logout({
        sessionKey: sessionStorage.getItem(SESSION_STORAGE_KEY)
      });
      sessionStorage.removeItem(SESSION_STORAGE_KEY);
    } catch {
      // キーを残し、再試行でセッションを無効化できるようにする
      this.errorMessage = SYSTEM_ERROR_MESSAGE;
    }
    this.isLoading = false;
  }

  handleGoToLogin() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: 'custom_employee_login__c' }
    });
  }
}
