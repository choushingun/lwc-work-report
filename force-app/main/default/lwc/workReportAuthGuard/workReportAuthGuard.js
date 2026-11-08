import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { requireLogin } from 'c/workReportAuth';

// 画面に配置するだけでログインチェックを行い、未ログインの場合はログイン画面へ遷移する
// チェックが終わるまでは画面全体をスピナーで覆い、ページの内容を見せない
export default class WorkReportAuthGuard extends NavigationMixin(LightningElement) {
  async connectedCallback() {
    this.showSpinner();
    const isValid = await requireLogin(this);
    // 未ログインの場合はログイン画面へ遷移するまで覆ったままにする
    if (isValid) {
      this.hideSpinner();
    }
  }

  // スピナーは描画後でないと取得できないため、描画を待ってから操作する
  async showSpinner() {
    await Promise.resolve();
    this.template.querySelector('c-spinner')?.showSpinner();
  }

  async hideSpinner() {
    await Promise.resolve();
    this.template.querySelector('c-spinner')?.hideSpinner();
  }
}
