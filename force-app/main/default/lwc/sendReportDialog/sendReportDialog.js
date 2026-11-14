/**
 * 勤務表の自社送付ダイアログ(勤務承認画面用)
 *
 * 送付する勤務表・送付先を表示し、現場承認者からの承認メール内容を入力する。
 * 表示・非表示は呼び出し元で lwc:if により切り替える。
 * イベント : send(先行送付・自社送付ボタン。detail: { isApproval, replyMailContent })
 *            close(キャンセルボタン・×ボタン・Escキー)
 * 自社送付(isApproval: true)は承認メール内容が必須。先行送付は任意。
 */
import { LightningElement, api } from 'lwc';

export default class SendReportDialog extends LightningElement {
  // checkSendReports の結果(ApprovalListController.SendInfo)
  @api info;

  focused = false;

  get reportNames() {
    return this.info?.reportNames ?? [];
  }

  get projectNames() {
    return (this.info?.projectNames ?? []).join('、') || '-';
  }

  get reportToMails() {
    return this.info?.reportToMails ?? [];
  }

  // 開いたときは承認メール内容にフォーカスする
  renderedCallback() {
    if (!this.focused) {
      this.focused = true;
      this.template.querySelector('.reply-mail')?.focus();
    }
  }

  handleAdvanceSend() {
    this.send(false);
  }

  handleApprovalSend() {
    this.send(true);
  }

  send(isApproval) {
    const input = this.template.querySelector('.reply-mail');
    const replyMailContent = input.value?.trim() ?? '';
    input.setCustomValidity(isApproval && !replyMailContent ? '承認メール内容を入力してください。' : '');
    if (!input.reportValidity()) {
      return;
    }
    this.dispatchEvent(new CustomEvent('send', { detail: { isApproval, replyMailContent } }));
  }

  // 入力したら入力エラーを消す
  handleInput(event) {
    event.target.setCustomValidity('');
    event.target.reportValidity();
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
