trigger TRG_WorkTime_A on WorkTime__c(after insert, after update, after delete) {
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
