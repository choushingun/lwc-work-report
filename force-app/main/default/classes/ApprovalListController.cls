/**
 * 機能名 : 勤務承認画面(approvalList)のコントローラー
 *
 * 管理職(Contact.Management__c)が、上長として担当する部下の勤務表を年月ごとに一覧表示する。
 * 上司が空白の管理職は、自分の勤務表(上長が空白のもの)も一覧に含める。
 * 選択した勤務表をまとめて操作する。
 *  ・承認   : 作成完了の勤務表を申請中にする
 *  ・却下   : 申請中の勤務表を却下にする(却下理由を設定する)
 *  ・自社送付: 現場承認者からの承認メール内容を添えて、勤務表ファイルを自社の勤務表送付先へメールで送信し、承認済にする
 *  ・先行送付: 自社送付と同じメールを送信する(承認前に送るため、状況は変えない)
 * 各操作は check～ で入力チェックと確認メッセージの取得を行い、確認後に実行する。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class ApprovalListController {
  private static final String STATUS_COMPLETED = '作成完了';
  private static final String STATUS_APPLYING = '申請中';
  private static final String STATUS_APPROVED = '承認済';
  private static final String STATUS_REJECTED = '却下';
  private static final Integer REJECT_COMMENT_MAX_LENGTH = 255;
  private static final String XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  // 自社送付・先行送付メールのLightningメールテンプレート(API参照名)
  private static final String APPROVAL_MAIL_TEMPLATE = 'WorkreportApprovalMail';
  private static final String ADVANCE_MAIL_TEMPLATE = 'WorkreportAdvanceMail';

  // 部下の指定年月の勤務表一覧取得(yyyy:年4桁、mm:月2桁)
  @AuraEnabled
  public static List<Workreport__c> getReports(String sessionKey, String yyyy, String mm) {
    Id contactId = getManagerId(sessionKey);
    if (!Pattern.matches('\\d{4}', yyyy ?? '') || !Pattern.matches('(0[1-9]|1[0-2])', mm ?? '')) {
      throw createException('年月の指定が正しくありません。');
    }
    return WorkreportDao.getListBySuperior(contactId, yyyy, mm);
  }

  // ---------------------------------------------------------------- 承認

  // 承認の入力チェック(問題がなければ確認メッセージを返す。問題がある場合は例外)
  @AuraEnabled
  public static List<String> checkApprove(String sessionKey, List<Id> reportIds) {
    List<Workreport__c> reports = getTargetReports(getManagerId(sessionKey), reportIds);
    validateApprove(reports);
    return new List<String>{ '選択した勤務表(' + reports.size() + '件)を承認しますか？' };
  }

  // 承認(作成完了を申請中にする。申請日時はトリガーで設定される)
  @AuraEnabled
  public static String approveReports(String sessionKey, List<Id> reportIds) {
    List<Workreport__c> reports = getTargetReports(getManagerId(sessionKey), reportIds);
    validateApprove(reports);
    List<Workreport__c> reportsForUpdate = new List<Workreport__c>();
    for (Workreport__c report : reports) {
      reportsForUpdate.add(new Workreport__c(Id = report.Id, Status__c = STATUS_APPLYING));
    }
    WorkreportDao.updateReports(reportsForUpdate);
    return reports.size() + '件の勤務表を承認しました。';
  }

  // ---------------------------------------------------------------- 却下

  // 却下の入力チェック(問題がなければ確認メッセージを返す。問題がある場合は例外)
  @AuraEnabled
  public static List<String> checkReject(String sessionKey, List<Id> reportIds) {
    List<Workreport__c> reports = getTargetReports(getManagerId(sessionKey), reportIds);
    validateReject(reports);
    return new List<String>{ '選択した勤務表(' + reports.size() + '件)を却下します。', '却下理由を入力してください。' };
  }

  // 却下(選択した勤務表すべてに同じ却下理由を設定する。却下日時はトリガーで設定される)
  @AuraEnabled
  public static String rejectReports(String sessionKey, List<Id> reportIds, String comment) {
    List<Workreport__c> reports = getTargetReports(getManagerId(sessionKey), reportIds);
    if (String.isBlank(comment)) {
      throw createException('却下理由を入力してください。');
    }
    if (comment.length() > REJECT_COMMENT_MAX_LENGTH) {
      throw createException('却下理由は' + REJECT_COMMENT_MAX_LENGTH + '文字以内で入力してください。');
    }
    validateReject(reports);
    List<Workreport__c> reportsForUpdate = new List<Workreport__c>();
    for (Workreport__c report : reports) {
      reportsForUpdate.add(new Workreport__c(Id = report.Id, Status__c = STATUS_REJECTED, RejectComment__c = comment.trim()));
    }
    WorkreportDao.updateReports(reportsForUpdate);
    return reports.size() + '件の勤務表を却下しました。';
  }

  // ---------------------------------------------------------------- 自社送付・先行送付

  // 自社送付ダイアログに表示する内容
  public class SendInfo {
    // 勤務表名(一覧と同じ表示)
    @AuraEnabled
    public List<String> reportNames;
    // プロジェクト名称(重複を除く)
    @AuraEnabled
    public List<String> projectNames;
    // 勤務表送付先(会社の勤務表送付先メールアドレス)
    @AuraEnabled
    public List<String> reportToMails;
    // 勤務表送付先宛名
    @AuraEnabled
    public String reportTo;
    // すでに自社送付(承認済)した勤務表がある場合の注意(ない場合は null)
    @AuraEnabled
    public String warning;
    // 承認メール内容の初期値(1件目の勤務表に保存されている内容)
    @AuraEnabled
    public String replyMailContent;
  }

  // 自社送付の入力チェック(問題がなければダイアログに表示する内容を返す。問題がある場合は例外)
  @AuraEnabled
  public static SendInfo checkSendReports(String sessionKey, List<Id> reportIds) {
    List<Workreport__c> reports = getTargetReports(getManagerId(sessionKey), reportIds);
    validateSend(reports, getReportFiles(reports));
    Account account = reports[0].Contact__r.Account;
    SendInfo info = new SendInfo();
    info.reportNames = new List<String>();
    Set<String> projectNames = new Set<String>();
    for (Workreport__c report : reports) {
      info.reportNames.add(getName(report));
      if (String.isNotBlank(report.ProjectName__c)) {
        projectNames.add(report.ProjectName__c);
      }
      if (report.Status__c == STATUS_APPROVED) {
        info.warning = 'すでに自社へ送付した勤務表があります。再度送付する場合は、送付ボタンを押してください。';
      }
    }
    info.projectNames = new List<String>(projectNames);
    info.reportTo = account.ReportTo__c;
    info.reportToMails = splitMails(account.ReportToMail__c);
    info.replyMailContent = reports[0].ReplyMailContent__c;
    return info;
  }

  // 自社送付・先行送付(勤務表ファイルを添付して自社の勤務表送付先へメールを送信する)
  // isApproval が true の場合は自社送付(承認メール内容は必須。状況を承認済にする。承認日時はトリガーで設定される)
  // false の場合は先行送付(状況は変えない)
  @AuraEnabled
  public static String sendReports(String sessionKey, List<Id> reportIds, String replyMailContent, Boolean isApproval) {
    Id contactId = getManagerId(sessionKey);
    List<Workreport__c> reports = getTargetReports(contactId, reportIds);
    Map<Id, Attachment> files = getReportFiles(reports);
    validateSend(reports, files);
    String content = String.isBlank(replyMailContent) ? null : replyMailContent.trim();
    if (isApproval == true && content == null) {
      throw createException('承認メール内容を入力してください。');
    }
    if (isApproval == true) {
      Account account = reports[0].Contact__r.Account;
      List<Workreport__c> reportsForUpdate = new List<Workreport__c>();
      for (Workreport__c report : reports) {
        reportsForUpdate.add(
          new Workreport__c(
            Id = report.Id,
            Status__c = STATUS_APPROVED,
            ReplyMailContent__c = content,
            // 自社送付先を会社からコピーする(送付した時点の送付先を残す)
            ReportTo__c = account.ReportTo__c,
            ReportToMail__c = account.ReportToMail__c
          )
        );
      }
      WorkreportDao.updateReports(reportsForUpdate);
    }
    // メールはトランザクション確定後に送信される(更新に失敗した場合は送信されない)
    sendReportMail(ContactDao.getSettingListById(contactId)[0], reports, files, content, isApproval == true);
    String reportTo = reports[0].Contact__r.Account.ReportTo__c;
    return isApproval == true
      ? reportTo + ' 宛てに勤務表(' + reports.size() + '件)を送付し、承認済にしました。'
      : reportTo + ' 宛てに勤務表(' + reports.size() + '件)を先行送付しました。';
  }

  // ---------------------------------------------------------------- 共通

  // 操作対象の勤務表(ログイン社員が上長の勤務表のみ。一覧と同じ順)
  private static List<Workreport__c> getTargetReports(Id contactId, List<Id> reportIds) {
    if (reportIds == null || reportIds.isEmpty()) {
      throw createException('勤務表を選択してください。');
    }
    Set<Id> ids = new Set<Id>(reportIds);
    List<Workreport__c> reports = WorkreportDao.getActionListBySuperior(contactId, ids);
    if (reports.size() != ids.size()) {
      throw createException('勤務表が見つかりません。画面を再表示してください。');
    }
    return reports;
  }

  // 承認できるのは作成完了の勤務表のみ(申請中以降は承認済みとして扱う)
  private static void validateApprove(List<Workreport__c> reports) {
    for (Workreport__c report : reports) {
      String name = getName(report);
      if (report.Status__c == STATUS_APPLYING || report.Status__c == STATUS_APPROVED) {
        throw createException(name + '：すでに承認済みです。');
      }
      if (report.Status__c != STATUS_COMPLETED) {
        throw createException(name + '：作成完了ではない勤務表は承認できません。');
      }
    }
  }

  // 却下できるのは申請中の勤務表のみ
  private static void validateReject(List<Workreport__c> reports) {
    for (Workreport__c report : reports) {
      String name = getName(report);
      if (report.Status__c == STATUS_APPROVED) {
        throw createException(name + '：すでに承認済みです。');
      }
      if (report.Status__c == STATUS_REJECTED) {
        throw createException(name + '：すでに却下済みです。');
      }
      if (report.Status__c != STATUS_APPLYING) {
        throw createException(name + '：申請中ではない勤務表は却下できません。');
      }
    }
  }

  // 自社送付の入力チェック(最初に見つかった問題を例外にする)
  private static void validateSend(List<Workreport__c> reports, Map<Id, Attachment> files) {
    Id accountId = reports[0].Contact__r.AccountId;
    for (Workreport__c report : reports) {
      String name = getName(report);
      // 申請中以降(申請中・承認済)のみ送付できる
      if (report.StatusForOrder__c < 4) {
        throw createException(name + '：未申請の勤務表は自社へ送付できません。');
      }
      Account account = report.Contact__r.Account;
      if (account == null || String.isBlank(account.ReportTo__c) || splitMails(account.ReportToMail__c).isEmpty()) {
        throw createException(name + '：会社の勤務表送付先が未入力です。システム管理者に連絡してください。');
      }
      // 送付先が同じ(同じ会社の社員の)勤務表のみまとめて送付できる
      if (report.Contact__r.AccountId != accountId) {
        throw createException(name + '：会社が違う勤務表はまとめて自社送付できません。');
      }
      if (!files.containsKey(report.Id)) {
        throw createException(name + '：勤務表ファイルが見つかりません。月末締めを行ってください。');
      }
    }
  }

  // 勤務表ごとの勤務表ファイル(月末締めで添付したExcel。同名が複数ある場合は最新)
  private static Map<Id, Attachment> getReportFiles(List<Workreport__c> reports) {
    Map<Id, String> nameById = new Map<Id, String>();
    for (Workreport__c report : reports) {
      nameById.put(report.Id, getReportFileName(report));
    }
    Map<Id, Attachment> files = new Map<Id, Attachment>();
    for (Attachment att : AttachmentDao.getBodyListByParents(nameById.keySet(), new Set<String>(nameById.values()))) {
      if (att.Name == nameById.get(att.ParentId) && !files.containsKey(att.ParentId)) {
        files.put(att.ParentId, att);
      }
    }
    return files;
  }

  // 自社の勤務表送付先へ勤務表を送信する
  // 宛先：会社の勤務表送付先、CC：送付した管理職・各社員
  // 件名・本文はLightningメールテンプレート(自社送付・先行送付で別。文面は旧システムと同じ)の差し込み項目を置き換えて作る
  // 先行送付のテンプレートには承認メール内容を入れない(旧システムと同じ)
  private static void sendReportMail(
    Contact manager,
    List<Workreport__c> reports,
    Map<Id, Attachment> files,
    String replyMailContent,
    Boolean isApproval
  ) {
    EmailTemplate template = EmailTemplateDao.getByDeveloperName(
      isApproval ? APPROVAL_MAIL_TEMPLATE : ADVANCE_MAIL_TEMPLATE
    );
    if (template == null) {
      throw createException('勤務表送付メールのテンプレートが見つかりません。システム管理者に連絡してください。');
    }
    Workreport__c first = reports[0];
    Account account = first.Contact__r.Account;
    Set<String> toMails = new Set<String>(splitMails(account.ReportToMail__c));
    Set<String> ccMails = new Set<String>(splitMails(manager.Email));
    List<String> people = new List<String>();
    List<Messaging.EmailFileAttachment> emailFiles = new List<Messaging.EmailFileAttachment>();
    for (Workreport__c report : reports) {
      ccMails.addAll(splitMails(report.Contact__r.Email));
      people.add('・' + report.Contact__r.Name.escapeHtml4());
      Attachment file = files.get(report.Id);
      Messaging.EmailFileAttachment emailFile = new Messaging.EmailFileAttachment();
      emailFile.setFileName(file.Name);
      emailFile.setBody(file.Body);
      emailFile.setContentType(String.isNotBlank(file.ContentType) ? file.ContentType : XLSX_CONTENT_TYPE);
      emailFile.setInline(false);
      emailFiles.add(emailFile);
    }
    ccMails.removeAll(toMails);

    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
    mail.setToAddresses(new List<String>(toMails));
    mail.setCcAddresses(new List<String>(ccMails));
    mail.setSaveAsActivity(false);
    // 送信元は組織のメールアドレス(ゲストユーザーの自動割り当てアドレスは迷惑メール扱いされやすい)。返信は送付した管理職宛てにする
    mail.setOrgWideEmailAddressId(System.Label.PasswordResetSenderId);
    if (String.isNotBlank(manager.Email)) {
      mail.setReplyTo(manager.Email);
    }
    // 差し込み項目(Lightningの書式 {{{...}}}。項目は {{{オブジェクト.項目API名}}}、項目以外は旧システムと同じ名前の {{{NumberOfPeople}}} {{{Peoples}}})
    // 本文はHTMLのため、本文用の値はエスケープし、改行は<br>にする(件名はテキストのためそのまま)
    String reportName = first.ReportName__c ?? '';
    mail.setSubject(template.Subject.replace('{{{Workreport__c.ReportName__c}}}', reportName));
    mail.setHtmlBody(
      template.HtmlValue
        .replace('{{{Workreport__c.Contact__r.Account.ReportTo__c}}}', removeHonorific(account.ReportTo__c).escapeHtml4())
        .replace('{{{Contact.Name}}}', (manager.Name ?? '').escapeHtml4())
        .replace('{{{NumberOfPeople}}}', String.valueOf(reports.size()))
        .replace('{{{Workreport__c.ReportName__c}}}', reportName.escapeHtml4())
        .replace('{{{Peoples}}}', String.join(people, '<br>'))
        .replace('{{{Workreport__c.ReplyMailContent__c}}}', toHtml(replyMailContent ?? ''))
    );
    mail.setFileAttachments(emailFiles);
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
  }

  // セミコロン区切りのメールアドレスを分割する(空白は除く)
  private static List<String> splitMails(String value) {
    List<String> mails = new List<String>();
    if (String.isBlank(value)) {
      return mails;
    }
    for (String mail : value.split(';')) {
      if (String.isNotBlank(mail)) {
        mails.add(mail.trim());
      }
    }
    return mails;
  }

  // テキストをメール本文(HTML)用にする(エスケープし、改行を<br>にする)
  private static String toHtml(String text) {
    return text.escapeHtml4().replace('\r\n', '\n').replace('\n', '<br>');
  }

  // 宛名の末尾の敬称(様・さん・殿)を除く
  private static String removeHonorific(String name) {
    return (name ?? '').trim().replaceAll('\\s*(様|さん|殿)$', '');
  }

  // 一覧に表示する勤務表名
  private static String getName(Workreport__c report) {
    return report.Name;
  }

  // 勤務表ファイル名(勤務表参照画面と同じ)
  private static String getReportFileName(Workreport__c report) {
    return String.isNotBlank(report.ReportFileName__c) ? report.ReportFileName__c : report.ReportName__c + '.xlsx';
  }

  // ログイン社員が管理職の場合は社員Idを返す(管理職以外は例外)
  private static Id getManagerId(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    if (!ContactDao.isManager(contactId)) {
      throw createException('勤務承認は管理職のみ利用できます。');
    }
    return contactId;
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
