/**
 * 機能名 : パスワード再設定(ログイン画面の「パスワードを忘れた」・パスワード再設定画面 passwordReset)のコントローラー
 *
 * 1. ログイン画面で入力したメールアドレスに、再設定画面のURL(トークン付き)をメールで送る
 * 2. 再設定画面でトークンを確認し、新しいパスワードを設定する
 * トークンは推測できない乱数とし、社員(Contact)にはハッシュ値と有効期限のみ保存する。
 * ゲストユーザーから呼ばれる。データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class PasswordResetController {
  // 再設定画面(Experience Builderのページ)のURL
  private static final String RESET_PAGE_PATH = '/workreport-password-reset';
  // トークンの有効期限(時間)
  private static final Integer TOKEN_VALID_HOURS = 24;
  private static final Integer MIN_PASSWORD_LENGTH = 4;
  private static final Integer MAX_PASSWORD_LENGTH = 16;
  private static final String REQUEST_MESSAGE =
    '入力したメールアドレスが登録されている場合、パスワード再設定用のメールを送信しました。メールをご確認ください。';
  private static final String INVALID_TOKEN_MESSAGE =
    'パスワード再設定用のURLが無効か、有効期限が切れています。ログイン画面から再度お手続きください。';

  // 再設定メールの送信
  // メールアドレスの登録有無を判別されないよう、未登録でも同じメッセージを返す
  @AuraEnabled
  public static String requestReset(String email) {
    if (String.isBlank(email)) {
      throw createException('メールアドレスを入力してください。');
    }
    List<Contact> contacts = ContactDao.getResetListByEmail(email.trim());
    // Emailは一意にできないため、重複している場合は送信しない(ログインと同じ扱い)
    if (contacts.size() != 1) {
      return REQUEST_MESSAGE;
    }
    Contact con = contacts[0];
    String token = EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    ContactDao.updateContact(
      new Contact(
        Id = con.Id,
        PasswordResetToken__c = hashToken(token),
        PasswordResetExpires__c = System.now().addHours(TOKEN_VALID_HOURS)
      )
    );
    sendResetMail(con.Email, getResetUrl(token));
    return REQUEST_MESSAGE;
  }

  // トークンが有効か(再設定画面の初期表示で使う)
  @AuraEnabled
  public static Boolean isValidToken(String token) {
    return getContactByToken(token) != null;
  }

  // パスワード再設定(成功時はトークンをクリアし、同じURLを再利用できないようにする)
  @AuraEnabled
  public static String resetPassword(String token, String password) {
    Contact con = getContactByToken(token);
    if (con == null) {
      throw createException(INVALID_TOKEN_MESSAGE);
    }
    if (String.isBlank(password)) {
      throw createException('新しいパスワードを入力してください。');
    }
    if (password.length() < MIN_PASSWORD_LENGTH || password.length() > MAX_PASSWORD_LENGTH) {
      throw createException(
        'パスワードは' + MIN_PASSWORD_LENGTH + '～' + MAX_PASSWORD_LENGTH + '文字で入力してください。'
      );
    }
    LoginController.setPassword(con.Id, password);
    ContactDao.updateContact(new Contact(Id = con.Id, PasswordResetToken__c = null, PasswordResetExpires__c = null));
    return 'パスワードを変更しました。新しいパスワードでログインしてください。';
  }

  private static Contact getContactByToken(String token) {
    if (String.isBlank(token)) {
      return null;
    }
    List<Contact> contacts = ContactDao.getListByResetToken(hashToken(token));
    if (contacts.isEmpty()) {
      return null;
    }
    Contact con = contacts[0];
    if (con.PasswordResetExpires__c == null || con.PasswordResetExpires__c < System.now()) {
      return null;
    }
    return con;
  }

  // 再設定画面のURL(メール内のリンク先を利用者の入力から作らないよう、サイトのURLから組み立てる)
  private static String getResetUrl(String token) {
    String baseUrl = Site.getBaseSecureUrl();
    if (String.isBlank(baseUrl)) {
      throw createException('パスワード再設定用のURLを作成できませんでした。');
    }
    return baseUrl + RESET_PAGE_PATH + '?token=' + token;
  }

  // ゲストユーザーは社員レコードを参照できず setTargetObjectId は使えないため、メールアドレスを直接指定する
  private static void sendResetMail(String email, String resetUrl) {
    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>{ email });
    mail.setSaveAsActivity(false);
    mail.setSenderDisplayName('勤務報告システム');
    mail.setSubject('【勤務報告システム】パスワード再設定のご案内');
    mail.setPlainTextBody(
      String.join(
        new List<String>{
          'パスワード再設定のお手続きを受け付けました。',
          '下記のURLを開き、新しいパスワードを設定してください。',
          '',
          resetUrl,
          '',
          '※URLの有効期限は' + TOKEN_VALID_HOURS + '時間です。',
          '※お心当たりがない場合は、このメールを破棄してください。パスワードは変更されません。'
        },
        '\n'
      )
    );
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
  }

  private static String hashToken(String token) {
    return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(token)));
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
