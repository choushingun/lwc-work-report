/**
 * 機能名 : 勤務表作成画面(workReportCreateWork)のコントローラー
 *
 * 新規作成または既存勤務表の複製で勤務表を作成し、当月分の勤務実績を一括作成する。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class CreateWorkController {
  private static final String STATUS_DRAFT = 'ドラフト';
  // 曜日判定の基準日(日曜日)
  private static final Date BASE_SUNDAY = Date.newInstance(1900, 1, 7);
  private static final String GOOGLE_HOLIDAY_URL = 'https://www.googleapis.com/calendar/v3/calendars/ja.japanese%23holiday%40group.v.calendar.google.com/events';
  // 画面で入力できる項目(複製元から引き継ぐ項目)
  private static final List<String> INPUT_FIELDS = new List<String>{
    'StartHour__c',
    'StartTime__c',
    'EndHour__c',
    'EndTime__c',
    'LunchTime__c',
    'RestTime__c',
    'UndertimeWork__c',
    'OvertimeWork__c',
    'Workplace__c',
    'Approver__c',
    'ApproverMail__c',
    'ApproverCC__c',
    'ProjectName__c',
    'ProjectCode__c',
    'ProjectName2__c',
    'ProjectCode2__c',
    'ProjectName3__c',
    'ProjectCode3__c'
  };

  public class InitData {
    @AuraEnabled
    public MonthlyReport__c report;
    @AuraEnabled
    public List<Option> yearOptions;
    @AuraEnabled
    public Map<String, List<Option>> picklistOptions;
    // 勤務表自社送付先
    @AuraEnabled
    public String reportTo;
    @AuraEnabled
    public String reportToMail;
    // 上長
    @AuraEnabled
    public String superiorName;
  }

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

  // 初期表示データ取得(sourceIdを指定した場合は複製)
  @AuraEnabled
  public static InitData getInitData(String sessionKey, Id sourceId) {
    Id contactId = WorkReportSession.getContactId(sessionKey);
    Contact con = ContactDao.getWithAccountById(contactId);

    MonthlyReport__c report;
    if (sourceId != null) {
      report = copyInputFields(getSourceReport(sourceId, contactId));
    } else {
      // 項目の初期値を設定する
      report = (MonthlyReport__c) MonthlyReport__c.SObjectType.newSObject(null, true);
    }
    Date today = Date.today();
    report.Year__c = String.valueOf(today.year());
    report.Month__c = String.valueOf(today.month()).leftPad(2, '0');
    report.Status__c = STATUS_DRAFT;

    InitData data = new InitData();
    data.report = report;
    data.yearOptions = getYearOptions(today);
    data.picklistOptions = new Map<String, List<Option>>{
      'Month__c' => getPicklistOptions(MonthlyReport__c.Month__c),
      'StartHour__c' => getPicklistOptions(MonthlyReport__c.StartHour__c),
      'StartTime__c' => getPicklistOptions(MonthlyReport__c.StartTime__c),
      'EndHour__c' => getPicklistOptions(MonthlyReport__c.EndHour__c),
      'EndTime__c' => getPicklistOptions(MonthlyReport__c.EndTime__c),
      'LunchTime__c' => getPicklistOptions(MonthlyReport__c.LunchTime__c)
    };
    data.reportTo = con.Account?.ReportTo__c;
    data.reportToMail = con.Account?.ReportToMail__c;
    data.superiorName = con.ReportsTo?.Name;
    return data;
  }

  // 勤務表保存(勤務実績も一括作成し、作成した勤務表Idを返す)
  @AuraEnabled
  public static Id saveReport(String sessionKey, MonthlyReport__c input) {
    if (input == null || String.isBlank(input.Year__c) || String.isBlank(input.Month__c)) {
      throw createException('作業年月を選択してください。');
    }
    if (
      input.UndertimeWork__c != null &&
      input.OvertimeWork__c != null &&
      input.OvertimeWork__c < input.UndertimeWork__c
    ) {
      throw createException('本月標準時間の下限は上限を超えています。');
    }
    if (isOutOfRange(input.Year__c, input.Month__c)) {
      throw createException('先月以前来月以降の勤務表を作成することができません。');
    }
    // コールアウトはDMLより前に行う必要があるため、セッション認証(最終アクセス日時の更新)より先に祝日を取得する
    List<Holiday__c> newHolidays = fetchHolidaysIfMissing(Integer.valueOf(input.Year__c));

    Id contactId = WorkReportSession.getContactId(sessionKey);
    Integer duplicates = MonthlyReportDao.countByYearMonth(contactId, input.Year__c, input.Month__c);
    if (duplicates > 0) {
      throw createException('勤務表がすでに存在しています。');
    }

    Contact con = ContactDao.getWithAccountById(contactId);
    // 画面から受け取るのは入力項目のみとし、それ以外はサーバー側で設定する
    MonthlyReport__c report = copyInputFields(input);
    report.Year__c = input.Year__c;
    report.Month__c = input.Month__c;
    report.Contact__c = contactId;
    report.Status__c = STATUS_DRAFT;
    report.Superior__c = con.ReportsToId;
    Integer year = Integer.valueOf(report.Year__c);
    Integer month = Integer.valueOf(report.Month__c);
    // 提出日(月末)
    report.SubmitDate__c = Date.newInstance(year, month, 1).addMonths(1).addDays(-1);
    String contactName = removeSpace(con.Name);
    report.Name = String.format(
      '{0}{1}年{2}月勤務表',
      new List<String>{ contactName, report.Year__c, report.Month__c }
    );
    String accountName = String.isNotBlank(con.Account?.Abbreviation__c)
      ? con.Account.Abbreviation__c
      : con.Account?.Name;
    report.ReportFileName__c = String.format(
      '作業報告書_{0}年{1}月_{2}_{3}.xlsx',
      new List<String>{ report.Year__c, report.Month__c, removeSpace(accountName), contactName }
    );
    Datetime now = System.now();
    report.CreatedBy__c = contactId;
    report.Created__c = now;
    report.LastModifiedBy__c = contactId;
    report.LastModified__c = now;

    Savepoint sp = Database.setSavepoint();
    try {
      HolidayDao.insertHolidays(newHolidays);
      MonthlyReportDao.insertReport(report);
      WorkTimeDao.insertWorkTimes(createWorkTimes(report));
    } catch (DmlException e) {
      Database.rollback(sp);
      throw createException(e.getDmlMessage(0));
    }
    return report.Id;
  }

  // 複製元の勤務表取得(本人の勤務表のみ)
  private static MonthlyReport__c getSourceReport(Id sourceId, Id contactId) {
    List<MonthlyReport__c> reports = MonthlyReportDao.getFieldListById(sourceId, contactId, INPUT_FIELDS);
    if (reports.isEmpty()) {
      throw createException('複製元の勤務表が見つかりません。');
    }
    return reports[0];
  }

  private static MonthlyReport__c copyInputFields(MonthlyReport__c source) {
    MonthlyReport__c report = new MonthlyReport__c();
    Map<String, Object> values = source.getPopulatedFieldsAsMap();
    for (String field : INPUT_FIELDS) {
      if (values.containsKey(field)) {
        report.put(field, values.get(field));
      }
    }
    return report;
  }

  // 作業年の選択肢(1月15日の締め日前は前年も選択可能)
  private static List<Option> getYearOptions(Date today) {
    List<Option> options = new List<Option>();
    Integer thisYear = today.year();
    if (today.month() == 1 && today.day() < 15) {
      options.add(new Option(String.valueOf(thisYear - 1), String.valueOf(thisYear - 1)));
    }
    options.add(new Option(String.valueOf(thisYear), String.valueOf(thisYear)));
    options.add(new Option(String.valueOf(thisYear + 1), String.valueOf(thisYear + 1)));
    return options;
  }

  private static List<Option> getPicklistOptions(Schema.SObjectField field) {
    List<Option> options = new List<Option>();
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (entry.isActive()) {
        options.add(new Option(entry.getLabel(), entry.getValue()));
      }
    }
    return options;
  }

  // 先々月～再来月以外の勤務表は作成不可(1月15日以降は締め済みのため前年分も不可)
  @TestVisible
  private static Boolean isOutOfRange(String y, String m) {
    Date today = Date.today();
    Integer months = today.monthsBetween(Date.newInstance(Integer.valueOf(y), Integer.valueOf(m), 1));
    if (months >= 3 || months <= -3) {
      return true;
    }
    return today.month() == 1 && today.day() >= 15 && months <= -1;
  }

  // 祝日未登録の年はGoogle Calendar API v3から日本の祝日を取得する(取得失敗時は祝日なしで続行する)
  private static List<Holiday__c> fetchHolidaysIfMissing(Integer year) {
    List<Holiday__c> holidays = new List<Holiday__c>();
    Integer registered = HolidayDao.countByYear(year);
    if (registered > 0) {
      return holidays;
    }
    try {
      PageReference page = new PageReference(GOOGLE_HOLIDAY_URL);
      page.getParameters().put('key', Label.GoogleApiKey);
      page.getParameters().put('timeMin', year + '-01-01T00:00:00Z');
      page.getParameters().put('timeMax', year + '-12-31T23:59:59Z');
      page.getParameters().put('maxResults', '100');
      page.getParameters().put('orderBy', 'startTime');
      page.getParameters().put('singleEvents', 'true');
      HttpRequest req = new HttpRequest();
      req.setEndpoint(page.getUrl());
      req.setMethod('GET');
      HttpResponse res = new Http().send(req);
      if (res.getStatusCode() != 200) {
        return holidays;
      }
      Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
      for (Object item : (List<Object>) root.get('items')) {
        Map<String, Object> event = (Map<String, Object>) item;
        Map<String, Object> start = (Map<String, Object>) event.get('start');
        holidays.add(
          new Holiday__c(
            Date__c = Date.valueOf((String) start.get('date')),
            Description__c = (String) event.get('summary')
          )
        );
      }
    } catch (Exception e) {
      // 祝日が取得できなくても勤務表は作成する(土日のみ休みとなる)
      holidays.clear();
    }
    return holidays;
  }

  // 当月分の勤務実績作成(土日・祝日は休みとする)
  private static List<WorkTime__c> createWorkTimes(MonthlyReport__c report) {
    Integer year = Integer.valueOf(report.Year__c);
    Integer month = Integer.valueOf(report.Month__c);
    Date firstDay = Date.newInstance(year, month, 1);
    Date lastDay = firstDay.addMonths(1).addDays(-1);

    Map<Date, String> holidays = new Map<Date, String>();
    for (Holiday__c h : HolidayDao.getListByPeriod(firstDay, lastDay)) {
      holidays.put(h.Date__c, h.Description__c);
    }

    String projectName = String.isNotBlank(report.ProjectName__c) ? report.ProjectName__c.split(',')[0] : null;
    String workplace = String.isNotBlank(report.Workplace__c) ? report.Workplace__c.split(';')[0] : null;
    Boolean hasStart = report.StartHour__c != null && report.StartTime__c != null;
    Boolean hasEnd = report.EndHour__c != null && report.EndTime__c != null;

    List<WorkTime__c> works = new List<WorkTime__c>();
    for (Date day = firstDay; day <= lastDay; day = day.addDays(1)) {
      WorkTime__c work = new WorkTime__c(
        MonthlyReport__c = report.Id,
        WorkDay__c = day,
        ProjectName__c = projectName,
        Workplace__c = workplace,
        RestTime__c = report.RestTime__c,
        StartHour__c = hasStart ? report.StartHour__c : '09',
        StartTime__c = hasStart ? report.StartTime__c : '00',
        EndHour__c = hasEnd ? report.EndHour__c : '17',
        EndTime__c = hasEnd ? report.EndTime__c : '30'
      );

      if (holidays.containsKey(day)) {
        work.IsVacation__c = true;
        work.IsHoliday__c = true;
        work.Memo__c = holidays.get(day);
        work.ProjectName__c = null;
        work.Workplace__c = null;
      }

      // 0:日曜日、6:土曜日
      Integer dayOfWeek = Math.mod(BASE_SUNDAY.daysBetween(day), 7);
      if (dayOfWeek == 0 || dayOfWeek == 6) {
        work.StartHour__c = '00';
        work.StartTime__c = '00';
        work.EndHour__c = '00';
        work.EndTime__c = '00';
        work.RestTime__c = 0;
        work.IsVacation__c = true;
        work.IsHoliday__c = true;
        work.ProjectName__c = null;
        work.Workplace__c = null;
      }
      works.add(work);
    }
    return works;
  }

  // 全角半角スペース削除
  private static String removeSpace(String str) {
    return String.isBlank(str) ? str : str.replace(' ', '').replace('　', '');
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
