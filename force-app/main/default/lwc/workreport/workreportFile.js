/**
 * 勤務表ファイル(Excel)の作成
 *
 * テンプレート(静的リソース Workreport)に勤務表と勤務実績(会社提出分)を書き込み、Base64文字列で返す。
 * Excelの操作は静的リソース XlsxPopulate(xlsx-populate)を使う。
 */
import { loadScript } from 'lightning/platformResourceLoader';
import XLSX_POPULATE from '@salesforce/resourceUrl/XlsxPopulate';
import WORKREPORT_TEMPLATE from '@salesforce/resourceUrl/Workreport';

// 1日の行は16行目(実績日の行 = 15 + 日)
const DAY_ROW_OFFSET = 15;
// 合計稼働時間の行
const TOTAL_ROW = 47;
// 曜日の背景色の見本(テンプレートの1～3日の曜日セル)
const SATURDAY_FILL_CELL = 'B16';
const HOLIDAY_FILL_CELL = 'B17';
const WEEKDAY_FILL_CELL = 'B18';
// Excelの時刻は1日を1とする数値で持つ
const MINUTES_PER_DAY = 24 * 60;

export async function createWorkreportFile(component, { report, worktimes }) {
  await loadScript(component, XLSX_POPULATE);
  const response = await fetch(WORKREPORT_TEMPLATE);
  if (!response.ok) {
    throw new Error('勤務表のテンプレートを取得できませんでした。');
  }
  const workbook = await window.XlsxPopulate.fromDataAsync(await response.arrayBuffer());
  const sheet = workbook.sheet(0);

  writeWorktimes(sheet, report, worktimes);
  writeReportInfo(sheet, report);
  sheet.name(`作業報告(${report.Month__c}月)`);

  return workbook.outputAsync({ type: 'base64' });
}

// 勤務実績(1日～月末)と合計稼働時間を書き込む
function writeWorktimes(sheet, report, worktimes) {
  // 書き込みで見本のセルも上書きするため、先に背景色を取得しておく
  const fills = {
    saturday: sheet.cell(SATURDAY_FILL_CELL).style('fill'),
    holiday: sheet.cell(HOLIDAY_FILL_CELL).style('fill'),
    weekday: sheet.cell(WEEKDAY_FILL_CELL).style('fill')
  };
  // プロジェクト1～3の稼働時間を書き込む列
  const projectColumns = [
    { name: report.ProjectName__c, column: 'F', total: 0 },
    { name: report.ProjectName2__c, column: 'G', total: 0 },
    { name: report.ProjectName3__c, column: 'H', total: 0 }
  ].filter((project) => project.name);

  const daysInMonth = new Date(Number(report.Year__c), Number(report.Month__c), 0).getDate();
  const worktimesByDay = new Map(worktimes.map((wt) => [Number(wt.WorkDay__c.slice(8, 10)), wt]));

  for (let day = 1; day <= daysInMonth; day++) {
    const wt = worktimesByDay.get(day);
    if (!wt) {
      continue;
    }
    const row = sheet.row(DAY_ROW_OFFSET + day);

    // 曜日(土曜・日祝は色付け)
    row.cell('B').value(wt.Week__c).style('fill', weekFill(wt, fills));

    // 休みの日は作業内容(備考)のみ
    if (wt.IsVacation__c) {
      row.cell('J').value(wt.Memo__c ?? '');
      continue;
    }

    setTime(row.cell('C'), timeToMinutes(wt.Start__c));
    setTime(row.cell('D'), timeToMinutes(wt.End__c));
    setTime(row.cell('E'), Number(wt.RestTime__c ?? 0));

    // 稼働時間は実績のプロジェクトに対応する列に書き込む
    const project = projectColumns.find((p) => p.name === wt.ProjectName__c);
    if (project) {
      const workTime = Number(wt.WorkTime__c ?? 0);
      project.total += workTime;
      row.cell(project.column).value(workTime);
    }
    row.cell('I').value(wt.Workplace__c ?? '');
    row.cell('J').value(wt.Memo__c ?? '');
  }

  // 合計稼働時間(プロジェクト別・全体)
  const totals = { F: 0, G: 0, H: 0 };
  projectColumns.forEach((project) => {
    totals[project.column] = project.total;
  });
  const totalRow = sheet.row(TOTAL_ROW);
  Object.entries(totals).forEach(([column, total]) => totalRow.cell(column).value(total));
  totalRow.cell('I').value(totals.F + totals.G + totals.H);
}

// 勤務表の情報(プロジェクト・所属会社・氏名・年月度・承認者)を書き込む
function writeReportInfo(sheet, report) {
  sheet.cell('D6').value(joinFields(report, ['ProjectName__c', 'ProjectName2__c', 'ProjectName3__c']));
  sheet.cell('D7').value(joinFields(report, ['ProjectCode__c', 'ProjectCode2__c', 'ProjectCode3__c']));
  sheet.cell('J8').value(report.Contact__r?.Account?.Name ?? '');
  sheet.cell('J10').value(report.Contact__r?.Name ?? '');
  sheet.cell('C12').value(`${report.Year__c}年${report.Month__c}月度`);
  if (report.Approver__c) {
    let approverInfo = `承認者：${report.Approver__c}様 `;
    if (report.ApproverMail__c) {
      approverInfo += `mailto:${report.ApproverMail__c}`;
    }
    sheet.cell('C50').value(approverInfo);
  }
}

function weekFill(wt, fills) {
  if (wt.Week__c === '土') {
    return fills.saturday;
  }
  if (wt.Week__c === '日' || wt.IsHoliday__c) {
    return fills.holiday;
  }
  return fills.weekday;
}

// "9:00" 形式の時刻を0時からの分に変換する(変換できない場合はnull)
function timeToMinutes(value) {
  const [hour, minute] = (value ?? '').split(':').map((part) => Number.parseInt(part, 10));
  if (Number.isNaN(hour) || Number.isNaN(minute)) {
    return null;
  }
  return hour * 60 + minute;
}

// 時刻・時間(分)をExcelの時刻として書き込む(書式はテンプレートのセルに従う)
function setTime(cell, minutes) {
  if (minutes !== null) {
    cell.value(minutes / MINUTES_PER_DAY);
  }
}

function joinFields(record, fields) {
  return fields
    .map((field) => record[field])
    .filter((value) => value)
    .join(';');
}
