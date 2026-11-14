import { LightningElement, api } from 'lwc';

// ページサイズの選択肢(最小のサイズ以下の件数では1ページに収まるため、ページングを表示しない)
const PAGE_SIZES = [10, 15, 25, 50];
const MIN_PAGE_SIZE = PAGE_SIZES[0];
const PAGE_SIZE_OPTIONS = PAGE_SIZES.map((size) => ({ label: `${size} ページ毎`, value: `${size}` }));

/**
 * 一覧画面の共通ページング
 * 表示範囲(例：11-20/70)・ページサイズ選択・前へ/次へを表示する。
 * ページ番号・ページサイズは親が保持し、変更時は change イベント(detail: { pageNumber, pageSize })で通知する。
 */
export default class Paging extends LightningElement {
  // 全件数
  @api totalCount = 0;
  // 現在のページ番号(1始まり)
  @api pageNumber = 1;
  // 1ページの件数
  @api pageSize = MIN_PAGE_SIZE;
  @api disabled = false;

  pageSizeOptions = PAGE_SIZE_OPTIONS;

  get totalPages() {
    return Math.max(1, Math.ceil(this.totalCount / this.pageSize));
  }

  // 最小のページサイズを超える件数がある場合のみ表示する
  get showPaging() {
    return this.totalCount > MIN_PAGE_SIZE;
  }

  get rangeLabel() {
    const start = (this.pageNumber - 1) * this.pageSize + 1;
    const end = Math.min(this.pageNumber * this.pageSize, this.totalCount);
    return `${start}-${end}/${this.totalCount}`;
  }

  get pageSizeValue() {
    return `${this.pageSize}`;
  }

  get hasPaging() {
    return this.totalPages > 1;
  }

  get isFirstPage() {
    return this.disabled || this.pageNumber <= 1;
  }

  get isLastPage() {
    return this.disabled || this.pageNumber >= this.totalPages;
  }

  // ページサイズを変えたら1ページ目に戻す
  handlePageSizeChange(event) {
    this.notify(1, Number(event.detail.value));
  }

  handlePrevious() {
    this.notify(Math.max(1, this.pageNumber - 1), this.pageSize);
  }

  handleNext() {
    this.notify(Math.min(this.totalPages, this.pageNumber + 1), this.pageSize);
  }

  notify(pageNumber, pageSize) {
    this.dispatchEvent(new CustomEvent('change', { detail: { pageNumber, pageSize } }));
  }
}
