import { LightningElement, api } from 'lwc';

/**
 * 共通スピナー
 *
 * 配置されている間はスピナーを表示する。表示の切り替えは親で lwc:if により行う。
 *   <c-spinner lwc:if={isLoading}></c-spinner>
 * 通常はページ全体を覆い、画面中央に表示する。
 * inline を指定すると親要素(position: relative)の範囲だけを覆う。
 * 覆いの背景色は親のCSSで --spinner-background を指定すると変えられる。
 */
export default class Spinner extends LightningElement {
  @api size;
  @api inline = false;
  @api variant = 'brand';
  @api alternativeText = '処理中';

  get containerClass() {
    return this.inline ? '' : 'full-page';
  }
}
