/**
 * 機能名 : 履歴詳細(ResumeDetail__c)のデータアクセス
 *
 * ゲストユーザーは共有上参照できないため、without sharing かつシステムモードで実行する。
 * 呼び出し元で必ずログイン社員(Contact)の履歴詳細に絞り込むこと。
 */
public without sharing class ResumeDetailDao {
  // 社員の履歴詳細一覧(新しい作業期間順)
  public static List<ResumeDetail__c> getListByContact(Id contactId) {
    return [
      SELECT Id, WorkPeriod__c, Role__c, IndustryType__c, Subject__c
      FROM ResumeDetail__c
      WHERE Resume__r.Contact__c = :contactId
      WITH SYSTEM_MODE
      ORDER BY StartDate__c DESC
    ];
  }

  // 社員の履歴詳細をIdで取得する(複製用に入力項目をすべて取得する。他の社員の履歴詳細は取得しない)
  public static List<ResumeDetail__c> getCopyListById(Id detailId, Id contactId) {
    return [
      SELECT
        Id,
        Resume__c,
        StartDate__c,
        EndDate__c,
        Role__c,
        IndustryType__c,
        Subject__c,
        WorkRange__c,
        Environment__c,
        DevelopeLanguageDb1__c,
        DevelopeLanguageDb2__c,
        DevelopeLanguageDb3__c,
        DevelopeTool1__c,
        DevelopeTool2__c,
        DevelopeTool3__c
      FROM ResumeDetail__c
      WHERE Id = :detailId AND Resume__r.Contact__c = :contactId
      WITH SYSTEM_MODE
    ];
  }

  public static void insertDetail(ResumeDetail__c detail) {
    insert as system detail;
  }

  public static void deleteDetails(List<ResumeDetail__c> details) {
    if (!details.isEmpty()) {
      delete as system details;
    }
  }
}
