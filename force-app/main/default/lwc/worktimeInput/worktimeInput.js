import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getInitData from '@salesforce/apex/WorktimeInputController.getInitData';
import saveWorktimes from '@salesforce/apex/WorktimeInputController.saveWorktimes';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const MONTH_REPORT_PAGE = 'workreport_view__c';
// 休みにした場合の備考(祝日以外)
const VACATION_MEMO = '全休';
// ▲▼で調整する分
const ADJUST_MINUTES = 15;

export default class WorktimeInput extends NavigationMixin(LightningElement) {
  reportId;
  report = {};
  rows = [];
  projectOptions = [];
  workplaceOptions = [];
  hourOptions = [];
  minuteOptions = [];
  isReadonly = true;
  isLoading = false;
  // 保存後の画面遷移中(スピナーを表示したままにする)
  isNavigating = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // キャンセル確認ダイアログ
  showCancelConfirm = false;
  focusCancelConfirm = false;
  // 初期表示時の入力内容(キャンセル時に変更有無を判定する)
  initialInput = '';

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
    this.callApex(() => this.fetchData());
  }

  async fetchData() {
    const data = await getInitData({ sessionKey: getSessionKey(), reportId: this.reportId });
    this.report = data.report;
    this.isReadonly = data.isReadonly;
    this.projectOptions = toOptions(data.projects);
    this.workplaceOptions = toOptions(data.workplaces);
    this.hourOptions = toOptions(data.hourOptions);
    this.minuteOptions = toOptions(data.minuteOptions);
    this.rows = data.rows.map((row) => this.decorate({ ...row, restTime: row.restTime ?? 0 }));
    this.initialInput = JSON.stringify(this.toInput());
    this.isAuthenticated = true;
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  // タイトルに勤務表の年月を表示する
  get pageTitle() {
    const reportName = this.report.ReportName__c;
    return reportName ? `勤務実績入力（${reportName}）` : '勤務実績入力';
  }

  get saveDisabled() {
    return this.isLoading || this.isReadonly;
  }

  // プロジェクト・作業場所が複数ある場合のみ一括設定を表示する(先頭は空白)
  get showBulkProject() {
    return this.projectOptions.length > 2;
  }

  get showBulkWorkplace() {
    return this.workplaceOptions.length > 2;
  }

  // 画面表示用の項目を設定する
  decorate(row) {
    // 休みの日は時間・プロジェクト・作業場所を編集不可
    const vacationDisabled = this.isReadonly;
    const timeDisabled = vacationDisabled || row.isVacation;
    return {
      ...row,
      // 入力欄(input)にundefinedを渡すと「undefined」と表示されるため空文字にする
      memo: row.memo ?? '',
      vacationDisabled,
      timeDisabled,
      memoDisabled: vacationDisabled,
      dayLabel: row.name,
      rowClass: row.workDay === todayString() ? 'row-today' : '',
      weekClass: weekClass(row),
      // 選択リスト(select)は選択中の値をoptionのselectedで指定する
      // 休みの日は値を表示しない(空の選択肢だけにする。保存する値は変えない)
      startHourOptions: optionsFor(row, this.hourOptions, row.startHour),
      startTimeOptions: optionsFor(row, this.minuteOptions, row.startTime),
      endHourOptions: optionsFor(row, this.hourOptions, row.endHour),
      endTimeOptions: optionsFor(row, this.minuteOptions, row.endTime),
      projectNameOptions: optionsFor(row, this.projectOptions, row.projectName),
      workplaceOptions: optionsFor(row, this.workplaceOptions, row.workplace),
      restTimeLabel: row.isVacation ? '' : row.restTime,
      // 休みの日は作業時間を表示しない
      workTimeLabel: row.isVacation ? '' : calcWorkTime(row)
    };
  }

  updateRow(id, changes) {
    this.rows = this.rows.map((row) => (row.id === id ? this.decorate({ ...row, ...changes }) : row));
  }

  handleFieldChange(event) {
    const { id, field } = event.target.dataset;
    let value = event.detail?.value ?? event.target.value;
    if (field === 'restTime') {
      value = value === '' || value === null ? 0 : Number(value);
    }
    this.updateRow(id, { [field]: value });
  }

  // 休みチェック(チェック時は時間をクリア、解除時は勤務表の標準時間を設定する)
  handleVacationChange(event) {
    const { id } = event.target.dataset;
    const row = this.rows.find((r) => r.id === id);
    const checked = event.target.checked;
    if (checked) {
      this.updateRow(id, {
        isVacation: true,
        startHour: '00',
        startTime: '00',
        endHour: '00',
        endTime: '00',
        restTime: 0,
        projectName: '',
        workplace: '',
        memo: row.isHoliday ? row.memo : VACATION_MEMO
      });
    } else {
      const r = this.report;
      this.updateRow(id, {
        isVacation: false,
        startHour: r.StartHour__c,
        startTime: r.StartTime__c,
        endHour: r.EndHour__c,
        endTime: r.EndTime__c,
        restTime: r.RestTime__c ?? 0,
        projectName: this.projectOptions[1]?.value ?? '',
        workplace: this.workplaceOptions[1]?.value ?? '',
        memo: row.memo === VACATION_MEMO ? '' : row.memo
      });
    }
  }

  // ▲▼で時刻を15分単位で調整する
  handleAdjust(event) {
    const { id, target, step } = event.currentTarget.dataset;
    const row = this.rows.find((r) => r.id === id);
    if (!row || row.timeDisabled) {
      return;
    }
    const hourField = `${target}Hour`;
    const minuteField = `${target}Time`;
    let total = Number(row[hourField]) * 60 + Number(row[minuteField]) + Number(step) * ADJUST_MINUTES;
    total = (total + 24 * 60) % (24 * 60);
    this.updateRow(id, {
      [hourField]: pad(Math.floor(total / 60)),
      [minuteField]: pad(total % 60)
    });
  }

  // プロジェクト・作業場所の一括設定(未選択の編集可能な行に先頭の選択肢を設定する)
  handleBulkSet(event) {
    const { field } = event.target.dataset;
    const options = field === 'projectName' ? this.projectOptions : this.workplaceOptions;
    const value = options[1]?.value;
    if (!value) {
      return;
    }
    this.rows = this.rows.map((row) => {
      if (row.timeDisabled || row[field]) {
        return row;
      }
      return this.decorate({ ...row, [field]: value });
    });
  }

  handleSave() {
    if (!this.validate()) {
      return;
    }
    this.callApex(async () => {
      await saveWorktimes({ sessionKey: getSessionKey(), reportId: this.reportId, rows: this.toInput() });
      this.isNavigating = true;
      this.navigateTo(MONTH_REPORT_PAGE, { id: this.reportId });
    });
  }

  // 入力内容に変更がある場合のみキャンセル確認ダイアログを開く(はいボタンにフォーカスする)
  handleCancel() {
    if (JSON.stringify(this.toInput()) === this.initialInput) {
      this.handleCancelConfirm();
      return;
    }
    this.showCancelConfirm = true;
    this.focusCancelConfirm = true;
  }

  renderedCallback() {
    if (this.focusCancelConfirm) {
      this.focusCancelConfirm = false;
      this.template.querySelector('.cancel-confirm-button')?.focus();
    }
  }

  handleCancelConfirmClose() {
    this.showCancelConfirm = false;
  }

  handleCancelConfirmKeyDown(event) {
    if (event.key === 'Escape') {
      this.handleCancelConfirmClose();
    }
  }

  handleCancelConfirm() {
    this.showCancelConfirm = false;
    this.isNavigating = true;
    this.isLoading = true;
    this.showSpinner();
    this.navigateTo(MONTH_REPORT_PAGE, { id: this.reportId });
  }

  // 労働時間が0の日は休みにチェックが必要
  validate() {
    this.errorMessage = '';
    const invalid = this.rows.find(
      (row) => !row.isVacation && row.startHour === row.endHour && row.startTime === row.endTime
    );
    if (invalid) {
      this.errorMessage = `${invalid.name}：労働時間が０の場合、休みにチェックを入れてください。`;
      return false;
    }
    return true;
  }

  // Apexに渡す形式に変換する(画面表示用の項目は除く)
  toInput() {
    return this.rows.map((row) => ({
      id: row.id,
      startHour: row.startHour,
      startTime: row.startTime,
      endHour: row.endHour,
      endTime: row.endTime,
      restTime: row.restTime,
      projectName: row.projectName || null,
      workplace: row.workplace || null,
      memo: row.memo || null,
      isVacation: row.isVacation
    }));
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
      this.isLoading = this.isNavigating;
      if (!this.isNavigating) {
        this.hideSpinner();
      }
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

function toOptions(values) {
  return (values || []).map((value) => ({ label: value === '' ? '--なし--' : value, value }));
}

const BLANK_OPTIONS = [{ key: 'opt-blank', label: '', value: '', selected: true }];

function optionsFor(row, options, value) {
  return row.isVacation ? BLANK_OPTIONS : withSelected(options, value);
}

// 選択中の値にselectedを付ける(値が空の場合は先頭の「--なし--」を選択する)
function withSelected(options, value) {
  const current = value ?? '';
  return options.map((opt) => ({ ...opt, key: `opt-${opt.value}`, selected: opt.value === current }));
}

function pad(num) {
  return `${num}`.padStart(2, '0');
}

function todayString() {
  const now = new Date();
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

// 土曜は青、日祝は赤
function weekClass(row) {
  if (!row.isHoliday) {
    return '';
  }
  return row.week === '土' ? 'text-blue' : 'text-red';
}

// 作業時間(時間、小数2桁)。終了が開始より前の場合は日を跨いだと見なす
function calcWorkTime(row) {
  const start = Number(row.startHour) * 60 + Number(row.startTime);
  let end = Number(row.endHour) * 60 + Number(row.endTime);
  if (Number.isNaN(start) || Number.isNaN(end)) {
    return '0.00';
  }
  if (end < start) {
    end += 24 * 60;
  }
  const minutes = end - start - Number(row.restTime || 0);
  return minutes > 0 ? (minutes / 60).toFixed(2) : '0.00';
}
