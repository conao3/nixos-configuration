export type SortDirection = "ascending" | "descending";

export interface SortState {
  column: number;
  direction: SortDirection | null;
}

export function nextSortState(
  current: SortState | undefined,
  column: number,
): SortState {
  if (current === undefined || current.column !== column) {
    return { column, direction: "ascending" };
  }
  if (current.direction === "ascending") {
    return { column, direction: "descending" };
  }
  if (current.direction === "descending") return { column, direction: null };
  return { column, direction: "ascending" };
}

const NEGATIVE_SIGN = /^[-−▲]/u;
const NUMBER_NOISE = /[,\s¥$€£%]|[^\d.eE+-]+$/gu;

export function parseNumericCell(text: string): number | null {
  const trimmed = text.trim();
  if (trimmed === "") return null;
  const negative = NEGATIVE_SIGN.test(trimmed);
  const body = trimmed
    .replace(NEGATIVE_SIGN, "")
    .replace(/^[¥$€£]/u, "")
    .replace(NUMBER_NOISE, "");
  if (!/^\d/u.test(body) || !/^\d*\.?\d+(?:[eE][+-]?\d+)?$/u.test(body)) {
    return null;
  }
  const value = Number(body);
  if (!Number.isFinite(value)) return null;
  return negative ? -value : value;
}

export function compareCells(a: string, b: string): number {
  const left = a.trim();
  const right = b.trim();
  const leftNumber = parseNumericCell(left);
  const rightNumber = parseNumericCell(right);
  if (leftNumber !== null && rightNumber !== null) {
    return leftNumber - rightNumber;
  }
  if (leftNumber !== null) return -1;
  if (rightNumber !== null) return 1;
  return left.localeCompare(right, undefined, { numeric: true });
}

const ORIGINAL_INDEX = "tweaksOriginalIndex";

export function applyTableSort(table: HTMLTableElement, state: SortState): void {
  for (const header of table.querySelectorAll("th")) {
    if (header.cellIndex === state.column && state.direction !== null) {
      header.dataset.tweaksSort = state.direction;
    } else {
      delete header.dataset.tweaksSort;
    }
  }
  for (const body of table.tBodies) {
    const rows = Array.from(body.rows);
    rows.forEach((row, index) => {
      row.dataset[ORIGINAL_INDEX] ??= String(index);
    });
    const original = (row: HTMLTableRowElement) =>
      Number(row.dataset[ORIGINAL_INDEX]);
    const text = (row: HTMLTableRowElement) =>
      row.cells[state.column]?.textContent ?? "";
    const direction = state.direction;
    const sorted = rows.toSorted((a, b) => {
      if (direction === null) return original(a) - original(b);
      const left = text(a).trim();
      const right = text(b).trim();
      if (left === "" || right === "") {
        if (left === right) return original(a) - original(b);
        return left === "" ? 1 : -1;
      }
      const order = compareCells(left, right);
      if (order === 0) return original(a) - original(b);
      return direction === "ascending" ? order : -order;
    });
    if (sorted.some((row, index) => row !== rows[index])) {
      body.append(...sorted);
    }
  }
}
