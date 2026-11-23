import { LightningElement, api } from 'lwc';

const TIME_PATTERN = /^([01]\d|2[0-3])([0-5]\d)$/;
// 直接入力の形式(時1～2桁 + 区切り(なし・:・時) + 分2桁 + 「分」(任意)、または時だけ(「時」は任意))
const INPUT_PATTERN = /^(\d{1,2})(?:[:時]?(\d{2})分?|時?)$/;
const FORMAT_ERROR_MESSAGE = '時刻は「09:00」の形式で入力してください。';
const REQUIRED_ERROR_MESSAGE = 'この項目を入力してください。';
const DEFAULT_MINUTE_STEP = 15;

// HHmm を { hour, minute } にする(形式が違う場合は null)
function parseTime(value) {
  const match = TIME_PATTERN.exec(value ?? '');
  return match ? { hour: Number(match[1]), minute: Number(match[2]) } : null;
}

const pad = (value) => String(value).padStart(2, '0');

// 全角の数字・記号を半角にし、空白を除く
function normalize(text) {
  return (text ?? '')
    .replace(/[０-９：]/g, (char) => String.fromCharCode(char.charCodeAt(0) - 0xfee0))
    .replace(/\s/g, '');
}

/**
 * 時刻選択(時・分の選択パネル)
 *
 * 入力欄に時刻を直接入力するか、パネルを開いて左の列で時、右の列で分を選ぶ(分を選ぶと閉じる)。
 * 直接入力は「0900」「9:00」「9時30分」「9」などを受け付ける(全角数字も可)。
 * value は時刻の文字列(HHmm。例：0930)。
 * 選択・入力・クリアしたら change イベントの detail.value に時刻(クリアは空文字)を渡す。
 * 時の列は firstHour の時から並べる(勤務時間用に 8 を指定すると 08～23、00～07 の順)。
 * 分は minuteStep 分刻み(初期値 15分)。直接入力も刻みに合わない分はエラーにする。
 */
export default class TimePicker extends LightningElement {
  // 項目名(読み上げ用。画面には表示しない)
  @api label = '';
  @api disabled = false;
  @api required = false;
  // 時の列の先頭の時(0～23)
  @api firstHour = 0;
  // 分の刻み
  @api minuteStep = DEFAULT_MINUTE_STEP;

  // 選択中の時・分(数値。未選択は null)
  hour = null;
  minute = null;
  isOpen = false;
  // 入力欄に表示中の文字(直接入力中は入力した文字のまま)
  inputText = '';
  // 入力チェックのエラー(なしは空文字)
  errorMessage = '';
  // パネルを開いたとき、選択中の時を列の見える位置までスクロールする
  needsScroll = false;

  @api
  get value() {
    return this.hour !== null && this.minute !== null ? `${pad(this.hour)}${pad(this.minute)}` : '';
  }

  set value(value) {
    const parsed = parseTime(value);
    const newValue = parsed ? `${pad(parsed.hour)}${pad(parsed.minute)}` : '';
    // 選択後に親から同じ値が戻ってきた場合は、表示中のエラーを消さない
    if (newValue === this.value) {
      return;
    }
    this.hour = parsed?.hour ?? null;
    this.minute = parsed?.minute ?? null;
    this.inputText = this.displayValue;
    this.errorMessage = '';
  }

  // 入力チェック(正しくない時刻・必須の未入力はエラーを表示して false)
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

  get ariaExpanded() {
    return String(this.isOpen);
  }

  get minuteStepValue() {
    const step = Number(this.minuteStep);
    return step > 0 && step <= 60 ? step : DEFAULT_MINUTE_STEP;
  }

  // 表示する時刻(例：09:00)
  get displayValue() {
    return this.value ? `${pad(this.hour)}:${pad(this.minute)}` : '';
  }

  // 時の列(firstHour から24時間分。選択中は強調する)
  get hours() {
    const first = Number(this.firstHour) || 0;
    return Array.from({ length: 24 }, (_, index) => {
      const hour = (first + index) % 24;
      const selected = hour === this.hour;
      return {
        value: String(hour),
        label: pad(hour),
        pressed: String(selected),
        className: selected ? 'time-button time-button_selected' : 'time-button'
      };
    });
  }

  // 分の列(minuteStep 分刻み。選択中は強調する)
  get minutes() {
    const items = [];
    for (let minute = 0; minute < 60; minute += this.minuteStepValue) {
      const selected = minute === this.minute;
      items.push({
        value: String(minute),
        label: pad(minute),
        pressed: String(selected),
        className: selected ? 'time-button time-button_selected' : 'time-button'
      });
    }
    return items;
  }

  renderedCallback() {
    if (!this.needsScroll) {
      return;
    }
    this.needsScroll = false;
    // 選択中の時を時の列の上から2つ目あたりに表示する
    const list = this.template.querySelector('.hour-list');
    const selected = list?.querySelector('.time-button_selected');
    if (list && selected) {
      list.scrollTop = Math.max(selected.parentElement.offsetTop - list.offsetTop - selected.offsetHeight, 0);
    }
  }

  // 入力欄を押したらパネルを開く(開いているときは閉じずに入力を続けられるようにする)
  handleInputClick() {
    if (!this.isOpen) {
      this.handleToggle();
    }
  }

  handleToggle() {
    this.isOpen = !this.isOpen;
    this.needsScroll = this.isOpen;
  }

  // 時を選ぶ(分が未選択なら 00 分にする。続けて分を選べるようパネルは開いたまま)
  handleSelectHour(event) {
    const hour = Number(event.currentTarget.dataset.value);
    this.select(hour, this.minute ?? 0, false);
  }

  // 分を選んだら確定してパネルを閉じる(時が未選択なら列の先頭の時にする)
  handleSelectMinute(event) {
    const minute = Number(event.currentTarget.dataset.value);
    this.select(this.hour ?? (Number(this.firstHour) || 0), minute, true);
  }

  // 入力欄で Enter キーを押したら入力を確定し、↓キーでパネルを開く
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

  // 直接入力した文字を時刻にする(空はクリア。正しくない場合はエラーを表示し、値は変えない)
  commitInput() {
    const text = normalize(this.inputText);
    if (!text) {
      if (this.value || this.errorMessage) {
        this.select(null, null, false);
      }
      if (this.required) {
        this.errorMessage = REQUIRED_ERROR_MESSAGE;
      }
      return;
    }
    // 区切りなしの3～4桁(930・0930)は、後ろ2桁を分とする
    const digits = /^\d{3,4}$/.test(text) ? `${text.slice(0, -2)}:${text.slice(-2)}` : text;
    const match = INPUT_PATTERN.exec(digits);
    const hour = match ? Number(match[1]) : null;
    const minute = match ? Number(match[2] ?? 0) : null;
    if (!match || hour > 23 || minute > 59) {
      this.errorMessage = FORMAT_ERROR_MESSAGE;
      return;
    }
    if (minute % this.minuteStepValue !== 0) {
      this.errorMessage = `分は${this.minuteStepValue}分単位で入力してください。`;
      return;
    }
    if (hour === this.hour && minute === this.minute) {
      // 値は同じ(表示だけ整える)
      this.inputText = this.displayValue;
      this.errorMessage = '';
      return;
    }
    this.select(hour, minute, false);
  }

  select(hour, minute, close) {
    this.hour = hour;
    this.minute = minute;
    this.inputText = this.displayValue;
    this.errorMessage = '';
    if (close && this.isOpen) {
      this.isOpen = false;
      this.template.querySelector('input')?.focus();
    }
    this.dispatchEvent(new CustomEvent('change', { detail: { value: this.value } }));
  }

  // パネルの外にフォーカスが移ったら閉じる
  handleFocusOut(event) {
    const picker = event.currentTarget;
    if (!picker.contains(event.relatedTarget)) {
      this.isOpen = false;
    }
  }

  // Escキーでパネルを閉じる
  handleKeyDown(event) {
    if (event.key === 'Escape' && this.isOpen) {
      event.stopPropagation();
      this.isOpen = false;
      this.template.querySelector('input')?.focus();
    }
  }
}
