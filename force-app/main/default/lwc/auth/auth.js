/**
 * 認証の共通処理(各画面のコンポーネントから使う)
 *
 * 未ログインまたはセッション切れの場合、表示中のURLを保存してログイン画面へ遷移する。
 * ログイン後は保存したURLへ戻る。
 */
import { NavigationMixin } from 'lightning/navigation';
import validateSession from '@salesforce/apex/WorkreportSession.validateSession';

const SESSION_STORAGE_KEY = 'workReportSessionKey';
const RETURN_URL_STORAGE_KEY = 'workReportReturnUrl';
const SESSION_INVALID = 'SESSION_INVALID';
export const LOGIN_PAGE = 'workreport_login__c';
// 個人情報(写真など)を変更したときに通知するイベント名(ヘッダーが受け取って表示し直す)
export const PROFILE_CHANGE_EVENT = 'workreportprofilechange';
const HOME_PAGE = 'Home';

export function getSessionKey() {
  return sessionStorage.getItem(SESSION_STORAGE_KEY);
}

export function setSessionKey(sessionKey) {
  sessionStorage.setItem(SESSION_STORAGE_KEY, sessionKey);
}

export function clearSessionKey() {
  sessionStorage.removeItem(SESSION_STORAGE_KEY);
}

// 個人情報の変更をヘッダーへ通知する
export function notifyProfileChange() {
  window.dispatchEvent(new CustomEvent(PROFILE_CHANGE_EVENT));
}

// Apexの例外がセッション無効によるものか判定する
export function isSessionInvalidError(error) {
  return error?.body?.message === SESSION_INVALID;
}

// Experience Builder(編集キャンバス・プレビュー)で表示中か判定する
// ビルダーではログインできないため、ログイン画面への遷移を行わない
export function isInBuilder() {
  const hostname = window.location.hostname;
  return (
    hostname.includes('sitepreview') ||
    hostname.includes('livepreview') ||
    hostname.includes('live-preview') ||
    hostname.includes('builder.salesforce-experience.com')
  );
}

// 表示中のURLを保存してログイン画面へ遷移する
export function redirectToLogin(component) {
  if (isInBuilder()) {
    return;
  }
  clearSessionKey();
  sessionStorage.setItem(RETURN_URL_STORAGE_KEY, window.location.pathname + window.location.search);
  component[NavigationMixin.Navigate]({
    type: 'comm__namedPage',
    attributes: { name: LOGIN_PAGE }
  });
}

// ログインチェック(未ログインの場合はログイン画面へ遷移し、falseを返す)
export async function requireLogin(component) {
  if (isInBuilder()) {
    return true;
  }
  const sessionKey = getSessionKey();
  let isValid = false;
  if (sessionKey) {
    try {
      isValid = await validateSession({ sessionKey });
    } catch {
      isValid = false;
    }
  }
  if (!isValid) {
    redirectToLogin(component);
  }
  return isValid;
}

// ログイン後の遷移(保存したURLがあればそこへ、無ければホームへ)
export function navigateAfterLogin(component) {
  const returnUrl = sessionStorage.getItem(RETURN_URL_STORAGE_KEY);
  sessionStorage.removeItem(RETURN_URL_STORAGE_KEY);
  if (isSafeReturnUrl(returnUrl)) {
    component[NavigationMixin.Navigate]({
      type: 'standard__webPage',
      attributes: { url: returnUrl }
    });
    return;
  }
  component[NavigationMixin.Navigate]({
    type: 'comm__namedPage',
    attributes: { name: HOME_PAGE }
  });
}

// オープンリダイレクト防止のため、同一サイト内のパスのみ許可する
function isSafeReturnUrl(url) {
  return typeof url === 'string' && url.startsWith('/') && !url.startsWith('//') && !url.startsWith('/\\');
}
