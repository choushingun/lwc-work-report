/**
 * 機能名 : 祝日(Holiday__c)のデータアクセス
 *
 * ゲストユーザーから祝日の参照・登録を行うため、without sharing かつシステムモードで実行する。
 */
public without sharing class HolidayDao {
  // 指定年の登録件数
  public static Integer countByYear(Integer year) {
    return [SELECT COUNT() FROM Holiday__c WHERE CALENDAR_YEAR(Date__c) = :year WITH SYSTEM_MODE];
  }

  // 期間内の祝日
  public static List<Holiday__c> getListByPeriod(Date fromDate, Date toDate) {
    return [
      SELECT Date__c, Description__c
      FROM Holiday__c
      WHERE Date__c >= :fromDate AND Date__c <= :toDate
      WITH SYSTEM_MODE
    ];
  }

  public static void insertHolidays(List<Holiday__c> holidays) {
    if (!holidays.isEmpty()) {
      insert as system holidays;
    }
  }
}
