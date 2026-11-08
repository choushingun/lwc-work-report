/**
 * 機能名 : 勤務表参照画面(workReportMonthReport)のコントローラー
 *
 * 勤務表の情報と勤務実績(会社提出分)を取得する。打刻は WorkListController.clockInOut を使う。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class MonthReportController {
  // 編集できない状況
  private static final Set<String> READONLY_STATUSES = new Set<String>{ '作成完了', '申請中', '承認済', 'クローズ' };
  private static final String STATUS_REJECTED = '却下';

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
    Id contactId = WorkReportSession.getContactId(sessionKey);
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
    data.messages = getMessages(report);
    return data;
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
