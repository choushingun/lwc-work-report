/**
 * 機能名 : 個人情報設定画面(personalSetting)のコントローラー
 *
 * ログイン社員の個人情報(上司・勤務表特別送付先・証明写真)の参照・保存と、パスワード変更を行う。
 * 上司は標準項目 ReportsTo(勤務表作成時に勤務表の上長になる)で、管理職の社員から選ぶ。
 * 上司を変えた場合は、作成済みの勤務表の上長もすべて新しい上司に置き換える(元の上司は使わない)。
 * 写真は社員(Contact)に「photo.拡張子」の名前で添付する(ヘッダーの写真にも使う)。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class PersonalSettingController {
  // 登録できる写真の形式(ContentType → 拡張子)
  private static final Map<String, String> PHOTO_EXTENSIONS = new Map<String, String>{
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif'
  };
  private static final Integer REPORT_TO_MAX_LENGTH = 20;
  private static final Integer REPORT_TO_MAIL_MAX_LENGTH = 200;

  public class SettingData {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String email;
    // 上司(Contact Id)と、上司の選択肢(管理職の社員)
    @AuraEnabled
    public Id superiorId;
    @AuraEnabled
    public List<Option> superiorOptions;
    // 自社送付先宛名・自社送付先(会社の設定。参照のみ)
    @AuraEnabled
    public String companyReportTo;
    @AuraEnabled
    public String companyReportToMail;
    // 勤務表特別送付先宛名・勤務表特別送付先(個人の設定)
    @AuraEnabled
    public String reportTo;
    @AuraEnabled
    public String reportToMail;
    // 証明写真(data URL。写真がない場合は null)
    @AuraEnabled
    public String photoUrl;
  }

  // 選択肢(画面のコンボボックス用)
  public class Option {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;

    public Option(String label, String value) {
      this.label = label;
      this.value = value;
    }
  }

  // 個人情報設定取得
  @AuraEnabled
  public static SettingData getSetting(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Contact con = getContact(contactId);
    SettingData data = new SettingData();
    data.name = con.Name;
    data.email = con.Email;
    data.superiorId = con.ReportsToId;
    data.superiorOptions = getSuperiorOptions(con);
    data.companyReportTo = con.Account?.ReportTo__c;
    data.companyReportToMail = con.Account?.ReportToMail__c;
    data.reportTo = con.ReportTo__c;
    data.reportToMail = con.ReportToMail__c;
    data.photoUrl = HeaderController.getPhotoUrl(contactId);
    return data;
  }

  // 個人情報設定保存
  // photoContent : 新しい写真(Base64文字列)。写真を変更しない場合は null
  @AuraEnabled
  public static String saveSetting(
    String sessionKey,
    Id superiorId,
    String reportTo,
    String reportToMail,
    String photoContent,
    String photoContentType
  ) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Contact con = getContact(contactId);
    // 上司は選択肢(管理職の社員、または設定済みの上司)からのみ選べる
    if (superiorId != null && !isSuperiorOption(con, superiorId)) {
      throw createException('上司を選択し直してください。');
    }
    reportTo = reportTo?.trim();
    reportToMail = reportToMail?.trim();
    if (String.isNotBlank(reportTo) && reportTo.length() > REPORT_TO_MAX_LENGTH) {
      throw createException('勤務表特別送付先宛名は' + REPORT_TO_MAX_LENGTH + '文字以内で入力してください。');
    }
    if (String.isNotBlank(reportToMail) && reportToMail.length() > REPORT_TO_MAIL_MAX_LENGTH) {
      throw createException('勤務表特別送付先は' + REPORT_TO_MAIL_MAX_LENGTH + '文字以内で入力してください。');
    }

    Attachment photo;
    if (String.isNotBlank(photoContent)) {
      String extension = PHOTO_EXTENSIONS.get(photoContentType);
      if (extension == null) {
        throw createException('証明写真はJPEG・PNG・GIFの画像を選択してください。');
      }
      Blob body = EncodingUtil.base64Decode(photoContent);
      if (body.size() > HeaderController.PHOTO_MAX_BYTES) {
        throw createException('証明写真は1MB以下の画像を選択してください。');
      }
      photo = new Attachment(
        ParentId = contactId,
        Name = HeaderController.PHOTO_NAME_PREFIX + '.' + extension,
        ContentType = photoContentType,
        Body = body
      );
    }

    // 例外時は写真の置き換えも取り消されるよう、同じトランザクションで行う
    try {
      ContactDao.updateContact(
        new Contact(
          Id = contactId,
          ReportsToId = superiorId,
          ReportTo__c = String.isBlank(reportTo) ? null : reportTo,
          ReportToMail__c = String.isBlank(reportToMail) ? null : reportToMail
        )
      );
      // 作成済みの勤務表の上長を新しい上司に置き換える(勤務承認一覧は勤務表の上長で絞り込むため)
      List<Workreport__c> reports = WorkreportDao.getListWithOtherSuperior(contactId, superiorId);
      for (Workreport__c report : reports) {
        report.Superior__c = superiorId;
      }
      WorkreportDao.updateReports(reports);
      if (photo != null) {
        AttachmentDao.deleteAttachments(AttachmentDao.getListByNamePrefix(contactId, HeaderController.PHOTO_NAME_PREFIX));
        AttachmentDao.insertAttachment(photo);
      }
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '個人情報を保存しました。';
  }

  // パスワード変更(現在のパスワードを確認して新しいパスワードを設定する)
  // 成功時は完了メッセージ、現在のパスワードの不一致・ロック中は null を返す
  // (例外を投げると失敗回数の更新がロールバックされるため、ログインと同じく null で返す)
  @AuraEnabled
  public static String changePassword(String sessionKey, String currentPassword, String newPassword) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    PasswordResetController.validateNewPassword(newPassword);
    if (newPassword == currentPassword) {
      throw createException('現在のパスワードと異なるパスワードを入力してください。');
    }
    if (!LoginController.verifyPassword(contactId, currentPassword)) {
      return null;
    }
    LoginController.setPassword(contactId, newPassword);
    return 'パスワードを変更しました。';
  }

  // 上司の選択肢(管理職の社員。設定済みの上司が管理職でない場合も残す)
  private static List<Option> getSuperiorOptions(Contact con) {
    List<Option> options = new List<Option>();
    Boolean hasCurrent = false;
    for (Contact candidate : ContactDao.getSuperiorCandidateList(con.Id)) {
      String label = candidate.Name + (String.isBlank(candidate.EmployeeNo__c) ? '' : ' (' + candidate.EmployeeNo__c + ')');
      options.add(new Option(label, candidate.Id));
      hasCurrent = hasCurrent || candidate.Id == con.ReportsToId;
    }
    if (con.ReportsToId != null && !hasCurrent) {
      options.add(0, new Option(con.ReportsTo.Name, con.ReportsToId));
    }
    return options;
  }

  private static Boolean isSuperiorOption(Contact con, Id superiorId) {
    for (Option option : getSuperiorOptions(con)) {
      if (option.value == superiorId) {
        return true;
      }
    }
    return false;
  }

  private static Contact getContact(Id contactId) {
    List<Contact> contacts = ContactDao.getSettingListById(contactId);
    if (contacts.isEmpty()) {
      throw createException('社員情報が見つかりません。');
    }
    return contacts[0];
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
