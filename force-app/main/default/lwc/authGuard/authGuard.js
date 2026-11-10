import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { requireLogin } from 'c/auth';

// 画面に配置するだけでログインチェックを行い、未ログインの場合はログイン画面へ遷移する
// チェックが終わるまでは画面全体をスピナーで覆い、ページの内容を見せない
export default class AuthGuard extends NavigationMixin(LightningElement) {
  isLoading = true;

  async connectedCallback() {
    const isValid = await requireLogin(this);
    // 未ログインの場合はログイン画面へ遷移するまで覆ったままにする
    if (isValid) {
      this.isLoading = false;
    }
  }
}
