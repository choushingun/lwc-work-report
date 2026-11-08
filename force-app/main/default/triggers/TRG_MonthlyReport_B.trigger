trigger TRG_MonthlyReport_B on MonthlyReport__c(before update) {
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
