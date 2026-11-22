/**
 * 機能名 : 履歴書の仕事経験画面(resumeProject)のコントローラー
 *
 * ログイン社員の履歴情報(Resume__c)の仕事経験(管理経験・作業経験・得意業務・得意技術)の参照・保存を行う。
 * 管理経験は人数の区分ごとに「管理」(文字列)と「期間(月)」(数値)を持つ(履歴書テンプレートの管理経験欄と同じ)。
 * 社員の履歴情報がない場合は、保存時に作成する。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ResumeProjectController {
  private static final Integer MANAGE_MAX_LENGTH = 10;
  // 期間(月)は数値(3桁)
  private static final Integer MONTHS_MAX = 999;
  private static final Integer ENJOYING_MAX_LENGTH = 255;

  // 管理経験の人数の区分(区分キー・表示名・管理の項目・期間(月)の項目。画面の表示順)
  private static final List<ManagementRow> MANAGEMENT_ROWS = new List<ManagementRow>{
    new ManagementRow('lessThanFive', '5人以下', 'Management_Lessthan_Five_M__c', 'Management_Lessthan_Five__c'),
    new ManagementRow('sixToTen', '6～10人', 'Management_Six_To_Ten_M__c', 'Management_Six_To_Ten__c'),
    new ManagementRow(
      'elevenToFifteen',
      '11～15人',
      'Management_Eleven_To_Fifteen_M__c',
      'Management_Eleven_To_Fifteen__c'
    ),
    new ManagementRow('aboveSixteen', '16人以上', 'Management_Above_Sixteen_M__c', 'Management_Above_Sixteen__c')
  };

  // 仕事経験(画面との受け渡し用)
  public class ProjectData {
    @AuraEnabled
    public List<Management> managements { get; set; }
    // 作業経験(複数選択リストの選択値)
    @AuraEnabled
    public List<String> workExperiences { get; set; }
    @AuraEnabled
    public String enjoyingBusiness { get; set; }
    @AuraEnabled
    public String enjoyingSkills { get; set; }
    // 作業経験の選択肢(取得時のみ)
    @AuraEnabled
    public List<Option> workExperienceOptions { get; set; }
  }

  // 管理経験(人数の区分ごと。key は区分キー、label は人数の表示名)
  public class Management {
    @AuraEnabled
    public String key { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String manage { get; set; }
    @AuraEnabled
    public Integer months { get; set; }
  }

  // 選択肢(画面のチェックボックスグループ用)
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

  // 管理経験の人数の区分の定義
  private class ManagementRow {
    String key;
    String label;
    String manageField;
    String monthsField;

    ManagementRow(String key, String label, String manageField, String monthsField) {
      this.key = key;
      this.label = label;
      this.manageField = manageField;
      this.monthsField = monthsField;
    }
  }

  // 仕事経験取得(履歴情報がない場合はすべて未入力)
  @AuraEnabled
  public static ProjectData getProject(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<Resume__c> resumes = ResumeDao.getListByContact(contactId, getQueryFields());
    Resume__c resume = resumes.isEmpty() ? new Resume__c() : resumes[0];

    ProjectData data = new ProjectData();
    data.managements = new List<Management>();
    for (ManagementRow row : MANAGEMENT_ROWS) {
      Management management = new Management();
      management.key = row.key;
      management.label = row.label;
      management.manage = (String) resume.get(row.manageField);
      Decimal months = (Decimal) resume.get(row.monthsField);
      management.months = months?.intValue();
      data.managements.add(management);
    }
    data.workExperiences = String.isBlank(resume.WorkExperience__c)
      ? new List<String>()
      : resume.WorkExperience__c.split(';');
    data.enjoyingBusiness = resume.EnjoyingBusiness__c;
    data.enjoyingSkills = resume.EnjoyingSkills__c;
    data.workExperienceOptions = getWorkExperienceOptions();
    return data;
  }

  // 仕事経験保存
  @AuraEnabled
  public static String saveProject(String sessionKey, ProjectData data) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    if (data == null) {
      throw createException('仕事経験を入力してください。');
    }

    Resume__c resume = getOrNewResume(contactId);
    // 管理経験(画面から渡されない区分は未入力にする)
    Map<String, Management> managements = new Map<String, Management>();
    for (Management management : data.managements ?? new List<Management>()) {
      if (management?.key != null) {
        managements.put(management.key, management);
      }
    }
    for (ManagementRow row : MANAGEMENT_ROWS) {
      Management management = managements.get(row.key) ?? new Management();
      String label = '管理経験(' + row.label + ')';
      resume.put(row.manageField, optionalText(management.manage, label + 'の管理', MANAGE_MAX_LENGTH));
      if (management.months != null && (management.months < 0 || management.months > MONTHS_MAX)) {
        throw createException(label + 'の期間(月)は0～' + MONTHS_MAX + 'の整数で入力してください。');
      }
      resume.put(row.monthsField, management.months);
    }
    resume.WorkExperience__c = getWorkExperienceValue(data.workExperiences);
    resume.EnjoyingBusiness__c = optionalText(data.enjoyingBusiness, '得意業務', ENJOYING_MAX_LENGTH);
    resume.EnjoyingSkills__c = optionalText(data.enjoyingSkills, '得意技術', ENJOYING_MAX_LENGTH);

    try {
      ResumeDao.upsertResume(resume);
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '仕事経験を保存しました。';
  }

  // 作業経験の保存値(選択肢の順に「;」でつなぐ。選択肢にない値はエラー、未選択は null)
  private static String getWorkExperienceValue(List<String> values) {
    Set<String> selected = new Set<String>(values ?? new List<String>());
    selected.remove(null);
    selected.remove('');
    List<String> result = new List<String>();
    for (Option option : getWorkExperienceOptions()) {
      if (selected.remove(option.value)) {
        result.add(option.value);
      }
    }
    if (!selected.isEmpty()) {
      throw createException('作業経験を選択し直してください。');
    }
    return result.isEmpty() ? null : String.join(result, ';');
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

  // 社員の履歴情報(ない場合は社員名で新しく作る)
  private static Resume__c getOrNewResume(Id contactId) {
    List<Resume__c> resumes = ResumeDao.getListByContact(contactId);
    if (!resumes.isEmpty()) {
      return resumes[0];
    }
    List<Contact> contacts = ContactDao.getHeaderListById(contactId);
    if (contacts.isEmpty()) {
      throw createException('社員情報が見つかりません。');
    }
    return new Resume__c(Contact__c = contactId, Name = contacts[0].Name);
  }

  // 取得する項目(管理経験の全項目・作業経験・得意業務・得意技術)
  private static List<String> getQueryFields() {
    List<String> fields = new List<String>();
    for (ManagementRow row : MANAGEMENT_ROWS) {
      fields.add(row.manageField);
      fields.add(row.monthsField);
    }
    fields.addAll(new List<String>{ 'WorkExperience__c', 'EnjoyingBusiness__c', 'EnjoyingSkills__c' });
    return fields;
  }

  // 作業経験の選択肢(複数選択リストの有効な値)
  private static List<Option> getWorkExperienceOptions() {
    List<Option> options = new List<Option>();
    for (Schema.PicklistEntry entry : Resume__c.WorkExperience__c.getDescribe().getPicklistValues()) {
      if (entry.isActive()) {
        options.add(new Option(entry.getLabel(), entry.getValue()));
      }
    }
    return options;
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
