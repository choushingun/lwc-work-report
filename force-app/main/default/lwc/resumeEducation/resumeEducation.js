import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getEducation from '@salesforce/apex/ResumeEducationController.getEducation';
import saveEducation from '@salesforce/apex/ResumeEducationController.saveEducation';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const RESUME_PAGE = 'resume__c';
// 語学能力の入力項目(画面の data-field と Apex の Language の項目名)
const LANGUAGE_TEXT_FIELDS = ['name', 'studyMethod', 'read', 'write', 'speak', 'qualification', 'qualifiedDate'];
const LANGUAGE_NUMBER_FIELDS = ['studyYears', 'score'];
// 資格/トレーニングの入力項目(画面の data-field と Apex の Training の項目名)
const TRAINING_FIELDS = ['trainingDate', 'content', 'memo'];

// 数値入力欄の値を整数にする(未入力は null)
function toNumber(value) {
  return value === '' || value == null ? null : Number(value);
}

// 文字列の入力値(前後の空白を除き、未入力は null)
function toText(value) {
  return value?.trim() || null;
}

// 入力欄に表示する値(未入力は空文字)
function toInputValues(record, fields) {
  const values = {};
  fields.forEach((field) => {
    values[field] = record[field] ?? '';
  });
  return values;
}

export default class ResumeEducation extends NavigationMixin(LightningElement) {
  // 語学能力・資格/トレーニング(no は項目の番号。各項目は入力中の値で、未入力は空文字)
  languages = [];
  trainings = [];
  // 読む・書く・会話の選択肢(先頭は未選択)
  levelOptions = [];
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
    this.callApex(() => this.fetchEducation());
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  async fetchEducation() {
    const data = await getEducation({ sessionKey: getSessionKey() });
    this.languages = (data.languages ?? []).map((language) => ({
      no: language.no,
      ...toInputValues(language, [...LANGUAGE_TEXT_FIELDS, ...LANGUAGE_NUMBER_FIELDS])
    }));
    this.trainings = (data.trainings ?? []).map((training) => ({
      no: training.no,
      // 表の入力欄は項目名を表示しないため、読み上げ用の項目名を持たせる
      dateLabel: `資格/トレーニング${training.no}の時間`,
      contentLabel: `資格/トレーニング${training.no}の内容`,
      memoLabel: `資格/トレーニング${training.no}の備考`,
      ...toInputValues(training, TRAINING_FIELDS)
    }));
    this.levelOptions = [{ label: '--なし--', value: '' }, ...(data.levelOptions ?? [])];
    this.savedInputs = JSON.stringify(this.getInputs());
    this.isAuthenticated = true;
  }

  // 入力中の語学資格(Apex の EducationData の形。未入力は null)
  getInputs() {
    return {
      languages: this.languages.map((language) => {
        const values = { no: language.no };
        LANGUAGE_TEXT_FIELDS.forEach((field) => {
          values[field] = toText(language[field]);
        });
        LANGUAGE_NUMBER_FIELDS.forEach((field) => {
          values[field] = toNumber(language[field]);
        });
        return values;
      }),
      trainings: this.trainings.map((training) => {
        const values = { no: training.no };
        TRAINING_FIELDS.forEach((field) => {
          values[field] = toText(training[field]);
        });
        return values;
      })
    };
  }

  handleLanguageChange(event) {
    this.languages = this.updateRow(this.languages, event);
  }

  handleTrainingChange(event) {
    this.trainings = this.updateRow(this.trainings, event);
  }

  // 入力欄の data-no の行の data-field の値を入力値にする
  updateRow(rows, event) {
    const no = Number(event.target.dataset.no);
    const field = event.target.dataset.field;
    const value = event.detail.value ?? '';
    return rows.map((row) => (row.no === no ? { ...row, [field]: value } : row));
  }

  // 保存したら履歴書トップ画面へ戻る(エラー時はこの画面に残ってダイアログで表示する)
  handleSave() {
    const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
    const isValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);
    if (!isValid) {
      return;
    }
    this.callApex(async () => {
      await saveEducation({ sessionKey: getSessionKey(), data: this.getInputs() });
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
