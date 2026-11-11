import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSetting from '@salesforce/apex/PersonalSettingController.getSetting';
import saveSetting from '@salesforce/apex/PersonalSettingController.saveSetting';
import requestPasswordChange from '@salesforce/apex/PersonalSettingController.requestPasswordChange';
import { getSessionKey, isSessionInvalidError, notifyProfileChange, redirectToLogin } from 'c/auth';

const SYSTEM_ERROR_MESSAGE = '処理に失敗しました。時間をおいて再度お試しください。';
const WORK_LIST_PAGE = 'workreport_list__c';
// 登録できる写真の形式と最大サイズ(Apex側と同じ)
const PHOTO_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/gif'];
const PHOTO_MAX_BYTES = 1024 * 1024;

export default class PersonalSetting extends NavigationMixin(LightningElement) {
  setting = {};
  // 上司(Contact Id。未設定は空文字)
  superiorId = '';
  reportTo = '';
  reportToMail = '';
  // 表示中の写真(登録済み、または選択した新しい写真の data URL)
  photoUrl;
  // 選択した新しい写真(保存するまで登録しない)
  newPhoto = null;
  isLoading = false;
  // ログイン確認済み(確認できるまで画面を表示しない)
  isAuthenticated = false;
  errorMessage = '';
  // 表示中のダイアログ(共通ダイアログで表示する。null は非表示)
  // { title, messages, confirmLabel, cancelLabel, isError, onConfirm(確定時の処理) }
  dialog = null;
  photoAccept = PHOTO_CONTENT_TYPES.join(',');

  connectedCallback() {
    if (!getSessionKey()) {
      redirectToLogin(this);
      return;
    }
    this.callApex(() => this.fetchSetting());
  }

  get showPageError() {
    return !this.isAuthenticated && this.errorMessage;
  }

  get photoTitle() {
    return this.photoUrl ? 'クリックして写真を変更する' : 'クリックして写真をアップロードする';
  }

  async fetchSetting() {
    const data = await getSetting({ sessionKey: getSessionKey() });
    this.setting = data;
    this.superiorId = data.superiorId ?? '';
    this.reportTo = data.reportTo ?? '';
    this.reportToMail = data.reportToMail ?? '';
    this.photoUrl = data.photoUrl;
    this.newPhoto = null;
    this.isAuthenticated = true;
  }

  // 上司の選択肢(先頭に「なし」を加える)
  get superiorOptions() {
    return [{ label: '(なし)', value: '' }, ...(this.setting.superiorOptions ?? [])];
  }

  handleSuperiorChange(event) {
    this.superiorId = event.detail.value;
  }

  handleReportToChange(event) {
    this.reportTo = event.target.value;
  }

  handleReportToMailChange(event) {
    this.reportToMail = event.target.value;
  }

  // 写真をクリックしたらファイル選択を開く
  handlePhotoClick() {
    if (!this.isLoading) {
      this.template.querySelector('.photo-input').click();
    }
  }

  // 写真を選択したら確認用に表示する(保存ボタンで登録する)
  handlePhotoChange(event) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) {
      return;
    }
    if (!PHOTO_CONTENT_TYPES.includes(file.type)) {
      this.openResultDialog('証明写真はJPEG・PNG・GIFの画像を選択してください。', true);
      return;
    }
    if (file.size > PHOTO_MAX_BYTES) {
      this.openResultDialog('証明写真は1MB以下の画像を選択してください。', true);
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result;
      this.photoUrl = dataUrl;
      this.newPhoto = { content: dataUrl.substring(dataUrl.indexOf(',') + 1), contentType: file.type };
    };
    reader.readAsDataURL(file);
  }

  handleSave() {
    const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
    const isValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);
    if (!isValid) {
      return;
    }
    this.callApex(async () => {
      const message = await saveSetting({
        sessionKey: getSessionKey(),
        superiorId: this.superiorId || null,
        reportTo: this.reportTo,
        reportToMail: this.reportToMail,
        photoContent: this.newPhoto?.content ?? null,
        photoContentType: this.newPhoto?.contentType ?? null
      });
      const photoChanged = !!this.newPhoto;
      await this.fetchSetting();
      // ヘッダーの写真を新しい写真に変える
      if (photoChanged) {
        notifyProfileChange();
      }
      return message;
    });
  }

  // 入力内容に変更があるか(上司・勤務表特別送付先の変更、または新しい写真を選択した場合)
  get isChanged() {
    const s = this.setting;
    return (
      this.superiorId !== (s.superiorId ?? '') ||
      this.reportTo !== (s.reportTo ?? '') ||
      this.reportToMail !== (s.reportToMail ?? '') ||
      !!this.newPhoto
    );
  }

  // 入力内容に変更がある場合のみキャンセル確認ダイアログを開く(勤務表作成画面と同じ)
  handleCancel() {
    if (!this.isChanged) {
      this.navigateBack();
      return;
    }
    this.dialog = {
      title: '入力内容の破棄',
      messages: ['入力内容を破棄して前の画面に戻りますか？', '保存されていない内容は失われます。'],
      confirmLabel: 'はい',
      cancelLabel: 'いいえ',
      onConfirm: () => this.navigateBack()
    };
  }

  // 前の画面へ戻る(前の画面がない場合は勤務表一覧へ)
  navigateBack() {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }
    this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: WORK_LIST_PAGE } });
  }

  // パスワード変更確認ダイアログを開く
  handlePasswordChange(event) {
    event.preventDefault();
    if (this.isLoading) {
      return;
    }
    this.dialog = {
      title: 'パスワード変更',
      messages: [
        `登録メールアドレス(${this.setting.email ?? ''})にパスワード変更用のメールを送信しますか？`,
        'メールに記載されたURLから新しいパスワードを設定してください。'
      ],
      confirmLabel: '送信',
      cancelLabel: 'キャンセル',
      onConfirm: () => this.callApex(() => requestPasswordChange({ sessionKey: getSessionKey() }))
    };
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
}
