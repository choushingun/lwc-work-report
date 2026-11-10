import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

// サイトのホーム(デフォルト画面)に配置し、勤務表一覧へ移動する
// 履歴は置き換えるため、ブラウザの「戻る」でホームに戻ることはない
const WORK_LIST_PAGE = 'workreport_list__c';

export default class HomeRedirect extends NavigationMixin(LightningElement) {
  connectedCallback() {
    this[NavigationMixin.Navigate]({ type: 'comm__namedPage', attributes: { name: WORK_LIST_PAGE } }, true);
  }
}
