@IsTest
private class WorkListControllerTest {
  private static final String LOGIN_EMAIL = 'worklist.test@example.com';
  private static final String PASSWORD = 'correct-password';

  @TestSetup
  static void setup() {
    Contact con = new Contact(LastName = 'WorkListTest', Email = LOGIN_EMAIL);
    insert as system con;
    LoginController.setPassword(con.Id, PASSWORD);
  }

  private static Id getContactId() {
    return [SELECT Id FROM Contact WHERE Email = :LOGIN_EMAIL WITH SYSTEM_MODE].Id;
  }

  private static MonthlyReport__c createReport(Date dt, String status) {
    MonthlyReport__c report = new MonthlyReport__c(
      Contact__c = getContactId(),
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
      UndertimeWork__c = 140
    );
    insert as system report;
    return report;
  }

  private static WorkTime__c createWorktime(Id reportId, Boolean isPaidHoliday, Boolean isVacation) {
    WorkTime__c wt = new WorkTime__c(
      MonthlyReport__c = reportId,
      WorkDay__c = Date.today(),
      StartHour__c = '09',
      StartTime__c = '00',
      EndHour__c = '18',
      EndTime__c = '00',
      IsPaidHoliday__c = isPaidHoliday,
      IsVacation__c = isVacation,
      Memo__c = isVacation ? '全休' : null
    );
    insert as system wt;
    return wt;
  }

  @IsTest
  static void getReports_returnsOwnReports() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    createReport(Date.today(), 'ドラフト');
    createReport(Date.today().addMonths(-1), '承認済');

    List<MonthlyReport__c> reports = WorkListController.getReports(sessionKey);

    Assert.areEqual(2, reports.size());
  }

  @IsTest
  static void getReports_invalidSession_throws() {
    for (String sessionKey : new List<String>{ null, 'invalid-key' }) {
      try {
        WorkListController.getReports(sessionKey);
        Assert.fail('例外が発生するはず');
      } catch (AuraHandledException e) {
        Assert.areEqual(WorkReportSession.SESSION_INVALID, e.getMessage());
      }
    }
  }

  @IsTest
  static void getReports_timedOut_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    SessionManagement__c session = [SELECT Id FROM SessionManagement__c WITH SYSTEM_MODE];
    session.LastAccessDatetime__c = System.now().addMinutes(-31);
    update as system session;

    try {
      WorkListController.getReports(sessionKey);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual(WorkReportSession.SESSION_INVALID, e.getMessage());
    }
  }

  @IsTest
  static void clockInOut_success_updatesWorktime() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(Date.today(), 'ドラフト');
    WorkTime__c wt = createWorktime(report.Id, false, true);

    String message = WorkListController.clockInOut(sessionKey);

    Assert.isNotNull(message);
    WorkTime__c updated = [
      SELECT IsVacation__c, Memo__c, ClockInDatetime__c, ClockOutDatetime__c
      FROM WorkTime__c
      WHERE Id = :wt.Id
      WITH SYSTEM_MODE
    ];
    Assert.isFalse(updated.IsVacation__c);
    Assert.isNull(updated.Memo__c);
    Assert.isTrue(updated.ClockInDatetime__c != null || updated.ClockOutDatetime__c != null);
  }

  @IsTest
  static void clockInOut_noReport_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    try {
      WorkListController.clockInOut(sessionKey);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('当月の勤務表がありません。当月の勤務表を作成してください。', e.getMessage());
    }
  }

  @IsTest
  static void clockInOut_readonlyReport_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    createReport(Date.today(), '申請中');
    try {
      WorkListController.clockInOut(sessionKey);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('申請中'));
    }
  }

  @IsTest
  static void clockInOut_noWorktime_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    createReport(Date.today(), 'ドラフト');
    try {
      WorkListController.clockInOut(sessionKey);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('今日の実績がありません。勤務実績を作成してください。', e.getMessage());
    }
  }

  @IsTest
  static void clockInOut_paidHoliday_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(Date.today(), 'ドラフト');
    createWorktime(report.Id, true, false);
    try {
      WorkListController.clockInOut(sessionKey);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('今日は有給休暇なので、打刻することができません。', e.getMessage());
    }
  }

  @IsTest
  static void deleteReport_success() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(Date.today(), 'ドラフト');

    WorkListController.deleteReport(sessionKey, report.Id);

    Assert.areEqual(0, [SELECT COUNT() FROM MonthlyReport__c WITH SYSTEM_MODE]);
  }

  @IsTest
  static void deleteReport_readonly_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    MonthlyReport__c report = createReport(Date.today(), '承認済');
    try {
      WorkListController.deleteReport(sessionKey, report.Id);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('申請中または承認済の勤務表は削除できません。', e.getMessage());
    }
    Assert.areEqual(1, [SELECT COUNT() FROM MonthlyReport__c WITH SYSTEM_MODE]);
  }

  @IsTest
  static void deleteReport_otherContact_throws() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    Contact other = new Contact(LastName = 'Other');
    insert as system other;
    MonthlyReport__c report = createReport(Date.today(), 'ドラフト');
    report.Contact__c = other.Id;
    update as system report;
    try {
      WorkListController.deleteReport(sessionKey, report.Id);
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual('勤務表が見つかりません。', e.getMessage());
    }
  }
}
