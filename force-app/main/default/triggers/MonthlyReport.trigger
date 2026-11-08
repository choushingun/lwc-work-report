trigger MonthlyReport on MonthlyReport__c(before update, after update) {
  // 更新前：状況の変化に応じて申請日時・承認日時などを設定する
  if (Trigger.isBefore && Trigger.isUpdate) {
    for (MonthlyReport__c report : Trigger.new) {
      // report.IsSelected__c = false;
      MonthlyReport__c oldReport = Trigger.oldMap.get(report.Id);
      // 状況が変化なかった場合、なにもしない
      if (oldReport.Status__c == report.Status__c) {
        continue;
      }
      if (report.Status__c == '承認済' || report.Status__c == '却下') {
        report.ApproveDateTime__c = System.now();
      } else if (report.Status__c == '申請中') {
        report.ApproveDateTime__c = null;
        report.ApplicationDateTime__c = System.now();
      } else if (report.Status__c == 'ドラフト' || String.isBlank(report.Status__c)) {
        report.ApproveDateTime__c = null;
        report.ApplicationDateTime__c = null;
        report.RejectComment__c = null;
      } else if (report.Status__c == '申請取消') {
        report.ApplicationDateTime__c = null;
        report.ApproveDateTime__c = null;
      }

      // 特別送信は下記２パターンが考えられる
      // 1. 申請中 ⇒ 承認済
      // 2. クローズ ⇒ 承認済
      if (report.Status__c == '承認済') {
        if (oldReport.Status__c == '申請中' || oldReport.Status__c == 'クローズ') {
          // 特別送付をおこなう(そこまで件数がないから、ガバナー制限を気にしなくてもよい)
          // reportUtility.doSendSpecial(report.Id);
          report.Status__c = 'クローズ';
        }
      }
    }
  }

  // 更新後：勤務表から削除・変更されたプロジェクトを勤務実績からクリアする
  if (Trigger.isAfter && Trigger.isUpdate) {
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
        List<WorkTime__c> workTimes = WorkTimeDao.getListByProject(report.Id, lstPrjForDelete);

        for (WorkTime__c wt : workTimes) {
          wt.ProjectName__c = '';
          worktimesForUpdate.add(wt);
        }
      }
    }
    WorkTimeDao.updateWorkTimes(worktimesForUpdate);
  }
}
