import { LightningElement, api } from 'lwc';

// 選べる範囲の下限の初期値(1950年01月)。上限の初期値は今月
const DEFAULT_MIN = '195001';
const YEAR_MONTH_PATTERN = /^(\d{4})(0[1-9]|1[0-2])$/;
const REQUIRED_ERROR_MESSAGE = 'この項目を入力してください。';
// 直接入力の形式(年4桁 + 区切り(なし・/・-・.・年) + 月1～2桁 + 「月」(任意))
const INPUT_PATTERN = /^(\d{4})[/\-.年]?(\d{1,2})月?$/;
const FORMAT_ERROR_MESSAGE = '年月は「2020/04」の形式で入力してください。';

// yyyyMM を { year, month } にする(形式が違う場合は null)
function parseYearMonth(value) {
  const match = YEAR_MONTH_PATTERN.exec(value ?? '');
  return match ? { year: Number(match[1]), month: Number(match[2]) } : null;
}

// 年月を比べるための通し番号
function toIndex(year, month) {
  return year * 12 + month;
}

// 表示用の年月(例：2020年04月)
function formatYearMonth(year, month) {
  return `${year}年${String(month).padStart(2, '0')}月`;
}

// 全角の数字・記号を半角にし、空白を除く
function normalize(text) {
  return (text ?? '')
    .replace(/[０-９／－．]/g, (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0))
    .replace(/[ー−]/g, '-')
    .replace(/\s/g, '');
}

/**
 * 年月選択(年月カレンダー)
 *
 * 入力欄に年月を直接入力するか、カレンダーを開いて年を ‹ › で切り替えて12か月から選ぶ。
 * 直接入力は「202004」「2020/4」「2020-04」「2020年4月」などを受け付ける(全角数字も可)。
 * value は年月の文字列(yyyyMM。例：202004)。
 * 選択・入力・クリアしたら change イベントの detail.value に年月(クリアは空文字)を渡す。
 * 選べる範囲は min・max(yyyyMM)で指定する(未指定は 1950年01月～今月)。
 * 入力した年月が正しくない場合・範囲外の場合・必須(required)で未入力の場合は、
 * 入力欄の下にエラーを表示し、reportValidity() は false を返す。
 */
export default class YearMonthPicker extends LightningElement {
  // 項目名(読み上げ用。画面には表示しない)
  @api label = '';
  @api disabled = false;
  @api required = false;
  // 選べる範囲(yyyyMM。未指定は 1950年01月～今月)
  @api min;
  @api max;

  // 選択中の年・月(数値。未選択は null)
  year = null;
  month = null;
  // カレンダーに表示中の年
  viewYear;
  isOpen = false;
  // 入力欄に表示中の文字(直接入力中は入力した文字のまま)
  inputText = '';
  // 入力チェックのエラー(なしは空文字)
  errorMessage = '';

  @api
  get value() {
    return this.year && this.month ? `${this.year}${String(this.month).padStart(2, '0')}` : '';
  }

  set value(value) {
    const parsed = parseYearMonth(value);
    const newValue = parsed ? `${parsed.year}${String(parsed.month).padStart(2, '0')}` : '';
    // 選択後に親から同じ値が戻ってきた場合は、表示中のエラーを消さない
    if (newValue === this.value) {
      return;
    }
    this.year = parsed?.year ?? null;
    this.month = parsed?.month ?? null;
    this.inputText = this.displayValue;
    this.errorMessage = '';
  }

  // 入力チェック(正しくない年月・範囲外・必須の未入力はエラーを表示して false)
  @api
  reportValidity() {
    if (!this.errorMessage && this.required && !this.value && !this.disabled) {
      this.errorMessage = REQUIRED_ERROR_MESSAGE;
    }
    return !this.errorMessage;
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get inputClass() {
    return this.hasError ? 'picker-input picker-input_error' : 'picker-input';
  }

  // 選べる範囲の下限・上限({ year, month })
  get minValue() {
    return parseYearMonth(this.min) ?? parseYearMonth(DEFAULT_MIN);
  }

  get maxValue() {
    const now = new Date();
    return parseYearMonth(this.max) ?? { year: now.getFullYear(), month: now.getMonth() + 1 };
  }

  get minYearValue() {
    return this.minValue.year;
  }

  get maxYearValue() {
    return this.maxValue.year;
  }

  isInRange(year, month) {
    const index = toIndex(year, month);
    return (
      index >= toIndex(this.minValue.year, this.minValue.month) &&
      index <= toIndex(this.maxValue.year, this.maxValue.month)
    );
  }

  // 表示する年月(月は2桁。例：1992年06月)
  get displayValue() {
    return this.year && this.month ? formatYearMonth(this.year, this.month) : '';
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
    const now = new Date();
    return !this.isInRange(now.getFullYear(), now.getMonth() + 1);
  }

  // 年のプルダウンの選択肢(新しい年から。表示中の年を選択状態にする)
  get yearOptions() {
    const options = [];
    for (let year = this.maxYearValue; year >= this.minYearValue; year--) {
      options.push({ value: String(year), label: String(year), selected: year === this.viewYear });
    }
    return options;
  }

  // 表示中の年の12か月(選択中の月は強調し、範囲外の月は選べなくする)
  get months() {
    const now = new Date();
    return Array.from({ length: 12 }, (_, index) => {
      const month = index + 1;
      const selected = this.viewYear === this.year && month === this.month;
      const isThisMonth = this.viewYear === now.getFullYear() && month === now.getMonth() + 1;
      const disabled = !this.isInRange(this.viewYear, month);
      let className = 'month-button';
      if (selected) {
        className += ' month-button_selected';
      } else if (isThisMonth) {
        className += ' month-button_today';
      }
      return {
        value: String(month),
        label: `${String(month).padStart(2, '0')}月`,
        pressed: String(selected),
        disabled,
        className
      };
    });
  }

  // 入力欄を押したらカレンダーを開く(開いているときは閉じずに入力を続けられるようにする)
  handleInputClick() {
    if (!this.isOpen) {
      this.handleToggle();
    }
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

  // 年のプルダウンで表示する年を切り替える(標準の日付カレンダーと同じ)
  handleYearSelect(event) {
    this.viewYear = Number(event.target.value);
  }

  handleSelectMonth(event) {
    this.select(this.viewYear, Number(event.currentTarget.dataset.month));
  }

  handleThisMonth() {
    const now = new Date();
    this.select(now.getFullYear(), now.getMonth() + 1);
  }

  // 入力欄で Enter キーを押したら入力を確定し、↓キーでカレンダーを開く
  handleInputKeyDown(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.commitInput();
    } else if (event.key === 'ArrowDown' && !this.isOpen) {
      event.preventDefault();
      this.handleToggle();
    }
  }

  handleInput(event) {
    this.inputText = event.target.value;
  }

  // 入力欄からフォーカスが外れたら入力を確定する
  handleInputChange(event) {
    event.stopPropagation();
    this.commitInput();
  }

  // 直接入力した文字を年月にする(空はクリア。正しくない場合はエラーを表示し、値は変えない)
  commitInput() {
    const text = normalize(this.inputText);
    if (!text) {
      if (this.year || this.errorMessage) {
        this.select(null, null);
      }
      if (this.required) {
        this.errorMessage = REQUIRED_ERROR_MESSAGE;
      }
      return;
    }
    const match = INPUT_PATTERN.exec(text);
    const year = match ? Number(match[1]) : null;
    const month = match ? Number(match[2]) : null;
    if (!match || month < 1 || month > 12) {
      this.errorMessage = FORMAT_ERROR_MESSAGE;
      return;
    }
    const rangeError = this.getRangeError(year, month);
    if (rangeError) {
      this.errorMessage = rangeError;
      return;
    }
    if (year === this.year && month === this.month) {
      // 値は同じ(表示だけ整える)
      this.inputText = this.displayValue;
      this.errorMessage = '';
      return;
    }
    this.select(year, month);
  }

  // 選べる範囲外の年月のエラー
  getRangeError(year, month) {
    if (this.isInRange(year, month)) {
      return '';
    }
    const { minValue, maxValue } = this;
    return `${formatYearMonth(minValue.year, minValue.month)}～${formatYearMonth(maxValue.year, maxValue.month)}の年月を入力してください。`;
  }

  select(year, month) {
    this.year = year;
    this.month = month;
    this.inputText = this.displayValue;
    this.errorMessage = '';
    const wasOpen = this.isOpen;
    this.isOpen = false;
    if (wasOpen) {
      this.template.querySelector('input')?.focus();
    }
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
      this.template.querySelector('input')?.focus();
    }
  }
}
