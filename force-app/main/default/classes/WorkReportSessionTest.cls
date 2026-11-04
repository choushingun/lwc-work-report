@IsTest
private class WorkReportSessionTest {
  private static final String LOGIN_EMAIL = 'session.test@example.com';
  private static final String PASSWORD = 'correct-password';

  @TestSetup
  static void setup() {
    Contact con = new Contact(LastName = 'SessionTest', Email = LOGIN_EMAIL);
    insert as system con;
    LoginController.setPassword(con.Id, PASSWORD);
  }

  private static SessionManagement__c getSession() {
    return [SELECT Id, LoginUser__c, LastAccessDatetime__c FROM SessionManagement__c WITH SYSTEM_MODE];
  }

  @IsTest
  static void validateSession_valid_updatesLastAccess() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    SessionManagement__c session = getSession();
    session.LastAccessDatetime__c = System.now().addMinutes(-10);
    update as system session;

    Assert.isTrue(WorkReportSession.validateSession(sessionKey));
    Assert.isTrue(getSession().LastAccessDatetime__c > System.now().addMinutes(-1));
  }

  @IsTest
  static void validateSession_invalid_returnsFalse() {
    Assert.isFalse(WorkReportSession.validateSession(null));
    Assert.isFalse(WorkReportSession.validateSession('invalid-key'));
  }

  @IsTest
  static void validateSession_timedOut_returnsFalse() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    SessionManagement__c session = getSession();
    session.LastAccessDatetime__c = System.now().addMinutes(-31);
    update as system session;

    Assert.isFalse(WorkReportSession.validateSession(sessionKey));
  }

  @IsTest
  static void validateSession_loggedOut_returnsFalse() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);
    LoginController.logout(sessionKey);

    Assert.isFalse(WorkReportSession.validateSession(sessionKey));
  }

  @IsTest
  static void getContactId_valid_returnsLoginUser() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);

    Assert.areEqual(getSession().LoginUser__c, WorkReportSession.getContactId(sessionKey));
  }

  @IsTest
  static void getContactId_invalid_throws() {
    try {
      WorkReportSession.getContactId('invalid-key');
      Assert.fail('例外が発生するはず');
    } catch (AuraHandledException e) {
      Assert.areEqual(WorkReportSession.SESSION_INVALID, e.getMessage());
    }
  }
}
