@IsTest
private class LoginControllerTest {
  private static final String LOGIN_EMAIL = 'login.test@example.com';
  private static final String PASSWORD = 'correct-password';

  @TestSetup
  static void setup() {
    Contact con = new Contact(LastName = 'LoginTest', Email = LOGIN_EMAIL);
    insert as system con;
    LoginController.setPassword(con.Id, PASSWORD);
  }

  private static Contact getContact() {
    return [
      SELECT Id, PasswordHash__c, FailedLoginCount__c, LockoutUntil__c
      FROM Contact
      WHERE Email = :LOGIN_EMAIL
      WITH SYSTEM_MODE
    ];
  }

  @IsTest
  static void setPassword_doesNotStorePlainText() {
    Contact con = getContact();
    Assert.areNotEqual(PASSWORD, con.PasswordHash__c);
    Assert.areEqual(64, con.PasswordHash__c.length());
  }

  @IsTest
  static void setPassword_blank_throws() {
    try {
      LoginController.setPassword(getContact().Id, ' ');
      Assert.fail('例外が発生するはず');
    } catch (IllegalArgumentException e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  static void login_success_createsSessionWithHashedKey() {
    String sessionKey = LoginController.login(LOGIN_EMAIL, PASSWORD);

    Assert.isNotNull(sessionKey);
    SessionManagement__c session = [
      SELECT Key__c, LoginUser__c, LoginDatetime__c, LastAccessDatetime__c
      FROM SessionManagement__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(LoginController.hashSessionKey(sessionKey), session.Key__c);
    Assert.areNotEqual(sessionKey, session.Key__c);
    Assert.areEqual(getContact().Id, session.LoginUser__c);
    Assert.isNotNull(session.LoginDatetime__c);
    Assert.isNotNull(session.LastAccessDatetime__c);
  }

  @IsTest
  static void login_invalidInput_returnsNull() {
    Assert.isNull(LoginController.login('', PASSWORD));
    Assert.isNull(LoginController.login(LOGIN_EMAIL, ''));
    Assert.isNull(LoginController.login('unknown@example.com', PASSWORD));
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SessionManagement__c WITH SYSTEM_MODE]
    );
  }

  @IsTest
  static void login_duplicateEmail_returnsNull() {
    // 組織の標準重複ルールに関わらず、重複データを作成する
    Database.DMLOptions options = new Database.DMLOptions();
    options.duplicateRuleHeader.allowSave = true;
    Contact duplicate = new Contact(LastName = 'Dup', Email = LOGIN_EMAIL);
    Database.insert(duplicate, options, AccessLevel.SYSTEM_MODE);

    Assert.isNull(LoginController.login(LOGIN_EMAIL, PASSWORD));
  }

  @IsTest
  static void login_wrongPassword_countsFailure() {
    Assert.isNull(LoginController.login(LOGIN_EMAIL, 'wrong'));

    Assert.areEqual(1, getContact().FailedLoginCount__c);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SessionManagement__c WITH SYSTEM_MODE]
    );
  }

  @IsTest
  static void login_success_resetsFailureCount() {
    LoginController.login(LOGIN_EMAIL, 'wrong');

    Assert.isNotNull(LoginController.login(LOGIN_EMAIL, PASSWORD));
    Assert.areEqual(0, getContact().FailedLoginCount__c);
  }

  @IsTest
  static void login_fiveFailures_locksAccount() {
    for (Integer i = 0; i < 5; i++) {
      LoginController.login(LOGIN_EMAIL, 'wrong');
    }

    Assert.isNotNull(getContact().LockoutUntil__c);
    Assert.isNull(LoginController.login(LOGIN_EMAIL, PASSWORD));
  }

  @IsTest
  static void login_afterLockoutExpired_succeeds() {
    update as system new Contact(
      Id = getContact().Id,
      LockoutUntil__c = System.now().addMinutes(-1)
    );

    Assert.isNotNull(LoginController.login(LOGIN_EMAIL, PASSWORD));
  }
}
