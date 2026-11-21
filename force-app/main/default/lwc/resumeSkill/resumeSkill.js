import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSkill from '@salesforce/apex/ResumeSkillController.getSkill';
import saveSkill from '@salesforce/apex/ResumeSkillController.saveSkill';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const RESUME_PAGE = 'resume__c';

export default class ResumeSkill extends NavigationMixin(LightningElement) {
  // 技術経験の分類と項目(項目の value は入力中の経験レベル。未選択は空文字)
  sections = [];
  // 経験レベルの選択肢(先頭は未選択)
  options = [];
  comment = '';
  // 保存済みの経験レベル(項目のAPI参照名 → 経験レベル)・備考(キャンセル時の変更確認用)
  savedSkills = {};
  savedComment = '';
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
    this.callApex(() => this.fetchSkill());
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  async fetchSkill() {
    const data = await getSkill({ sessionKey: getSessionKey() });
    this.sections = (data.sections ?? []).map((section) => ({
      label: section.label,
      items: section.items.map((item) => ({ ...item, value: item.value ?? '' }))
    }));
    this.savedSkills = this.getSkills();
    this.options = [{ label: '--なし--', value: '' }, ...(data.options ?? [])];
    this.comment = data.comment ?? '';
    this.savedComment = this.comment;
    this.isAuthenticated = true;
  }

  // 入力中の経験レベル(項目のAPI参照名 → 経験レベル)
  getSkills() {
    const skills = {};
    this.sections.forEach((section) => {
      section.items.forEach((item) => {
        skills[item.field] = item.value;
      });
    });
    return skills;
  }

  handleSkillChange(event) {
    const field = event.target.dataset.field;
    const value = event.detail.value ?? '';
    this.sections = this.sections.map((section) => ({
      ...section,
      items: section.items.map((item) => (item.field === field ? { ...item, value } : item))
    }));
  }

  handleCommentChange(event) {
    this.comment = event.target.value ?? '';
  }

  // 保存したら履歴書トップ画面へ戻る(エラー時はこの画面に残ってダイアログで表示する)
  handleSave() {
    const textarea = this.template.querySelector('lightning-textarea');
    if (!textarea.reportValidity()) {
      return;
    }
    this.callApex(async () => {
      await saveSkill({ sessionKey: getSessionKey(), skills: this.getSkills(), comment: this.comment });
      this.isNavigating = true;
      this.navigateToResume();
    });
  }

  // 入力内容に変更があるか
  get isChanged() {
    const skills = this.getSkills();
    return (
      this.comment !== this.savedComment || Object.keys(skills).some((field) => skills[field] !== this.savedSkills[field])
    );
  }

  // 入力内容に変更がある場合のみキャンセル確認ダイアログを開く(基本情報画面と同じ)
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
