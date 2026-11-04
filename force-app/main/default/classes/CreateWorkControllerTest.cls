@IsTest
private class CreateWorkControllerTest {
  private static final String LOGIN_EMAIL = 'creatework.test@example.com';
  private static final String PASSWORD = 'correct-password';

  private class HolidayApiMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    HolidayApiMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      Assert.isTrue(req.getEndpoint().startsWith('https://www.googleapis.com/calendar/v3/calendars/'));
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setBody(body);
      return res;
    }
  }

  @TestSetup
  static void setup() {
    Account acc = new Account(
      Name = 'テスト 会社',
      Abbreviation__c = 'テスト',
      ReportTo__c = '経理',
      ReportToMail__c = 'keiri@example.com'
    );
    insert as system acc;
    Contact boss = new Contact(LastName = 'Boss', AccountId = acc.Id);
    insert as system boss;
    Contact con = new Contact(LastName = 'Create Work', Email = LOGIN_EMAIL, AccountId = acc.Id, ReportsToId = boss.Id);
    insert as system con;
    LoginController.setPassword(con.Id, PASSWORD);
  }

  private static Id getContactId() {
    return [SELECT Id FROM Contact WHERE Email = :LOGIN_EMAIL WITH SYSTEM_MODE].Id;
  }

  private static MonthlyReport__c buildInput(Date dt) {
    return new MonthlyReport__c(
      Year__c = String.valueOf(dt.year()),
      Month__c = String.valueOf(dt.month()).leftPad(2, '0'),
      StartHour__c = '09',
      StartTime__c = '00',
      EndHour__c = '18',
      EndTime__c = '00',
      LunchTime__c = '12:00',
      RestTime__c = 60,
      UndertimeWork__c = 140,
      OvertimeWork__c = 180,
      Workplace__c = '自宅作業;勝どき',
      ProjectName__c = 'PJ1'
    );
  }

  @IsTest
  static void getInitData_new_returnsDefaults() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);

    CreateWorkController.InitData data = CreateWorkController.getInitData(sessionKey, null);

    Assert.areEqual(String.valueOf(Date.today().year()), data.report.Year__c);
    Assert.areEqual(60, data.report.RestTime__c);
    Assert.areEqual('Boss', data.superiorName);
    Assert.areEqual('経理', data.reportTo);
    Assert.isFalse(data.yearOptions.isEmpty());
    Assert.areEqual(12, data.picklistOptions.get('Month__c').size());
  }

  @IsTest
  static void getInitData_copy_copiesInputFields() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c source = buildInput(Date.today().addMonths(-1));
    source.Contact__c = getContactId();
    source.Status__c = '承認済';
    source.Approver__c = '承認者';
    insert as system source;

    CreateWorkController.InitData data = CreateWorkController.getInitData(sessionKey, source.Id);

    Assert.isNull(data.report.Id);
    Assert.areEqual('承認者', data.report.Approver__c);
    Assert.areEqual('ドラフト', data.report.Status__c);
    Assert.areEqual(String.valueOf(Date.today().month()).leftPad(2, '0'), data.report.Month__c);
  }

  @IsTest
  static void getInitData_otherContactReport_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    Contact other = new Contact(LastName = 'Other');
    insert as system other;
    MonthlyReport__c source = buildInput(Date.today());
    source.Contact__c = other.Id;
    insert as system source;

    try {
      CreateWorkController.getInitData(sessionKey, source.Id);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('複製元の勤務表が見つかりません。', e.getMessage());
    }
  }

  @IsTest
  static void getInitData_invalidSession_throws() {
    try {
      CreateWorkController.getInitData('invalid', null);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual(WorkReportSession.SESSION_INVALID, e.getMessage());
    }
  }

  @IsTest
  static void saveReport_success_createsReportAndWorktimes() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    Date today = Date.today();
    Date firstDay = today.toStartOfMonth();
    insert as system new Holiday__c(Date__c = firstDay.addDays(2), Description__c = 'テスト祝日');
    MonthlyReport__c input = buildInput(today);
    input.Status__c = '承認済';

    Id reportId = CreateWorkController.saveReport(sessionKey, input);

    MonthlyReport__c report = [
      SELECT Name, Contact__c, Status__c, Superior__c, SubmitDate__c, ReportFileName__c, CreatedBy__c
      FROM MonthlyReport__c
      WHERE Id = :reportId
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(getContactId(), report.Contact__c);
    Assert.areEqual(getContactId(), report.CreatedBy__c);
    Assert.areEqual('ドラフト', report.Status__c);
    Assert.isNotNull(report.Superior__c);
    Assert.areEqual(firstDay.addMonths(1).addDays(-1), report.SubmitDate__c);
    Assert.isTrue(report.Name.startsWith('CreateWork'));
    Assert.isTrue(report.ReportFileName__c.contains('_テスト_'));

    List<WorkTime__c> works = [
      SELECT WorkDay__c, IsHoliday__c, Memo__c, ProjectName__c, Workplace__c
      FROM WorkTime__c
      WHERE MonthlyReport__c = :reportId
      WITH SYSTEM_MODE
      ORDER BY WorkDay__c
    ];
    Assert.areEqual(Date.daysInMonth(today.year(), today.month()), works.size());
    WorkTime__c holiday = works[2];
    Assert.isTrue(holiday.IsHoliday__c);
    Assert.areEqual('テスト祝日', holiday.Memo__c);
    Date baseSunday = Date.newInstance(1900, 1, 7);
    for (WorkTime__c w : works) {
      Integer dayOfWeek = Math.mod(baseSunday.daysBetween(w.WorkDay__c), 7);
      if (dayOfWeek == 0 || dayOfWeek == 6) {
        Assert.isTrue(w.IsHoliday__c);
      } else if (w.WorkDay__c != holiday.WorkDay__c) {
        Assert.isFalse(w.IsHoliday__c);
        Assert.areEqual('PJ1', w.ProjectName__c);
        Assert.areEqual('自宅作業', w.Workplace__c);
      }
    }
  }

  @IsTest
  static void saveReport_noHolidays_fetchesFromGoogle() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    Date today = Date.today();
    Date holidayDate = today.toStartOfMonth().addDays(2);
    String body = JSON.serialize(
      new Map<String, Object>{
        'items' => new List<Object>{
          new Map<String, Object>{
            'summary' => 'Google祝日',
            'start' => new Map<String, Object>{ 'date' => String.valueOf(holidayDate) }
          }
        }
      }
    );
    Test.setMock(HttpCalloutMock.class, new HolidayApiMock(200, body));

    Test.startTest();
    Id reportId = CreateWorkController.saveReport(sessionKey, buildInput(today));
    Test.stopTest();

    List<Holiday__c> holidays = [SELECT Date__c, Description__c FROM Holiday__c WITH SYSTEM_MODE];
    Assert.areEqual(1, holidays.size());
    Assert.areEqual(holidayDate, holidays[0].Date__c);
    WorkTime__c work = [
      SELECT IsHoliday__c, Memo__c
      FROM WorkTime__c
      WHERE MonthlyReport__c = :reportId AND WorkDay__c = :holidayDate
      WITH SYSTEM_MODE
    ];
    Assert.isTrue(work.IsHoliday__c);
    Assert.areEqual('Google祝日', work.Memo__c);
  }

  @IsTest
  static void saveReport_googleError_createsReportWithoutHolidays() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    Test.setMock(HttpCalloutMock.class, new HolidayApiMock(403, '{"error":{}}'));

    Test.startTest();
    Id reportId = CreateWorkController.saveReport(sessionKey, buildInput(Date.today()));
    Test.stopTest();

    Assert.isNotNull(reportId);
    Assert.areEqual(0, [SELECT COUNT() FROM Holiday__c WITH SYSTEM_MODE]);
  }

  @IsTest
  static void saveReport_duplicate_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    CreateWorkController.saveReport(sessionKey, buildInput(Date.today()));

    try {
      CreateWorkController.saveReport(sessionKey, buildInput(Date.today()));
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('勤務表がすでに存在しています。', e.getMessage());
    }
  }

  @IsTest
  static void saveReport_invalidStandardTime_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c input = buildInput(Date.today());
    input.UndertimeWork__c = 200;

    try {
      CreateWorkController.saveReport(sessionKey, input);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('本月標準時間の下限は上限を超えています。', e.getMessage());
    }
  }

  @IsTest
  static void saveReport_outOfRange_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);

    try {
      CreateWorkController.saveReport(sessionKey, buildInput(Date.today().addMonths(3)));
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('先月以前来月以降の勤務表を作成することができません。', e.getMessage());
    }
  }

  @IsTest
  static void saveReport_noYearMonth_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c input = buildInput(Date.today());
    input.Month__c = null;

    try {
      CreateWorkController.saveReport(sessionKey, input);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('作業年月を選択してください。', e.getMessage());
    }
  }

  @IsTest
  static void saveReport_dmlError_rollsBack() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c input = buildInput(Date.today());
    // 15分単位でないため入力規則エラー
    input.RestTime__c = 10;

    try {
      CreateWorkController.saveReport(sessionKey, input);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('15分単位で入力してください。', e.getMessage());
    }
    Assert.areEqual(0, [SELECT COUNT() FROM MonthlyReport__c WITH SYSTEM_MODE]);
  }
}
