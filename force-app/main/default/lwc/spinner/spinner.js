import { LightningElement, api } from 'lwc';

/**
 * 共通スピナー
 *
 * 親コンポーネントから showSpinner() / hideSpinner() を呼んで表示を切り替える。
 *   this.template.querySelector('c-spinner').showSpinner();
 * 通常はページ全体を覆い、画面中央に表示する。
 * inline を指定すると親要素(position: relative)の範囲だけを覆う。
 * 覆いの背景色は親のCSSで --spinner-background を指定すると変えられる。
 */
export default class Spinner extends LightningElement {
  @api size;
  @api inline = false;
  @api variant = 'brand';
  @api alternativeText = '処理中';
  @api
  showSpinner() {
    this.isVisible = true;
  }
  @api
  hideSpinner() {
    this.isVisible = false;
  }
  isVisible = false;

  get containerClass() {
    return this.inline ? '' : 'full-page';
  }
}
