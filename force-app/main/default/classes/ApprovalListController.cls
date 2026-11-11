/**
 * 機能名 : 勤務承認画面(approvalList)のコントローラー
 *
 * 管理職(Contact.Management__c)が、上長として担当する部下の勤務表を年月ごとに一覧表示する。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ApprovalListController {
  // 部下の指定年月の勤務表一覧取得(yyyy:年4桁、mm:月2桁)
  @AuraEnabled
  public static List<Workreport__c> getReports(String sessionKey, String yyyy, String mm) {
    Id contactId = getManagerId(sessionKey);
    if (!Pattern.matches('\\d{4}', yyyy ?? '') || !Pattern.matches('(0[1-9]|1[0-2])', mm ?? '')) {
      throw createException('年月の指定が正しくありません。');
    }
    return WorkreportDao.getListBySuperior(contactId, yyyy, mm);
  }

  // ログイン社員が管理職の場合は社員Idを返す(管理職以外は例外)
  private static Id getManagerId(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    if (!ContactDao.isManager(contactId)) {
      throw createException('勤務承認は管理職のみ利用できます。');
    }
    return contactId;
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
