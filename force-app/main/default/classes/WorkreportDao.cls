/**
 * 機能名 : 勤務表(Workreport__c)のデータアクセス
 *
 * ゲストユーザーは勤務表の所有者になれず共有上参照できないため、without sharing かつシステムモードで実行する。
 * 呼び出し元で必ずログイン社員(Contact)の勤務表に絞り込むこと。
 */
public without sharing class WorkreportDao {
  // Idで取得する(トリガー用)
  public static Map<Id, Workreport__c> getMapByIds(Set<Id> reportIds) {
    return new Map<Id, Workreport__c>(
      [
        SELECT Id, Year__c, Month__c, LastModified__c
        FROM Workreport__c
        WHERE Id IN :reportIds
        WITH SYSTEM_MODE
      ]
    );
  }

  // 社員の勤務表一覧(新しい年月順)
  public static List<Workreport__c> getListByContact(Id contactId) {
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
      FROM Workreport__c
      WHERE Contact__c = :contactId
      WITH SYSTEM_MODE
      ORDER BY Year__c DESC, Month__c DESC
    ];
  }

  // 上長(管理職)の部下の指定年月の勤務表一覧(勤務承認画面用、社員番号順)
  // 上司が空白の管理職(上長のない自分の勤務表)は、自分の勤務表も含める
  public static List<Workreport__c> getListBySuperior(Id superiorId, String year, String month) {
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
      FROM Workreport__c
      WHERE
        (Superior__c = :superiorId
        OR (Contact__c = :superiorId
        AND Superior__c = NULL))
        AND Year__c = :year
        AND Month__c = :month
      WITH SYSTEM_MODE
      ORDER BY EmployeeNo__c, ReportName__c
    ];
  }

  // 社員の勤務表のうち、上長が superiorId と異なるもの(上司変更時に上長を置き換える用)
  public static List<Workreport__c> getListWithOtherSuperior(Id contactId, Id superiorId) {
    return [
      SELECT Id
      FROM Workreport__c
      WHERE Contact__c = :contactId AND Superior__c != :superiorId
      WITH SYSTEM_MODE
    ];
  }

  // 社員の指定年月の勤務表件数
  public static Integer countByYearMonth(Id contactId, String year, String month) {
    return [
      SELECT COUNT()
      FROM Workreport__c
      WHERE Contact__c = :contactId AND Year__c = :year AND Month__c = :month
      WITH SYSTEM_MODE
    ];
  }

  // 社員の指定年月の勤務表(打刻用)
  public static List<Workreport__c> getListByYearMonth(Id contactId, String year, String month) {
    return [
      SELECT Id, Status__c, StartHour__c, StartTime__c, EndHour__c, EndTime__c, RestTime__c, ProjectName__c
      FROM Workreport__c
      WHERE Year__c = :year AND Month__c = :month AND Contact__c = :contactId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  // 社員の勤務表(状況のみ)
  public static List<Workreport__c> getStatusListById(Id reportId, Id contactId) {
    return [
      SELECT Id, Status__c
      FROM Workreport__c
      WHERE Id = :reportId AND Contact__c = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // 社員の勤務表(指定項目のみ、複製用)
  public static List<Workreport__c> getFieldListById(Id reportId, Id contactId, List<String> fields) {
    return Database.queryWithBinds(
      'SELECT ' + String.join(fields, ', ') + ' FROM Workreport__c WHERE Id = :reportId AND Contact__c = :contactId',
      new Map<String, Object>{ 'reportId' => reportId, 'contactId' => contactId },
      AccessLevel.SYSTEM_MODE
    );
  }

  // 社員の勤務表(実績入力画面用)
  public static List<Workreport__c> getInputListById(Id reportId, Id contactId) {
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
      FROM Workreport__c
      WHERE Id = :reportId AND Contact__c = :contactId
      WITH SYSTEM_MODE
    ];
  }

  // 社員の勤務表と勤務実績(参照画面用)
  public static List<Workreport__c> getDetailListById(Id reportId, Id contactId) {
    return getDetailListById(reportId, contactId, null);
  }

  // 社員の勤務表、または上長(superiorId)の部下の勤務表と勤務実績(参照画面用)
  // superiorId が null の場合は社員本人の勤務表のみ取得する
  public static List<Workreport__c> getDetailListById(Id reportId, Id contactId, Id superiorId) {
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
        Contact__c,
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
            WorkHours__c,
            ProjectName__c,
            Workplace__c,
            Memo__c,
            IsVacation__c,
            IsHoliday__c,
            IsSubmit__c,
            IsSubmitCompany__c
          FROM WorkreportRelation__r
          ORDER BY WorkDay__c
        )
      FROM Workreport__c
      WHERE
        Id = :reportId
        AND (Contact__c = :contactId
        OR (Superior__c = :superiorId
        AND Superior__c != NULL))
      WITH SYSTEM_MODE
    ];
  }

  public static void insertReport(Workreport__c report) {
    insert as system report;
  }

  public static void updateReports(List<Workreport__c> reports) {
    if (!reports.isEmpty()) {
      update as system reports;
    }
  }

  public static void deleteReports(List<Workreport__c> reports) {
    if (!reports.isEmpty()) {
      delete as system reports;
    }
  }
}
