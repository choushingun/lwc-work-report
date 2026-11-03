/**
 * 機能名 : ログイン画面(workReportLogin)のコントローラー
 *
 * 社員(Contact)のメールアドレス・パスワードで認証し、SessionManagement__cにセッションを登録する。
 * ゲストユーザーから呼ばれ、Contactの参照・更新が必要なため without sharing かつシステムモードで実行する。
 */
public without sharing class LoginController {
  private static final Integer MAX_FAILED_COUNT = 5;
  private static final Integer LOCKOUT_MINUTES = 15;
  private static final Integer HASH_ITERATIONS = 2000;
  private static final String DUMMY_SALT = '00000000000000000000000000000000';

  // ログイン処理(成功時はセッションキー、失敗時はnullを返す)
  // 例外を投げると失敗回数の更新がロールバックされるため、失敗はnullで返す
  @AuraEnabled
  public static String login(String email, String password) {
    if (String.isBlank(email) || String.isBlank(password)) {
      return null;
    }
    List<Contact> contacts = [
      SELECT Id, PasswordHash__c, PasswordSalt__c, FailedLoginCount__c, LockoutUntil__c
      FROM Contact
      WHERE Email = :email.trim()
      WITH SYSTEM_MODE
      LIMIT 2
    ];
    // Emailは標準項目で一意制約を付けられないため、重複時はログイン不可とする
    if (contacts.size() != 1 || contacts[0].PasswordHash__c == null) {
      // 応答時間からメールアドレスの登録有無を判別されないよう、同じ計算を行う
      hashPassword(password, DUMMY_SALT);
      return null;
    }

    Contact con = contacts[0];
    system.debug('con.PasswordHash__c' + con.PasswordHash__c);
    system.debug('con.PasswordSalt__c' + con.PasswordSalt__c);
    Boolean isMatched = hashPassword(password, con.PasswordSalt__c).equals(con.PasswordHash__c);
    if (con.LockoutUntil__c != null && System.now() < con.LockoutUntil__c) {
      return null;
    }
    if (!isMatched) {
      recordFailure(con);
      return null;
    }

    con.FailedLoginCount__c = 0;
    con.LockoutUntil__c = null;
    update as system con;
    return createSession(con.Id);
  }

  // ログアウト処理(有効なセッションにログアウト日時を記録する)
  @AuraEnabled
  public static void logout(String sessionKey) {
    if (String.isBlank(sessionKey)) {
      return;
    }
    List<SessionManagement__c> sessions = [
      SELECT Id
      FROM SessionManagement__c
      WHERE Key__c = :hashSessionKey(sessionKey) AND LogoutDatetime__c = NULL
      WITH SYSTEM_MODE
    ];
    Datetime now = System.now();
    for (SessionManagement__c session : sessions) {
      session.LogoutDatetime__c = now;
    }
    update as system sessions;
  }

  // パスワード設定(管理者が匿名Apexから実行する)
  public static void setPassword(Id contactId, String password) {
    if (String.isBlank(password)) {
      throw new IllegalArgumentException('パスワードが空です');
    }
    String salt = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    update as system new Contact(
      Id = contactId,
      PasswordSalt__c = salt,
      PasswordHash__c = hashPassword(password, salt),
      FailedLoginCount__c = 0,
      LockoutUntil__c = null
    );
  }

  private static void recordFailure(Contact con) {
    Integer failedCount = con.FailedLoginCount__c == null ? 1 : con.FailedLoginCount__c.intValue() + 1;
    if (failedCount >= MAX_FAILED_COUNT) {
      con.LockoutUntil__c = System.now().addMinutes(LOCKOUT_MINUTES);
      failedCount = 0;
    }
    con.FailedLoginCount__c = failedCount;
    update as system con;
  }

  // セッション登録(DBにはキーのハッシュ値のみ保存する)
  private static String createSession(Id contactId) {
    String sessionKey = EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    Datetime now = System.now();
    insert as system new SessionManagement__c(
      Key__c = hashSessionKey(sessionKey),
      LoginUser__c = contactId,
      LoginDatetime__c = now,
      LastAccessDatetime__c = now
    );
    return sessionKey;
  }

  @TestVisible
  private static String hashSessionKey(String sessionKey) {
    return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(sessionKey)));
  }

  private static String hashPassword(String password, String salt) {
    Blob key = Blob.valueOf(password);
    Blob hash = Blob.valueOf(salt);
    for (Integer i = 0; i < HASH_ITERATIONS; i++) {
      hash = Crypto.generateMac('hmacSHA256', hash, key);
    }
    return EncodingUtil.convertToHex(hash);
  }
}
