import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getEducation from '@salesforce/apex/ResumeEducationController.getEducation';
import saveEducation from '@salesforce/apex/ResumeEducationController.saveEducation';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const RESUME_PAGE = 'resume__c';
// 語学能力の入力項目(画面の data-field と Apex の Language の項目名)
const LANGUAGE_TEXT_FIELDS = ['name', 'studyMethod', 'read', 'write', 'speak', 'qualification', 'qualifiedYearMonth'];
const LANGUAGE_NUMBER_FIELDS = ['studyYears', 'score'];
const LANGUAGE_FIELDS = [...LANGUAGE_TEXT_FIELDS, ...LANGUAGE_NUMBER_FIELDS];
// 資格・トレーニングの入力項目(画面の data-field と Apex の Training の項目名)
const TRAINING_FIELDS = ['yearMonth', 'content', 'memo'];
// 語学能力・資格・トレーニングの最大件数(Resume__c の項目の番号 1～5)
const MAX_ROW_COUNT = 5;

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

// 行が未入力か
function isEmptyRow(row, fields) {
  return fields.every((field) => row[field] === '' || row[field] == null);
}

let rowKeySeq = 0;

// 画面表示用の行(key は描画用の一意キー)
function toRow(values, fields) {
  rowKeySeq += 1;
  return { key: `row-${rowKeySeq}`, ...toInputValues(values, fields) };
}

// 取得した行のうち入力済みのものを表示用の行にする(1件もない場合は空の1件)
function toDisplayRows(records, fields) {
  const rows = (records ?? []).filter((record) => !isEmptyRow(record, fields)).map((record) => toRow(record, fields));
  return rows.length ? rows : [toRow({}, fields)];
}

// 語学能力の行に表示順の番号を振り直す
// (資格獲得年月の年月選択部品は項目名を表示しないため、読み上げ用の項目名も持たせる)
function numberLanguages(rows) {
  return rows.map((row, index) => ({
    ...row,
    no: index + 1,
    qualifiedYearMonthLabel: `語学能力${index + 1}の資格獲得年月`,
    removeLabel: `語学能力${index + 1}を削除`
  }));
}

// 資格・トレーニングの行に表示順の番号を振り直す
// (表の入力欄は項目名を表示しないため、読み上げ用の項目名も持たせる)
function numberTrainings(rows) {
  return rows.map((row, index) => {
    const label = `資格・トレーニング${index + 1}の`;
    return {
      ...row,
      no: index + 1,
      yearMonthLabel: `${label}獲得年月`,
      contentLabel: `${label}内容`,
      memoLabel: `${label}備考`,
      removeLabel: `資格・トレーニング${index + 1}を削除`
    };
  });
}

// 保存用の行(未入力の行を除いて前から詰め、1から番号を振る。渡さない番号は Apex で未入力になる)
function toSaveRows(rows, fields, convert) {
  return rows
    .filter((row) => !isEmptyRow(row, fields))
    .map((row, index) => {
      const values = { no: index + 1 };
      fields.forEach((field) => {
        values[field] = convert(field, row[field]);
      });
      return values;
    });
}

export default class ResumeEducation extends NavigationMixin(LightningElement) {
  // 語学能力・資格・トレーニング(画面に表示中の行。no は表示順の番号で、保存時に詰めて項目の番号にする)
  // 各項目は入力中の値で、未入力は空文字
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
    // 入力済みの行のみ表示する(1件もない場合は空の1件を表示する)
    this.languages = numberLanguages(toDisplayRows(data.languages, LANGUAGE_FIELDS));
    this.trainings = numberTrainings(toDisplayRows(data.trainings, TRAINING_FIELDS));
    this.levelOptions = [{ label: '--なし--', value: '' }, ...(data.levelOptions ?? [])];
    this.savedInputs = JSON.stringify(this.getInputs());
    this.isAuthenticated = true;
  }

  // 入力中の語学資格(Apex の EducationData の形。未入力は null)
  // 語学能力・資格・トレーニングは未入力の行を除いて前から詰める
  getInputs() {
    return {
      languages: toSaveRows(this.languages, LANGUAGE_FIELDS, (field, value) =>
        LANGUAGE_NUMBER_FIELDS.includes(field) ? toNumber(value) : toText(value)
      ),
      trainings: toSaveRows(this.trainings, TRAINING_FIELDS, (field, value) => toText(value))
    };
  }

  handleLanguageChange(event) {
    this.languages = this.updateRow(this.languages, event);
  }

  get canAddLanguage() {
    return this.languages.length < MAX_ROW_COUNT;
  }

  // 1件のみの場合は削除できない(入力欄を空にすれば未入力として保存される)
  get canRemoveLanguage() {
    return this.languages.length > 1;
  }

  // 語学能力を末尾に1件追加する(最大5件)
  handleAddLanguage() {
    if (this.canAddLanguage) {
      this.languages = numberLanguages([...this.languages, toRow({}, LANGUAGE_FIELDS)]);
    }
  }

  // 語学能力を削除し、後ろの行を前に詰める
  handleRemoveLanguage(event) {
    const no = Number(event.currentTarget.dataset.no);
    this.languages = numberLanguages(this.languages.filter((language) => language.no !== no));
  }

  get canAddTraining() {
    return this.trainings.length < MAX_ROW_COUNT;
  }

  // 1件のみの場合は削除できない(削除ボタンは表示したまま非活性にする)
  get isTrainingRemoveDisabled() {
    return this.trainings.length <= 1;
  }

  // 資格・トレーニングを末尾に1件追加する(最大5件)
  handleAddTraining() {
    if (this.canAddTraining) {
      this.trainings = numberTrainings([...this.trainings, toRow({}, TRAINING_FIELDS)]);
    }
  }

  // 資格・トレーニングを削除し、後ろの行を前に詰める
  handleRemoveTraining(event) {
    if (this.isTrainingRemoveDisabled) {
      return;
    }
    const no = Number(event.currentTarget.dataset.no);
    this.trainings = numberTrainings(this.trainings.filter((training) => training.no !== no));
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
    const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, c-year-month-picker')];
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
