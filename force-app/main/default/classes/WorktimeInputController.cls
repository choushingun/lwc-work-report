/**
 * 機能名 : 勤務実績入力画面(worktimeInput)のコントローラー
 *
 * 勤務実績(会社提出分)の時間・休み・プロジェクト・作業場所・備考を一括で編集する。
 * 旧システムの実績編集画面(Worktime1_PAGE / Worktime1_CTRL)を移植したもの。
 * データアクセスはオブジェクトごとのDAOクラス(without sharing)で行う。
 */
public class WorktimeInputController {
  public class InitData {
    @AuraEnabled
    public Workreport__c report;
    // 勤務実績(会社提出分、実績日順)
    @AuraEnabled
    public List<WorktimeRow> rows;
    // プロジェクト選択肢(先頭は空白)
    @AuraEnabled
    public List<String> projects;
    // 作業場所選択肢(先頭は空白)
    @AuraEnabled
    public List<String> workplaces;
    @AuraEnabled
    public List<String> hourOptions;
    @AuraEnabled
    public List<String> minuteOptions;
    // 編集不可(状況または年月による)
    @AuraEnabled
    public Boolean isReadonly;
  }

  public class WorktimeRow {
    @AuraEnabled
    public Id id { get; set; }
    // 実績日(MM月dd日)
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public Date workDay { get; set; }
    @AuraEnabled
    public String week { get; set; }
    @AuraEnabled
    public String startHour { get; set; }
    @AuraEnabled
    public String startTime { get; set; }
    @AuraEnabled
    public String endHour { get; set; }
    @AuraEnabled
    public String endTime { get; set; }
    @AuraEnabled
    public Decimal restTime { get; set; }
    @AuraEnabled
    public Decimal workHours { get; set; }
    @AuraEnabled
    public String projectName { get; set; }
    @AuraEnabled
    public String workplace { get; set; }
    @AuraEnabled
    public String memo { get; set; }
    @AuraEnabled
    public Boolean isVacation { get; set; }
    @AuraEnabled
    public Boolean isHoliday { get; set; }
  }

  // 初期表示データ取得
  @AuraEnabled
  public static InitData getInitData(String sessionKey, Id reportId) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Workreport__c report = getReport(reportId, contactId);

    InitData data = new InitData();
    data.report = report;
    data.rows = new List<WorktimeRow>();
    for (Worktime__c wt : WorktimeDao.getListByReport(reportId)) {
      if (wt.IsSubmit__c != true) {
        data.rows.add(toRow(wt));
      }
    }
    data.projects = new List<String>{ '' };
    for (String project : new List<String>{ report.ProjectName__c, report.ProjectName2__c, report.ProjectName3__c }) {
      if (String.isNotBlank(project)) {
        data.projects.add(project);
      }
    }
    data.workplaces = new List<String>{ '' };
    if (String.isNotBlank(report.Workplace__c)) {
      data.workplaces.addAll(report.Workplace__c.split(';'));
    }
    data.hourOptions = getPicklistValues(Worktime__c.StartHour__c);
    data.minuteOptions = getPicklistValues(Worktime__c.StartTime__c);
    data.isReadonly = WorkreportController.isReadonly(report);
    return data;
  }

  // 勤務実績保存
  @AuraEnabled
  public static void saveWorktimes(String sessionKey, Id reportId, List<WorktimeRow> rows) {
    Id contactId = WorkreportSession.getContactId(sessionKey);
    Workreport__c report = getReport(reportId, contactId);
    if (WorkreportController.isReadonly(report)) {
      throw createException('この勤務表は編集できません。');
    }

    // 修正前の勤務実績(会社提出・客先提出)
    Map<Id, Worktime__c> companyById = new Map<Id, Worktime__c>();
    Map<Date, Worktime__c> customerByDay = new Map<Date, Worktime__c>();
    for (Worktime__c wt : WorktimeDao.getListByReport(reportId)) {
      if (wt.IsSubmit__c == true) {
        customerByDay.put(wt.WorkDay__c, wt);
      } else {
        companyById.put(wt.Id, wt);
      }
    }

    Map<Id, Worktime__c> updates = new Map<Id, Worktime__c>();
    // 削除する客先提出レコード(実績日単位)
    Map<Date, Worktime__c> deletes = new Map<Date, Worktime__c>();
    for (WorktimeRow row : rows == null ? new List<WorktimeRow>() : rows) {
      Worktime__c old = companyById.get(row.id);
      // 他の勤務表の実績は更新しない
      if (old == null) {
        continue;
      }
      Boolean isVacation = row.isVacation == true;
      Worktime__c wt = new Worktime__c(
        Id = old.Id,
        IsVacation__c = isVacation,
        StartHour__c = row.startHour,
        StartTime__c = row.startTime,
        EndHour__c = row.endHour,
        EndTime__c = row.endTime,
        RestTime__c = row.restTime,
        Memo__c = row.memo,
        // 休みの場合、プロジェクト・作業場所はクリアする
        ProjectName__c = isVacation || String.isBlank(row.projectName) ? null : row.projectName,
        Workplace__c = isVacation || String.isBlank(row.workplace) ? null : row.workplace
      );

      if (String.isBlank(wt.StartHour__c) || String.isBlank(wt.StartTime__c)) {
        throw createException(old.Name + '：開始時間を入力してください。');
      }
      if (String.isBlank(wt.EndHour__c) || String.isBlank(wt.EndTime__c)) {
        throw createException(old.Name + '：終了時間を入力してください。');
      }
      // 開始時刻＝終了時刻(労働時間が0)は休みのみ可
      if (wt.StartHour__c == wt.EndHour__c && wt.StartTime__c == wt.EndTime__c && !isVacation) {
        throw createException(old.Name + '：労働時間が０の場合、休みにチェックを入れてください。');
      }

      Worktime__c customer = customerByDay.get(old.WorkDay__c);
      if (customer != null) {
        // 休み：×⇒〇の場合、客先提出レコードを削除する
        if (old.IsVacation__c != true && isVacation) {
          deletes.put(old.WorkDay__c, customer);
          // 会社提出と客先提出の時間が同じになった場合、１つにする
        } else if (!isTimeModified(wt, customer)) {
          deletes.put(old.WorkDay__c, customer);
        }
      }

      // 開始時間を変更し、休憩時間を変更していない場合、昼休憩の時間を調整する
      Boolean isStartModified = old.StartHour__c != wt.StartHour__c || old.StartTime__c != wt.StartTime__c;
      if (isStartModified && old.RestTime__c == wt.RestTime__c && !isVacation) {
        adjustLunchTime(wt, old.LunchTime__c);
      }
      updates.put(wt.Id, wt);
    }

    // 客先提出レコードがある日だけ、会社提出レコードに会社提出フラグを立てる
    for (Worktime__c old : companyById.values()) {
      Boolean isSubmitCompany = customerByDay.containsKey(old.WorkDay__c) && !deletes.containsKey(old.WorkDay__c);
      if (updates.containsKey(old.Id)) {
        updates.get(old.Id).IsSubmitCompany__c = isSubmitCompany;
      } else if ((old.IsSubmitCompany__c == true) != isSubmitCompany) {
        updates.put(old.Id, new Worktime__c(Id = old.Id, IsSubmitCompany__c = isSubmitCompany));
      }
    }

    Savepoint sp = Database.setSavepoint();
    try {
      WorktimeDao.deleteWorktimes(deletes.values());
      WorktimeDao.updateWorktimes(updates.values());
    } catch (DmlException e) {
      Database.rollback(sp);
      throw createException(e.getDmlMessage(0));
    }
  }

  private static Workreport__c getReport(Id reportId, Id contactId) {
    List<Workreport__c> reports = WorkreportDao.getInputListById(reportId, contactId);
    if (reports.isEmpty()) {
      throw createException('勤務表が見つかりません。');
    }
    return reports[0];
  }

  private static WorktimeRow toRow(Worktime__c wt) {
    WorktimeRow row = new WorktimeRow();
    row.id = wt.Id;
    row.name = wt.Name;
    row.workDay = wt.WorkDay__c;
    row.week = wt.Week__c;
    row.startHour = wt.StartHour__c;
    row.startTime = wt.StartTime__c;
    row.endHour = wt.EndHour__c;
    row.endTime = wt.EndTime__c;
    row.restTime = wt.RestTime__c;
    row.workHours = wt.WorkHours__c;
    row.projectName = wt.ProjectName__c;
    row.workplace = wt.Workplace__c;
    row.memo = wt.Memo__c;
    row.isVacation = wt.IsVacation__c == true;
    row.isHoliday = wt.IsHoliday__c == true;
    return row;
  }

  // 会社提出と客先提出で時間が違うか
  private static Boolean isTimeModified(Worktime__c company, Worktime__c customer) {
    return company.StartHour__c != customer.StartHour__c ||
      company.StartTime__c != customer.StartTime__c ||
      company.EndHour__c != customer.EndHour__c ||
      company.EndTime__c != customer.EndTime__c;
  }

  // 昼休憩の開始以降に出社した場合、休憩時間を0にする(昼休憩中の場合は出社時間を昼休憩の終了時間にする)
  private static void adjustLunchTime(Worktime__c wt, String lunchTime) {
    if (String.isBlank(lunchTime) || !lunchTime.contains(':')) {
      return;
    }
    Integer restMinutes = wt.RestTime__c == null ? 0 : wt.RestTime__c.intValue();
    Time start = Time.newInstance(Integer.valueOf(wt.StartHour__c), Integer.valueOf(wt.StartTime__c), 0, 0);
    Time lunchStart = Time.newInstance(
      Integer.valueOf(lunchTime.split(':')[0]),
      Integer.valueOf(lunchTime.split(':')[1]),
      0,
      0
    );
    Time lunchEnd = lunchStart.addMinutes(restMinutes);
    if (start >= lunchStart) {
      wt.RestTime__c = 0;
      if (start < lunchEnd) {
        wt.StartHour__c = String.valueOf(lunchEnd.hour()).leftPad(2, '0');
        wt.StartTime__c = String.valueOf(lunchEnd.minute()).leftPad(2, '0');
      }
    }
  }

  private static List<String> getPicklistValues(Schema.SObjectField field) {
    List<String> values = new List<String>();
    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (entry.isActive()) {
        values.add(entry.getValue());
      }
    }
    return values;
  }

  private static AuraHandledException createException(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
