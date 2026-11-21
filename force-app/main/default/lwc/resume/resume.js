import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDetails from '@salesforce/apex/ResumeController.getDetails';
import copyDetail from '@salesforce/apex/ResumeController.copyDetail';
import deleteDetail from '@salesforce/apex/ResumeController.deleteDetail';
import { getSessionKey, isSessionInvalidError, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
// 履歴詳細の作成・編集画面(Experience Builderのページ名)
const RESUME_DETAIL_PAGE = 'resume_detail__c';
const DEFAULT_PAGE_SIZE = 10;

// 履歴情報の各入力画面(Experience Builderのページ名)
const RESUME_MENUS = [
  {
    label: '基本情報',
    description: '氏名・性別・学歴・最寄駅など',
    icon: 'standard:avatar',
    page: 'resume_contact_info__c'
  },
  {
    label: '技術経験',
    description: '言語・DB・OS・フレームワークなどの経験レベル',
    icon: 'standard:skill',
    page: 'resume_skill__c'
  },
  {
    label: '仕事経験',
    description: 'マネジメント経験・作業経験・得意分野',
    icon: 'standard:work_type',
    page: 'resume_project__c'
  },
  {
    label: '語学資格',
    description: '語学能力・資格・研修',
    icon: 'standard:education',
    page: 'resume_education__c'
  }
];

export default class Resume extends NavigationMixin(LightningElement) {
  details = [];
  pageNumber = 1;
  pageSize = DEFAULT_PAGE_SIZE;
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  resumeMenus = RESUME_MENUS;
  // 表示中のダイアログ(共通ダイアログで表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;

  connectedCallback() {
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.callApex(() => this.fetchDetails());
  }

  get sessionKey() {
    return getSessionKey();
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.details.length / this.pageSize));
  }

  get displayDetails() {
    const start = (this.pageNumber - 1) * this.pageSize;
    return this.details.slice(start, start + this.pageSize);
  }

  async fetchDetails() {
    this.details = await getDetails({ sessionKey: this.sessionKey });
    this.pageNumber = Math.min(this.pageNumber, this.totalPages);
    this.isAuthenticated = true;
  }

  // 履歴情報の各入力画面へ
  handleOpenMenu(event) {
    this.navigateTo(event.currentTarget.dataset.page);
  }

  handleCreateDetail() {
    this.navigateTo(RESUME_DETAIL_PAGE);
  }

  handleEditDetail(event) {
    this.navigateTo(RESUME_DETAIL_PAGE, { id: event.currentTarget.dataset.id });
  }

  // 複製して、複製した履歴詳細の編集画面へ
  handleCopyDetail(event) {
    const detailId = event.currentTarget.dataset.id;
    this.callApex(async () => {
      const newId = await copyDetail({ sessionKey: this.sessionKey, detailId });
      this.navigateTo(RESUME_DETAIL_PAGE, { id: newId });
    });
  }

  // 削除確認ダイアログを開く
  handleDeleteDetail(event) {
    const detailId = event.currentTarget.dataset.id;
    this.dialog = {
      title: '履歴詳細を削除',
      messages: '履歴詳細を削除しますか？',
      confirmLabel: '削除',
      cancelLabel: 'キャンセル',
      onConfirm: () => this.removeDetail(detailId)
    };
  }

  // 履歴詳細を削除する(Apexの deleteDetail と区別するため別名にする)
  removeDetail(detailId) {
    this.callApex(async () => {
      await deleteDetail({ sessionKey: this.sessionKey, detailId });
      await this.fetchDetails();
      return '履歴詳細を削除しました。';
    });
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

  // ページング(ページ番号・ページサイズ)の変更
  handlePageChange(event) {
    this.pageNumber = event.detail.pageNumber;
    this.pageSize = event.detail.pageSize;
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
      this.isLoading = false;
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

  navigateTo(name, state) {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name },
      state
    });
  }
}
