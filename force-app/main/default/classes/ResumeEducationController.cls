/**
 * 機能名 : 履歴書の語学資格画面(resumeEducation)のコントローラー
 *
 * ログイン社員の履歴情報(Resume__c)の語学能力(5件)と資格/トレーニング(5件)の参照・保存を行う。
 * 語学能力の読む・書く・会話は選択リスト(グローバル値セット SkillOption：◎・〇・△・×)。
 * 項目は「Language_Name1__c」のように末尾の番号(1～5)で行を表す。
 * 社員の履歴情報がない場合は、保存時に作成する。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ResumeEducationController {
  // 語学能力・資格/トレーニングの行数(項目の番号 1～ROW_COUNT)
  private static final Integer ROW_COUNT = 5;
  private static final Integer LANGUAGE_TEXT_MAX_LENGTH = 15;
  private static final Integer STUDY_YEARS_MAX = 99;
  private static final Integer SCORE_MAX = 9999;
  private static final Integer TRAINING_CONTENT_MAX_LENGTH = 30;
  private static final Integer TRAINING_MEMO_MAX_LENGTH = 25;

  // 語学能力の項目(番号を除いたAPI参照名)
  private static final List<String> LANGUAGE_FIELDS = new List<String>{
    'Language_Name',
    'Language_StudyMethod',
    'Language_StudyYears',
    'Language_Read',
    'Language_Write',
    'Language_Speak',
    'Language_Qualification',
    'Language_QualifiedDate',
    'Language_Score'
  };
  // 資格/トレーニングの項目(番号を除いたAPI参照名)
  private static final List<String> TRAINING_FIELDS = new List<String>{
    'Training_Date',
    'Training_Content',
    'Training_Memo'
  };

  // 語学資格(画面との受け渡し用)
  public class EducationData {
    @AuraEnabled
    public List<Language> languages { get; set; }
    @AuraEnabled
    public List<Training> trainings { get; set; }
    // 読む・書く・会話の選択肢(取得時のみ)
    @AuraEnabled
    public List<Option> levelOptions { get; set; }
  }

  // 語学能力(1行分。no は項目の番号)
  public class Language {
    @AuraEnabled
    public Integer no { get; set; }
    // 外国語類別
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String studyMethod { get; set; }
    // 通算年数
    @AuraEnabled
    public Integer studyYears { get; set; }
    @AuraEnabled
    public String read { get; set; }
    @AuraEnabled
    public String write { get; set; }
    @AuraEnabled
    public String speak { get; set; }
    // 資格名
    @AuraEnabled
    public String qualification { get; set; }
    // 資格獲得年月
    @AuraEnabled
    public Date qualifiedDate { get; set; }
    // 総点数
    @AuraEnabled
    public Integer score { get; set; }
  }

  // 資格/トレーニング(1行分。no は項目の番号)
  public class Training {
    @AuraEnabled
    public Integer no { get; set; }
    // 時間(取得・受講した日付)
    @AuraEnabled
    public Date trainingDate { get; set; }
    @AuraEnabled
    public String content { get; set; }
    @AuraEnabled
    public String memo { get; set; }
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

  // 語学資格取得(履歴情報がない場合はすべて未入力)
  @AuraEnabled
  public static EducationData getEducation(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<Resume__c> resumes = ResumeDao.getListByContact(contactId, getQueryFields());
    Resume__c resume = resumes.isEmpty() ? new Resume__c() : resumes[0];

    EducationData data = new EducationData();
    data.languages = new List<Language>();
    data.trainings = new List<Training>();
    for (Integer no = 1; no <= ROW_COUNT; no++) {
      Language language = new Language();
      language.no = no;
      language.name = (String) resume.get(field('Language_Name', no));
      language.studyMethod = (String) resume.get(field('Language_StudyMethod', no));
      language.studyYears = toInteger(resume.get(field('Language_StudyYears', no)));
      language.read = (String) resume.get(field('Language_Read', no));
      language.write = (String) resume.get(field('Language_Write', no));
      language.speak = (String) resume.get(field('Language_Speak', no));
      language.qualification = (String) resume.get(field('Language_Qualification', no));
      language.qualifiedDate = (Date) resume.get(field('Language_QualifiedDate', no));
      language.score = toInteger(resume.get(field('Language_Score', no)));
      data.languages.add(language);

      Training training = new Training();
      training.no = no;
      training.trainingDate = (Date) resume.get(field('Training_Date', no));
      training.content = (String) resume.get(field('Training_Content', no));
      training.memo = (String) resume.get(field('Training_Memo', no));
      data.trainings.add(training);
    }
    data.levelOptions = getLevelOptions();
    return data;
  }

  // 語学資格保存(画面から渡されない行は未入力にする)
  @AuraEnabled
  public static String saveEducation(String sessionKey, EducationData data) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    if (data == null) {
      throw createException('語学資格を入力してください。');
    }

    Set<String> levelValues = new Set<String>();
    for (Option option : getLevelOptions()) {
      levelValues.add(option.value);
    }
    Map<Integer, Language> languages = new Map<Integer, Language>();
    for (Language language : data.languages ?? new List<Language>()) {
      if (language?.no != null) {
        languages.put(language.no, language);
      }
    }
    Map<Integer, Training> trainings = new Map<Integer, Training>();
    for (Training training : data.trainings ?? new List<Training>()) {
      if (training?.no != null) {
        trainings.put(training.no, training);
      }
    }

    Resume__c resume = getOrNewResume(contactId);
    for (Integer no = 1; no <= ROW_COUNT; no++) {
      Language language = languages.get(no) ?? new Language();
      String label = '語学能力' + no + 'の';
      resume.put(
        field('Language_Name', no),
        optionalText(language.name, label + '外国語類別', LANGUAGE_TEXT_MAX_LENGTH)
      );
      resume.put(
        field('Language_StudyMethod', no),
        optionalText(language.studyMethod, label + '学習方法', LANGUAGE_TEXT_MAX_LENGTH)
      );
      resume.put(
        field('Language_StudyYears', no),
        optionalNumber(language.studyYears, label + '通算年数', STUDY_YEARS_MAX)
      );
      resume.put(field('Language_Read', no), optionalLevel(language.read, label + '読む', levelValues));
      resume.put(field('Language_Write', no), optionalLevel(language.write, label + '書く', levelValues));
      resume.put(field('Language_Speak', no), optionalLevel(language.speak, label + '会話', levelValues));
      resume.put(
        field('Language_Qualification', no),
        optionalText(language.qualification, label + '資格名', LANGUAGE_TEXT_MAX_LENGTH)
      );
      resume.put(field('Language_QualifiedDate', no), language.qualifiedDate);
      resume.put(field('Language_Score', no), optionalNumber(language.score, label + '総点数', SCORE_MAX));

      Training training = trainings.get(no) ?? new Training();
      label = '資格/トレーニング' + no + 'の';
      resume.put(field('Training_Date', no), training.trainingDate);
      resume.put(
        field('Training_Content', no),
        optionalText(training.content, label + '内容', TRAINING_CONTENT_MAX_LENGTH)
      );
      resume.put(field('Training_Memo', no), optionalText(training.memo, label + '備考', TRAINING_MEMO_MAX_LENGTH));
    }

    try {
      ResumeDao.upsertResume(resume);
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '語学資格を保存しました。';
  }

  // 番号付きの項目のAPI参照名(例：Language_Name + 1 → Language_Name1__c)
  private static String field(String baseName, Integer no) {
    return baseName + no + '__c';
  }

  // 数値項目の値を整数にする(未入力は null)
  private static Integer toInteger(Object value) {
    return value == null ? null : ((Decimal) value).intValue();
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

  // 任意の整数(0～最大値。範囲外はエラー)
  private static Integer optionalNumber(Integer value, String label, Integer maxValue) {
    if (value != null && (value < 0 || value > maxValue)) {
      throw createException(label + 'は0～' + maxValue + 'の整数で入力してください。');
    }
    return value;
  }

  // 任意の経験レベル(選択肢の値のみ。未選択は null)
  private static String optionalLevel(String value, String label, Set<String> levelValues) {
    if (String.isBlank(value)) {
      return null;
    }
    if (!levelValues.contains(value)) {
      throw createException(label + 'を選択し直してください。');
    }
    return value;
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

  // 取得する項目(語学能力・資格/トレーニングの全行の全項目)
  private static List<String> getQueryFields() {
    List<String> fields = new List<String>();
    for (Integer no = 1; no <= ROW_COUNT; no++) {
      for (String baseName : LANGUAGE_FIELDS) {
        fields.add(field(baseName, no));
      }
      for (String baseName : TRAINING_FIELDS) {
        fields.add(field(baseName, no));
      }
    }
    return fields;
  }

  // 読む・書く・会話の選択肢(グローバル値セット SkillOption の有効な値。全項目で共通)
  private static List<Option> getLevelOptions() {
    List<Option> options = new List<Option>();
    for (Schema.PicklistEntry entry : Resume__c.Language_Read1__c.getDescribe().getPicklistValues()) {
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
