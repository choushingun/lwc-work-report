/**
 * 機能名 : 履歴情報(Resume__c)のデータアクセス
 *
 * ゲストユーザーは共有上参照できないため、without sharing かつシステムモードで実行する。
 * 呼び出し元で必ずログイン社員(Contact)の履歴情報に絞り込むこと。
 */
public without sharing class ResumeDao {
  // 社員の履歴情報(社員ごとに1件)
  public static List<Resume__c> getListByContact(Id contactId) {
    return [SELECT Id FROM Resume__c WHERE Contact__c = :contactId WITH SYSTEM_MODE LIMIT 1];
  }

  // 社員の履歴情報を指定した項目付きで取得する(社員ごとに1件)
  // fields には呼び出し元で定義した項目のAPI参照名のみを渡すこと(画面からの値を渡さない)
  public static List<Resume__c> getListByContact(Id contactId, List<String> fields) {
    String soql = 'SELECT Id, ' + String.join(fields, ', ') + ' FROM Resume__c WHERE Contact__c = :contactId LIMIT 1';
    return Database.queryWithBinds(soql, new Map<String, Object>{ 'contactId' => contactId }, AccessLevel.SYSTEM_MODE);
  }

  public static void upsertResume(Resume__c resume) {
    upsert as system resume;
  }
}
