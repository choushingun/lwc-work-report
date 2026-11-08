import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getReport from '@salesforce/apex/MonthReportController.getReport';
import clockInOut from '@salesforce/apex/WorkListController.clockInOut';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/workReportAuth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
// プロジェクト・プロジェクトコードの表示文字数(超える分はマウスを乗せると表示する)
const PROJECT_DISPLAY_LENGTH = 20;
const STATUS_ICONS = {
  申請中: 'utility:clock',
  承認済: 'utility:success',
  却下: 'utility:error',
  申請取消: 'utility:undo'
};
// 状況アイコンの色(CSSのクラス名)
const STATUS_CLASSES = {
  申請中: 'status-success',
  承認済: 'status-success',
  却下: 'status-error'
};
// 承認日時を表示する状況(それ以外は申請日時を表示する)
const APPROVED_STATUSES = ['承認済', '却下'];

export default class WorkReportMonthReport extends NavigationMixin(LightningElement) {
  reportId;
  report = {};
  worktimes = [];
  isCurrentMonth = false;
  isReadonly = true;
  messages = [];
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  infoMessage = '';
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
      timeClass: wt.isSubmitCompany && !wt.isPaidHoliday ? 'text-red' : ''
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

  // 土曜は青、日祝・有給休暇は赤
  weekClass(wt) {
    if (wt.isHoliday) {
      return wt.week === '土' ? 'text-blue' : 'text-red';
    }
    return wt.isPaidHoliday ? 'text-red' : '';
  }

  todayString() {
    const now = new Date();
    const mm = `${now.getMonth() + 1}`.padStart(2, '0');
    const dd = `${now.getDate()}`.padStart(2, '0');
    return `${now.getFullYear()}-${mm}-${dd}`;
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
