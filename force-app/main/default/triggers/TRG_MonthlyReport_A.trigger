trigger TRG_MonthlyReport_A on MonthlyReport__c(after update) {
  List<WorkTime__c> worktimesForUpdate = new List<WorkTime__c>();
  for (MonthlyReport__c report : Trigger.new) {
    MonthlyReport__c oldReport = Trigger.oldMap.get(report.Id);
    if (String.isNotBlank(oldReport.ProjectName__c) && oldReport.ProjectName__c != report.ProjectName__c) {
      List<String> oldList = oldReport.ProjectName__c.split(',');
      List<String> newList = new List<String>();
      if (String.isNotBlank(report.ProjectName__c)) {
        newList = report.ProjectName__c.split(',');
      }
      Set<String> newSet = new Set<String>();
      for (String s : newList) {
        newSet.add(s);
      }

      List<String> lstPrjForDelete = new List<String>();
      for (String s : oldList) {
        // 削除されたか、変更されたか
        if (!newSet.contains(s))
          lstPrjForDelete.add(s);
      }

      // 実績検索
      List<WorkTime__c> workTimes = [
        SELECT Id, ProjectName__c
        FROM WorkTime__c
        WHERE MonthlyReport__c = :report.Id AND ProjectName__c = :lstPrjForDelete
      ];

      for (WorkTime__c wt : workTimes) {
        wt.ProjectName__c = '';
        worktimesForUpdate.add(wt);
      }
    }
  }
  if (worktimesForUpdate.size() > 0) {
    update worktimesForUpdate;
  }

}
