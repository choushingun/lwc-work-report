import { LightningElement, api } from 'lwc';

const DEFAULT_MIN_YEAR = 1950;

/**
 * 年月選択(年月カレンダー)
 *
 * 入力欄を押すとカレンダーを開き、年を ‹ › で切り替えて12か月から選ぶ。
 * value は月初日の日付文字列(yyyy-MM-dd)。日付が入っている場合も年月だけを表示する。
 * 選択・クリアしたら change イベントの detail.value に月初日(クリアは空文字)を渡す。
 */
export default class YearMonthPicker extends LightningElement {
  // 項目名(読み上げ用。画面には表示しない)
  @api label = '';
  @api disabled = false;
  // 選択できる年の範囲(未指定は 1950年～今年)
  @api minYear = DEFAULT_MIN_YEAR;
  @api maxYear;

  // 選択中の年・月(数値。未選択は null)
  year = null;
  month = null;
  // カレンダーに表示中の年
  viewYear;
  isOpen = false;

  @api
  get value() {
    return this.year && this.month ? `${this.year}-${String(this.month).padStart(2, '0')}-01` : '';
  }

  set value(value) {
    const match = /^(\d{4})-(\d{2})/.exec(value ?? '');
    this.year = match ? Number(match[1]) : null;
    this.month = match ? Number(match[2]) : null;
  }

  // 年月の選択は必須ではなく、選んだ値は常に正しい年月のため、入力チェックはない
  // (他の入力欄と同じく reportValidity() で一括チェックできるように用意する)
  @api
  reportValidity() {
    return true;
  }

  get minYearValue() {
    return Number(this.minYear) || DEFAULT_MIN_YEAR;
  }

  get maxYearValue() {
    return Number(this.maxYear) || new Date().getFullYear();
  }

  get displayValue() {
    return this.year && this.month ? `${this.year}年${this.month}月` : '';
  }

  // カレンダーを開いている間は slds-is-open を付ける(SLDSのドロップダウンの表示条件)
  get triggerClass() {
    return `slds-dropdown-trigger slds-dropdown-trigger_click picker${this.isOpen ? ' slds-is-open' : ''}`;
  }

  get ariaExpanded() {
    return String(this.isOpen);
  }

  get isMinYear() {
    return this.viewYear <= this.minYearValue;
  }

  get isMaxYear() {
    return this.viewYear >= this.maxYearValue;
  }

  // 今月が選べる範囲外の場合は「今月」ボタンを押せなくする
  get isThisMonthDisabled() {
    const thisYear = new Date().getFullYear();
    return thisYear < this.minYearValue || thisYear > this.maxYearValue;
  }

  // 表示中の年の12か月(選択中の月は強調し、今年の先の月は選べなくする)
  get months() {
    const now = new Date();
    const isMaxDefault = !this.maxYear;
    return Array.from({ length: 12 }, (_, index) => {
      const month = index + 1;
      const selected = this.viewYear === this.year && month === this.month;
      const isThisMonth = this.viewYear === now.getFullYear() && month === now.getMonth() + 1;
      // 上限を指定しない場合(今年まで)は、未来の月も選べないようにする
      const disabled = isMaxDefault && this.viewYear === now.getFullYear() && month > now.getMonth() + 1;
      let className = 'slds-button month-button';
      if (selected) {
        className += ' month-button_selected';
      } else if (isThisMonth) {
        className += ' month-button_today';
      }
      return { value: String(month), label: `${month}月`, pressed: String(selected), disabled, className };
    });
  }

  handleToggle() {
    if (this.isOpen) {
      this.isOpen = false;
      return;
    }
    // 選択中の年(未選択は今年)のカレンダーを開く
    const year = this.year ?? new Date().getFullYear();
    this.viewYear = Math.min(Math.max(year, this.minYearValue), this.maxYearValue);
    this.isOpen = true;
  }

  handlePrevYear() {
    this.viewYear = Math.max(this.viewYear - 1, this.minYearValue);
  }

  handleNextYear() {
    this.viewYear = Math.min(this.viewYear + 1, this.maxYearValue);
  }

  handleSelectMonth(event) {
    this.select(this.viewYear, Number(event.currentTarget.dataset.month));
  }

  handleThisMonth() {
    const now = new Date();
    this.select(now.getFullYear(), now.getMonth() + 1);
  }

  handleClear() {
    this.select(null, null);
  }

  select(year, month) {
    this.year = year;
    this.month = month;
    this.isOpen = false;
    this.template.querySelector('.picker-input')?.focus();
    this.dispatchEvent(new CustomEvent('change', { detail: { value: this.value } }));
  }

  // カレンダーの外にフォーカスが移ったら閉じる
  handleFocusOut(event) {
    const picker = event.currentTarget;
    if (!picker.contains(event.relatedTarget)) {
      this.isOpen = false;
    }
  }

  // Escキーでカレンダーを閉じる
  handleKeyDown(event) {
    if (event.key === 'Escape' && this.isOpen) {
      event.stopPropagation();
      this.isOpen = false;
      this.template.querySelector('.picker-input')?.focus();
    }
  }
}
