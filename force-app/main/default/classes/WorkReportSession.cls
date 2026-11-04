/**
 * 機能名 : セッション認証の共通処理
 *
 * 各画面のコントローラーから呼び、セッションキーからログイン社員(Contact)を特定する。
 * ゲストユーザーから呼ばれるため without sharing かつシステムモードで実行する。
 */
public without sharing class WorkReportSession {
  // セッションが無効な場合のエラーメッセージ(画面側でログイン画面へ遷移する判定に使う)
  public static final String SESSION_INVALID = 'SESSION_INVALID';
  private static final Integer SESSION_TIMEOUT_MINUTES = 30;

  // 画面表示時の認証チェック(有効な場合は最終アクセス日時を更新する)
  @AuraEnabled
  public static Boolean validateSession(String sessionKey) {
    return findSession(sessionKey) != null;
  }

  // セッションキーから社員Idを取得する(無効な場合はSESSION_INVALIDの例外を投げる)
  public static Id getContactId(String sessionKey) {
    SessionManagement__c session = findSession(sessionKey);
    if (session == null) {
      AuraHandledException e = new AuraHandledException(SESSION_INVALID);
      e.setMessage(SESSION_INVALID);
      throw e;
    }
    return session.LoginUser__c;
  }

  private static SessionManagement__c findSession(String sessionKey) {
    if (String.isBlank(sessionKey)) {
      return null;
    }
    List<SessionManagement__c> sessions = [
      SELECT Id, LoginUser__c, LastAccessDatetime__c
      FROM SessionManagement__c
      WHERE Key__c = :LoginController.hashSessionKey(sessionKey) AND LogoutDatetime__c = NULL
      WITH SYSTEM_MODE
      ORDER BY LoginDatetime__c DESC
      LIMIT 1
    ];
    Datetime now = System.now();
    if (
      sessions.isEmpty() ||
      sessions[0].LastAccessDatetime__c == null ||
      sessions[0].LastAccessDatetime__c.addMinutes(SESSION_TIMEOUT_MINUTES) < now
    ) {
      return null;
    }
    SessionManagement__c session = sessions[0];
    session.LastAccessDatetime__c = now;
    update as system session;
    return session;
  }
}
