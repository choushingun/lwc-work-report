/**
 * 機能名 : 履歴書の技術経験画面(resumeSkill)のコントローラー
 *
 * ログイン社員の履歴情報(Resume__c)の技術経験(OS・開発言語・DBなどの経験レベル)と備考の参照・保存を行う。
 * 経験レベルは選択リスト(グローバル値セット SkillOption：◎・〇・△・×)で、画面の分類と項目はこのクラスで定義する。
 * 社員の履歴情報がない場合は、保存時に作成する。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ResumeSkillController {
  private static final String COMMENT_FIELD = 'Comment__c';
  private static final Integer COMMENT_MAX_LENGTH = 255;

  // 技術経験の分類と項目(分類名 → 項目のAPI参照名と表示名。画面の表示順)
  private static final List<SkillSection> SKILL_SECTIONS = new List<SkillSection>{
    new SkillSection(
      'OS',
      new List<String>{
        'OS_Dos__c', 'DOS',
        'OS_Windows__c', 'Windows',
        'OS_Windows2K_XP__c', 'Windows2K/XP',
        'OS_Unix__c', 'Unix',
        'OS_Linux__c', 'Linux',
        'OS_EJB__c', 'EJB'
      }
    ),
    new SkillSection(
      '開発言語',
      new List<String>{
        'LAN_Java__c', 'Java',
        'LAN_Java_Servlet__c', 'Java Servlet',
        'LAN_Jsp__c', 'JSP',
        'LAN_Javascript__c', 'JavaScript',
        'LAN_ActionScript__c', 'ActionScript',
        'LAN_Python__c', 'Python',
        'LAN_Asp__c', 'ASP',
        'LAN_Asp_net__c', 'ASP.NET',
        'LAN_Html__c', 'HTML',
        'LAN_Xml__c', 'XML',
        'LAN_Php__c', 'PHP',
        'LAN_VB_VBA__c', 'VB/VBA',
        'LAN_VBScript__c', 'VBScript',
        'LAN_VB_NET__c', 'VB.NET',
        'LAN_CSharp__c', 'C#',
        'LAN_Perl__c', 'Perl',
        'LAN_C__c', 'C',
        'LAN_Cpp__c', 'C++',
        'LAN_VCpp__c', 'VC++',
        'LAN_COBOL__c', 'COBOL',
        'LAN_AJAX__c', 'AJAX',
        'LAN_PL_SQL__c', 'PL/SQL',
        'LAN_PowerBuilder__c', 'PowerBuilder',
        'LAN_Ruby__c', 'Ruby',
        'LAN_CSS__c', 'CSS'
      }
    ),
    new SkillSection(
      'DB',
      new List<String>{
        'DB_Oracle__c', 'Oracle',
        'DB_SQLServer__c', 'SQL Server',
        'DB_DB2__c', 'DB2',
        'DB_MySql__c', 'MySQL',
        'DB_Access__c', 'Access'
      }
    ),
    new SkillSection(
      'WEBサーバー',
      new List<String>{
        'WEB_Weblogic__c', 'WebLogic',
        'WEB_Apache__c', 'Apache',
        'WEB_IIS__c', 'IIS',
        'WEB_LotusNotes__c', 'Lotus Notes',
        'WEB_Websphere__c', 'WebSphere'
      }
    ),
    new SkillSection(
      'フレームワーク',
      new List<String>{
        'FRAME_Struts__c', 'Struts',
        'FRAME_WebWork__c', 'WebWork',
        'FRAME_Spring__c', 'Spring',
        'FRAME_Hibernate__c', 'Hibernate',
        'FRAME_Flex__c', 'Flex',
        'FRAME_Swing__c', 'Swing',
        'FRAME_JSF__c', 'JSF'
      }
    ),
    new SkillSection(
      'CRM',
      new List<String>{
        'CRM_Siebel__c', 'Siebel',
        'CRM_SAP__c', 'SAP',
        'CRM_SFDC__c', 'SFDC',
        'CRM_SFDC_Lightning__c', 'SFDC Lightning'
      }
    ),
    new SkillSection(
      'その他',
      new List<String>{
        'OTHER_NET_IDE__c', '.NET IDE',
        'OTHER_Ultra_Edit__c', 'UltraEdit',
        'OTHER_Object_Browser__c', 'Object Browser',
        'OTHER_PL_SQL_Developer__c', 'PL/SQL Developer',
        'OTHER_EBS__c', 'EBS',
        'OTHER_Eclipse__c', 'Eclipse',
        'OTHER_Sublime_Text__c', 'Sublime Text'
      }
    )
  };

  // 技術経験(画面との受け渡し用)
  public class SkillData {
    @AuraEnabled
    public List<Section> sections;
    // 経験レベルの選択肢(◎・〇・△・×)
    @AuraEnabled
    public List<Option> options;
    @AuraEnabled
    public String comment;
  }

  // 技術経験の分類(画面表示用)
  public class Section {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public List<Item> items = new List<Item>();
  }

  // 技術経験の項目(画面表示用。value は経験レベル、未選択は null)
  public class Item {
    @AuraEnabled
    public String field;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
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

  // 技術経験の分類の定義(fieldLabels は 項目のAPI参照名・表示名 を交互に並べる)
  private class SkillSection {
    String label;
    List<String> fields = new List<String>();
    Map<String, String> fieldLabels = new Map<String, String>();

    SkillSection(String label, List<String> fieldLabels) {
      this.label = label;
      for (Integer i = 0; i < fieldLabels.size(); i += 2) {
        this.fields.add(fieldLabels[i]);
        this.fieldLabels.put(fieldLabels[i], fieldLabels[i + 1]);
      }
    }
  }

  // 技術経験取得(履歴情報がない場合はすべて未選択)
  @AuraEnabled
  public static SkillData getSkill(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<Resume__c> resumes = ResumeDao.getListByContact(contactId, getQueryFields());
    Resume__c resume = resumes.isEmpty() ? new Resume__c() : resumes[0];

    SkillData data = new SkillData();
    data.sections = new List<Section>();
    for (SkillSection skillSection : SKILL_SECTIONS) {
      Section section = new Section();
      section.label = skillSection.label;
      for (String field : skillSection.fields) {
        Item item = new Item();
        item.field = field;
        item.label = skillSection.fieldLabels.get(field);
        item.value = (String) resume.get(field);
        section.items.add(item);
      }
      data.sections.add(section);
    }
    data.options = getOptions();
    data.comment = resume.Comment__c;
    return data;
  }

  // 技術経験保存
  // skills : 項目のAPI参照名 → 経験レベル(未選択は null または空文字)
  @AuraEnabled
  public static String saveSkill(String sessionKey, Map<String, String> skills, String comment) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    comment = comment?.trim();
    if (String.isNotBlank(comment) && comment.length() > COMMENT_MAX_LENGTH) {
      throw createException('備考は' + COMMENT_MAX_LENGTH + '文字以内で入力してください。');
    }

    Set<String> optionValues = new Set<String>();
    for (Option option : getOptions()) {
      optionValues.add(option.value);
    }
    Resume__c resume = getOrNewResume(contactId);
    // 定義した項目のみ更新する(画面から渡されない項目は未選択にする)
    Map<String, String> values = skills ?? new Map<String, String>();
    for (SkillSection skillSection : SKILL_SECTIONS) {
      for (String field : skillSection.fields) {
        String value = values.get(field);
        if (String.isBlank(value)) {
          value = null;
        } else if (!optionValues.contains(value)) {
          throw createException(skillSection.fieldLabels.get(field) + 'の経験を選択し直してください。');
        }
        resume.put(field, value);
      }
    }
    resume.Comment__c = String.isBlank(comment) ? null : comment;

    try {
      ResumeDao.upsertResume(resume);
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '技術経験を保存しました。';
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

  // 取得する項目(技術経験の全項目と備考)
  private static List<String> getQueryFields() {
    List<String> fields = new List<String>();
    for (SkillSection skillSection : SKILL_SECTIONS) {
      fields.addAll(skillSection.fields);
    }
    fields.add(COMMENT_FIELD);
    return fields;
  }

  // 経験レベルの選択肢(グローバル値セット SkillOption の有効な値。全項目で共通)
  private static List<Option> getOptions() {
    List<Option> options = new List<Option>();
    for (Schema.PicklistEntry entry : Resume__c.OS_Dos__c.getDescribe().getPicklistValues()) {
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
