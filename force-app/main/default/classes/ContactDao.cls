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

  public static void updateContact(Contact con) {
    update as system con;
  }
}
