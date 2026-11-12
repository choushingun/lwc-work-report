/**
 * 機能名 : 社員(Contact)のデータアクセス
 *
 * ゲストユーザーからログイン認証・社員情報の参照を行うため、without sharing かつシステムモードで実行する。
 */
public without sharing class ContactDao {
  // メールアドレスで取得する(ログイン用、重複判定のため最大2件)
  public static List<Contact> getLoginListByEmail(String email) {
    return [
      SELECT Id, PasswordHash__c, PasswordSalt__c, FailedLoginCount__c, LockoutUntil__c
      FROM Contact
      WHERE Email = :email
      WITH SYSTEM_MODE
      LIMIT 2
    ];
  }

  // Idで取得する(ログイン中のパスワード変更で現在のパスワードを確認する用)
  public static List<Contact> getLoginListById(Id contactId) {
    return [
      SELECT Id, PasswordHash__c, PasswordSalt__c, FailedLoginCount__c, LockoutUntil__c
      FROM Contact
      WHERE Id = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // メールアドレスで取得する(パスワード再設定用。退職済みは除く。重複判定のため最大2件)
  public static List<Contact> getResetListByEmail(String email) {
    Date today = Date.today();
    return [
      SELECT Id, Email
      FROM Contact
      WHERE Email = :email AND (RetirementDate__c = NULL OR RetirementDate__c >= :today)
      WITH SYSTEM_MODE
      LIMIT 2
    ];
  }

  // パスワード再設定トークン(ハッシュ値)で取得する
  public static List<Contact> getListByResetToken(String tokenHash) {
    return [
      SELECT Id, PasswordResetExpires__c
      FROM Contact
      WHERE PasswordResetToken__c = :tokenHash
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  // 社員と所属会社・上長
  public static Contact getWithAccountById(Id contactId) {
    return [
      SELECT
        Name,
        ReportsToId,
        ReportsTo.Name,
        Account.Name,
        Account.Abbreviation__c,
        Account.ReportTo__c,
        Account.ReportToMail__c
      FROM Contact
      WHERE Id = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // 社員の名前・管理職(ヘッダー用)
  public static List<Contact> getHeaderListById(Id contactId) {
    return [SELECT Name, Management__c FROM Contact WHERE Id = :contactId WITH SYSTEM_MODE];
  }

  // 社員の個人情報設定(個人情報設定画面用)
  public static List<Contact> getSettingListById(Id contactId) {
    return [
      SELECT
        Name,
        Email,
        ReportsToId,
        ReportsTo.Name,
        ReportTo__c,
        ReportToMail__c,
        Account.ReportTo__c,
        Account.ReportToMail__c
      FROM Contact
      WHERE Id = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // 上司の候補(管理職で退職していない社員。本人を除く。名前順)
  public static List<Contact> getSuperiorCandidateList(Id excludeId) {
    Date today = Date.today();
    return [
      SELECT Id, Name, EmployeeNo__c
      FROM Contact
      WHERE
        Management__c = TRUE
        AND Id != :excludeId
        AND (RetirementDate__c = NULL
        OR RetirementDate__c >= :today)
      WITH SYSTEM_MODE
      ORDER BY Name, EmployeeNo__c
    ];
  }

  // 管理職か(社員が見つからない場合はfalse)
  public static Boolean isManager(Id contactId) {
    List<Contact> contacts = [SELECT Management__c FROM Contact WHERE Id = :contactId WITH SYSTEM_MODE];
    return !contacts.isEmpty() && contacts[0].Management__c;
  }

  public static void updateContact(Contact con) {
    update as system con;
  }
}
