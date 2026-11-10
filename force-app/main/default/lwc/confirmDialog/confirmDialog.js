/**
 * 共通ダイアログ(確認ダイアログ・処理結果ダイアログ)
 *
 * 表示・非表示は呼び出し元で lwc:if により切り替える。
 * cancel-label を指定すると2ボタン(確認用)、省略すると確定ボタンのみ(処理結果用)になる。
 * イベント : confirm(確定ボタン)、close(キャンセルボタン・×ボタン・Escキー)
 */
import { LightningElement, api } from 'lwc';

export default class ConfirmDialog extends LightningElement {
  @api title = '';
  // 本文(文字列または文字列の配列。配列の場合は1要素1行で表示する)
  @api messages;
  @api confirmLabel = 'OK';
  @api cancelLabel;
  // エラーの場合は本文を赤字にする
  @api isError = false;

  focused = false;

  get messageLines() {
    const lines = Array.isArray(this.messages) ? this.messages : [this.messages];
    return lines.filter((text) => text).map((text, index) => ({ key: `${index}`, text }));
  }

  get messageClass() {
    return this.isError ? 'text-red' : '';
  }

  // 開いたときは確定ボタンにフォーカスする
  renderedCallback() {
    if (!this.focused) {
      this.focused = true;
      this.template.querySelector('.confirm-button')?.focus();
    }
  }

  handleConfirm() {
    this.dispatchEvent(new CustomEvent('confirm'));
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent('close'));
  }

  handleKeyDown(event) {
    if (event.key === 'Escape') {
      this.handleClose();
    }
  }
}
