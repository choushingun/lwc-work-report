/**
 * 機能名 : 添付ファイル(Attachment)のデータアクセス
 *
 * ゲストユーザーから勤務表ファイルの登録・削除を行うため、without sharing かつシステムモードで実行する。
 * 呼び出し元で必ずログイン社員の勤務表に絞り込むこと。
 */
public without sharing class AttachmentDao {
  // 親レコードに添付された、指定したファイル名の添付ファイル
  public static List<Attachment> getListByName(Id parentId, String name) {
    return [
      SELECT Id
      FROM Attachment
      WHERE ParentId = :parentId AND Name = :name
      WITH SYSTEM_MODE
    ];
  }

  // 親レコードに添付された、指定したファイル名の添付ファイル(本文付き、新しい順)
  public static List<Attachment> getBodyListByName(Id parentId, String name) {
    return [
      SELECT Id, Name, ContentType, Body
      FROM Attachment
      WHERE ParentId = :parentId AND Name = :name
      WITH SYSTEM_MODE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
  }

  public static void insertAttachment(Attachment att) {
    insert as system att;
  }

  public static void deleteAttachments(List<Attachment> attachments) {
    if (!attachments.isEmpty()) {
      delete as system attachments;
    }
  }
}
