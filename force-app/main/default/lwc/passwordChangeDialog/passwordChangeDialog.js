/**
 * パスワード変更ダイアログ(個人情報設定画面で使う)
 *
 * 現在のパスワード・新しいパスワード・新しいパスワード(確認)を入力する。
 * 入力チェック(必須・文字数・確認用との一致)のみ行い、変更処理は呼び出し元で行う。
 * 表示・非表示は呼び出し元で lwc:if により切り替える。
 * イベント : save(変更ボタン。detail = { currentPassword, newPassword })、close(キャンセルボタン・×ボタン・Escキー)
 */
import { LightningElement, api } from 'lwc';

const MIN_PASSWORD_LENGTH = 4;
const MAX_PASSWORD_LENGTH = 16;

export default class PasswordChangeDialog extends LightningElement {
  // 処理中(ボタンを押せないようにする)
  @api isLoading = false;
  // 変更に失敗した場合のエラーメッセージ(ダイアログ内に赤字で表示する)
  @api errorMessage = '';

  currentPassword = '';
  newPassword = '';
  newPasswordConfirm = '';
  minLength = MIN_PASSWORD_LENGTH;
  maxLength = MAX_PASSWORD_LENGTH;
  lengthMessage = `パスワードは${MIN_PASSWORD_LENGTH}～${MAX_PASSWORD_LENGTH}文字で入力してください。`;
  focused = false;

  // 開いたときは現在のパスワードにフォーカスする
  renderedCallback() {
    if (!this.focused) {
      this.focused = true;
      this.template.querySelector('lightning-input[data-name="currentPassword"]')?.focus();
    }
  }

  handleInputChange(event) {
    this[event.target.dataset.name] = event.target.value;
  }

  handleSave() {
    if (this.isLoading || !this.validate()) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent('save', {
        detail: { currentPassword: this.currentPassword, newPassword: this.newPassword }
      })
    );
  }

  // 必須・文字数は各入力欄で、確認用との一致・現在のパスワードとの違いはここでチェックする
  validate() {
    const inputs = [...this.template.querySelectorAll('lightning-input')];
    const newInput = inputs.find((input) => input.dataset.name === 'newPassword');
    const confirmInput = inputs.find((input) => input.dataset.name === 'newPasswordConfirm');
    newInput.setCustomValidity(
      this.newPassword && this.newPassword === this.currentPassword
        ? '現在のパスワードと異なるパスワードを入力してください。'
        : ''
    );
    confirmInput.setCustomValidity(
      this.newPasswordConfirm && this.newPassword !== this.newPasswordConfirm ? 'パスワードが一致しません。' : ''
    );
    return inputs.reduce((isValid, input) => input.reportValidity() && isValid, true);
  }

  handleClose() {
    if (!this.isLoading) {
      this.dispatchEvent(new CustomEvent('close'));
    }
  }

  // Escキーで閉じる、Enterキーで変更する
  handleKeyDown(event) {
    if (event.key === 'Escape') {
      this.handleClose();
    } else if (event.key === 'Enter') {
      this.handleSave();
    }
  }
}
