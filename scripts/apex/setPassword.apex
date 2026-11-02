// 社員のパスワードを設定する（値を書き換えて匿名Apexで実行する。実パスワードはコミットしないこと）
Contact con = [SELECT Id FROM Contact WHERE Email = 'jinjun.zhang@accenture.com'];
LoginController.setPassword(con.Id, '1111');
