import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { requireLogin } from 'c/workReportAuth';

// 画面に配置するだけでログインチェックを行い、未ログインの場合はログイン画面へ遷移する
export default class WorkReportAuthGuard extends NavigationMixin(LightningElement) {
  connectedCallback() {
    requireLogin(this);
  }
}
