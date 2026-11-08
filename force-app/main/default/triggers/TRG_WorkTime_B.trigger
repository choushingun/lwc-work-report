trigger TRG_WorkTime_B on WorkTime__c(before insert, before update) {
  if (Trigger.IsInsert || Trigger.IsUpdate) {
    // 勤務表ID
    Set<Id> reportIdSet = new Set<Id>();

    for (WorkTime__c w : Trigger.new) {
      reportIdSet.add(w.MonthlyReport__c);
    }
    // 勤務表情報取得
    Map<Id, MonthlyReport__c> reportMap = new Map<Id, MonthlyReport__c>(
      [SELECT Year__c, Month__c FROM MonthlyReport__c WHERE Id IN :reportIdSet]
    );

    for (Integer i = 0; i < Trigger.new.size(); i++) {
      WorkTime__c w = Trigger.new[i];
      // 勤務表
      MonthlyReport__c report = reportMap.get(w.MonthlyReport__c);
      //勤務実績名
      Datetime dt = Datetime.newInstance(w.WorkDay__c, Time.newInstance(0, 0, 0, 0));
      w.Name = dt.format('MM月dd日');

      // 勤務時間計算
      w = ReportUtility.calcWorkTime(w);

      // 年月チェック
      if (
        Integer.valueOf(report.Year__c) != w.WorkDay__c.year() ||
        Integer.valueOf(report.Month__c) != w.WorkDay__c.month()
      ) {
        w.addError('勤務表と同月以外の勤務実績を作成することができません。');
        continue;
      }
    }
  }
}
