/**
 * 機能名 : ヘッダー(workreportNav)のコントローラー
 *
 * ログイン社員の名前・写真・管理職かどうかを返す(メニューの出し分けと写真の表示に使う)。
 * 写真は社員(Contact)に添付した、ファイル名が「photo」で始まる画像とする。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class HeaderController {
  // 写真のファイル名の先頭(個人情報設定画面で登録する)
  public static final String PHOTO_NAME_PREFIX = 'photo';
  // 写真の最大サイズ(これより大きい画像は表示しない。個人情報設定画面の登録上限と同じ)
  public static final Integer PHOTO_MAX_BYTES = 1024 * 1024;

  public class HeaderInfo {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Boolean isManager;
    // 写真(data URL。写真がない場合は null)
    @AuraEnabled
    public String photoUrl;
  }

  // ヘッダー情報取得(セッションが無効な場合は null を返す。ログイン画面への遷移は各画面で行う)
  @AuraEnabled
  public static HeaderInfo getHeaderInfo(String sessionKey) {
    Id contactId = WorkreportSession.findContactId(sessionKey);
    if (contactId == null) {
      return null;
    }
    List<Contact> contacts = ContactDao.getHeaderListById(contactId);
    if (contacts.isEmpty()) {
      return null;
    }
    HeaderInfo info = new HeaderInfo();
    info.name = contacts[0].Name;
    info.isManager = contacts[0].Management__c;
    info.photoUrl = getPhotoUrl(contactId);
    return info;
  }

  // 社員の写真(data URL。写真がない場合は null)。個人情報設定画面からも使う
  public static String getPhotoUrl(Id contactId) {
    List<Attachment> photos = AttachmentDao.getLatestImageList(contactId, PHOTO_NAME_PREFIX, PHOTO_MAX_BYTES);
    if (photos.isEmpty()) {
      return null;
    }
    return 'data:' + photos[0].ContentType + ';base64,' + EncodingUtil.base64Encode(photos[0].Body);
  }
}
