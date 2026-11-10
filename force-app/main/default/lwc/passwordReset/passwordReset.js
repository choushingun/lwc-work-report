/**
 * パスワード再設定画面
 *
 * パスワード再設定メールのURL(?token=...)から開き、新しいパスワードを設定する。
 * 初期表示でトークンを確認し、無効・期限切れの場合はログイン画面へ戻るボタンのみ表示する。
 */
import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import isValidToken from '@salesforce/apex/PasswordResetController.isValidToken';
import resetPassword from '@salesforce/apex/PasswordResetController.resetPassword';
import { LOGIN_PAGE } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const INVALID_TOKEN_MESSAGE =
  'パスワード再設定用のURLが無効か、有効期限が切れています。ログイン画面から再度お手続きください。';
const MIN_PASSWORD_LENGTH = 4;
const MAX_PASSWORD_LENGTH = 16;

export default class PasswordReset extends NavigationMixin(LightningElement) {
  token;
  password = '';
  passwordConfirm = '';
  isLoading = true;
  // 'form' : 入力中、'invalid' : URLが無効、'done' : 変更完了
  state;
  message = '';
  // 表示中のダイアログ(null は非表示)
  dialog = null;
  minLength = MIN_PASSWORD_LENGTH;
  maxLength = MAX_PASSWORD_LENGTH;
  lengthMessage = `パスワードは${MIN_PASSWORD_LENGTH}～${MAX_PASSWORD_LENGTH}文字で入力してください。`;

  @wire(CurrentPageReference)
  setPageReference(pageRef) {
    const token = pageRef?.state?.token;
    if (!pageRef || (this.state && token === this.token)) {
      return;
    }
    this.token = token;
    this.checkToken();
  }

  async checkToken() {
    this.isLoading = true;
    try {
      const isValid = this.token ? await isValidToken({ token: this.token }) : false;
      if (isValid) {
        this.state = 'form';
      } else {
        this.showResult('invalid', INVALID_TOKEN_MESSAGE);
      }
    } catch (error) {
      this.showResult('invalid', error?.body?.message || SYSTEM_ERROR_MESSAGE);
    } finally {
      this.isLoading = false;
    }
  }

  get showForm() {
    return this.state === 'form';
  }

  get showMessage() {
    return this.state === 'invalid' || this.state === 'done';
  }

  get messageClass() {
    return this.state === 'invalid' ? 'message message_error' : 'message';
  }

  handlePasswordChange(event) {
    this.password = event.target.value;
  }

  handlePasswordConfirmChange(event) {
    this.passwordConfirm = event.target.value;
  }

  async handleSave() {
    if (this.isLoading || !this.validate()) {
      return;
    }
    this.isLoading = true;
    try {
      const message = await resetPassword({ token: this.token, password: this.password });
      this.showResult('done', message);
    } catch (error) {
      this.dialog = {
        title: 'エラー',
        messages: error?.body?.message || SYSTEM_ERROR_MESSAGE,
        confirmLabel: 'OK',
        isError: true
      };
    } finally {
      this.isLoading = false;
    }
  }

  // 必須・文字数は各入力欄で、確認用との一致はここでチェックする
  validate() {
    const inputs = [...this.template.querySelectorAll('lightning-input')];
    const confirmInput = inputs.find((input) => input.name === 'passwordConfirm');
    confirmInput.setCustomValidity(
      this.passwordConfirm && this.password !== this.passwordConfirm ? 'パスワードが一致しません。' : ''
    );
    return inputs.reduce((isValid, input) => input.reportValidity() && isValid, true);
  }

  showResult(state, message) {
    this.state = state;
    this.message = message;
    this.password = '';
    this.passwordConfirm = '';
  }

  handleDialogClose() {
    this.dialog = null;
  }

  handleGoToLogin() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: LOGIN_PAGE }
    });
  }
}
