import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getInitData from '@salesforce/apex/WorkreportInputController.getInitData';
import saveReport from '@salesforce/apex/WorkreportInputController.saveReport';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const WORK_LIST_PAGE = 'workreport_list__c';
// 編集モードの戻り先(勤務表画面)
const MONTH_REPORT_PAGE = 'workreport_view__c';
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

export default class WorkreportInput extends NavigationMixin(LightningElement) {
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
  // 複製元または編集対象の勤務表Id
  sourceId;
  // 編集モード(勤務表画面の「勤務表編集」から遷移した場合)
  isEdit = false;
  // 編集不可(編集モードで、作成完了以降の状況または対象外の年月の場合)
  isReadonly = false;
  initialized = false;
  // 表示中のダイアログ(確認・処理結果を1つの共通ダイアログで切り替えて表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;
  // 初期表示時の入力値(変更有無の判定に使う)
  initialInput = '';

  @wire(CurrentPageReference)
  setPageReference(pageRef) {
    this.sourceId = pageRef?.state?.id;
    this.isEdit = pageRef?.state?.edit === '1' && !!this.sourceId;
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.loadInitData();
  }

  // 初期表示(編集できない勤務表の場合はダイアログで知らせる)
  async loadInitData() {
    await this.callApex(async () => {
      const data = await getInitData({ sessionKey: getSessionKey(), sourceId: this.sourceId, isEdit: this.isEdit });
      this.report = { ...data.report };
      this.isReadonly = data.isReadonly;
      this.initialInput = JSON.stringify(this.toInput());
      this.yearOptions = data.yearOptions;
      this.picklistOptions = data.picklistOptions;
      this.reportTo = data.reportTo;
      this.reportToMail = data.reportToMail;
      this.superiorName = data.superiorName;
      this.isAuthenticated = true;
    });
    if (this.isAuthenticated && this.isReadonly) {
      this.dialog = { title: '注意', messages: 'この勤務表は編集できません。', confirmLabel: 'OK' };
    }
  }

  get pageTitle() {
    if (!this.isEdit) {
      return '新規勤務表';
    }
    const reportName = this.report.ReportName__c;
    return reportName ? `勤務表編集（${reportName}）` : '勤務表編集';
  }

  // 編集モードでは年月は変更不可
  get yearMonthDisabled() {
    return this.isEdit || this.isReadonly;
  }

  get saveDisabled() {
    return this.isLoading || this.isReadonly;
  }

  // 戻り先(キャンセル確認ダイアログのメッセージに使う)
  get returnPageLabel() {
    return this.isEdit ? '勤務表' : '勤務表一覧';
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
      this.navigateBack();
    });
  }

  // 入力内容に変更がある場合のみキャンセル確認ダイアログを開く
  handleCancel() {
    if (JSON.stringify(this.toInput()) === this.initialInput) {
      this.cancelInput();
      return;
    }
    this.dialog = {
      title: '入力内容の破棄',
      messages: [`入力内容を破棄して${this.returnPageLabel}に戻りますか？`, '保存されていない内容は失われます。'],
      confirmLabel: 'はい',
      cancelLabel: 'いいえ',
      onConfirm: () => this.cancelInput()
    };
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

  // 入力内容を破棄して戻る
  cancelInput() {
    this.isNavigating = true;
    this.isLoading = true;
    this.navigateBack();
  }

  // 編集モードは勤務表画面、新規・複製は勤務表一覧へ戻る
  navigateBack() {
    if (this.isEdit) {
      this.navigateTo(MONTH_REPORT_PAGE, { id: this.sourceId });
    } else {
      this.navigateTo(WORK_LIST_PAGE);
    }
  }

  // 入力値をApexに渡す形式に変換する(数値項目は空の場合nullにする)
  toInput() {
    // 編集モードはIdを渡して更新する
    const input = this.isEdit ? { Id: this.sourceId } : {};
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
  // エラーは、画面表示後(ボタン押下時)はダイアログ、初期表示時は画面上部に表示する
  async callApex(action) {
    this.errorMessage = '';
    this.isLoading = true;
    let errorMessage;
    try {
      await action();
    } catch (error) {
      if (isSessionInvalidError(error)) {
        redirectToLogin(this);
        return;
      }
      errorMessage = error?.body?.message || SYSTEM_ERROR_MESSAGE;
    } finally {
      this.isLoading = this.isNavigating;
    }
    if (errorMessage) {
      if (this.isAuthenticated) {
        this.dialog = { title: 'エラー', messages: errorMessage, confirmLabel: 'OK', isError: true };
      } else {
        this.errorMessage = errorMessage;
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
}
