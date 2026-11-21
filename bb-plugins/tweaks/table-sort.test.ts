import assert from "node:assert/strict";
import { test } from "node:test";
import { compareCells, nextSortState, parseNumericCell } from "./table-sort.ts";

test("parses numbers with separators, currency, units and signs", () => {
  assert.equal(parseNumericCell("1,234"), 1234);
  assert.equal(parseNumericCell("¥1,200"), 1200);
  assert.equal(parseNumericCell("567 CAD"), 567);
  assert.equal(parseNumericCell("12.5%"), 12.5);
  assert.equal(parseNumericCell("−3"), -3);
  assert.equal(parseNumericCell("▲1,000"), -1000);
  assert.equal(parseNumericCell("-0.5"), -0.5);
  assert.equal(parseNumericCell("abc"), null);
  assert.equal(parseNumericCell("2026-11-21"), null);
  assert.equal(parseNumericCell(""), null);
});

test("orders numbers before text and text by locale", () => {
  assert.ok(compareCells("9", "10") < 0);
  assert.ok(compareCells("10", "abc") < 0);
  assert.ok(compareCells("abc", "10") > 0);
  assert.ok(compareCells("apple", "banana") < 0);
});

test("cycles ascending, descending, original", () => {
  const first = nextSortState(undefined, 1);
  assert.deepEqual(first, { column: 1, direction: "ascending" });
  const second = nextSortState(first, 1);
  assert.deepEqual(second, { column: 1, direction: "descending" });
  const third = nextSortState(second, 1);
  assert.deepEqual(third, { column: 1, direction: null });
  assert.deepEqual(nextSortState(third, 1), { column: 1, direction: "ascending" });
  assert.deepEqual(nextSortState(second, 0), { column: 0, direction: "ascending" });
});
