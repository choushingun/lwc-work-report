/**
 * 機能名 : 履歴書画面(resume)のコントローラー
 *
 * WorkreportSessionでセッションキーから社員(Contact)を特定し、履歴詳細の一覧取得・複製・削除を行う。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ResumeController {
  // 履歴詳細一覧取得
  @AuraEnabled
  public static List<ResumeDetail__c> getDetails(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    return ResumeDetailDao.getListByContact(contactId);
  }

  // 履歴詳細複製(複製した履歴詳細のIdを返す)
  @AuraEnabled
  public static Id copyDetail(String sessionKey, Id detailId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<ResumeDetail__c> details = ResumeDetailDao.getCopyListById(detailId, contactId);
    if (details.isEmpty()) {
      throw createException('履歴詳細が見つかりません。画面を再表示してください。');
    }
    ResumeDetail__c newDetail = details[0].clone(false, true);
    ResumeDetailDao.insertDetail(newDetail);
    return newDetail.Id;
  }

  // 履歴詳細削除(既に削除されている場合は何もしない)
  @AuraEnabled
  public static void deleteDetail(String sessionKey, Id detailId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    ResumeDetailDao.deleteDetails(ResumeDetailDao.getCopyListById(detailId, contactId));
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
