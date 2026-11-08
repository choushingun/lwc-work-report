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
