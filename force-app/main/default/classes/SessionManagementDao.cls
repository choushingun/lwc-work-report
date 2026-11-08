/**
 * 機能名 : セッション管理(SessionManagement__c)のデータアクセス
 *
 * ゲストユーザーからセッションの登録・照合を行うため、without sharing かつシステムモードで実行する。
 */
public without sharing class SessionManagementDao {
  // ログアウトしていない最新のセッション
  public static List<SessionManagement__c> getLatestActiveListByKey(String keyHash) {
    return [
      SELECT Id, LoginUser__c, LastAccessDatetime__c
      FROM SessionManagement__c
      WHERE Key__c = :keyHash AND LogoutDatetime__c = NULL
      WITH SYSTEM_MODE
      ORDER BY LoginDatetime__c DESC
      LIMIT 1
    ];
  }

  // ログアウトしていないセッション
  public static List<SessionManagement__c> getActiveListByKey(String keyHash) {
    return [
      SELECT Id
      FROM SessionManagement__c
      WHERE Key__c = :keyHash AND LogoutDatetime__c = NULL
      WITH SYSTEM_MODE
    ];
  }

  public static void insertSession(SessionManagement__c session) {
    insert as system session;
  }

  public static void updateSessions(List<SessionManagement__c> sessions) {
    if (!sessions.isEmpty()) {
      update as system sessions;
    }
  }
}
