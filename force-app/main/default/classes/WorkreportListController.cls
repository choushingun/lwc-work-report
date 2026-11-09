/**
 * 機能名 : 勤務表一覧画面(workreportList)のコントローラー
 *
 * WorkreportSessionでセッションキーから社員(Contact)を特定し、勤務表の一覧取得・打刻・削除を行う。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class WorkreportListController {
  private static final Set<String> READONLY_STATUSES = new Set<String>{ '申請中', '承認済' };

  // 勤務表一覧取得
  @AuraEnabled
  public static List<MonthlyReport__c> getReports(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    return MonthlyReportDao.getListByContact(contactId);
  }

  // 打刻処理(成功時は画面に表示するメッセージを返す)
  @AuraEnabled
  public static String clockInOut(String sessionKey) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Date today = Date.today();
    String yyyy = String.valueOf(today.year());
    String mm = String.valueOf(today.month()).leftPad(2, '0');

    List<MonthlyReport__c> reports = MonthlyReportDao.getListByYearMonth(contactId, yyyy, mm);
    if (reports.isEmpty()) {
      throw createException('当月の勤務表がありません。当月の勤務表を作成してください。');
    }
    MonthlyReport__c report = reports[0];
    // 今月はすでに申請中、承認済みの場合、打刻不可
    if (READONLY_STATUSES.contains(report.Status__c)) {
      throw createException(
        String.format(
          '今月の勤務表はすでに{0}になっているため、打刻することができません。',
          new List<String>{ report.Status__c }
        )
      );
    }

    // 当日の会社提出実績
    List<WorkTime__c> worktimes = WorktimeDao.getCompanyListByDay(report.Id, today);
    if (worktimes.isEmpty()) {
      throw createException('今日の実績がありません。勤務実績を作成してください。');
    }
    WorkTime__c current = worktimes[0];
    WorkTime__c wt = new WorkTime__c(Id = current.Id);
    // 休みの場合、チェックを外して勤務表の標準時間を設定する
    if (current.IsVacation__c) {
      wt.IsVacation__c = false;
      if (current.Memo__c == '全休') {
        wt.Memo__c = '';
      }
      wt.StartHour__c = report.StartHour__c;
      wt.StartTime__c = report.StartTime__c;
      wt.EndHour__c = report.EndHour__c;
      wt.EndTime__c = report.EndTime__c;
      wt.RestTime__c = report.RestTime__c;
      if (String.isNotBlank(report.ProjectName__c)) {
        wt.ProjectName__c = report.ProjectName__c.split(',')[0];
      }
    }

    // 15分単位で丸める(七捨八入)
    Datetime now = System.now();
    Integer overMinute = Math.mod(now.minute(), 15);
    Datetime rounded = now.addMinutes(overMinute > 7 ? 15 - overMinute : -overMinute);
    String h = String.valueOf(rounded.hour()).leftPad(2, '0');
    String m = String.valueOf(rounded.minute()).leftPad(2, '0');

    // 午後2時までは出勤、以降は退勤と見なす
    String message;
    if (now.hour() <= 14) {
      wt.StartHour__c = h;
      wt.StartTime__c = m;
      wt.ClockInDatetime__c = now;
      message = 'おはようございます！現在の時刻で打刻しました。';
    } else {
      wt.EndHour__c = h;
      wt.EndTime__c = m;
      wt.ClockOutDatetime__c = now;
      message = '現在の時刻で打刻しました。お疲れ様でした！';
    }
    WorktimeDao.updateWorkTimes(new List<WorkTime__c>{ wt });
    return message;
  }

  // 勤務表削除(勤務実績は主従関係で連動削除される)
  @AuraEnabled
  public static void deleteReport(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    List<MonthlyReport__c> reports = MonthlyReportDao.getStatusListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    if (READONLY_STATUSES.contains(reports[0].Status__c)) {
      throw createException('申請中または承認済の勤務表は削除できません。');
    }
    try {
      MonthlyReportDao.deleteReports(reports);
    } catch (DmlException e) {
      throw createException('勤務表削除処理失敗しました。');
    }
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
