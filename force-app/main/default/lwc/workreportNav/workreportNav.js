import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import basePath from '@salesforce/community/basePath';
import getHeaderInfo from '@salesforce/apex/HeaderController.getHeaderInfo';
import { PROFILE_CHANGE_EVENT, getSessionKey } from 'c/auth';

// ナビゲーションの項目(サイトのURLのパス)。managerOnly の項目は管理職にだけ表示する
// subPaths : 項目の下の画面(表示中は項目に下線を表示する)
// 標準のナビゲーションメニューは全員がゲストユーザーのため社員ごとに出し分けできず、このコンポーネントで表示する
const MENU_ITEMS = [
  {
    label: '勤務表',
    path: '/workreport-list',
    // 勤務表参照・勤務表作成(編集)・勤務実績入力
    subPaths: ['/workreport-view', '/workreport-input', '/worktime-input']
  },
  { label: '勤務承認', path: '/approval-list', managerOnly: true },
  // イベント・ナレッジは未作成のため、標準のナビゲーションメニューと同じ仮のリンクにしている
  { label: 'イベント', path: '/CheckPasswordResetEmail' },
  { label: 'ナレッジ', path: '/CheckPasswordResetEmail' },
  { label: 'ログアウト', path: '/workreport-logout' }
];

// 歯車アイコンで開く個人設定画面(Experience Builderのページ名)
const PERSONAL_SETTING_PAGE = 'personal_setting__c';

export default class WorkreportNav extends NavigationMixin(LightningElement) {
  // ヘッダー情報を取得したセッションキー(ログイン・ログアウトでキーが変わった場合だけ取得し直す)
  checkedSessionKey;
  isLoggedIn = false;
  isManager = false;
  userName = '';
  // 写真(data URL。写真がない場合は人型アイコンを表示する)
  photoUrl;
  currentPath = '';

  // 個人情報設定画面で写真などを変更したら、ヘッダー情報を取得し直す
  handleProfileChange = () => {
    this.checkedSessionKey = undefined;
    this.checkSession();
  };

  connectedCallback() {
    window.addEventListener(PROFILE_CHANGE_EVENT, this.handleProfileChange);
  }

  disconnectedCallback() {
    window.removeEventListener(PROFILE_CHANGE_EVENT, this.handleProfileChange);
  }

  // ページ移動のたびに呼ばれる(テーマのヘッダーに配置するため、画面を移動しても作り直されない)
  @wire(CurrentPageReference)
  setPageReference() {
    this.currentPath = window.location.pathname;
    this.checkSession();
  }

  async checkSession() {
    const sessionKey = getSessionKey();
    if (sessionKey === this.checkedSessionKey) {
      return;
    }
    this.checkedSessionKey = sessionKey;
    let info = null;
    if (sessionKey) {
      try {
        info = await getHeaderInfo({ sessionKey });
      } catch {
        info = null;
      }
    }
    // 取得中に別のセッションへ変わった場合は結果を使わない
    if (sessionKey !== this.checkedSessionKey) {
      return;
    }
    // セッションが無効(null)の場合はヘッダーを表示しない(ログイン画面への遷移は各画面で行う)
    this.isLoggedIn = !!info;
    this.isManager = info?.isManager === true;
    this.userName = info?.name ?? '';
    this.photoUrl = info?.photoUrl;
  }

  get photoTitle() {
    return this.photoUrl ? this.userName : '写真はアップロードされていません';
  }

  handlePersonalSetting() {
    this[NavigationMixin.Navigate]({
      type: 'comm__namedPage',
      attributes: { name: PERSONAL_SETTING_PAGE }
    });
  }

  get menuItems() {
    return MENU_ITEMS.filter((item) => !item.managerOnly || this.isManager).map((item) => {
      const url = `${basePath}${item.path}`;
      const isActive = [item.path, ...(item.subPaths ?? [])].some((path) => this.currentPath === `${basePath}${path}`);
      return {
        ...item,
        url,
        key: item.label,
        itemClass: isActive ? 'nav-item nav-item_active' : 'nav-item',
        ariaCurrent: isActive ? 'page' : null
      };
    });
  }

  handleClick(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate]({
      type: 'standard__webPage',
      attributes: { url: event.currentTarget.dataset.url }
    });
  }
}
