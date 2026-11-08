trigger TRG_WorkTime_A on WorkTime__c(after insert, after update, after delete) {
  Set<Id> reportIds = new Set<Id>();
  list<WorkTime__c> lstWorktime = Trigger.isDelete ? Trigger.old : Trigger.new;
  for (WorkTime__c worktime : lstWorktime) {
    reportIds.add(worktime.MonthlyReport__c);
  }

  List<MonthlyReport__c> lstReport = [
    SELECT Id, LastModified__c
    FROM MonthlyReport__c
    WHERE Id = :reportIds
  ];

  for (MonthlyReport__c report : lstReport) {
    report.LastModified__c = System.now();
  }

  if (lstReport.size() > 0) {
    update lstReport;
  }

}
