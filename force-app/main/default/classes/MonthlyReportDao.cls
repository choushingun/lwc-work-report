/**
 * 機能名 : 勤務表(MonthlyReport__c)のデータアクセス
 *
 * ゲストユーザーは勤務表の所有者になれず共有上参照できないため、without sharing かつシステムモードで実行する。
 * 呼び出し元で必ずログイン社員(Contact)の勤務表に絞り込むこと。
 */
public without sharing class MonthlyReportDao {
  // Idで取得する(トリガー用)
  public static Map<Id, MonthlyReport__c> getMapByIds(Set<Id> reportIds) {
    return new Map<Id, MonthlyReport__c>(
      [
        SELECT Id, Year__c, Month__c, LastModified__c
        FROM MonthlyReport__c
        WHERE Id IN :reportIds
        WITH SYSTEM_MODE
      ]
    );
  }

  // 社員の勤務表一覧(新しい年月順)
  public static List<MonthlyReport__c> getListByContact(Id contactId) {
    return [
      SELECT
        Id,
        ReportName__c,
        Status__c,
        WorkDays__c,
        StandardWorkDays__c,
        StandardWorktime__c,
        TotalWorkTime__c,
        Overtime__c,
        ApplicationApprovalDT__c
      FROM MonthlyReport__c
      WHERE Contact__c = :contactId
      WITH SYSTEM_MODE
      ORDER BY Year__c DESC, Month__c DESC
    ];
  }

  // 社員の指定年月の勤務表件数
  public static Integer countByYearMonth(Id contactId, String year, String month) {
    return [
      SELECT COUNT()
      FROM MonthlyReport__c
      WHERE Contact__c = :contactId AND Year__c = :year AND Month__c = :month
      WITH SYSTEM_MODE
    ];
  }

  // 社員の指定年月の勤務表(打刻用)
  public static List<MonthlyReport__c> getListByYearMonth(Id contactId, String year, String month) {
    return [
      SELECT Id, Status__c, StartHour__c, StartTime__c, EndHour__c, EndTime__c, RestTime__c, ProjectName__c
      FROM MonthlyReport__c
      WHERE Year__c = :year AND Month__c = :month AND Contact__c = :contactId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  // 社員の勤務表(状況のみ)
  public static List<MonthlyReport__c> getStatusListById(Id reportId, Id contactId) {
    return [
      SELECT Id, Status__c
      FROM MonthlyReport__c
      WHERE Id = :reportId AND Contact__c = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // 社員の勤務表(指定項目のみ、複製用)
  public static List<MonthlyReport__c> getFieldListById(Id reportId, Id contactId, List<String> fields) {
    return Database.queryWithBinds(
      'SELECT ' + String.join(fields, ', ') + ' FROM MonthlyReport__c WHERE Id = :reportId AND Contact__c = :contactId',
      new Map<String, Object>{ 'reportId' => reportId, 'contactId' => contactId },
      AccessLevel.SYSTEM_MODE
    );
  }

  // 社員の勤務表(実績入力画面用)
  public static List<MonthlyReport__c> getInputListById(Id reportId, Id contactId) {
    return [
      SELECT
        Id,
        ReportName__c,
        Year__c,
        Month__c,
        Status__c,
        StartHour__c,
        StartTime__c,
        EndHour__c,
        EndTime__c,
        RestTime__c,
        ProjectName__c,
        ProjectName2__c,
        ProjectName3__c,
        Workplace__c
      FROM MonthlyReport__c
      WHERE Id = :reportId AND Contact__c = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // 社員の勤務表と勤務実績(参照画面用)
  public static List<MonthlyReport__c> getDetailListById(Id reportId, Id contactId) {
    return [
      SELECT
        Id,
        ReportName__c,
        UserName__c,
        Year__c,
        Month__c,
        Status__c,
        StartHour__c,
        StartTime__c,
        EndHour__c,
        EndTime__c,
        UndertimeWork__c,
        OvertimeWork__c,
        WorkDays__c,
        TotalWorkTime__c,
        Approver__c,
        ApproverMail__c,
        ProjectName__c,
        ProjectCode__c,
        ProjectName2__c,
        ProjectCode2__c,
        ProjectName3__c,
        ProjectCode3__c,
        RejectComment__c,
        ApplicationDateTime__c,
        ApproveDateTime__c,
        ReportFileName__c,
        Superior__r.Name,
        Contact__r.Name,
        Contact__r.Account.Name,
        Contact__r.Account.Abbreviation__c,
        Contact__r.Account.ReportTo__c,
        Contact__r.Account.ReportToMail__c,
        (
          SELECT
            Id,
            WorkDay__c,
            Week__c,
            Start__c,
            End__c,
            RestTime__c,
            WorkTime__c,
            ProjectName__c,
            Workplace__c,
            Memo__c,
            IsVacation__c,
            IsHoliday__c,
            IsSubmit__c,
            IsSubmitCompany__c
          FROM MonthlyReportRelation__r
          ORDER BY WorkDay__c
        )
      FROM MonthlyReport__c
      WHERE Id = :reportId AND Contact__c = :contactId
      WITH SYSTEM_MODE
    ];
  }

  public static void insertReport(MonthlyReport__c report) {
    insert as system report;
  }

  public static void updateReports(List<MonthlyReport__c> reports) {
    if (!reports.isEmpty()) {
      update as system reports;
    }
  }

  public static void deleteReports(List<MonthlyReport__c> reports) {
    if (!reports.isEmpty()) {
      delete as system reports;
    }
  }
}
