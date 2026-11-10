trigger Worktime on Worktime__c(before insert, before update, after insert, after update, after delete) {
  // 登録・更新前：勤務実績名・勤務時間を設定し、勤務表と同じ年月かチェックする
  if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
    // 勤務表ID
    Set<Id> reportIdSet = new Set<Id>();

    for (Worktime__c w : Trigger.new) {
      reportIdSet.add(w.Workreport__c);
    }
    // 勤務表情報取得
    Map<Id, Workreport__c> reportMap = WorkreportDao.getMapByIds(reportIdSet);
    system.debug('reportIdSet=' + reportIdSet);

    for (Integer i = 0; i < Trigger.new.size(); i++) {
      Worktime__c w = Trigger.new[i];
      // 勤務表
      Workreport__c report = reportMap.get(w.Workreport__c);
      //勤務実績名
      Datetime dt = Datetime.newInstance(w.WorkDay__c, Time.newInstance(0, 0, 0, 0));
      w.Name = dt.format('MM月dd日');

      // 勤務時間計算
      w = ReportUtility.calcWorkHours(w);

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
    list<Worktime__c> lstWorktime = Trigger.isDelete ? Trigger.old : Trigger.new;
    for (Worktime__c worktime : lstWorktime) {
      reportIds.add(worktime.Workreport__c);
    }

    List<Workreport__c> reports = WorkreportDao.getMapByIds(reportIds).values();
    for (Workreport__c report : reports) {
      report.LastModified__c = System.now();
    }
    WorkreportDao.updateReports(reports);
  }
}
