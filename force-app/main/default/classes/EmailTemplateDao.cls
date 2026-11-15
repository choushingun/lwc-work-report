/**
 * 機能名 : メールテンプレート(EmailTemplate)のデータアクセス
 *
 * ゲストユーザーからメールテンプレートを参照するため、without sharing かつシステムモードで実行する。
 */
public without sharing class EmailTemplateDao {
  // API参照名で取得する(見つからない場合はnull)。Lightningメールテンプレートの本文は HtmlValue
  public static EmailTemplate getByDeveloperName(String developerName) {
    List<EmailTemplate> templates = [
      SELECT Id, Subject, HtmlValue
      FROM EmailTemplate
      WHERE DeveloperName = :developerName AND IsActive = TRUE
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0];
  }
}
