import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getReports from '@salesforce/apex/ApprovalListController.getReports';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const MONTH_REPORT_PAGE = 'workreport_view__c';
// 年月の選択範囲(当月から過去・未来の月数)
const PAST_MONTHS = 24;
const FUTURE_MONTHS = 1;

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
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 日時はSalesforce標準画面と同じ24時間表記(例：2026/11/09 0:15)にする
  hour12 = false;
  pageRef;

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

  // 年月の選択肢(新しい月順。桁をそろえるため月は2桁で表示する)
  get monthOptions() {
    const options = [];
    for (let ym = this.maxYearMonth; ym >= this.minYearMonth; ym = addMonths(ym, -1)) {
      const [year, month] = ym.split('-');
      options.push({ label: `${year}年${month}月`, value: ym });
    }
    return options;
  }

  get isFirstMonth() {
    return this.isLoading || this.yearMonth <= this.minYearMonth;
  }

  get isLastMonth() {
    return this.isLoading || this.yearMonth >= this.maxYearMonth;
  }

  // ボタン操作がないため、エラーは初期表示時・年月切替時とも画面上部に表示する
  get showPageError() {
    return !!this.errorMessage;
  }

  get hasReports() {
    return this.reports.length > 0;
  }

  get noReports() {
    return !this.isLoading && !this.hasReports;
  }

  get countLabel() {
    return `${this.reports.length}件`;
  }

  get displayReports() {
    return this.reports.map((r) => ({ ...r, isSelected: this.selectedIds.has(r.Id) }));
  }

  get isAllSelected() {
    return this.hasReports && this.selectedIds.size === this.reports.length;
  }

  loadReports() {
    this.callApex(async () => {
      const [yyyy, mm] = this.yearMonth.split('-');
      const records = await getReports({ sessionKey: getSessionKey(), yyyy, mm });
      this.reports = records.map((r) => ({
        ...r,
        workDaysLabel: `${r.WorkDays__c ?? 0}/${r.StandardWorkDays__c ?? 0}`,
        overtimeClass: r.Overtime__c < 0 ? 'text-red' : ''
      }));
      this.selectedIds = new Set();
      this.isAuthenticated = true;
    });
  }

  handlePreviousMonth() {
    this.changeMonth(addMonths(this.yearMonth, -1));
  }

  handleNextMonth() {
    this.changeMonth(addMonths(this.yearMonth, 1));
  }

  handleMonthChange(event) {
    this.changeMonth(event.detail.value);
  }

  // 年月をURLに設定する(ページ参照が変わると一覧を再取得する。履歴は置き換える)
  changeMonth(yearMonth) {
    this[NavigationMixin.Navigate](
      { ...this.pageRef, state: { ...this.pageRef.state, month: yearMonth } },
      true
    );
  }

  handleSelectAll(event) {
    this.selectedIds = event.target.checked ? new Set(this.reports.map((r) => r.Id)) : new Set();
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
  // エラーは画面上部に表示する
  async callApex(action) {
    this.errorMessage = '';
    this.isLoading = true;
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
    }
  }
}
