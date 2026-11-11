/**
 * 機能名 : 勤務表参照画面(workreport)のコントローラー
 *
 * 勤務表の情報と勤務実績(会社提出分)を取得する。月末締め(勤務表ファイルの添付)を行う。打刻は WorkreportListController.clockInOut を使う。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class WorkreportController {
  // 編集できない状況
  private static final Set<String> READONLY_STATUSES = new Set<String>{ '作成完了', '申請中', '承認済', 'クローズ' };
  private static final String STATUS_REJECTED = '却下';
  private static final String STATUS_COMPLETED = '作成完了';
  private static final String STATUS_DRAFT = 'ドラフト';
  private static final String XLSX_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  public class ReportData {
    @AuraEnabled
    public Workreport__c report;
    // ログイン社員本人の勤務表(false は上長として部下の勤務表を参照している。参照のみで操作不可)
    @AuraEnabled
    public Boolean isOwner;
    // 勤務実績(会社提出分、実績日順)
    @AuraEnabled
    public List<WorktimeRow> worktimes;
    // 当月の勤務表
    @AuraEnabled
    public Boolean isCurrentMonth;
    // 編集不可(状況または年月による)
    @AuraEnabled
    public Boolean isReadonly;
    // 締め取消できる(作成完了で、対象の年月の場合)
    @AuraEnabled
    public Boolean canCancelComplete;
    // 月末締めできる年月(当月以前。未来の月は締められない)
    @AuraEnabled
    public Boolean isClosableMonth;
    // 画面上部に表示するお知らせ
    @AuraEnabled
    public List<String> messages;
    // 勤務表ファイル(月末締めで添付したExcel)がある
    @AuraEnabled
    public Boolean hasReportFile;
    // 勤務表ファイル名(ファイルがない場合は null)
    @AuraEnabled
    public String reportFileName;
  }

  public class ReportFile {
    @AuraEnabled
    public String fileName;
    @AuraEnabled
    public String contentType;
    // ファイル内容(Base64文字列)
    @AuraEnabled
    public String content;
  }

  public class WorktimeRow {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Date workDay;
    @AuraEnabled
    public String week;
    @AuraEnabled
    public String startTime;
    @AuraEnabled
    public String endTime;
    @AuraEnabled
    public Decimal restTime;
    @AuraEnabled
    public Decimal workHours;
    // 備考(客先提出分の備考・時間をまとめたもの)
    @AuraEnabled
    public String memo;
    @AuraEnabled
    public Boolean isHoliday;
    @AuraEnabled
    public Boolean isSubmitCompany;
  }

  // 勤務表参照データ取得(管理職は上長として部下の勤務表も参照できる)
  @AuraEnabled
  public static ReportData getReport(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Workreport__c report = getViewableReport(reportId, contactId);
    Boolean isOwner = report.Contact__c == contactId;

    ReportData data = new ReportData();
    data.report = report;
    data.isOwner = isOwner;
    data.worktimes = toRows(report.WorkreportRelation__r);
    data.isCurrentMonth = isCurrentMonth(report.Year__c, report.Month__c);
    // 部下の勤務表は参照のみ(締め取消などの操作はできない)
    data.isReadonly = !isOwner || isReadonly(report);
    data.canCancelComplete = isOwner && canCancelComplete(report);
    data.isClosableMonth = isClosableMonth(report.Year__c, report.Month__c);
    // お知らせは社員本人向けの内容のため、部下の勤務表では表示しない
    data.messages = isOwner ? getMessages(report) : new List<String>();
    String fileName = getReportFileName(report);
    data.hasReportFile = !AttachmentDao.getListByName(report.Id, fileName).isEmpty();
    data.reportFileName = data.hasReportFile ? fileName : null;
    return data;
  }

  // 勤務表ファイル(月末締めで添付したExcel)のダウンロード用データ取得(管理職は部下の勤務表ファイルも取得できる)
  @AuraEnabled
  public static ReportFile getReportFile(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Workreport__c report = getViewableReport(reportId, contactId);
    List<Attachment> attachments = AttachmentDao.getBodyListByName(reportId, getReportFileName(report));
    if (attachments.isEmpty()) {
      throw createException('勤務表ファイルがありません。');
    }
    ReportFile file = new ReportFile();
    file.fileName = attachments[0].Name;
    file.contentType = String.isNotBlank(attachments[0].ContentType) ? attachments[0].ContentType : XLSX_CONTENT_TYPE;
    file.content = EncodingUtil.base64Encode(attachments[0].Body);
    return file;
  }

  // 参照できる勤務表を取得する(社員本人の勤務表、管理職の場合は上長として担当する部下の勤務表)
  private static Workreport__c getViewableReport(Id reportId, Id contactId) {
    Id superiorId = ContactDao.isManager(contactId) ? contactId : null;
    List<Workreport__c> reports = WorkreportDao.getDetailListById(reportId, contactId, superiorId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    return reports[0];
  }

  // 月末締め前のチェックを行い、勤務表ファイル(Excel)の作成に使うデータを返す。
  // ファイルは画面側でテンプレート(静的リソース Workreport)に書き込んで作成し、completeReport で登録する
  @AuraEnabled
  public static CompleteData getCompleteData(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Workreport__c report = getCompletableReport(reportId, contactId);
    CompleteData data = new CompleteData();
    data.report = report;
    data.worktimes = getCompanyWorktimes(report.WorkreportRelation__r);
    return data;
  }

  public class CompleteData {
    @AuraEnabled
    public Workreport__c report;
    // 勤務実績(会社提出分、実績日順)
    @AuraEnabled
    public List<Worktime__c> worktimes;
  }

  // 月末締め(勤務表ファイルを添付し、状況を作成完了にする。以降は編集不可)
  // fileContent : 画面で作成した勤務表ファイル(Excel)のBase64文字列
  @AuraEnabled
  public static String completeReport(String sessionKey, Id reportId, String fileContent) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Workreport__c report = getCompletableReport(reportId, contactId);
    if (String.isBlank(fileContent)) {
      throw createException('勤務表ファイルを作成できませんでした。');
    }

    // ファイル名は勤務表作成時に決まるが、その後に会社の略名が登録・変更されることがあるため、締めの時点で作り直す
    String fileName = WorkreportInputController.buildReportFileName(
      report.Year__c,
      report.Month__c,
      report.Contact__r?.Account,
      report.Contact__r?.Name
    );
    Datetime now = System.now();
    Workreport__c updated = new Workreport__c(
      Id = report.Id,
      ReportFileName__c = fileName,
      Status__c = STATUS_COMPLETED,
      ApplicationDateTime__c = now,
      LastModifiedBy__c = contactId,
      LastModified__c = now
    );
    // 例外時はファイルの添付も取り消されるよう、同じトランザクションで行う
    try {
      saveReportFile(report, fileName, EncodingUtil.base64Decode(fileContent));
      WorkreportDao.updateReports(new List<Workreport__c>{ updated });
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '勤務表を作成完了にしました。';
  }

  // 勤務表ファイルを添付する(同名のファイル、ファイル名を作り直す前の旧名のファイルがあれば置き換える)
  private static void saveReportFile(Workreport__c report, String fileName, Blob body) {
    AttachmentDao.deleteAttachments(AttachmentDao.getListByName(report.Id, getReportFileName(report)));
    AttachmentDao.deleteAttachments(AttachmentDao.getListByName(report.Id, fileName));
    AttachmentDao.insertAttachment(
      new Attachment(ParentId = report.Id, Name = fileName, ContentType = XLSX_CONTENT_TYPE, Body = body)
    );
  }

  private static String getReportFileName(Workreport__c report) {
    return String.isNotBlank(report.ReportFileName__c) ? report.ReportFileName__c : report.ReportName__c + '.xlsx';
  }

  // 会社提出分の勤務実績
  private static List<Worktime__c> getCompanyWorktimes(List<Worktime__c> worktimes) {
    List<Worktime__c> companyWorktimes = new List<Worktime__c>();
    for (Worktime__c wt : worktimes) {
      if (wt.IsSubmit__c != true) {
        companyWorktimes.add(wt);
      }
    }
    return companyWorktimes;
  }

  // 月末締めできる勤務表を取得する(入力内容に不備があれば例外)
  private static Workreport__c getCompletableReport(Id reportId, Id contactId) {
    List<Workreport__c> reports = WorkreportDao.getDetailListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    Workreport__c report = reports[0];
    if (isReadonly(report)) {
      throw createException('この勤務表は締めることができません。');
    }
    if (!isClosableMonth(report.Year__c, report.Month__c)) {
      throw createException('月末締めは' + Integer.valueOf(report.Month__c) + '月になってから行ってください。');
    }
    // 現場承認者
    if (String.isBlank(report.Approver__c) || String.isBlank(report.ApproverMail__c)) {
      throw createException('現場承認者情報を入力してください。');
    }
    // プロジェクト情報
    if (String.isBlank(report.ProjectCode__c) || String.isBlank(report.ProjectName__c)) {
      throw createException('プロジェクト情報を入力してください。');
    }
    // 勤務実績未作成
    if (report.TotalWorkTime__c == null || report.TotalWorkTime__c <= 0) {
      throw createException('勤務実績を作成してください。');
    }
    // 勤務のある日(有給休暇を除く)は、プロジェクト・作業場所・備考が必須
    for (Worktime__c wt : WorktimeDao.getCompanyListByReport(report.Id)) {
      if (wt.WorkHours__c == null || wt.WorkHours__c <= 0 || wt.IsPaidHoliday__c) {
        continue;
      }
      String day = String.valueOf(wt.WorkDay__c.day());
      if (String.isBlank(wt.ProjectName__c)) {
        throw createException(day + '日の実績にプロジェクトを入力してください。');
      }
      if (String.isBlank(wt.Workplace__c)) {
        throw createException(day + '日の実績に作業場所を入力してください。');
      }
      if (String.isBlank(wt.Memo__c)) {
        throw createException(day + '日の実績に備考を入力してください。');
      }
    }
    return report;
  }

  // 締め取消(作成完了をドラフトに戻し、月末締めで添付した勤務表ファイルを削除する。申請日時などはトリガーでクリアされる)
  @AuraEnabled
  public static String cancelCompleteReport(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<Workreport__c> reports = WorkreportDao.getDetailListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    if (!canCancelComplete(reports[0])) {
      throw createException('この勤務表は締め取消できません。');
    }
    Workreport__c updated = new Workreport__c(
      Id = reportId,
      Status__c = STATUS_DRAFT,
      LastModifiedBy__c = contactId,
      LastModified__c = System.now()
    );
    try {
      AttachmentDao.deleteAttachments(AttachmentDao.getListByName(reportId, getReportFileName(reports[0])));
      WorkreportDao.updateReports(new List<Workreport__c>{ updated });
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '月末締めを取り消しました。';
  }

  private static Boolean canCancelComplete(Workreport__c report) {
    return report.Status__c == STATUS_COMPLETED && !isReadonlyMonth(report.Year__c, report.Month__c);
  }

  // 会社提出分の実績を表示用に変換する(客先提出分の備考と時間は備考にまとめる)
  private static List<WorktimeRow> toRows(List<Worktime__c> worktimes) {
    Map<Date, Worktime__c> customerWorktimes = new Map<Date, Worktime__c>();
    for (Worktime__c wt : worktimes) {
      if (wt.IsSubmit__c == true && wt.IsSubmitCompany__c != true) {
        customerWorktimes.put(wt.WorkDay__c, wt);
      }
    }

    List<WorktimeRow> rows = new List<WorktimeRow>();
    for (Worktime__c wt : worktimes) {
      if (wt.IsSubmit__c == true) {
        continue;
      }
      WorktimeRow row = new WorktimeRow();
      row.id = wt.Id;
      row.workDay = wt.WorkDay__c;
      row.week = wt.Week__c;
      row.startTime = wt.Start__c;
      row.endTime = wt.End__c;
      row.restTime = wt.RestTime__c;
      row.workHours = wt.WorkHours__c;
      row.isHoliday = wt.IsHoliday__c == true;
      row.isSubmitCompany = wt.IsSubmitCompany__c == true;
      row.memo = mergeMemo(wt.Memo__c, customerWorktimes.get(wt.WorkDay__c));
      rows.add(row);
    }
    return rows;
  }

  private static String mergeMemo(String memo, Worktime__c customer) {
    List<String> lines = new List<String>();
    if (String.isNotBlank(memo)) {
      lines.add(memo);
    }
    if (customer != null) {
      if (String.isNotBlank(customer.Memo__c) && customer.Memo__c != memo) {
        lines.add(customer.Memo__c);
      }
      lines.add('客先提出：' + customer.Start__c + '～' + customer.End__c);
    }
    return String.join(lines, '\n');
  }

  private static List<String> getMessages(Workreport__c report) {
    List<String> messages = new List<String>();
    if (String.isBlank(report.ProjectName__c) || String.isBlank(report.ProjectCode__c)) {
      // ダイアログで1要素1行に表示するため、2行に分けて追加する
      messages.add('案件はアサインされていません、上長へ連絡してください。');
      messages.add('勤務表の記入は可能ですが、月末締め処理はできません。');
    }
    if (report.Status__c == STATUS_REJECTED) {
      String message = '申請は却下されました。';
      if (String.isNotBlank(report.RejectComment__c)) {
        message += 'コメント：' + report.RejectComment__c;
      }
      messages.add(message);
    }
    return messages;
  }

  // 月末締めできる年月(当月以前)
  private static Boolean isClosableMonth(String yyyy, String mm) {
    Date today = Date.today();
    return Date.newInstance(Integer.valueOf(yyyy), Integer.valueOf(mm), 1) <= today.toStartOfMonth();
  }

  private static Boolean isCurrentMonth(String yyyy, String mm) {
    Date today = Date.today();
    return yyyy == String.valueOf(today.year()) && mm == String.valueOf(today.month()).leftPad(2, '0');
  }

  // 編集不可(状況または年月による)の判定。実績入力画面(WorktimeInputController)からも使う
  public static Boolean isReadonly(Workreport__c report) {
    return READONLY_STATUSES.contains(report.Status__c) || isReadonlyMonth(report.Year__c, report.Month__c);
  }

  // 先々月～再来月以外の勤務表は編集不可とする
  private static Boolean isReadonlyMonth(String yyyy, String mm) {
    Date today = Date.today();
    Integer months = today.monthsBetween(Date.newInstance(Integer.valueOf(yyyy), Integer.valueOf(mm), 1));
    Boolean isReadonly = months >= 3 || months <= -3;
    // 1月15日以降は締め済みのため、去年12月以前の勤務表は編集不可
    if (today.month() == 1 && today.day() >= 15 && months <= -1) {
      isReadonly = true;
    }
    return isReadonly;
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
