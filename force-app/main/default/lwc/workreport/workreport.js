import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getReport from '@salesforce/apex/WorkreportController.getReport';
import clockInOut from '@salesforce/apex/WorkreportListController.clockInOut';
import completeReport from '@salesforce/apex/WorkreportController.completeReport';
import cancelCompleteReport from '@salesforce/apex/WorkreportController.cancelCompleteReport';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
// 勤務実績入力画面(Experience Builderのページ名)
const WORKTIME_INPUT_PAGE = 'worktime_input__c';
// 勤務表作成画面(編集モードで開く)
const CREATE_WORK_PAGE = 'workreport_input__c';
// プロジェクト・プロジェクトコードの表示文字数(超える分はマウスを乗せると表示する)
const PROJECT_DISPLAY_LENGTH = 20;
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
// 承認日時を表示する状況(それ以外は申請日時を表示する)
const APPROVED_STATUSES = ['承認済', '却下'];

export default class Workreport extends NavigationMixin(LightningElement) {
  reportId;
  report = {};
  worktimes = [];
  isCurrentMonth = false;
  isReadonly = true;
  // 締め取消できる(作成完了で、対象の年月の場合)
  canCancelComplete = false;
  messages = [];
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 日時はSalesforce標準画面と同じ24時間表記(例：2026/11/09 0:15)にする
  hour12 = false;
  infoMessage = '';
  // 月末締め確認ダイアログ
  showCompleteConfirm = false;
  focusCompleteConfirm = false;
  clockTitle = '午後2時までは出勤、以降は退勤と見なされます。\n徹夜など日を跨る場合は使用しないでください。';

  @wire(CurrentPageReference)
  setPageReference(pageRef) {
    const reportId = pageRef?.state?.id;
    if (!pageRef || (reportId && reportId === this.reportId)) {
      return;
    }
    this.reportId = reportId;
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    if (!reportId) {
      this.errorMessage = '勤務表が指定されていません。';
      return;
    }
    this.callApex(() => this.fetchReport());
  }

  async fetchReport() {
    const data = await getReport({ sessionKey: getSessionKey(), reportId: this.reportId });
    this.report = data.report;
    this.worktimes = data.worktimes;
    this.isCurrentMonth = data.isCurrentMonth;
    this.isReadonly = data.isReadonly;
    this.canCancelComplete = data.canCancelComplete;
    this.messages = data.messages.map((message, index) => ({ key: `${index}`, message }));
    this.isAuthenticated = true;
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  get hasMessages() {
    return this.messages.length > 0;
  }

  get workHours() {
    const r = this.report;
    return `${r.StartHour__c ?? ''}時${r.StartTime__c ?? ''}分～${r.EndHour__c ?? ''}時${r.EndTime__c ?? ''}分`;
  }

  get standardHours() {
    const r = this.report;
    return `${r.UndertimeWork__c ?? ''}時間～${r.OvertimeWork__c ?? ''}時間`;
  }

  get reportTo() {
    return this.report.Contact__r?.Account?.ReportTo__c;
  }

  get reportToMail() {
    return this.report.Contact__r?.Account?.ReportToMail__c;
  }

  get superiorName() {
    return this.report.Superior__r?.Name;
  }

  get statusIcon() {
    return STATUS_ICONS[this.report.Status__c] || 'utility:edit';
  }

  get statusClass() {
    return STATUS_CLASSES[this.report.Status__c] || 'status-default';
  }

  get statusDateTime() {
    return APPROVED_STATUSES.includes(this.report.Status__c)
      ? this.report.ApproveDateTime__c
      : this.report.ApplicationDateTime__c;
  }

  get totalWorkTime() {
    return Number(this.report.TotalWorkTime__c ?? 0).toFixed(1);
  }

  // 総労働時間が本月標準時間の範囲外の場合は赤字にする
  get totalWorkTimeClass() {
    const r = this.report;
    const total = Number(r.TotalWorkTime__c ?? 0);
    return total < Number(r.UndertimeWork__c ?? 0) || total > Number(r.OvertimeWork__c ?? 0)
      ? 'slds-text-color_error'
      : '';
  }

  get projects() {
    return this.joinFields(['ProjectName__c', 'ProjectName2__c', 'ProjectName3__c']);
  }

  get projectCodes() {
    return this.joinFields(['ProjectCode__c', 'ProjectCode2__c', 'ProjectCode3__c']);
  }

  get projectLabel() {
    return this.projects.slice(0, PROJECT_DISPLAY_LENGTH);
  }

  get projectCodeLabel() {
    return this.projectCodes.slice(0, PROJECT_DISPLAY_LENGTH);
  }

  joinFields(fields) {
    return fields
      .map((field) => this.report[field])
      .filter((value) => value)
      .join(';');
  }

  // 編集不可の勤務表、勤務実績がない場合は実績入力できない
  get worktimeInputDisabled() {
    return this.isLoading || this.isReadonly || !this.hasWorktimes;
  }

  handleWorktimeInput() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: WORKTIME_INPUT_PAGE },
      state: { id: this.reportId }
    });
  }

  // 作成完了以降の状況などで編集できない勤務表は、勤務表編集ボタンを押せない
  get editDisabled() {
    return this.isLoading || this.isReadonly;
  }

  // 勤務表作成画面を編集モードで開く
  handleEditReport() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: CREATE_WORK_PAGE },
      state: { id: this.reportId, edit: '1' }
    });
  }

  get clockDisabled() {
    return this.isLoading || !this.isCurrentMonth || this.isReadonly;
  }

  // 勤務実績を前半・後半の2列に分けて表示する
  get worktimeRows() {
    const today = this.todayString();
    return this.worktimes.map((wt) => ({
      ...wt,
      dayLabel: wt.workDay?.replaceAll('-', '/'),
      hasMemo: !!wt.memo,
      rowClass: wt.workDay === today ? 'row-today' : '',
      weekClass: this.weekClass(wt),
      timeClass: wt.isSubmitCompany ? 'text-red' : ''
    }));
  }

  get firstHalfRows() {
    return this.worktimeRows.slice(0, this.halfSize);
  }

  get secondHalfRows() {
    return this.worktimeRows.slice(this.halfSize);
  }

  get halfSize() {
    return Math.ceil(this.worktimes.length / 2);
  }

  get hasWorktimes() {
    return this.worktimes.length > 0;
  }

  // 土曜は青、日祝は赤
  weekClass(wt) {
    if (!wt.isHoliday) {
      return '';
    }
    return wt.week === '土' ? 'text-blue' : 'text-red';
  }

  todayString() {
    const now = new Date();
    const mm = `${now.getMonth() + 1}`.padStart(2, '0');
    const dd = `${now.getDate()}`.padStart(2, '0');
    return `${now.getFullYear()}-${mm}-${dd}`;
  }

  // 月末締め確認ダイアログを開く(はいボタンにフォーカスする)
  handleComplete() {
    this.showCompleteConfirm = true;
    this.focusCompleteConfirm = true;
  }

  renderedCallback() {
    if (this.focusCompleteConfirm) {
      this.focusCompleteConfirm = false;
      this.template.querySelector('.complete-confirm-button')?.focus();
    }
  }

  handleCompleteConfirmClose() {
    this.showCompleteConfirm = false;
  }

  handleCompleteConfirmKeyDown(event) {
    if (event.key === 'Escape') {
      this.handleCompleteConfirmClose();
    }
  }

  // 月末締め済(作成完了)の場合は締め取消ボタンを表示する
  get isCompleted() {
    return this.report.Status__c === '作成完了';
  }

  get cancelCompleteDisabled() {
    return this.isLoading || !this.canCancelComplete;
  }

  // 締め取消(ドラフトに戻す。成功後は勤務表を再取得し、編集できる状態で表示する)
  handleCancelComplete() {
    this.infoMessage = '';
    this.callApex(async () => {
      const message = await cancelCompleteReport({ sessionKey: getSessionKey(), reportId: this.reportId });
      await this.fetchReport();
      this.infoMessage = message;
    });
  }

  // 月末締め(成功後は勤務表を再取得し、編集不可の状態で表示する)
  handleCompleteConfirm() {
    this.showCompleteConfirm = false;
    this.infoMessage = '';
    this.callApex(async () => {
      const message = await completeReport({ sessionKey: getSessionKey(), reportId: this.reportId });
      await this.fetchReport();
      this.infoMessage = message;
    });
  }

  handleClockInOut() {
    this.infoMessage = '';
    this.callApex(async () => {
      const message = await clockInOut({ sessionKey: getSessionKey() });
      await this.fetchReport();
      this.infoMessage = message;
    });
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
