/**
 * 機能名 : 勤務実績(Worktime__c)のデータアクセス
 *
 * ゲストユーザーは勤務実績の所有者になれず共有上参照できないため、without sharing かつシステムモードで実行する。
 * 呼び出し元で必ずログイン社員の勤務表に絞り込むこと。
 */
public without sharing class WorktimeDao {
  // 勤務表の中で、指定したプロジェクトの勤務実績
  public static List<Worktime__c> getListByProject(Id reportId, List<String> projectNames) {
    return [
      SELECT Id, ProjectName__c
      FROM Worktime__c
      WHERE Workreport__c = :reportId AND ProjectName__c IN :projectNames
      WITH SYSTEM_MODE
    ];
  }

  // 勤務表の指定日の会社提出実績
  public static List<Worktime__c> getCompanyListByDay(Id reportId, Date workDay) {
    return [
      SELECT Id, IsVacation__c, Memo__c
      FROM Worktime__c
      WHERE Workreport__c = :reportId AND WorkDay__c = :workDay AND IsSubmit__c = FALSE
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  // 勤務表の会社提出分の勤務実績(月末締めのチェック用、実績日順)
  public static List<Worktime__c> getCompanyListByReport(Id reportId) {
    return [
      SELECT Id, WorkDay__c, WorkHours__c, ProjectName__c, Workplace__c, Memo__c, IsPaidHoliday__c
      FROM Worktime__c
      WHERE Workreport__c = :reportId AND IsSubmit__c = FALSE
      WITH SYSTEM_MODE
      ORDER BY WorkDay__c
    ];
  }

  // 勤務表の全勤務実績(会社提出・客先提出の両方、実績日順)
  public static List<Worktime__c> getListByReport(Id reportId) {
    return [
      SELECT
        Id,
        Name,
        WorkDay__c,
        Week__c,
        StartHour__c,
        StartTime__c,
        EndHour__c,
        EndTime__c,
        RestTime__c,
        LunchTime__c,
        WorkHours__c,
        ProjectName__c,
        Workplace__c,
        Memo__c,
        IsVacation__c,
        IsHoliday__c,
        IsSubmit__c,
        IsSubmitCompany__c
      FROM Worktime__c
      WHERE Workreport__c = :reportId
      WITH SYSTEM_MODE
      ORDER BY WorkDay__c
    ];
  }

  public static void insertWorktimes(List<Worktime__c> worktimes) {
    if (!worktimes.isEmpty()) {
      insert as system worktimes;
    }
  }

  public static void updateWorktimes(List<Worktime__c> worktimes) {
    if (!worktimes.isEmpty()) {
      update as system worktimes;
    }
  }

  public static void deleteWorktimes(List<Worktime__c> worktimes) {
    if (!worktimes.isEmpty()) {
      delete as system worktimes;
    }
  }
}
