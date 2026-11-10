import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getReports from '@salesforce/apex/WorkreportListController.getReports';
import clockInOut from '@salesforce/apex/WorkreportListController.clockInOut';
import deleteReport from '@salesforce/apex/WorkreportListController.deleteReport';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const MONTH_REPORT_PAGE = 'workreport_view__c';
const CREATE_WORK_PAGE = 'workreport_input__c';
const READONLY_STATUSES = ['申請中', '承認済'];
const MIN_PAGE_SIZE = 10;
const PAGE_SIZE_OPTIONS = [MIN_PAGE_SIZE, 20, 50].map((size) => ({ label: `${size}`, value: `${size}` }));
const STATUS_ICONS = {
  作成完了: 'utility:lock',
  申請中: 'utility:forward',
  承認済: 'utility:check',
  却下: 'utility:close',
  申請取消: 'utility:undo'
};
// 状況アイコンの色(CSSのクラス名)
const STATUS_CLASSES = {
  作成完了: 'status-completed',
  申請中: 'status-pending',
  承認済: 'status-success',
  却下: 'status-error',
  申請取消: 'status-canceled'
};

export default class WorkreportList extends NavigationMixin(LightningElement) {
  reports = [];
  pageNumber = 1;
  pageSize = MIN_PAGE_SIZE;
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 日時はSalesforce標準画面と同じ24時間表記(例：2026/11/09 0:15)にする
  hour12 = false;
  pageSizeOptions = PAGE_SIZE_OPTIONS;
  // 削除確認中の勤務表Id(設定中は確認ダイアログを表示する)
  // 表示中のダイアログ(共通ダイアログで表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;

  connectedCallback() {
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.loadReports();
  }

  get sessionKey() {
    return getSessionKey();
  }

  get hasReports() {
    return this.reports.length > 0;
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  get noReports() {
    return !this.isLoading && !this.hasReports;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.reports.length / this.pageSize));
  }

  get displayReports() {
    const start = (this.pageNumber - 1) * this.pageSize;
    return this.reports.slice(start, start + this.pageSize);
  }

  get rangeLabel() {
    const start = (this.pageNumber - 1) * this.pageSize + 1;
    const end = Math.min(this.pageNumber * this.pageSize, this.reports.length);
    return `${start}-${end}/${this.reports.length}`;
  }

  get showPageSize() {
    return this.reports.length > MIN_PAGE_SIZE;
  }

  get pageSizeValue() {
    return `${this.pageSize}`;
  }

  get hasPaging() {
    return this.totalPages > 1;
  }

  get isFirstPage() {
    return this.pageNumber <= 1;
  }

  get isLastPage() {
    return this.pageNumber >= this.totalPages;
  }

  loadReports() {
    this.callApex(() => this.fetchReports());
  }

  async fetchReports() {
    const records = await getReports({ sessionKey: this.sessionKey });
    this.reports = records.map((r) => ({
      ...r,
      workDaysLabel: `${r.WorkDays__c ?? 0}/${r.StandardWorkDays__c ?? 0}`,
      statusIcon: STATUS_ICONS[r.Status__c] || 'utility:edit',
      statusClass: STATUS_CLASSES[r.Status__c] || 'status-default',
      overtimeClass: r.Overtime__c < 0 ? 'text-red' : '',
      deleteDisabled: READONLY_STATUSES.includes(r.Status__c)
    }));
    this.pageNumber = Math.min(this.pageNumber, this.totalPages);
    this.isAuthenticated = true;
  }

  handleClockInOut() {
    this.callApex(async () => {
      const message = await clockInOut({ sessionKey: this.sessionKey });
      await this.fetchReports();
      return message;
    });
  }

  handleCreateReport() {
    this.navigateTo(CREATE_WORK_PAGE);
  }

  handleViewReport(event) {
    this.navigateTo(MONTH_REPORT_PAGE, { id: event.currentTarget.dataset.id });
  }

  handleCopyReport(event) {
    this.navigateTo(CREATE_WORK_PAGE, { id: event.currentTarget.dataset.id });
  }

  // 削除確認ダイアログを開く
  handleDeleteReport(event) {
    const reportId = event.currentTarget.dataset.id;
    this.dialog = {
      title: '勤務表を削除',
      messages: ['この勤務表を削除しますか？', '勤務実績もすべて削除されます。'],
      confirmLabel: '削除',
      cancelLabel: 'キャンセル',
      onConfirm: () => this.removeReport(reportId)
    };
  }

  // 処理結果ダイアログを開く(OKボタンのみ)
  openResultDialog(message, isError) {
    this.dialog = { title: isError ? 'エラー' : '完了', messages: message, confirmLabel: 'OK', isError };
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

  // 勤務表を削除する(Apexの deleteReport と区別するため別名にする)
  removeReport(reportId) {
    this.callApex(async () => {
      await deleteReport({ sessionKey: this.sessionKey, reportId });
      await this.fetchReports();
    });
  }

  handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value);
    this.pageNumber = 1;
  }

  handlePrevious() {
    this.pageNumber = Math.max(1, this.pageNumber - 1);
  }

  handleNext() {
    this.pageNumber = Math.min(this.totalPages, this.pageNumber + 1);
  }

  // Apex呼び出し共通処理(ローディング表示・エラー処理・セッション切れ時のログイン画面遷移)
  // action が返したメッセージは、ボタン押下の結果としてダイアログで表示する。
  // エラーは、画面表示後(ボタン押下時)はダイアログ、初期表示時は画面上部に表示する
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

  navigateTo(name, state) {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name },
      state
    });
  }
}
