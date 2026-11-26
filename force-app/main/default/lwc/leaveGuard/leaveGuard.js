/**
 * 入力画面から離れるときの確認(キャンセルボタン以外で画面を離れる場合)
 *
 * 入力画面は表示中に setLeaveGuard で次の2つを登録し、画面を閉じるときに clearLeaveGuard で解除する。
 *   isDirty()             : 保存していない変更があれば true
 *   confirmLeave(onLeave) : 確認ダイアログを開き、「はい」なら onLeave() を呼ぶ
 *
 * ・ブラウザ・タブを閉じる、再読み込み、URLの直接入力 : ブラウザ標準の確認ダイアログを出す
 *   (ブラウザの仕様で、独自のダイアログや文言は出せない)
 * ・サイト内のメニュー・設定アイコン : confirmLeave で画面の確認ダイアログを出す
 *   (メニュー側は画面を移動する前に、このモジュールの confirmLeave を呼ぶ)
 */
let currentGuard = null;

function handleBeforeUnload(event) {
  if (currentGuard?.isDirty()) {
    event.preventDefault();
    // 古いブラウザ(Chrome 119 以前など)は returnValue の設定が必要
    event.returnValue = '';
  }
}

export function setLeaveGuard(guard) {
  if (!currentGuard) {
    window.addEventListener('beforeunload', handleBeforeUnload);
  }
  currentGuard = guard;
}

export function clearLeaveGuard(guard) {
  // 次の画面が先に登録している場合があるため、自分の登録のときだけ解除する
  if (currentGuard !== guard) {
    return;
  }
  currentGuard = null;
  window.removeEventListener('beforeunload', handleBeforeUnload);
}

// 画面を移動する前に呼ぶ。変更がなければそのまま onLeave() を呼ぶ
export function confirmLeave(onLeave) {
  if (currentGuard?.isDirty()) {
    currentGuard.confirmLeave(onLeave);
    return;
  }
  onLeave();
}
