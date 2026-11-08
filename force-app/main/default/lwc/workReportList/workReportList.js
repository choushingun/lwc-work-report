import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getReports from '@salesforce/apex/WorkListController.getReports';
import clockInOut from '@salesforce/apex/WorkListController.clockInOut';
import deleteReport from '@salesforce/apex/WorkListController.deleteReport';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/workReportAuth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const MONTH_REPORT_PAGE = 'month_report__c';
const CREATE_WORK_PAGE = 'create_work__c';
const READONLY_STATUSES = ['申請中', '承認済'];
const MIN_PAGE_SIZE = 10;
const PAGE_SIZE_OPTIONS = [MIN_PAGE_SIZE, 20, 50].map((size) => ({ label: `${size}`, value: `${size}` }));
const STATUS_ICONS = {
  作成完了: 'utility:lock',
  申請中: 'utility:clock',
  承認済: 'utility:success',
  却下: 'utility:error',
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

export default class WorkReportList extends NavigationMixin(LightningElement) {
  reports = [];
  pageNumber = 1;
  pageSize = MIN_PAGE_SIZE;
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 日時はSalesforce標準画面と同じ24時間表記(例：2026/11/09 0:15)にする
  hour12 = false;
  infoMessage = '';
  pageSizeOptions = PAGE_SIZE_OPTIONS;
  // 削除確認中の勤務表Id(設定中は確認ダイアログを表示する)
  deleteTargetId = null;
  focusDeleteConfirm = false;

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

  get showDeleteConfirm() {
    return !!this.deleteTargetId;
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
      deleteDisabled: READONLY_STATUSES.includes(r.Status__c)
    }));
    this.pageNumber = Math.min(this.pageNumber, this.totalPages);
    this.isAuthenticated = true;
  }

  handleClockInOut() {
    this.infoMessage = '';
    this.callApex(async () => {
      const message = await clockInOut({ sessionKey: this.sessionKey });
      await this.fetchReports();
      this.infoMessage = message;
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

  // 削除確認ダイアログを開く(削除ボタンにフォーカスする)
  handleDeleteReport(event) {
    this.deleteTargetId = event.currentTarget.dataset.id;
    this.focusDeleteConfirm = true;
  }

  renderedCallback() {
    if (this.focusDeleteConfirm) {
      this.focusDeleteConfirm = false;
      this.template.querySelector('.delete-confirm-button')?.focus();
    }
  }

  handleDeleteCancel() {
    this.deleteTargetId = null;
  }

  handleDeleteKeyDown(event) {
    if (event.key === 'Escape') {
      this.handleDeleteCancel();
    }
  }

  handleDeleteConfirm() {
    const reportId = this.deleteTargetId;
    this.deleteTargetId = null;
    this.infoMessage = '';
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
  async callApex(action) {
    this.errorMessage = '';
    this.isLoading = true;
    this.showSpinner();
    try {
      await action();
    } catch (error) {
      if (isSessionInvalidError(error)) {
        redirectToLogin(this);
        return;
      }
      this.errorMessage = error?.body?.message || SYSTEM_ERROR_MESSAGE;
    } finally {
      this.isLoading = false;
      this.hideSpinner();
    }
  }

  navigateTo(name, state) {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name },
      state
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
