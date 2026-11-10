public class ReportUtility {
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

  // 勤務時間計算
  public static Worktime__c calcWorkHours(Worktime__c w) {
    if (!w.IsVacation__c) {
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
      w.WorkHours__c = t;
      if (w.WorkHours__c < 0)
        w.WorkHours__c = 0;
    } else {
      w.StartTime__c = '00';
      w.EndTime__c = '00';
      w.StartHour__c = '00';
      w.EndHour__c = '00';
      w.RestTime__c = 0;
      w.WorkHours__c = 0;
    }
    return w;
  }
}
