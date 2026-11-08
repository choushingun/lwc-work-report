@IsTest
private class MonthReportControllerTest {
  private static final String LOGIN_EMAIL = 'monthreport.test@example.com';
  private static final String OTHER_EMAIL = 'monthreport.other@example.com';
  private static final String PASSWORD = 'correct-password';

  @TestSetup
  static void setup() {
    Contact con = new Contact(LastName = 'MonthReportTest', Email = LOGIN_EMAIL);
    Contact other = new Contact(LastName = 'MonthReportOther', Email = OTHER_EMAIL);
    insert as system new List<Contact>{ con, other };
    LoginController.setPassword(con.Id, PASSWORD);
  }

  private static Id getContactId(String email) {
    return [SELECT Id FROM Contact WHERE Email = :email WITH SYSTEM_MODE].Id;
  }

  private static MonthlyReport__c createReport(Id contactId, Date dt, String status) {
    MonthlyReport__c report = new MonthlyReport__c(
      Contact__c = contactId,
      Year__c = String.valueOf(dt.year()),
      Month__c = String.valueOf(dt.month()).leftPad(2, '0'),
      Status__c = status,
      StartHour__c = '09',
      StartTime__c = '00',
      EndHour__c = '18',
      EndTime__c = '00',
      LunchTime__c = '12:00',
      RestTime__c = 60,
      OvertimeWork__c = 180,
      UndertimeWork__c = 140,
      ProjectName__c = 'プロジェクトA',
      ProjectCode__c = 'P001'
    );
    insert as system report;
    return report;
  }

  private static WorkTime__c newWorktime(Id reportId, Date day, Boolean isSubmit, String memo) {
    return new WorkTime__c(
      MonthlyReport__c = reportId,
      WorkDay__c = day,
      StartHour__c = '09',
      StartTime__c = '00',
      EndHour__c = '18',
      EndTime__c = '00',
      IsSubmit__c = isSubmit,
      Memo__c = memo
    );
  }

  @IsTest
  static void getReport_returnsCompanyWorktimesWithCustomerMemo() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(getContactId(LOGIN_EMAIL), Date.today(), 'ドラフト');
    Date day1 = Date.today().toStartOfMonth();
    insert as system new List<WorkTime__c>{
      newWorktime(report.Id, day1, false, '作業'),
      newWorktime(report.Id, day1, true, '客先作業'),
      newWorktime(report.Id, day1.addDays(1), false, null)
    };

    MonthReportController.ReportData data = MonthReportController.getReport(sessionKey, report.Id);

    Assert.areEqual(report.Id, data.report.Id);
    Assert.areEqual(2, data.worktimes.size(), '客先提出分は一覧に含めない');
    Assert.areEqual(day1, data.worktimes[0].workDay);
    Assert.isTrue(data.worktimes[0].memo.contains('作業'));
    Assert.isTrue(data.worktimes[0].memo.contains('客先作業'));
    Assert.isTrue(data.worktimes[0].memo.contains('客先提出：'));
    Assert.isTrue(data.isCurrentMonth);
    Assert.isFalse(data.isReadonly);
    Assert.isTrue(data.messages.isEmpty());
  }

  @IsTest
  static void getReport_readonlyStatus() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(getContactId(LOGIN_EMAIL), Date.today(), '申請中');

    MonthReportController.ReportData data = MonthReportController.getReport(sessionKey, report.Id);

    Assert.isTrue(data.isReadonly);
  }

  @IsTest
  static void getReport_oldMonth_readonlyAndNotCurrent() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(getContactId(LOGIN_EMAIL), Date.today().addMonths(-4), 'ドラフト');

    MonthReportController.ReportData data = MonthReportController.getReport(sessionKey, report.Id);

    Assert.isTrue(data.isReadonly);
    Assert.isFalse(data.isCurrentMonth);
  }

  @IsTest
  static void getReport_rejectedAndNoProject_returnsMessages() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(getContactId(LOGIN_EMAIL), Date.today(), '却下');
    report.ProjectCode__c = null;
    report.RejectComment__c = '時間が違います';
    update as system report;

    MonthReportController.ReportData data = MonthReportController.getReport(sessionKey, report.Id);

    Assert.areEqual(2, data.messages.size());
    Assert.isTrue(data.messages[1].contains('時間が違います'));
  }

  @IsTest
  static void getReport_otherContact_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(getContactId(OTHER_EMAIL), Date.today(), 'ドラフト');

    try {
      MonthReportController.getReport(sessionKey, report.Id);
      Assert.fail('例外が発生すること');
    } catch (AuraHandledException e) {
      Assert.areEqual('勤務表が見つかりません。', e.getMessage());
    }
  }

  @IsTest
  static void getReport_invalidSession_throws() {
    MonthlyReport__c report = createReport(getContactId(LOGIN_EMAIL), Date.today(), 'ドラフト');

    try {
      MonthReportController.getReport('invalid', report.Id);
      Assert.fail('例外が発生すること');
    } catch (AuraHandledException e) {
      Assert.areEqual(WorkReportSession.SESSION_INVALID, e.getMessage());
    }
  }
}
