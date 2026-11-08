import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getInitData from '@salesforce/apex/CreateWorkController.getInitData';
import saveReport from '@salesforce/apex/CreateWorkController.saveReport';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/workReportAuth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const WORK_LIST_PAGE = 'work_report_list__c';
const NUMBER_FIELDS = ['RestTime__c', 'UndertimeWork__c', 'OvertimeWork__c'];
const INPUT_FIELDS = [
  'Year__c',
  'Month__c',
  'StartHour__c',
  'StartTime__c',
  'EndHour__c',
  'EndTime__c',
  'LunchTime__c',
  'Workplace__c',
  'Approver__c',
  'ApproverMail__c',
  'ApproverCC__c',
  'ProjectName__c',
  'ProjectCode__c',
  'ProjectName2__c',
  'ProjectCode2__c',
  'ProjectName3__c',
  'ProjectCode3__c',
  ...NUMBER_FIELDS
];
const PROJECTS = [
  { key: '1', nameField: 'ProjectName__c', codeField: 'ProjectCode__c' },
  { key: '2', nameField: 'ProjectName2__c', codeField: 'ProjectCode2__c' },
  { key: '3', nameField: 'ProjectName3__c', codeField: 'ProjectCode3__c' }
];

export default class WorkReportCreateWork extends NavigationMixin(LightningElement) {
  report = {};
  yearOptions = [];
  picklistOptions = {};
  reportTo = '';
  reportToMail = '';
  superiorName = '';
  // 初期表示データを取得するまでスピナーを表示する
  isLoading = true;
  // 保存成功後の画面遷移中(遷移が終わるまでスピナーを表示し続ける)
  isNavigating = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  sourceId;
  initialized = false;
  // キャンセル確認ダイアログを表示中
  showCancelConfirm = false;
  focusCancelConfirm = false;
  // 初期表示時の入力値(変更有無の判定に使う)
  initialInput = '';

  @wire(CurrentPageReference)
  setPageReference(pageRef) {
    this.sourceId = pageRef?.state?.id;
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.callApex(async () => {
      const data = await getInitData({ sessionKey: getSessionKey(), sourceId: this.sourceId });
      this.report = { ...data.report };
      this.initialInput = JSON.stringify(this.toInput());
      this.yearOptions = data.yearOptions;
      this.picklistOptions = data.picklistOptions;
      this.reportTo = data.reportTo;
      this.reportToMail = data.reportToMail;
      this.superiorName = data.superiorName;
      this.isAuthenticated = true;
    });
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  get monthOptions() {
    return this.picklistOptions.Month__c ?? [];
  }

  get startHourOptions() {
    return this.picklistOptions.StartHour__c ?? [];
  }

  get startTimeOptions() {
    return this.picklistOptions.StartTime__c ?? [];
  }

  get endHourOptions() {
    return this.picklistOptions.EndHour__c ?? [];
  }

  get endTimeOptions() {
    return this.picklistOptions.EndTime__c ?? [];
  }

  get lunchTimeOptions() {
    return this.picklistOptions.LunchTime__c ?? [];
  }

  get projects() {
    return PROJECTS.map((p) => ({
      ...p,
      nameLabel: `プロジェクト${p.key}`,
      codeLabel: `プロジェクトコード${p.key}`,
      name: this.report[p.nameField],
      code: this.report[p.codeField]
    }));
  }

  handleChange(event) {
    const { field } = event.target.dataset;
    this.report = { ...this.report, [field]: event.target.value };
  }

  handleSave() {
    const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
    const isValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);
    if (!isValid) {
      return;
    }
    this.callApex(async () => {
      await saveReport({ sessionKey: getSessionKey(), input: this.toInput() });
      this.isNavigating = true;
      this.navigateTo(WORK_LIST_PAGE);
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
    this.navigateTo(WORK_LIST_PAGE);
  }

  // 入力値をApexに渡す形式に変換する(数値項目は空の場合nullにする)
  toInput() {
    const input = {};
    INPUT_FIELDS.forEach((field) => {
      const value = this.report[field];
      if (value === '' || value === null || value === undefined) {
        input[field] = null;
      } else {
        input[field] = NUMBER_FIELDS.includes(field) ? Number(value) : value;
      }
    });
    return input;
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
