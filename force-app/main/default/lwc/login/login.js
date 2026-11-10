import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import login from '@salesforce/apex/LoginController.login';
import requestReset from '@salesforce/apex/PasswordResetController.requestReset';
import { navigateAfterLogin, setSessionKey } from 'c/auth';
import LOGO from '@salesforce/resourceUrl/WorkreportLogo';

const LOGIN_FAILED_MESSAGE = 'メールアドレスまたはパスワードが正しくありません。';
const SYSTEM_ERROR_MESSAGE = 'ログインに失敗しました。時間をおいて再度お試しください。';
const RESET_ERROR_MESSAGE = 'メールを送信できませんでした。時間をおいて再度お試しください。';

export default class Login extends NavigationMixin(LightningElement) {
  email = '';
  password = '';
  errorMessage = '';
  isLoading = false;
  logoUrl = LOGO;
  // 表示中のダイアログ(null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;

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

  // パスワードを忘れた : 入力したメールアドレスに再設定用のメールを送る(確認ダイアログを出してから送る)
  handleForgotPassword() {
    const emailInput = this.template.querySelector('lightning-input[data-id="email"]');
    if (this.isLoading || !emailInput.reportValidity()) {
      return;
    }
    this.errorMessage = '';
    this.dialog = {
      title: 'パスワードの再設定',
      messages: ['パスワードをリセットしますか？', '入力したメールアドレスに、パスワード再設定用のメールを送信します。'],
      confirmLabel: 'はい',
      cancelLabel: 'いいえ',
      onConfirm: () => this.requestReset()
    };
  }

  async requestReset() {
    this.isLoading = true;
    try {
      const message = await requestReset({ email: this.email });
      this.dialog = { title: '送信完了', messages: message, confirmLabel: 'OK' };
    } catch (error) {
      this.dialog = {
        title: 'エラー',
        messages: error?.body?.message || RESET_ERROR_MESSAGE,
        confirmLabel: 'OK',
        isError: true
      };
    } finally {
      this.isLoading = false;
    }
  }

  // ダイアログの確定ボタン(ダイアログを閉じてから確定時の処理を行う)
  handleDialogConfirm() {
    const onConfirm = this.dialog?.onConfirm;
    this.dialog = null;
    onConfirm?.();
  }

  // ダイアログのキャンセルボタン・×ボタン・Escキー
  handleDialogClose() {
    this.dialog = null;
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
