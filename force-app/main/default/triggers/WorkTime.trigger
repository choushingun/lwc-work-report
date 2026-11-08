trigger WorkTime on WorkTime__c(before insert, before update, after insert, after update, after delete) {
  // 登録・更新前：勤務実績名・勤務時間を設定し、勤務表と同じ年月かチェックする
  if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
    // 勤務表ID
    Set<Id> reportIdSet = new Set<Id>();

    for (WorkTime__c w : Trigger.new) {
      reportIdSet.add(w.MonthlyReport__c);
    }
    // 勤務表情報取得
    Map<Id, MonthlyReport__c> reportMap = MonthlyReportDao.getMapByIds(reportIdSet);
    system.debug('reportIdSet=' + reportIdSet);

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
        report == null ||
        Integer.valueOf(report.Year__c) != w.WorkDay__c.year() ||
        Integer.valueOf(report.Month__c) != w.WorkDay__c.month()
      ) {
        w.addError('勤務表と同月以外の勤務実績を作成することができません。');
        continue;
      }
    }
  }

  // 登録・更新・削除後：勤務表の最終更新日時を更新する
  if (Trigger.isAfter) {
    Set<Id> reportIds = new Set<Id>();
    list<WorkTime__c> lstWorktime = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (WorkTime__c worktime : lstWorktime) {
      reportIds.add(worktime.MonthlyReport__c);
    }

    List<MonthlyReport__c> reports = MonthlyReportDao.getMapByIds(reportIds).values();
    for (MonthlyReport__c report : reports) {
      report.LastModified__c = System.now();
    }
    MonthlyReportDao.updateReports(reports);
  }
}
