import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getReports from '@salesforce/apex/ApprovalListController.getReports';
import checkApprove from '@salesforce/apex/ApprovalListController.checkApprove';
import approveReports from '@salesforce/apex/ApprovalListController.approveReports';
import checkReject from '@salesforce/apex/ApprovalListController.checkReject';
import rejectReports from '@salesforce/apex/ApprovalListController.rejectReports';
import checkSendReports from '@salesforce/apex/ApprovalListController.checkSendReports';
import sendReports from '@salesforce/apex/ApprovalListController.sendReports';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const MONTH_REPORT_PAGE = 'workreport_view__c';
// 年月の選択範囲(当月から過去・未来の月数)
const PAST_MONTHS = 24;
const FUTURE_MONTHS = 1;
const DEFAULT_PAGE_SIZE = 10;
// 却下理由の最大文字数(Workreport__c.RejectComment__c)
const REJECT_COMMENT_MAX_LENGTH = 255;

// 年月(YYYY-MM)を months か月ずらす
function addMonths(yearMonth, months) {
  const [year, month] = yearMonth.split('-').map(Number);
  const date = new Date(year, month - 1 + months, 1);
  return `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}`;
}

function currentYearMonth() {
  const now = new Date();
  return `${now.getFullYear()}-${`${now.getMonth() + 1}`.padStart(2, '0')}`;
}

export default class ApprovalList extends NavigationMixin(LightningElement) {
  reports = [];
  // 選択中の年月(YYYY-MM)。URLのパラメータ month で保持し、参照画面から戻っても同じ年月を表示する
  yearMonth;
  // チェックを付けた勤務表Id
  selectedIds = new Set();
  pageNumber = 1;
  pageSize = DEFAULT_PAGE_SIZE;
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 日時はSalesforce標準画面と同じ24時間表記(例：2026/11/09 0:15)にする
  hour12 = false;
  pageRef;
  // 表示中のダイアログ(共通ダイアログで表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, inputLabel, inputMaxLength, onConfirm(確定時の処理。引数は入力値) }
  dialog = null;
  // 自社送付ダイアログに表示する内容(null は非表示) { info: SendInfo, reportIds }
  sendDialog = null;

  @wire(CurrentPageReference)
  setPageReference(pageRef) {
    if (!pageRef) {
      return;
    }
    this.pageRef = pageRef;
    const yearMonth = this.isValidYearMonth(pageRef.state?.month) ? pageRef.state.month : currentYearMonth();
    if (yearMonth === this.yearMonth) {
      return;
    }
    this.yearMonth = yearMonth;
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.loadReports();
  }

  // 選択範囲内の年月か
  isValidYearMonth(value) {
    return /^\d{4}-(0[1-9]|1[0-2])$/.test(value ?? '') && value >= this.minYearMonth && value <= this.maxYearMonth;
  }

  get minYearMonth() {
    return addMonths(currentYearMonth(), -PAST_MONTHS);
  }

  get maxYearMonth() {
    return addMonths(currentYearMonth(), FUTURE_MONTHS);
  }

  // 年月部品に渡す値・範囲(yyyyMM。この画面の年月は YYYY-MM で持つ)
  get pickerValue() {
    return this.yearMonth?.replace('-', '') ?? '';
  }

  get pickerMin() {
    return this.minYearMonth.replace('-', '');
  }

  get pickerMax() {
    return this.maxYearMonth.replace('-', '');
  }

  get isFirstMonth() {
    return this.isLoading || this.yearMonth <= this.minYearMonth;
  }

  get isLastMonth() {
    return this.isLoading || this.yearMonth >= this.maxYearMonth;
  }

  // 初期表示のエラーは画面上部に表示する(画面表示後のエラーはダイアログで表示する)
  get showPageError() {
    return !this.isAuthenticated && !!this.errorMessage;
  }

  get hasReports() {
    return this.reports.length > 0;
  }

  get noReports() {
    return !this.isLoading && !this.hasReports;
  }

  // 表示中のページの勤務表
  get pageReports() {
    const start = (this.pageNumber - 1) * this.pageSize;
    return this.reports.slice(start, start + this.pageSize);
  }

  get displayReports() {
    return this.pageReports.map((r) => ({ ...r, isSelected: this.selectedIds.has(r.Id) }));
  }

  // 表示中のページの勤務表がすべて選択されているか
  get isAllSelected() {
    const pageReports = this.pageReports;
    return pageReports.length > 0 && pageReports.every((r) => this.selectedIds.has(r.Id));
  }

  // 年月の勤務表を取得する(1ページ目を表示する)
  loadReports() {
    this.callApex(async () => {
      await this.fetchReports();
      this.pageNumber = 1;
    });
  }

  // 一覧を取得し直す(選択はクリアする)
  async fetchReports() {
    const [yyyy, mm] = this.yearMonth.split('-');
    const records = await getReports({ sessionKey: getSessionKey(), yyyy, mm });
    this.reports = records.map((r) => ({
      ...r,
      workDaysLabel: `${r.WorkDays__c ?? 0}/${r.StandardWorkDays__c ?? 0}`,
      overtimeClass: r.Overtime__c < 0 ? 'text-red' : ''
    }));
    this.selectedIds = new Set();
    this.pageNumber = Math.min(this.pageNumber, Math.max(1, Math.ceil(this.reports.length / this.pageSize)));
    this.isAuthenticated = true;
  }

  handleApprove() {
    this.runAction({
      title: '承認',
      check: checkApprove,
      execute: (reportIds) => approveReports({ sessionKey: getSessionKey(), reportIds })
    });
  }

  handleReject() {
    this.runAction({
      title: '却下',
      check: checkReject,
      inputLabel: '却下理由',
      inputMaxLength: REJECT_COMMENT_MAX_LENGTH,
      execute: (reportIds, comment) => rejectReports({ sessionKey: getSessionKey(), reportIds, comment })
    });
  }

  // 自社送付(入力チェック後、自社送付ダイアログで承認メール内容を入力して先行送付・自社送付する)
  handleSendReports() {
    const reportIds = [...this.selectedIds];
    if (reportIds.length === 0) {
      this.openResultDialog('勤務表を選択してください。', true);
      return;
    }
    this.callApex(async () => {
      const info = await checkSendReports({ sessionKey: getSessionKey(), reportIds });
      this.sendDialog = { info, reportIds };
    });
  }

  // 自社送付ダイアログの先行送付・自社送付ボタン
  handleSendDialogSend(event) {
    const { reportIds } = this.sendDialog;
    const { isApproval, replyMailContent } = event.detail;
    this.sendDialog = null;
    this.callApex(async () => {
      const message = await sendReports({ sessionKey: getSessionKey(), reportIds, replyMailContent, isApproval });
      await this.fetchReports();
      return message;
    });
  }

  handleSendDialogClose() {
    this.sendDialog = null;
  }

  // 選択した勤務表への操作(入力チェック後、確認ダイアログで確定したら実行し、一覧を取得し直す)
  runAction({ title, check, execute, confirmLabel = title, inputLabel, inputMaxLength }) {
    const reportIds = [...this.selectedIds];
    // ボタンは常に押せるため、未選択の場合はサーバーを呼ばずにエラーを表示する
    if (reportIds.length === 0) {
      this.openResultDialog('勤務表を選択してください。', true);
      return;
    }
    this.callApex(async () => {
      const messages = await check({ sessionKey: getSessionKey(), reportIds });
      this.dialog = {
        title,
        messages,
        confirmLabel,
        cancelLabel: 'キャンセル',
        inputLabel,
        inputMaxLength,
        onConfirm: (value) =>
          this.callApex(async () => {
            const message = await execute(reportIds, value);
            await this.fetchReports();
            return message;
          })
      };
    });
  }

  openResultDialog(message, isError) {
    this.dialog = { title: isError ? 'エラー' : '完了', messages: message, confirmLabel: 'OK', isError };
  }

  // ダイアログの確定ボタン(ダイアログを閉じてから確定時の処理を行う)
  handleDialogConfirm(event) {
    const onConfirm = this.dialog?.onConfirm;
    this.dialog = null;
    onConfirm?.(event.detail?.value);
  }

  // ダイアログのキャンセルボタン・×ボタン・Escキー
  handleDialogClose() {
    this.dialog = null;
  }

  handlePreviousMonth() {
    this.changeMonth(addMonths(this.yearMonth, -1));
  }

  handleNextMonth() {
    this.changeMonth(addMonths(this.yearMonth, 1));
  }

  // 年月部品で選んだ年月(yyyyMM)を YYYY-MM にして切り替える(空にした場合は切り替えない)
  handleMonthChange(event) {
    const value = event.detail.value;
    if (!value) {
      return;
    }
    this.changeMonth(`${value.slice(0, 4)}-${value.slice(4, 6)}`);
  }

  // 年月をURLに設定する(ページ参照が変わると一覧を再取得する。履歴は置き換える)
  changeMonth(yearMonth) {
    this[NavigationMixin.Navigate](
      { ...this.pageRef, state: { ...this.pageRef.state, month: yearMonth } },
      true
    );
  }

  // ページング(ページ番号・ページサイズ)の変更
  handlePageChange(event) {
    this.pageNumber = event.detail.pageNumber;
    this.pageSize = event.detail.pageSize;
  }

  // すべて選択は表示中のページの勤務表が対象(他のページの選択はそのまま)
  handleSelectAll(event) {
    const selectedIds = new Set(this.selectedIds);
    this.pageReports.forEach((r) => {
      if (event.target.checked) {
        selectedIds.add(r.Id);
      } else {
        selectedIds.delete(r.Id);
      }
    });
    this.selectedIds = selectedIds;
  }

  handleSelect(event) {
    const selectedIds = new Set(this.selectedIds);
    if (event.target.checked) {
      selectedIds.add(event.target.dataset.id);
    } else {
      selectedIds.delete(event.target.dataset.id);
    }
    this.selectedIds = selectedIds;
  }

  // 勤務表名から勤務表参照画面へ(上長として参照のみ)
  handleViewReport(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: MONTH_REPORT_PAGE },
      state: { id: event.currentTarget.dataset.id }
    });
  }

  // Apex呼び出し共通処理(ローディング表示・エラー処理・セッション切れ時のログイン画面遷移)
  // action が返したメッセージは、処理結果としてダイアログで表示する。
  // エラーは、画面表示後はダイアログ、初期表示時は画面上部に表示する(勤務表一覧と同じ)
  async callApex(action) {
    this.errorMessage = '';
    this.isLoading = true;
    let message;
    let errorMessage;
    try {
      message = await action();
    } catch (error) {
      if (isSessionInvalidError(error)) {
        redirectToLogin(this);
        return;
      }
      errorMessage = error?.body?.message || SYSTEM_ERROR_MESSAGE;
    } finally {
      this.isLoading = false;
    }
    if (errorMessage) {
      if (this.isAuthenticated) {
        this.openResultDialog(errorMessage, true);
      } else {
        this.errorMessage = errorMessage;
      }
    } else if (message) {
      this.openResultDialog(message, false);
    }
  }
}
