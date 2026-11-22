import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getContactInfo from '@salesforce/apex/ResumeContactInfoController.getContactInfo';
import saveContactInfo from '@salesforce/apex/ResumeContactInfoController.saveContactInfo';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const RESUME_PAGE = 'resume__c';
// 入力項目(画面の data-field と Apex の ContactInfo の項目名)
const INPUT_FIELDS = [
  'shimei',
  'furigana',
  'gender',
  'graduatedSchool',
  'academicBackground',
  'major',
  'graduateDate',
  'comingJapanDate',
  'birthdate',
  'nearestLine',
  'nearestStation'
];

// 今日の日付(yyyy-MM-dd。誕生日の上限)
function getToday() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

export default class ResumeContactInfo extends NavigationMixin(LightningElement) {
  // 保存済みの基本情報(キャンセル時の変更確認用)
  savedInfo = {};
  // 入力中の基本情報(未入力は空文字)
  info = {};
  genderOptions = [];
  academicBackgroundOptions = [];
  isLoading = false;
  // 保存成功後の画面遷移中(遷移が終わるまでスピナーを表示し続ける)
  isNavigating = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  today = getToday();
  // 表示中のダイアログ(共通ダイアログで表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;

  connectedCallback() {
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.callApex(() => this.fetchContactInfo());
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  get ageLabel() {
    return this.savedInfo.age == null ? '' : `${this.savedInfo.age}歳`;
  }

  get experiencesLabel() {
    return this.savedInfo.experiences == null ? '' : `${this.savedInfo.experiences}年`;
  }

  async fetchContactInfo() {
    const data = await getContactInfo({ sessionKey: getSessionKey() });
    const info = {};
    INPUT_FIELDS.forEach((field) => {
      info[field] = data[field] ?? '';
    });
    this.savedInfo = { ...info, age: data.age, experiences: data.experiences };
    this.info = info;
    // 性別はトグルボタンで選ぶ(選択中のボタンを押すと未選択に戻す)
    this.genderOptions = data.genderOptions ?? [];
    // 最終学歴は未選択に戻せるよう、先頭に「なし」を加える
    this.academicBackgroundOptions = [{ label: '--なし--', value: '' }, ...(data.academicBackgroundOptions ?? [])];
    this.isAuthenticated = true;
  }

  // 性別のトグルボタン(選択中のボタンは強調表示する)
  get genderButtons() {
    return this.genderOptions.map((option) => ({
      ...option,
      variant: option.value === this.info.gender ? 'brand' : 'neutral'
    }));
  }

  // 性別のボタンを押したら選択する(選択中のボタンをもう一度押すと未選択に戻す)
  handleGenderClick(event) {
    const value = event.currentTarget.dataset.value;
    this.info = { ...this.info, gender: this.info.gender === value ? '' : value };
  }

  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.info = { ...this.info, [field]: event.detail.value ?? '' };
  }

  handleSave() {
    const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, c-year-month-picker')];
    const isValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);
    if (!isValid) {
      return;
    }
    // 未入力は null で渡す
    const info = {};
    INPUT_FIELDS.forEach((field) => {
      info[field] = this.info[field] || null;
    });
    // 保存したら履歴書トップ画面へ戻る(エラー時はこの画面に残ってダイアログで表示する)
    this.callApex(async () => {
      await saveContactInfo({ sessionKey: getSessionKey(), info });
      this.isNavigating = true;
      this.navigateToResume();
    });
  }

  // 入力内容に変更があるか
  get isChanged() {
    return INPUT_FIELDS.some((field) => this.info[field] !== this.savedInfo[field]);
  }

  // 入力内容に変更がある場合のみキャンセル確認ダイアログを開く(個人情報設定画面と同じ)
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
      this.isLoading = this.isNavigating;
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
