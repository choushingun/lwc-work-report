/**
 * 機能名 : 履歴書の基本情報画面(resumeContactInfo)のコントローラー
 *
 * ログイン社員(Contact)の履歴書用の基本情報(氏名・フリガナ・性別・学歴・最寄駅など)の参照・保存を行う。
 * 卒業年月・来日年月は年月のみ入力し、テキスト項目に yyyyMM で保存する。
 * 保存時は履歴情報(Resume__c)も更新する(社員の履歴情報がない場合は作成する)。
 * 履歴書の出力時に、出力済みの履歴書が最新かを履歴情報の最終更新日時で判断するため。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ResumeContactInfoController {
  private static final Integer NAME_MAX_LENGTH = 40;
  private static final Integer TEXT_MAX_LENGTH = 30;
  // 年月の形式(yyyyMM)
  private static final Pattern YEAR_MONTH_PATTERN = Pattern.compile('^[0-9]{4}(0[1-9]|1[0-2])$');

  // 基本情報(画面との受け渡し用。年齢・実務年数は数式項目のため参照のみ)
  public class ContactInfo {
    @AuraEnabled
    public String shimei { get; set; }
    @AuraEnabled
    public String furigana { get; set; }
    @AuraEnabled
    public String gender { get; set; }
    @AuraEnabled
    public String graduatedSchool { get; set; }
    @AuraEnabled
    public String academicBackground { get; set; }
    @AuraEnabled
    public String major { get; set; }
    @AuraEnabled
    public String graduateYearMonth { get; set; }
    @AuraEnabled
    public String comingJapanYearMonth { get; set; }
    @AuraEnabled
    public Date birthdate { get; set; }
    @AuraEnabled
    public Integer age { get; set; }
    @AuraEnabled
    public Integer experiences { get; set; }
    // 最寄駅の路線名・駅名(「線」「駅」は付けない)
    @AuraEnabled
    public String nearestLine { get; set; }
    @AuraEnabled
    public String nearestStation { get; set; }
    // 性別・最終学歴の選択肢(選択リスト項目の値)
    @AuraEnabled
    public List<Option> genderOptions { get; set; }
    @AuraEnabled
    public List<Option> academicBackgroundOptions { get; set; }
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

  // 基本情報取得
  @AuraEnabled
  public static ContactInfo getContactInfo(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Contact con = getContact(contactId);
    ContactInfo info = new ContactInfo();
    info.shimei = con.Shimei__c;
    info.furigana = con.Furigana__c;
    info.gender = con.Gender__c;
    info.graduatedSchool = con.GraduatedSchool__c;
    info.academicBackground = con.AcademicBackground__c;
    info.major = con.Major__c;
    info.graduateYearMonth = con.GraduateYearMonth__c;
    info.comingJapanYearMonth = con.ComingJapanYearMonth__c;
    info.birthdate = con.Birthdate;
    // 誕生日・卒業年月が未入力の場合は表示しない
    info.age = con.Birthdate == null ? null : con.Age__c?.intValue();
    info.experiences = con.GraduateYearMonth__c == null ? null : con.Experiences__c?.intValue();
    info.nearestLine = con.NearestLine__c;
    info.nearestStation = con.NearestStation__c;
    info.genderOptions = getOptions(Contact.Gender__c);
    info.academicBackgroundOptions = getOptions(Contact.AcademicBackground__c);
    return info;
  }

  // 基本情報保存
  @AuraEnabled
  public static String saveContactInfo(String sessionKey, ContactInfo info) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Contact con = getContact(contactId);
    if (info == null) {
      throw createException('基本情報を入力してください。');
    }
    String shimei = requireText(info.shimei, '氏名', NAME_MAX_LENGTH);
    String furigana = requireText(info.furigana, 'フリガナ', NAME_MAX_LENGTH);
    String graduatedSchool = optionalText(info.graduatedSchool, '出身', TEXT_MAX_LENGTH);
    String major = optionalText(info.major, '専攻', TEXT_MAX_LENGTH);
    String nearestLine = removeSuffix(optionalText(info.nearestLine, '最寄駅の路線', TEXT_MAX_LENGTH), '線');
    String nearestStation = removeSuffix(optionalText(info.nearestStation, '最寄駅', TEXT_MAX_LENGTH), '駅');
    String gender = optionalOption(info.gender, '性別', Contact.Gender__c);
    String academicBackground = optionalOption(info.academicBackground, '最終学歴', Contact.AcademicBackground__c);
    String graduateYearMonth = optionalYearMonth(info.graduateYearMonth, '卒業年月');
    String comingJapanYearMonth = optionalYearMonth(info.comingJapanYearMonth, '来日年月');
    if (info.birthdate != null && info.birthdate > Date.today()) {
      throw createException('誕生日は今日以前の日付を入力してください。');
    }

    List<Resume__c> resumes = ResumeDao.getListByContact(contactId);
    Resume__c resume = resumes.isEmpty() ? new Resume__c(Contact__c = contactId, Name = con.Name) : resumes[0];
    try {
      ContactDao.updateContact(
        new Contact(
          Id = contactId,
          Shimei__c = shimei,
          Furigana__c = furigana,
          Gender__c = gender,
          GraduatedSchool__c = graduatedSchool,
          AcademicBackground__c = academicBackground,
          Major__c = major,
          GraduateYearMonth__c = graduateYearMonth,
          ComingJapanYearMonth__c = comingJapanYearMonth,
          Birthdate = info.birthdate,
          NearestLine__c = nearestLine,
          NearestStation__c = nearestStation
        )
      );
      // 出力済みの履歴書が最新かを判断できるよう、履歴情報も更新する
      ResumeDao.upsertResume(resume);
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '基本情報を保存しました。';
  }

  // 必須の文字列(前後の空白を除いて、未入力・文字数超過はエラー)
  private static String requireText(String value, String label, Integer maxLength) {
    String text = optionalText(value, label, maxLength);
    if (text == null) {
      throw createException(label + 'を入力してください。');
    }
    return text;
  }

  // 任意の文字列(前後の空白を除いて、未入力は null。文字数超過はエラー)
  private static String optionalText(String value, String label, Integer maxLength) {
    String text = value?.trim();
    if (String.isBlank(text)) {
      return null;
    }
    if (text.length() > maxLength) {
      throw createException(label + 'は' + maxLength + '文字以内で入力してください。');
    }
    return text;
  }

  // 任意の年月(yyyyMM。未入力は null。形式が違う場合はエラー)
  private static String optionalYearMonth(String value, String label) {
    String text = value?.trim();
    if (String.isBlank(text)) {
      return null;
    }
    if (!YEAR_MONTH_PATTERN.matcher(text).matches()) {
      throw createException(label + 'を選択し直してください。');
    }
    return text;
  }

  // 末尾の「線」「駅」を除く(画面で入力欄の後ろに表示するため、二重にならないようにする)
  private static String removeSuffix(String value, String suffix) {
    if (value == null || !value.endsWith(suffix) || value.length() == suffix.length()) {
      return value;
    }
    return value.removeEnd(suffix).trim();
  }

  // 任意の選択値(選択リスト項目の有効な値のみ。未選択は null)
  private static String optionalOption(String value, String label, SObjectField field) {
    if (String.isBlank(value)) {
      return null;
    }
    for (Option option : getOptions(field)) {
      if (option.value == value) {
        return value;
      }
    }
    throw createException(label + 'を選択し直してください。');
  }

  // 選択リスト項目の有効な値
  private static List<Option> getOptions(SObjectField field) {
    List<Option> options = new List<Option>();
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (entry.isActive()) {
        options.add(new Option(entry.getLabel(), entry.getValue()));
      }
    }
    return options;
  }

  private static Contact getContact(Id contactId) {
    List<Contact> contacts = ContactDao.getResumeInfoListById(contactId);
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
