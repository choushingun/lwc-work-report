public without sharing class ReportUtility {
  private static String kHexChars = '0123456789abcdef';
  // セッションキー
  public static String SESSION_KEY = 'SESSION_KEY';
  // VFページ名
  public static String VF_PAGENAME = 'VF_PAGENAME';
  // ページ数
  public static String PAGE_NUM = 'PAGE_NUM';
  public static final String MATCH_ASCII = '^[\\u0020-\\u007E]+$';
  public static final String MATCH_HANKANA = '^[\\uFF65-\\uFF9F]+$';

  private static Map<String, String> halfToZenNumMap = new Map<String, String>{
    '0' => '０',
    '1' => '１',
    '2' => '２',
    '3' => '３',
    '4' => '４',
    '5' => '５',
    '6' => '６',
    '7' => '７',
    '8' => '８',
    '9' => '９',
    '-' => '－',
    ' ' => ' ',
    '(' => '（',
    ')' => '）'
  };

  // public static String left(String value, Integer num) {
  //   return String.isNotBlank(value) ? value.left(num) : value;
  // }

  // // 当月判断
  // public static Boolean isCurrentMonth(String yyyy, String mm) {
  //   try {
  //     Integer y = Integer.valueOf(yyyy);
  //     Integer m = Integer.valueOf(mm);
  //     if (y == Date.today().Year() && m == Date.today().month()) {
  //       return true;
  //     }
  //   } catch (Exception e) {
  //   }
  //   return false;
  // }

  // // 半角文字チェック
  // public static Boolean containsHankaku(String str) {
  //   // 空白の場合、チェックしない
  //   if (String.isBlank(str)) {
  //     return false;
  //   }
  //   String rex = '^(?=.*[' + MATCH_ASCII + MATCH_HANKANA + ']+).*$';
  //   return Pattern.matches(rex, str);
  // }

  // // 全角半角スペース削除
  // public static String removeSpace(String str) {
  //   // 空白の場合、チェックしない
  //   if (String.isBlank(str)) {
  //     return str;
  //   }
  //   return str.replace(' ', '').replace('　', '');
  // }

  // // 敬称削除
  // public static String removeHonorificTitle(String str) {
  //   // 空白の場合、チェックしない
  //   if (String.isBlank(str)) {
  //     return str;
  //   }
  //   return str.removeEnd('さん').removeEnd('様');
  // }

  // public static MonthlyReport__c getReport(Id rId) {
  //   // 勤務表取得
  //   MonthlyReport__c report = [
  //     SELECT
  //       Name,
  //       StartHour__c,
  //       StartTime__c,
  //       EndHour__c,
  //       EndTime__c,
  //       Year__c,
  //       Month__c,
  //       RestTime__c,
  //       Overtime__c,
  //       RejectComment__c,
  //       Contact__c,
  //       Superior__c,
  //       approver__c,
  //       ApproverMail__c,
  //       ReportName__c,
  //       LunchTime__c,
  //       Workplace__c,
  //       ApproverCC__c,
  //       ReportFileName__c,
  //       UndertimeWork__c,
  //       TotalWorkTime__c,
  //       TotalWorkTime2__c,
  //       ProjectName__c,
  //       ProjectCode__c,
  //       ProjectName2__c,
  //       ProjectCode2__c,
  //       ProjectName3__c,
  //       ProjectCode3__c,
  //       OvertimeWork__c,
  //       EmployeeNo__c,
  //       TravelingExpenses__c,
  //       TravelingExpenses2__c,
  //       StatusIcon__c,
  //       ApplicationDateTime__c,
  //       ApproveDateTime__c,
  //       Superior__r.Name,
  //       UserName__c,
  //       Status__c,
  //       WorkDays__c,
  //       StatusForOrder__c,
  //       ReplyMailContent__c,
  //       HaveExpensesDetail__c,
  //       NoonBreakTime__c,
  //       ReportTo__c,
  //       ReportToMail__c,
  //       Contact__r.Email,
  //       Contact__r.Name,
  //       contact__r.ReportTo__c,
  //       contact__r.ReportToMail__c,
  //       Contact__r.PaidVacation__c,
  //       Contact__r.UsedVacation__c,
  //       Contact__r.Account.Name,
  //       contact__r.Account.Abbreviation__c,
  //       contact__r.Account.ReportTo__c,
  //       contact__r.Account.ReportToMail__c,
  //       (
  //         SELECT
  //           Name,
  //           Start__c,
  //           StartHour__c,
  //           StartTime__c,
  //           EndHour__c,
  //           EndTime__c,
  //           End__c,
  //           WorkDay__c,
  //           WorkTime__c,
  //           LunchTime__c,
  //           ProjectRef__c,
  //           ProjectName__c,
  //           IsVacation__c,
  //           IsPaidHoliday__c,
  //           IsBusinessTrip__c,
  //           IsHoliday__c,
  //           IsSubmit__c,
  //           IsSubmitCompany__c,
  //           RestTime__c,
  //           Week__c,
  //           Memo__c,
  //           Workplace__c,
  //           ProjectRef__r.ProjectName__c
  //         FROM MonthlyReportRelation__r
  //         ORDER BY WorkDay__c
  //       ),
  //       (
  //         SELECT
  //           Date__c,
  //           Route__c,
  //           Name,
  //           From__c,
  //           To__c,
  //           FareDate__c,
  //           Direction__c,
  //           OneWayRoundTrip__c,
  //           Amount__c,
  //           IsSubmit__c,
  //           Price__c,
  //           Subtotal__c,
  //           Memo__c
  //         FROM MonthlyReportRelationFare__r
  //         ORDER BY FareDate__c, CreatedDate
  //       ),
  //       (
  //         SELECT Id, Name
  //         FROM Attachments
  //         LIMIT 1
  //       )
  //     FROM MonthlyReport__c
  //     WHERE Id = :rId
  //   ];
  //   return report;
  // }

  // // お客様提出分または会社へ提出分勤務実績取得
  // public static List<WorkTime__c> getWorktimes(List<WorkTime__c> worktimes, Boolean bSubmit) {
  //   List<WorkTime__c> lstWorktime = new List<WorkTime__c>();

  //   for (WorkTime__c wt : worktimes) {
  //     // 会社提出(IsSubmit__c=false or 空白)
  //     if (!bSubmit) {
  //       if (wt.IsSubmit__c != true) {
  //         lstWorktime.add(wt);
  //       }
  //       // 客先提出(IsSubmitCompany__c=false or 空白)
  //     } else {
  //       if (wt.IsSubmitCompany__c != true) {
  //         lstWorktime.add(wt);
  //       }
  //     }
  //   }

  //   return lstWorktime;
  // }

  // // 画面編集より客先提出フラグと会社提出フラグを統一する
  // public static void ayscIsSubmitCompanyFlag(Id rId) {
  //   MonthlyReport__c report = getReport(rId);
  //   // 勤務実績(会社提出)
  //   List<WorkTime__c> workDays1 = ReportUtility.getWorktimes(report.MonthlyReportRelation__r, false);
  //   Map<Date, WorkTime__c> mapWorkDays1 = new Map<Date, WorkTime__c>();
  //   for (WorkTime__c wt : workDays1) {
  //     mapWorkDays1.put(wt.WorkDay__c, wt);
  //   }
  //   // 勤務実績(客先提出)
  //   List<WorkTime__c> workDays2 = ReportUtility.getWorktimes(report.MonthlyReportRelation__r, true);
  //   Map<Date, WorkTime__c> mapWorkDays2 = new Map<Date, WorkTime__c>();
  //   for (WorkTime__c wt : workDays2) {
  //     if (wt.IsSubmit__c) {
  //       mapWorkDays2.put(wt.WorkDay__c, wt);
  //     }
  //   }

  //   // 客先提出レコードがあった場合、会社提出レコードに会社提出フラグをたてる
  //   for (Date day : mapWorkDays2.keySet()) {
  //     if (mapWorkDays1.containsKey(day)) {
  //       mapWorkDays1.get(day).IsSubmitCompany__c = true;
  //     }
  //   }

  //   // 会社提出レコードだけの場合、会社提出フラグをはずす
  //   for (WorkTime__c wt : workDays1) {
  //     if (!mapWorkDays2.containsKey(wt.WorkDay__c)) {
  //       wt.IsSubmitCompany__c = false;
  //     }
  //   }

  //   update workDays1;
  // }

  // public static Boolean getReadonlyMode(MonthlyReport__c report, UserInfoDto userInfo) {
  //   List<String> READONLY_STATUS = new List<String>{ '作成完了', '申請中', '承認済', 'クローズ' };

  //   // 下記のケースは修正不可とする
  //   // 1. 申請中と承認済
  //   // 2. 先々月～再来月以外の勤務表
  //   // 3. 本人ではない(承認者)
  //   if (
  //     report.Contact__c != userInfo.con.Id ||
  //     READONLY_STATUS.contains(report.Status__c) ||
  //     ReportUtility.bReadonlyFromYM(report.Year__c, report.Month__c)
  //   ) {
  //     return true;
  //   }
  //   return false;
  // }

  // // 文字列比較
  // public static Boolean bEquals(String str1, String str2) {
  //   if (str1 == null) {
  //     return str2 == null;
  //   }
  //   return str1.equals(str2);
  // }

  // // 会社提出と客先提出メモマージ
  // @TestVisible
  // private static String mergeMemo(String memo1, String memo2) {
  //   memo1 = memo1 == null ? '' : memo1;

  //   // memo2なし or memo1とmemo2同じ
  //   if (String.isBlank(memo2) || memo1 == memo2) {
  //     return memo1;
  //   }

  //   // memo1なし
  //   if (String.isBlank(memo1)) {
  //     return memo2;
  //   }
  //   return memo1 + '<br/>' + memo2;
  // }

  // // 交通費をマスタに設定処理
  // public static void setFarePriceMaster(Fare__c fare) {
  //   List<Fare__c> fares = new List<Fare__c>();
  //   fares.add(fare);
  //   ReportUtility.setFarePriceMaster(fares);
  // }

  // // 交通費をマスタに設定処理
  // public static void setFarePriceMaster(List<Fare__c> fares) {
  //   Map<String, Fare__c> mapFare1 = new Map<String, Fare__c>();
  //   Map<String, String> mapFare2 = new Map<String, String>();
  //   for (Fare__c fare : fares) {
  //     String f = getStationName(fare.From__c);
  //     String t = getStationName(fare.To__c);
  //     String v = getStationName(fare.Via__c);
  //     String key1 = f + v + t;
  //     String key2 = t + v + f;
  //     mapFare1.put(key1, fare);
  //     mapFare2.put(key2, key1);
  //   }

  //   // 交通費マスタ検索
  //   List<CommonMaster__c> masters = [
  //     SELECT Name, From__c, To__c, Via__c, Price__c, MonthlyPrice__c
  //     FROM CommonMaster__c
  //     WHERE RecordType.DeveloperName = 'Fare' AND (Name = :mapFare1.keySet() OR Name = :mapFare2.keySet())
  //   ];

  //   for (CommonMaster__c master : masters) {
  //     String f = getStationName(master.From__c);
  //     String t = getStationName(master.To__c);
  //     String v = getStationName(master.Via__c);
  //     String key1 = f + v + t;
  //     String key2 = t + v + f;

  //     fare__c fare1 = null;
  //     if (mapFare1.containsKey(key1)) {
  //       fare1 = mapFare1.get(key1);
  //     } else if (mapFare2.containsKey(key1)) {
  //       fare1 = mapFare1.get(mapFare2.get(key1));
  //     }

  //     // 内容は同じの場合、なにもしないMapから削除する
  //     if (fare1 != null) {
  //       if (fare1.OneWayRoundTrip__c == '定期') {
  //         if (master.MonthlyPrice__c == null || master.MonthlyPrice__c == 0) {
  //           master.MonthlyPrice__c = fare1.Price__c;
  //         }
  //       } else {
  //         if (master.Price__c == null || master.Price__c == 0) {
  //           master.Price__c = fare1.Price__c;
  //         }
  //       }

  //       if (
  //         (fare1.OneWayRoundTrip__c == '定期' && fare1.Price__c == master.MonthlyPrice__c) ||
  //         (fare1.OneWayRoundTrip__c != '定期' &&
  //         fare1.Price__c == master.Price__c)
  //       ) {
  //         if (mapFare1.containsKey(key1)) {
  //           mapFare1.remove(key1);
  //         } else {
  //           mapFare1.remove(mapFare2.get(key1));
  //         }
  //       }
  //     }
  //   }

  //   update masters;

  //   Id recordTypeId = getRecordtypeId('CommonMaster__c', 'Fare');
  //   List<CommonMaster__c> lstForInsert = new List<CommonMaster__c>();
  //   for (fare__c f : mapFare1.values()) {
  //     if (f.Price__c == 0 || f.Price__c == null) {
  //       continue;
  //     }
  //     CommonMaster__c m = new CommonMaster__c();
  //     m.From__c = f.From__c;
  //     m.To__c = f.To__c;
  //     m.Via__c = f.Via__c;
  //     m.recordTypeId = recordTypeId;
  //     if (f.OneWayRoundTrip__c == '定期') {
  //       m.MonthlyPrice__c = f.Price__c;
  //     } else {
  //       m.Price__c = f.Price__c;
  //     }
  //     lstForInsert.add(m);
  //   }
  //   if (lstForInsert.size() > 0) {
  //     insert lstForInsert;
  //   }
  // }

  // // 駅名に駅を削除する
  // public static String getStationName(String str) {
  //   if (str == null) {
  //     return '';
  //   }
  //   if (str.endswith('駅')) {
  //     return str.left(str.length() - 1);
  //   }
  //   return str;
  // }

  // // マスタから交通費を取得する処理
  // public static decimal getFarePriceFromMaster(String f, String v, String t, Boolean bMonthly) {
  //   Decimal retVal = 0;
  //   if (String.isBlank(f) || String.isBlank(t)) {
  //     return retVal;
  //   }

  //   // 後ろついている駅を削除する
  //   if (f.endswith('駅')) {
  //     f = f.left(f.length() - 1);
  //   }

  //   if (t.endswith('駅')) {
  //     t = t.left(t.length() - 1);
  //   }

  //   if (v != null && v.endswith('駅')) {
  //     v = v.left(v.length() - 1);
  //   }

  //   // 交通費マスタ検索
  //   List<CommonMaster__c> lstMaster = [
  //     SELECT Name, Via__c, Price__c, MonthlyPrice__c
  //     FROM CommonMaster__c
  //     WHERE RecordType.DeveloperName = 'Fare' AND ((From__c = :f AND To__c = :t) OR (From__c = :t AND To__c = :f))
  //   ];

  //   for (CommonMaster__c master : lstMaster) {
  //     Decimal price = (master.Price__c == null) ? 0 : master.Price__c;
  //     Decimal monthly = (master.MonthlyPrice__c == null) ? 0 : master.MonthlyPrice__c;
  //     if (bMonthly) {
  //       retVal = monthly;
  //     } else {
  //       retVal = price;
  //     }
  //     if (v == master.Via__c) {
  //       break;
  //     }
  //   }
  //   return retVal;
  // }

  // // 勤務実績加工処理
  // public static List<WorkTime> getWorktimes(MonthlyReport__c report) {
  //   // 勤務実績表示データ加工
  //   List<WorkTime> lstWorkTimes = new List<WorkTime>();
  //   List<WorkTime__c> worktimes1 = getWorktimes(report.MonthlyReportRelation__r, false);
  //   List<WorkTime__c> worktimes2 = getWorktimes(report.MonthlyReportRelation__r, true);
  //   Map<Date, WorkTime__c> mapWorktime2 = new Map<Date, WorkTime__c>();
  //   for (WorkTime__c wt : worktimes2) {
  //     if (wt.IsSubmit__c) {
  //       mapWorktime2.put(wt.WorkDay__c, wt);
  //     }
  //   }
  //   // 客先提出と会社提出の備考をマージし表示する
  //   for (WorkTime__c wt : worktimes1) {
  //     WorkTime__c wt2 = mapWorktime2.get(wt.WorkDay__c);
  //     if (wt2 != null) {
  //       wt.Memo__c = ReportUtility.mergeMemo(wt.Memo__c, wt2.Memo__c);
  //       // 有給休暇の場合、時間の表示は不要
  //       if (!wt2.IsPaidHoliday__c) {
  //         if (String.isBlank(wt.Memo__c)) {
  //           wt.Memo__c = '客先提出：' + wt2.Start__c + '～' + wt2.End__c;
  //         } else {
  //           wt.Memo__c += '<br/>客先提出：' + wt2.Start__c + '～' + wt2.End__c;
  //         }
  //       }
  //     }
  //   }

  //   if (worktimes1.size() > 0) {
  //     Integer rows = worktimes1.size() / 2 + Math.mod(worktimes1.size(), 2);
  //     for (Integer i = 0; i < rows; i++) {
  //       WorkTime__c wt2;
  //       Integer idx2 = rows + i;
  //       if (idx2 < worktimes1.size()) {
  //         wt2 = worktimes1[idx2];
  //       }
  //       WorkTime work = new WorkTime(worktimes1[i], wt2);
  //       lstWorkTimes.add(work);
  //     }
  //   }

  //   return lstWorkTimes;
  // }

  // // 年月プルダウン取得
  // public static String[] getYMPicklist(Date dt) {
  //   List<String> lstStr = new List<String>();
  //   String yyyy = String.valueOf(dt.year());
  //   lstStr.add(yyyy);
  //   Integer m = dt.month();
  //   String mm = String.valueOf(m).leftPad(2, '0');
  //   lstStr.add(mm);
  //   return lstStr;
  // }

  // // 勤務実績一括作成
  // public static void doCreateHoliday(String sYear) {
  //   // 祝日を取得する
  //   Integer year = Integer.valueOf(sYear);
  //   List<Holiday__c> holidays = [
  //     SELECT Id
  //     FROM Holiday__c
  //     WHERE CALENDAR_YEAR(Date__c) = :year
  //   ];

  //   if (holidays.isEmpty()) {
  //     try {
  //       // google calendar api v3で祝日取得する
  //       holidays = CommonUtility.getHolidays(Integer.valueOf(year), Label.GoogleApiKey);
  //       // DB登録
  //       insert holidays;
  //     } catch (Exception e) {
  //       // テストぅラスなどエラーが発生してもなにもしない
  //     }
  //   }
  // }

  // // 勤務実績一括作成
  // public static void doCreateWorkTime(MonthlyReport__c report) {
  //   // 祝日を取得する
  //   Integer year = Integer.valueOf(report.Year__c);
  //   List<Holiday__c> holidays = [
  //     SELECT Date__c, Description__c
  //     FROM Holiday__c
  //     WHERE CALENDAR_YEAR(Date__c) = :year
  //     ORDER BY Date__c
  //   ];

  //   Map<Integer, String> mapHoliday = new Map<Integer, String>();
  //   for (Holiday__c h : holidays) {
  //     if (
  //       h.Date__c.Year() == Integer.valueOf(report.Year__c) &&
  //       h.Date__c.Month() == Integer.valueOf(report.Month__c)
  //     ) {
  //       mapHoliday.put(h.Date__c.day(), h.Description__c);
  //     }
  //   }

  //   // 勤務実績取得
  //   List<WorkTime__c> works = [
  //     SELECT Id, Name
  //     FROM WorkTime__c
  //     WHERE MonthlyReport__c = :report.Id
  //   ];
  //   delete works;

  //   // 当月日数取得
  //   Integer numberDays = Date.daysInMonth(Integer.valueOf(report.Year__c), Integer.valueOf(report.Month__c));
  //   List<WorkTime__c> monWorks = new List<WorkTime__c>();
  //   for (Integer i = 1; i <= numberDays; i++) {
  //     String day = String.valueOf(i).leftPad(2, '0');

  //     // 日付
  //     Datetime dt = Datetime.valueOf(report.Year__c + '-' + report.Month__c + '-' + day + ' 00:00:00');
  //     String week = dt.format('E');

  //     WorkTime__c work = new WorkTime__c();
  //     // 実績日
  //     work.WorkDay__c = dt.date();
  //     // 参照関係
  //     work.MonthlyReport__c = report.Id;

  //     // デフォルトプロジェクト
  //     if (String.isNotBlank(report.ProjectName__c)) {
  //       work.ProjectName__c = report.ProjectName__c.split(',')[0];
  //     } else {
  //       Map<Id, String> mapProject = getProjectInfo(report.Year__c, report.Month__c, report.Contact__c);
  //       for (String key : mapProject.keySet()) {
  //         work.ProjectRef__c = key;
  //       }
  //     }

  //     // デフォルト作業場所
  //     if (String.isNotBlank(report.Workplace__c)) {
  //       work.Workplace__c = report.Workplace__c.split(';')[0];
  //     }

  //     // 休憩（分）
  //     if (report.RestTime__c != null) {
  //       work.RestTime__c = report.RestTime__c;
  //     }
  //     // 開始時間
  //     if (report.StartHour__c != null && report.StartTime__c != null) {
  //       work.StartHour__c = report.StartHour__c;
  //       work.StartTime__c = report.StartTime__c;
  //     } else {
  //       work.StartHour__c = '09';
  //       work.StartTime__c = '00';
  //     }
  //     // 終了時間
  //     if (report.EndHour__c != null && report.EndTime__c != null) {
  //       work.EndHour__c = report.EndHour__c;
  //       work.EndTime__c = report.EndTime__c;
  //     } else {
  //       work.EndHour__c = '17';
  //       work.EndTime__c = '30';
  //     }

  //     // 祝日の場合
  //     if (mapHoliday.containsKey(i)) {
  //       work.IsVacation__c = true;
  //       work.Memo__c = mapHoliday.get(i);
  //       work.IsHoliday__c = true;
  //       work.ProjectName__c = null;
  //       work.ProjectRef__c = null;
  //       work.Workplace__c = null;
  //     }

  //     if (week == 'Sun' || week == 'Sat') {
  //       work.StartHour__c = '00';
  //       work.StartTime__c = '00';
  //       work.EndHour__c = '00';
  //       work.EndTime__c = '00';
  //       work.RestTime__c = 0;
  //       work.ProjectName__c = null;
  //       work.ProjectRef__c = null;
  //       work.IsHoliday__c = true;
  //       work.IsVacation__c = true;
  //       work.Workplace__c = null;
  //     }

  //     // Insert対象に追加
  //     monWorks.add(work);
  //   }

  //   // データ登録
  //   insert monWorks;
  // }

  // public static List<String> getProjectIds(String y, String m, String conId) {
  //   Map<Id, String> mapProject = getProjectInfo(y, m, conId);
  //   List<String> projectIds = new List<String>();
  //   for (String prjId : mapProject.keySet()) {
  //     projectIds.add(prjId);
  //   }
  //   return projectIds;
  // }

  // public static List<String> getProjects(String y, String m, String conId) {
  //   Map<Id, String> mapProject = getProjectInfo(y, m, conId);
  //   return mapProject.values();
  // }

  // // 担当案件名
  // public static Map<Id, String> getProjectInfo(String y, String m, String conId) {
  //   // 要員で案件を検索する
  //   String ym = y + '/' + m;
  //   List<MemberInfo__c> memberLst = [
  //     SELECT ProjectRef__r.ProjectName__c
  //     FROM MemberInfo__c
  //     WHERE WorkYearMonth__c = :ym AND PicRef__c = :conId
  //   ];

  //   Map<Id, String> mapProject = new Map<Id, String>();
  //   for (MemberInfo__c member : memberLst) {
  //     mapProject.put(member.ProjectRef__c, member.ProjectRef__r.ProjectName__c);
  //   }
  //   return mapProject;
  // }

  // // プロジェクト選択リスト値
  // public static List<SelectOption> getProjectSelectOption(String y, String m, String conId) {
  //   Map<Id, String> mapProject = getProjectInfo(y, m, conId);

  //   // 選択リスト値を作成する
  //   List<SelectOption> options = new List<SelectOption>();
  //   options.add(new SelectOption('', ''));

  //   for (String key : mapProject.keySet()) {
  //     options.add(new SelectOption(key, mapProject.get(key)));
  //   }

  //   return options;
  // }

  // // 前月以前の定期コピー
  // public static String doCopyPrevFare(MonthlyReport__c report) {
  //   // 前月以前の定期を取得する
  //   List<Fare__c> fares = [
  //     SELECT MonthlyReport__c
  //     FROM Fare__c
  //     WHERE
  //       MonthlyReport__r.Contact__c = :report.Contact__c
  //       AND OneWayRoundTrip__c IN ('定期', 'バス代', '駐輪場')
  //       AND (MonthlyReport__r.Year__c < :report.Year__c
  //       OR (MonthlyReport__r.Year__c = :report.Year__c
  //       AND MonthlyReport__r.Month__c < :report.Month__c))
  //     ORDER BY FareDate__c DESC
  //     LIMIT 1
  //   ];

  //   String msg = '前月以前の定期情報が見つかりません。';

  //   if (!fares.isEmpty()) {
  //     fares = [
  //       SELECT From__c, To__c, Price__c, FareDate__c, OneWayRoundTrip__c
  //       FROM Fare__c
  //       WHERE MonthlyReport__c = :fares[0].MonthlyReport__c AND OneWayRoundTrip__c IN ('定期', 'バス代', '駐輪場')
  //     ];

  //     List<Fare__c> newFares = new List<Fare__c>();
  //     for (Fare__c fare : fares) {
  //       Fare__c newFare = fare.clone();
  //       newFare.FareDate__c = Date.newInstance(Integer.valueOf(report.Year__c), Integer.valueOf(report.Month__c), 1);
  //       newFare.MonthlyReport__c = report.Id;
  //       newFares.add(newFare);
  //     }

  //     try {
  //       if (newFares.size() > 0) {
  //         insert newFares;
  //       }
  //     } catch (DmlException e) {
  //       for (Integer i = 0; i < e.getNumDml(); i++) {
  //         ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getDmlMessage(i)));
  //       }
  //       return '';
  //     }
  //     msg = '前月の定期をコピーしました。';
  //   }
  //   return msg;
  // }

  // // 打刻処理
  // public static void doClockInOut(MonthlyReport__c report, List<worktime> lstWorkTimes) {
  //   WorkTime__c wt1 = getWorktime(lstWorkTimes, Date.Today());
  //   // 当日実績が無かった場合、エラーとする
  //   if (wt1 == null) {
  //     // メッセージを出す
  //     ApexPages.addMessage(
  //       new ApexPages.Message(ApexPages.Severity.ERROR, '今日の実績がありません。勤務実績を作成してください。')
  //     );
  //     return;
  //   }

  //   // 有給休暇の場合、打刻できない
  //   if (wt1.IsPaidHoliday__c) {
  //     ApexPages.addMessage(
  //       new ApexPages.Message(ApexPages.Severity.ERROR, '今日は有給休暇なので、打刻することができません。')
  //     );
  //     return;
  //   }

  //   // 休みの場合、チェックを外す
  //   // 徹夜など日を跨る場合はレアケースなので、考慮しない
  //   WorkTime__c wt = new WorkTime__c(Id = wt1.Id);
  //   if (wt1.IsVacation__c) {
  //     wt.IsVacation__c = false;
  //     if (wt1.Memo__c == '全休') {
  //       wt.Memo__c = '';
  //     }
  //     wt.StartHour__c = report.StartHour__c;
  //     wt.StartTime__c = report.StartTime__c;
  //     wt.EndHour__c = report.EndHour__c;
  //     wt.EndTime__c = report.EndTime__c;
  //     wt.RestTime__c = report.RestTime__c;
  //     if (String.isNotblank(report.ProjectName__c)) {
  //       wt.ProjectName__c = report.ProjectName__c.split(',')[0];
  //     } else {
  //       List<String> projectIds = getProjectIds(report.Year__c, report.Month__c, report.Contact__c);
  //       wt.ProjectRef__c = projectIds.size() > 0 ? projectIds[0] : null;
  //     }
  //   }

  //   // 午後２時までは出勤、以降は退勤と見なす
  //   Datetime dt = System.Now();
  //   Boolean isAM = dt.hour() > 14 ? false : true;

  //   // 15分単位で丸める
  //   Integer adjust = 0;
  //   Integer over_minute = Math.mod(dt.minute(), 15);
  //   // 15単位内七捨八入にする
  //   if (over_minute > 7) {
  //     adjust = 15 - over_minute;
  //   } else {
  //     adjust = -over_minute;
  //   }

  //   // 出退勤時間を決める
  //   Datetime dt1 = dt.addMinutes(adjust);
  //   String h = String.valueOf(dt1.hour()).leftPad(2, '0');
  //   String m = String.valueOf(dt1.minute()).leftPad(2, '0');
  //   String msg;
  //   if (isAM) {
  //     wt.StartHour__c = h;
  //     wt.StartTime__c = m;
  //     wt.ClockInDatetime__c = System.now();
  //     msg = 'おはようございます！<br/>現在の時刻で打刻しました。';
  //   } else {
  //     wt.EndHour__c = h;
  //     wt.EndTime__c = m;
  //     wt.ClockOutDatetime__c = System.now();
  //     msg = '現在の時刻で打刻しました。<br/>お疲れ様でした！';
  //   }

  //   // 更新
  //   update wt;

  //   // メッセージ
  //   ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, msg));
  // }

  // // 当日の実績を取得する
  // private static WorkTime__c getWorktime(List<worktime> lstWorkTimes, Date dt) {
  //   WorkTime__c wt;
  //   if (lstWorkTimes != null) {
  //     for (worktime work : lstWorkTimes) {
  //       if (work.wt1.WorkDay__c == dt) {
  //         wt = work.wt1;
  //         break;
  //       } else if (work.wt2.WorkDay__c == dt) {
  //         wt = work.wt2;
  //         break;
  //       } else {
  //         continue;
  //       }
  //     }
  //   }
  //   return wt;
  // }

  // // 半角数字⇒全角数字
  // public static string changeHalfToZenNum(string s) {
  //   if (String.isBlank(s)) {
  //     return '';
  //   }

  //   String ret = '';
  //   for (Integer i = 0; i < s.length(); i++) {
  //     String str = s.substring(i, i + 1);
  //     if (halfToZenNumMap.containsKey(str)) {
  //       ret += halfToZenNumMap.get(str);
  //     } else {
  //       ret += str;
  //     }
  //   }
  //   return ret;
  // }

  // public static String getYYYYMM(Date dt) {
  //   if (dt == null)
  //     return '';
  //   Datetime dt1 = Datetime.newInstance(dt, Time.newInstance(0, 0, 0, 0));
  //   return dt1.format('yyyy/MM');
  // }

  // public static String[] getYYYYMMArray(Date dt) {
  //   List<String> arr = new List<String>{ '', '' };

  //   if (dt == null) {
  //     return arr;
  //   }
  //   arr[0] = String.valueOf(dt.year());
  //   arr[1] = String.valueOf(dt.month()).leftPad(2, '0');

  //   return arr;
  // }

  // // 先々月～再来月以外の勤務表をReadonlyにする
  // public static Boolean bReadonlyFromYM(String y, String m) {
  //   Date reportDT = Date.newInstance(Integer.valueOf(y), Integer.valueOf(m), 1);
  //   Integer months = Date.Today().monthsBetween(reportDT);
  //   Boolean bReadonly = months >= 3 || months <= -3;
  //   // １月１５日以降で既に締めのため、去年１２月以前の勤務表を編集することができない
  //   if (Date.Today().Month() == 1 && Date.Today().Day() >= 15) {
  //     if (months <= -1) {
  //       bReadonly = true;
  //     }
  //   }
  //   return bReadonly;
  // }

  // // site url
  // public static String getSiteUrl(String siteName) {
  //   if (!bSiteUser() || String.isBlank(siteName)) {
  //     return '';
  //   }

  //   siteName = siteName.remove('/');
  //   Site site = [SELECT GuestUserId, Name, Subdomain, UrlPathPrefix FROM Site WHERE Name = :siteName];
  //   Organization org = [SELECT InstanceName, IsSandbox, OrganizationType FROM Organization];
  //   User kanri = [SELECT UserName FROM User WHERE Profile.Name = 'システム管理者' LIMIT 1];
  //   String sandboxName = kanri.UserName.substringAfterLast('.');
  //   String siteFullUrl;
  //   if (org.IsSandbox) {
  //     siteFullUrl = 'http://' + sandboxName + '-' + site.Subdomain + '.';
  //   } else {
  //     siteFullUrl = 'http://' + site.Subdomain + '.';
  //   }
  //   siteFullUrl +=
  //     (org.IsSandbox || org.OrganizationType == 'Developer Edition' ? (org.InstanceName.toLowerCase() + '.') : '') +
  //     'force.com';
  //   if (site.UrlPathPrefix != null) {
  //     siteFullUrl += '/' + site.UrlPathPrefix;
  //   }
  //   return siteFullUrl;
  // }

  // 勤務時間計算
  public static WorkTime__c calcWorkTime(WorkTime__c w) {
    if (!w.isVacation__c || w.IsPaidHoliday__c) {
      if (w.RestTime__c == null)
        w.RestTime__c = 0;
      Time startTime = Time.newInstance(Integer.valueOf(w.StartHour__c), Integer.valueOf(w.startTime__c), 0, 0);
      Time endTime = Time.newInstance(Integer.valueOf(w.EndHour__c), Integer.valueOf(w.EndTime__c), 0, 0);
      decimal t =
        ((Integer.valueOf(w.EndHour__c) - Integer.valueOf(w.StartHour__c)) * 60 +
        Integer.valueOf(w.EndTime__c) -
        Integer.valueOf(w.StartTime__c) -
        w.RestTime__c) / 60.0;
      if (startTime > endTime) {
        // 徹夜
        t =
          ((Integer.valueOf(w.EndHour__c) + 24 - Integer.valueOf(w.StartHour__c)) * 60 +
          Integer.valueOf(w.EndTime__c) -
          Integer.valueOf(w.StartTime__c) -
          w.RestTime__c) / 60.0;
      }
      w.WorkTime__c = t;
      if (w.WorkTime__c < 0)
        w.WorkTime__c = 0;
    } else {
      w.StartTime__c = '00';
      w.EndTime__c = '00';
      w.StartHour__c = '00';
      w.EndHour__c = '00';
      w.RestTime__c = 0;
      w.WorkTime__c = 0;
    }
    return w;
  }

  // // 昼休憩過ぎた時出社した場合の時間調整
  // public static WorkTime__c adjustWorktime(WorkTime__c w) {
  //   if (w.RestTime__c == null)
  //     w.RestTime__c = 0;
  //   // 出社時間
  //   Time start = Time.NewInstance(Integer.valueOf(w.StartHour__c), Integer.valueOf(w.StartTime__c), 0, 0);
  //   // 昼開始時間
  //   Integer lunchHour = Integer.valueOf(w.LunchTime__c.split(':')[0]);
  //   Integer lunchTime = Integer.valueOf(w.LunchTime__c.split(':')[1]);
  //   Time lunchStart = Time.NewInstance(lunchHour, lunchTime, 0, 0);
  //   // 昼終了時間
  //   Time lunchEnd = lunchStart.addMinutes(Integer.valueOf(w.RestTime__c));
  //   if (start >= lunchStart) {
  //     w.RestTime__c = 0;
  //     // 昼休み中の場合、出社時間を昼終了時間に調整
  //     if (start < lunchEnd) {
  //       w.StartHour__c = String.valueOf(lunchEnd.hour()).leftPad(2, '0');
  //       w.StartTime__c = String.valueOf(lunchEnd.minute()).leftPad(2, '0');
  //     }
  //   }
  //   return w;
  // }

  // public static Boolean CreateVacation(String reportId) {
  //   // 勤務表情報
  //   MonthlyReport__c report = [
  //     SELECT Contact__c, SubmitDate__c
  //     FROM MonthlyReport__c
  //     WHERE Id = :reportId
  //   ];

  //   Date firstDate = report.SubmitDate__c.toStartOfMonth();
  //   list<Vacation__c> lstForDelete = [
  //     SELECT Id
  //     FROM Vacation__c
  //     WHERE Contact__c = :report.Contact__c AND TargetDate__c <= :report.SubmitDate__c AND TargetDate__c >= :firstDate
  //   ];

  //   // 勤務実績から有給を抽出する
  //   List<WorkTime__c> lstWorkTime = [
  //     SELECT WorkDay__c, MonthlyReport__r.Contact__c
  //     FROM WorkTime__c
  //     WHERE MonthlyReport__c = :reportId AND IsPaidHoliday__c = TRUE AND IsSubmit__c != TRUE
  //   ];

  //   list<Vacation__c> lstForInsert = new List<Vacation__c>();
  //   for (WorkTime__c w : lstWorkTime) {
  //     Vacation__c vacation = new Vacation__c();
  //     vacation.Contact__c = w.MonthlyReport__r.Contact__c;
  //     vacation.RestFlag__c = '全休';
  //     vacation.TargetDate__c = w.WorkDay__c;
  //     lstForInsert.add(vacation);
  //   }

  //   try {
  //     if (lstForDelete.size() > 0)
  //       delete lstForDelete;
  //     if (lstForInsert.size() > 0)
  //       insert lstForInsert;
  //   } catch (DmlException e) {
  //     for (Integer i = 0; i < e.getNumDml(); i++) {
  //       ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getDmlMessage(i)));
  //     }
  //     return false;
  //   }
  //   return true;
  // }

  // // 組織のメールアドレスIdを取得する
  // public static Id getOrgWideEmailAddressId(String displayName) {
  //   // 表示名(DiplayName)またはメールアドレス(Address)で検索
  //   List<OrgWideEmailAddress> wideMails = [
  //     SELECT Address, DisplayName
  //     FROM OrgWideEmailAddress
  //     WHERE DisplayName = :displayName OR Address = :displayName
  //     LIMIT 1
  //   ];
  //   if (wideMails.isEmpty()) {
  //     return null;
  //   }
  //   return wideMails[0].Id;
  // }

  // public static string GetAccessTokenFromSalarySandbox() {
  //   Auth.JWT jwt = new Auth.JWT();
  //   jwt.setSub('outaku.go@grids.co.jp.salary');
  //   jwt.setAud('https://test.salesforce.com');
  //   jwt.setIss('3MVG959Nd8JMmavT2.skN2MSUW1_mtsEsVoJq52zAy6zlnZvnwpZSsHITdkauyMrcsPV2qafxoBXJ8gJIEeBU');

  //   //Create the object that signs the JWT bearer token
  //   Auth.JWS jws = new Auth.JWS(jwt, 'WorkReportSystem');

  //   //Get the resulting JWS in case debugging is required
  //   String token = jws.getCompactSerialization();

  //   //Set the token endpoint that the JWT bearer token is posted to
  //   String tokenEndpoint = 'https://test.salesforce.com/services/oauth2/token';

  //   //POST the JWT bearer token
  //   Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(tokenEndpoint, jws);

  //   //Get the access token
  //   return bearer.getAccessToken();
  // }

  // // 月末日を求める
  // public static Date getMonthEndDay(Integer year, Integer month) {
  //   if (year == null || month == null)
  //     return null;
  //   Date nextMonthStartDay = Date.newInstance(year, month, 1);
  //   Date thisMonthEndDay = nextMonthStartDay.addmonths(1).addDays(-1);
  //   return thisMonthEndDay;
  // }

  // // Recordtype Idを求める
  // public static String getRecordtypeId(String objectName, String rtName) {
  //   RecordType rt;
  //   try {
  //     rt = [
  //       SELECT Id
  //       FROM RecordType
  //       WHERE SobjectType = :objectName AND DeveloperName = :rtName AND IsActive = TRUE
  //     ];
  //   } catch (Exception e) {
  //     return null;
  //   }

  //   return rt.Id;
  // }

  // public static Boolean IsSameObject(String sfdcId1, String sfdcId2) {
  //   if (sfdcId1 != null && sfdcId2 != null) {
  //     sfdcId1 = sfdcId1.toLowerCase();
  //     sfdcId2 = sfdcId2.toLowerCase();
  //     if (sfdcId1.length() > 15) {
  //       sfdcId1 = sfdcId1.left(15);
  //     }
  //     if (sfdcId2.length() > 15) {
  //       sfdcId2 = sfdcId2.left(15);
  //     }
  //   }
  //   return sfdcId1 == sfdcId2;
  // }

  // // VF画面URL取得(client用)
  // public static String getVisualforceUrl(PageReference pageRef) {
  //   return getVisualforceUrl(pageRef, null);
  // }

  // // VF画面URL取得(client用)
  // public static String getVisualforceUrl(PageReference pageRef, Map<String, String> params) {
  //   User user = [
  //     SELECT UserType
  //     FROM User
  //     WHERE Id = :UserInfo.getUserId()
  //   ];
  //   // パラメーター
  //   if (params != null) {
  //     for (String k : params.keySet()) {
  //       pageRef.getParameters().put(k, params.get(k));
  //     }
  //   }
  //   String url = pageRef.getUrl();
  //   // サイトユーザ
  //   if (bSiteUser()) {
  //     url = url.replace('/apex/', Site.getPathPrefix() + '/');
  //   }
  //   return url;
  // }

  // public static String getCurrentUserContactId() {
  //   // サイトユーザ
  //   if (bSiteUser()) {
  //     return '';
  //   }

  //   // コミュニティユーザ
  //   if (bCommunityUser()) {
  //     User user = [
  //       SELECT ContactId
  //       FROM User
  //       WHERE Id = :UserInfo.getUserId()
  //     ];
  //     return user.ContactId;
  //   }

  //   // 一般Salesforceユーザ
  //   List<Contact> contacts = [
  //     SELECT Id
  //     FROM Contact
  //     WHERE SfdcUser__c = :UserInfo.getUserId()
  //   ];
  //   if (contacts.size() > 0) {
  //     return contacts[0].Id;
  //   }
  //   return '';
  // }

  // public static Boolean bSiteUser() {
  //   return Test.isRunningTest() || UserInfo.getUserType() == 'Guest';
  // }

  // public static Boolean bCommunityUser() {
  //   return UserInfo.getUserType() == 'PowerPartner';
  // }

  // public static Boolean bCreator(Sobject o, String conId) {
  //   String creator = (String) o.get('CreatedBy__c');
  //   if (o == null || String.isBlank(creator)) {
  //     return false;
  //   }
  //   return creator == conId;
  // }

  // public static String getVisualforceUrl(String url, Map<String, String> params) {
  //   PageReference pageRef;
  //   // サイトユーザ
  //   if (bSiteUser()) {
  //     if (url.contains('/apex/')) {
  //       url = url.replace('/apex/', Site.getPathPrefix() + '/');
  //     } else {
  //       url = Site.getPathPrefix() + url;
  //     }
  //   }
  //   pageRef = new PageReference(url);

  //   // パラメーター
  //   if (params != null) {
  //     for (String k : params.keySet()) {
  //       pageRef.getParameters().put(k, params.get(k));
  //     }
  //   }
  //   return pageRef.getUrl();
  // }

  // // APEXメール送信
  // public static void sendEmail(
  //   String replyTo,
  //   String senderDisplayName,
  //   String[] toAddresses,
  //   String[] ccAddresses,
  //   String subject,
  //   String plainTextBody,
  //   Messaging.EmailFileAttachment[] emailAttachments
  // ) {
  //   List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
  //   Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
  //   // 返信先
  //   if (String.isNotblank(replyTo)) {
  //     message.setReplyTo(replyTo);
  //   }
  //   // 送信者名
  //   if (String.isNotblank(senderDisplayName)) {
  //     message.setSenderDisplayName(senderDisplayName);
  //   }
  //   // 宛先
  //   message.setToAddresses(toAddresses);
  //   // CC
  //   if (ccAddresses != null) {
  //     message.setCcAddresses(ccAddresses);
  //   }
  //   // 件名
  //   message.setSubject(subject);
  //   // text本文
  //   message.setPlainTextBody(plainTextBody);

  //   // 勤務表を添付する
  //   message.setFileAttachments(emailAttachments);
  //   messages.add(message);
  //   // 送信
  //   Messaging.sendEmail(messages);
  // }

  // // 社員保存
  // public static void updateContact(Contact con) {
  //   update con;
  // }

  // // モバイルチェック
  // public static Boolean isMobileDevice() {
  //   if (!Test.isRunningTest()) {
  //     Map<String, String> headerlist = ApexPages.currentPage().getHeaders();
  //     String userAgent = headerList.get('User-Agent');
  //     return (userAgent.contains('Android') ||
  //     userAgent.contains('BlackBerry') ||
  //     userAgent.contains('IEMobile') ||
  //     userAgent.contains('iPad') ||
  //     userAgent.contains('iPhone') ||
  //     userAgent.contains('iPod'));
  //   }
  //   return false;
  // }

  // // 整数チェック
  // public static Boolean isNumber(String str) {
  //   if (String.isBlank(str)) {
  //     return false;
  //   }
  //   try {
  //     Integer v = Integer.valueOf(str);
  //   } catch (Exception e) {
  //     return false;
  //   }
  //   return true;
  // }

  // // 画面VF名
  // public static String getCurrentVfName() {
  //   String url = ApexPages.CurrentPage().getUrl();
  //   if (url == null) {
  //     return '';
  //   }
  //   String keyword;
  //   if (url.contains('/apex/')) {
  //     keyword = '/apex/';
  //   }
  //   if (url.contains('/' + Site.getPathPrefix() + '/')) {
  //     keyword = '/' + Site.getPathPrefix() + '/';
  //   }
  //   if (String.isNotblank(keyword)) {
  //     String s1 = url.split(keyword)[1];
  //     return s1.split('\\?')[0];
  //   }

  //   return '';
  // }

  // // 各アクションにカレントページ数をCookieに保存
  // public static void setPageNumberToCookie(ApexPages.StandardSetController ssc) {
  //   setPageNumberToCookie(ssc.getPageNumber());
  // }

  // // ページ数をCookieに保存
  // public static void setPageNumberToCookie(Integer pageNum) {
  //   CommonUtility.setCookieValue(ReportUtility.PAGE_NUM, String.valueOf(pageNum));
  // }

  // // ページ数をCookieから取得
  // public static Integer getPageNumberFromCookie() {
  //   String pageNum = CommonUtility.getCookieValue(ReportUtility.PAGE_NUM);
  //   if (isNumber(pageNum)) {
  //     return Integer.valueOf(pageNum);
  //   }
  //   return 1;
  // }

  // // Login処理
  // public static PageReference doLogin(String uid, String pwd) {
  //   PageReference pf;
  //   try {
  //     // 社員検索
  //     Contact con = [
  //       SELECT Id, Name, Password__c, Token__c
  //       FROM Contact
  //       WHERE Email = :uid AND (RetirementDate__c = NULL OR RetirementDate__c >= :System.Today())
  //       LIMIT 1
  //     ];

  //     if (!bEquals(pwd, con.Password__c)) {
  //       ApexPages.addMessage(
  //         new ApexPages.Message(
  //           ApexPages.Severity.ERROR,
  //           'ユーザ名とパスワードを確認してください。それでもログインできない場合は、Salesforce システム管理者にお問い合わせください。'
  //         )
  //       );
  //     } else if (String.isNotBlank(con.Token__c)) {
  //       ApexPages.addMessage(
  //         new ApexPages.Message(
  //           ApexPages.Severity.ERROR,
  //           'パスワードはリセットされています。パスワードを変更してから再ログインしてください。'
  //         )
  //       );
  //     } else {
  //       pf = Page.Worklist_PAGE;
  //       String sessionKey = CommonUtility.NewGuid();
  //       CommonUtility.setCookieValue(ReportUtility.SESSION_KEY, sessionKey, pf);
  //       CommonUtility.setSessionValue(sessionKey, con.Id);
  //       pf.setRedirect(true);
  //     }
  //   } catch (Exception e) {
  //     ApexPages.addMessage(
  //       new ApexPages.Message(
  //         ApexPages.Severity.ERROR,
  //         'ユーザ名とパスワードを確認してください。それでもログインできない場合は、Salesforce システム管理者にお問い合わせください。'
  //       )
  //     );
  //   }

  //   return pf;
  // }

  // // 特別送付
  // public static void doSendSpecial(Id reportId) {
  //   // 勤務表情報を取得する
  //   MonthlyReport__c report = ReportUtility.getReport(reportId);

  //   // メールテンプレートに差し込み値を置換する
  //   EmailTemplate template = [
  //     SELECT Subject, Body
  //     FROM EmailTemplate
  //     WHERE DeveloperName = 'SpecialApprovalEmailTemplate'
  //   ];

  //   // 件名
  //   String strSubject = template.Subject;
  //   strSubject = strSubject.replace('{!MonthlyReport__c.ReportName__c}', report.ReportName__c);
  //   // 本文
  //   String strBody = template.Body;
  //   String reportTo = ReportUtility.removeHonorificTitle(report.contact__r.ReportTo__c);
  //   strBody = strBody.replace('{!MonthlyReport__c.UserName__c}', report.UserName__c);
  //   strBody = strBody.replace('{!MonthlyReport__c.ReportName__c}', report.ReportName__c);
  //   strBody = strBody.replace('{!MonthlyReport__c.Contact__r.ReportTo__c}', reportTo);

  //   // 添付作成
  //   Messaging.EmailFileAttachment emailAttachment = new Messaging.EmailFileAttachment();
  //   Attachment att = [
  //     SELECT Id, Body
  //     FROM Attachment
  //     WHERE ParentId = :report.Id AND Name = :report.ReportFileName__c
  //     LIMIT 1
  //   ];
  //   emailAttachment.setInline(false);
  //   emailAttachment.setBody(att.Body);
  //   emailAttachment.setFileName(report.ReportFileName__c);
  //   emailAttachment.setContentType('application/vnd.ms-excel');
  //   Messaging.EmailFileAttachment[] emailAttachments = new List<Messaging.EmailFileAttachment>{ emailAttachment };

  //   // メール送信
  //   List<String> toMails = report.contact__r.ReportToMail__c.split(';');
  //   ReportUtility.sendEmail(
  //     report.Contact__r.Email,
  //     report.Contact__r.Name,
  //     toMails,
  //     new List<String>{ report.Contact__r.Email },
  //     strSubject,
  //     strBody,
  //     emailAttachments
  //   );
  // }
}
