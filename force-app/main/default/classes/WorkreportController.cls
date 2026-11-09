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
    public MonthlyReport__c report;
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
    // 画面上部に表示するお知らせ
    @AuraEnabled
    public List<String> messages;
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
    public Decimal workTime;
    // 備考(客先提出分の備考・時間をまとめたもの)
    @AuraEnabled
    public String memo;
    @AuraEnabled
    public Boolean isHoliday;
    @AuraEnabled
    public Boolean isSubmitCompany;
  }

  // 勤務表参照データ取得
  @AuraEnabled
  public static ReportData getReport(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<MonthlyReport__c> reports = MonthlyReportDao.getDetailListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    MonthlyReport__c report = reports[0];

    ReportData data = new ReportData();
    data.report = report;
    data.worktimes = toRows(report.MonthlyReportRelation__r);
    data.isCurrentMonth = isCurrentMonth(report.Year__c, report.Month__c);
    data.isReadonly = isReadonly(report);
    data.canCancelComplete = canCancelComplete(report);
    data.messages = getMessages(report);
    return data;
  }

  // 月末締め前のチェックを行い、勤務表ファイル(Excel)の作成に使うデータを返す。
  // ファイルは画面側でテンプレート(静的リソース Workreport)に書き込んで作成し、completeReport で登録する
  @AuraEnabled
  public static CompleteData getCompleteData(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    MonthlyReport__c report = getCompletableReport(reportId, contactId);
    CompleteData data = new CompleteData();
    data.report = report;
    data.worktimes = getCompanyWorktimes(report.MonthlyReportRelation__r);
    return data;
  }

  public class CompleteData {
    @AuraEnabled
    public MonthlyReport__c report;
    // 勤務実績(会社提出分、実績日順)
    @AuraEnabled
    public List<WorkTime__c> worktimes;
  }

  // 月末締め(勤務表ファイルを添付し、状況を作成完了にする。以降は編集不可)
  // fileContent : 画面で作成した勤務表ファイル(Excel)のBase64文字列
  @AuraEnabled
  public static String completeReport(String sessionKey, Id reportId, String fileContent) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    MonthlyReport__c report = getCompletableReport(reportId, contactId);
    if (String.isBlank(fileContent)) {
      throw createException('勤務表ファイルを作成できませんでした。');
    }

    Datetime now = System.now();
    MonthlyReport__c updated = new MonthlyReport__c(
      Id = report.Id,
      Status__c = STATUS_COMPLETED,
      ApplicationDateTime__c = now,
      LastModifiedBy__c = contactId,
      LastModified__c = now
    );
    // 例外時はファイルの添付も取り消されるよう、同じトランザクションで行う
    try {
      saveReportFile(report, EncodingUtil.base64Decode(fileContent));
      MonthlyReportDao.updateReports(new List<MonthlyReport__c>{ updated });
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '勤務表を作成完了にしました。';
  }

  // 勤務表ファイルを添付する(同名のファイルがあれば置き換える)
  private static void saveReportFile(MonthlyReport__c report, Blob body) {
    String fileName = getReportFileName(report);
    AttachmentDao.deleteAttachments(AttachmentDao.getListByName(report.Id, fileName));
    AttachmentDao.insertAttachment(
      new Attachment(ParentId = report.Id, Name = fileName, ContentType = XLSX_CONTENT_TYPE, Body = body)
    );
  }

  private static String getReportFileName(MonthlyReport__c report) {
    return String.isNotBlank(report.ReportFileName__c) ? report.ReportFileName__c : report.ReportName__c + '.xlsx';
  }

  // 会社提出分の勤務実績
  private static List<WorkTime__c> getCompanyWorktimes(List<WorkTime__c> worktimes) {
    List<WorkTime__c> companyWorktimes = new List<WorkTime__c>();
    for (WorkTime__c wt : worktimes) {
      if (wt.IsSubmit__c != true) {
        companyWorktimes.add(wt);
      }
    }
    return companyWorktimes;
  }

  // 月末締めできる勤務表を取得する(入力内容に不備があれば例外)
  private static MonthlyReport__c getCompletableReport(Id reportId, Id contactId) {
    List<MonthlyReport__c> reports = MonthlyReportDao.getDetailListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    MonthlyReport__c report = reports[0];
    if (isReadonly(report)) {
      throw createException('この勤務表は締めることができません。');
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
    for (WorkTime__c wt : WorktimeDao.getCompanyListByReport(report.Id)) {
      if (wt.WorkTime__c == null || wt.WorkTime__c <= 0 || wt.IsPaidHoliday__c) {
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
    List<MonthlyReport__c> reports = MonthlyReportDao.getDetailListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    if (!canCancelComplete(reports[0])) {
      throw createException('この勤務表は締め取消できません。');
    }
    MonthlyReport__c updated = new MonthlyReport__c(
      Id = reportId,
      Status__c = STATUS_DRAFT,
      LastModifiedBy__c = contactId,
      LastModified__c = System.now()
    );
    try {
      AttachmentDao.deleteAttachments(AttachmentDao.getListByName(reportId, getReportFileName(reports[0])));
      MonthlyReportDao.updateReports(new List<MonthlyReport__c>{ updated });
    } catch (DmlException e) {
      throw createException(e.getDmlMessage(0));
    }
    return '月末締めを取り消しました。';
  }

  private static Boolean canCancelComplete(MonthlyReport__c report) {
    return report.Status__c == STATUS_COMPLETED && !isReadonlyMonth(report.Year__c, report.Month__c);
  }

  // 会社提出分の実績を表示用に変換する(客先提出分の備考と時間は備考にまとめる)
  private static List<WorktimeRow> toRows(List<WorkTime__c> worktimes) {
    Map<Date, WorkTime__c> customerWorktimes = new Map<Date, WorkTime__c>();
    for (WorkTime__c wt : worktimes) {
      if (wt.IsSubmit__c == true && wt.IsSubmitCompany__c != true) {
        customerWorktimes.put(wt.WorkDay__c, wt);
      }
    }

    List<WorktimeRow> rows = new List<WorktimeRow>();
    for (WorkTime__c wt : worktimes) {
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
      row.workTime = wt.WorkTime__c;
      row.isHoliday = wt.IsHoliday__c == true;
      row.isSubmitCompany = wt.IsSubmitCompany__c == true;
      row.memo = mergeMemo(wt.Memo__c, customerWorktimes.get(wt.WorkDay__c));
      rows.add(row);
    }
    return rows;
  }

  private static String mergeMemo(String memo, WorkTime__c customer) {
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

  private static List<String> getMessages(MonthlyReport__c report) {
    List<String> messages = new List<String>();
    if (String.isBlank(report.ProjectName__c) || String.isBlank(report.ProjectCode__c)) {
      messages.add(
        '案件はアサインされていません、上長へ連絡してください。勤務表の記入は可能ですが、月末締め処理はできません。'
      );
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

  private static Boolean isCurrentMonth(String yyyy, String mm) {
    Date today = Date.today();
    return yyyy == String.valueOf(today.year()) && mm == String.valueOf(today.month()).leftPad(2, '0');
  }

  // 編集不可(状況または年月による)の判定。実績入力画面(WorktimeInputController)からも使う
  public static Boolean isReadonly(MonthlyReport__c report) {
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
