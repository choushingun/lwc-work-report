import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getProject from '@salesforce/apex/ResumeProjectController.getProject';
import saveProject from '@salesforce/apex/ResumeProjectController.saveProject';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const RESUME_PAGE = 'resume__c';

// 数値入力欄の値を整数にする(未入力は null)
function toNumber(value) {
  return value === '' || value == null ? null : Number(value);
}

export default class ResumeProject extends NavigationMixin(LightningElement) {
  // 管理経験(人数の区分ごと。manage・months は入力中の値。未入力は空文字)
  managements = [];
  // 作業経験(選択中の値)
  workExperiences = [];
  workExperienceOptions = [];
  enjoyingBusiness = '';
  enjoyingSkills = '';
  // 保存済みの入力内容(キャンセル時の変更確認用。getInputs() の JSON)
  savedInputs = '';
  isLoading = false;
  // 保存成功後の画面遷移中(遷移が終わるまでスピナーを表示し続ける)
  isNavigating = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 表示中のダイアログ(共通ダイアログで表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;

  connectedCallback() {
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.callApex(() => this.fetchProject());
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  async fetchProject() {
    const data = await getProject({ sessionKey: getSessionKey() });
    this.managements = (data.managements ?? []).map((management) => ({
      key: management.key,
      label: management.label,
      manageLabel: `${management.label}の管理`,
      monthsLabel: `${management.label}の期間(月)`,
      manage: management.manage ?? '',
      months: management.months ?? ''
    }));
    this.workExperienceOptions = data.workExperienceOptions ?? [];
    // 選択中の値は選択肢の順に並べる(チェックの付け外しで並びが変わらないようにする)
    const workExperiences = data.workExperiences ?? [];
    this.workExperiences = this.workExperienceOptions
      .map((option) => option.value)
      .filter((value) => workExperiences.includes(value));
    this.enjoyingBusiness = data.enjoyingBusiness ?? '';
    this.enjoyingSkills = data.enjoyingSkills ?? '';
    this.savedInputs = JSON.stringify(this.getInputs());
    this.isAuthenticated = true;
  }

  // 入力中の仕事経験(Apex の ProjectData の形。未入力は null)
  getInputs() {
    return {
      managements: this.managements.map((management) => ({
        key: management.key,
        manage: management.manage.trim() || null,
        months: toNumber(management.months)
      })),
      workExperiences: [...this.workExperiences],
      enjoyingBusiness: this.enjoyingBusiness.trim() || null,
      enjoyingSkills: this.enjoyingSkills.trim() || null
    };
  }

  handleManagementChange(event) {
    const { key, field } = event.target.dataset;
    const value = event.detail.value ?? '';
    this.managements = this.managements.map((management) =>
      management.key === key ? { ...management, [field]: value } : management
    );
  }

  // 作業経験の選択肢(チェック状態付き)
  get workExperienceItems() {
    return this.workExperienceOptions.map((option) => ({
      ...option,
      checked: this.workExperiences.includes(option.value)
    }));
  }

  // 選択中の値は選択肢の順に並べる(変更確認で順番の違いを変更とみなさないため)
  handleWorkExperienceChange(event) {
    const value = event.target.dataset.value;
    const checked = event.detail.checked;
    this.workExperiences = this.workExperienceOptions
      .map((option) => option.value)
      .filter((optionValue) => (optionValue === value ? checked : this.workExperiences.includes(optionValue)));
  }

  handleTextChange(event) {
    this[event.target.dataset.field] = event.target.value ?? '';
  }

  // 保存したら履歴書トップ画面へ戻る(エラー時はこの画面に残ってダイアログで表示する)
  handleSave() {
    const inputs = [...this.template.querySelectorAll('lightning-input, lightning-textarea')];
    const isValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);
    if (!isValid) {
      return;
    }
    this.callApex(async () => {
      await saveProject({ sessionKey: getSessionKey(), data: this.getInputs() });
      this.isNavigating = true;
      this.navigateToResume();
    });
  }

  // 入力内容に変更があるか
  get isChanged() {
    return JSON.stringify(this.getInputs()) !== this.savedInputs;
  }

  // 入力内容に変更がある場合のみキャンセル確認ダイアログを開く(技術経験画面と同じ)
  handleCancel() {
    if (!this.isChanged) {
      this.navigateToResume();
      return;
    }
    this.dialog = {
      title: '入力内容の破棄',
      messages: ['入力内容を破棄して履歴書画面に戻りますか？', '保存されていない内容は失われます。'],
      confirmLabel: 'はい',
      cancelLabel: 'いいえ',
      onConfirm: () => this.navigateToResume()
    };
  }

  navigateToResume() {
    this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: RESUME_PAGE } });
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
}
