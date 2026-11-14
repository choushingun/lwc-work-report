/**
 * 共通ダイアログ(確認ダイアログ・処理結果ダイアログ)
 *
 * 表示・非表示は呼び出し元で lwc:if により切り替える。
 * cancel-label を指定すると2ボタン(確認用)、省略すると確定ボタンのみ(処理結果用)になる。
 * input-label を指定すると本文の下に入力欄(複数行)を表示する(却下理由など。入力必須)。
 * イベント : confirm(確定ボタン。detail.value に入力値)、close(キャンセルボタン・×ボタン・Escキー)
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
  // 入力欄のラベル(省略時は入力欄を表示しない)
  @api inputLabel;
  // 入力欄の最大文字数
  @api inputMaxLength;

  focused = false;

  get messageLines() {
    const lines = Array.isArray(this.messages) ? this.messages : [this.messages];
    return lines.filter((text) => text).map((text, index) => ({ key: `${index}`, text }));
  }

  get messageClass() {
    return this.isError ? 'text-red' : '';
  }

  // 開いたときは入力欄(ない場合は確定ボタン)にフォーカスする
  renderedCallback() {
    if (!this.focused) {
      this.focused = true;
      (this.template.querySelector('.dialog-input') ?? this.template.querySelector('.confirm-button'))?.focus();
    }
  }

  // 入力欄がある場合は入力チェックを行い、問題がなければ入力値を渡す
  handleConfirm() {
    const input = this.template.querySelector('.dialog-input');
    if (input && !input.reportValidity()) {
      return;
    }
    this.dispatchEvent(new CustomEvent('confirm', { detail: { value: input?.value?.trim() } }));
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
