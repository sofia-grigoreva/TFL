import { performance } from "perf_hooks";
import { writeFileSync } from "fs";

type Capture = Record<number, string>;
type ParseResult = [Capture, number][];
type Parser = (s: string, pos: number, caps: Capture) => ParseResult;

function parseChar(expected: string): Parser {
  return (s: string, pos: number, caps: Capture) => {
    if (pos < s.length && s[pos] === expected) {
      return [[{ ...caps }, pos + 1]];
    }
    return [];
  };
}

function parseUnion(options: Parser[]): Parser {
  return (s: string, pos: number, caps: Capture) => {
    let results: ParseResult = [];
    for (const opt of options) {
      results = results.concat(opt(s, pos, caps));
    }
    return results;
  };
}

function parseStar(parseUnit: Parser): Parser {
  return (s: string, pos: number, caps: Capture) => {
    let results: ParseResult = [[{ ...caps }, pos]];
    const stack: ParseResult = [[{ ...caps }, pos]];
    const visited = new Set<string>();

    while (stack.length > 0) {
      const [currentCaps, p] = stack.pop()!;
      for (const [newCaps, newPos] of parseUnit(s, p, currentCaps)) {
        const state = `${newPos}:${JSON.stringify(
          Object.entries(newCaps).sort()
        )}`;
        if (visited.has(state)) continue;
        visited.add(state);
        results.push([newCaps, newPos]);
        if (newPos !== p) stack.push([newCaps, newPos]);
      }
    }

    return results;
  };
}

function parseGroupCapture(idx: number, innerParser: Parser): Parser {
  return (s: string, pos: number, caps: Capture) => {
    const results: ParseResult = [];
    for (const [innerCaps, newPos] of innerParser(s, pos, caps)) {
      const groupText = s.slice(pos, newPos);
      const combined: Capture = { ...innerCaps, [idx]: groupText };
      results.push([combined, newPos]);
    }
    return results;
  };
}

function parseBackreference(idx: number): Parser {
  return (s: string, pos: number, caps: Capture) => {
    const captured = caps[idx] ?? "";
    const end = pos + captured.length;
    if (s.slice(pos, end) === captured) return [[{ ...caps }, end]];
    return [];
  };
}

function captureEndExternal(
  s: string,
  pos: number,
  caps: Capture
): ParseResult {
  const results: ParseResult = [];
  for (const [firstCaps, firstPos] of parseBackreference(2)(s, pos, caps)) {
    for (const [rCaps, rPos] of parseStar(parseBackreference(2))(
      s,
      firstPos,
      firstCaps
    )) {
      results.push([rCaps, rPos]);
    }
  }
  return results;
}

function fullParserExternal(
  s: string,
  pos: number,
  group1: Parser,
  group2: Parser
): ParseResult {
  const results: ParseResult = [];

  for (const [caps1, p1] of group1(s, pos, {})) {
    for (const [, p2] of parseChar("a")(s, p1, caps1)) {
      for (const [caps2, p3] of group2(s, p2, caps1)) {
        const merged1: Capture = { ...caps1, ...caps2 };
        for (const [, p4] of parseBackreference(1)(s, p3, merged1)) {
          for (const [, p5] of parseChar("b")(s, p4, merged1)) {
            for (const [, p6] of parseBackreference(2)(s, p5, merged1)) {
              for (const [, pf] of captureEndExternal(s, p6, merged1)) {
                if (pf === s.length) results.push([merged1, pf]);
              }
            }
          }
        }
      }
    }
  }

  return results;
}

function buildParser(): Parser {
  const unionAB = parseUnion([parseChar("a"), parseChar("b")]);
  const group1 = parseGroupCapture(1, parseStar(unionAB));
  const group2 = parseGroupCapture(2, parseStar(unionAB));

  return (s: string, pos: number, caps: Capture = {}) =>
    fullParserExternal(s, pos, group1, group2);
}

// ----------------------

function optimalParser(word: string): [string, string][] {
  const n = word.length;
  if (n <= 1 || !/^[ab]+$/.test(word)) return [];

  const results: [string, string][] = [];

  for (let len1 = 0; len1 <= Math.floor((n - 2) / 2); len1++) {
    const group1 = word.slice(0, len1);
    if (word[len1] !== "a") continue;

    const posAfterA = len1 + 1;
    const maxLen2 = Math.floor((n - 2 * len1 - 2) / 3);

    for (let len2 = 0; len2 <= maxLen2; len2++) {
      const group2 = word.slice(posAfterA, posAfterA + len2);
      const posAfterGroup2 = posAfterA + len2;

      if (posAfterGroup2 + len1 + len2 + len2 > n) continue;
      if (word.slice(posAfterGroup2, posAfterGroup2 + len1) !== group1)
        continue;
      const posAfterBack1 = posAfterGroup2 + len1;
      if (posAfterBack1 >= n || word[posAfterBack1] !== "b") continue;

      const posAfterB = posAfterBack1 + 1;
      const remainder = word.slice(posAfterB);

      if (group2.length === 0) {
        if (remainder === "") results.push([group1, group2]);
        continue;
      }

      const group2Len = group2.length;
      if (remainder.length % group2Len !== 0) continue;

      const repeats = remainder.length / group2Len;

      if (repeats >= 2 && remainder === group2.repeat(repeats))
        results.push([group1, group2]);
    }
  }

  return results;
}

// ----------------------

function randomLetters(length: number): string {
  return Array.from({ length }, () => (Math.random() < 0.5 ? "a" : "b")).join(
    ""
  );
}

function generateWordInLanguage(i: number): string {
  const x = randomLetters(Math.floor(Math.random() * i));
  const y = randomLetters(Math.floor(Math.random() * i));
  const part = x + "a" + y + x + "b" + y;
  const count = Math.floor(Math.random() * 5) + 1;
  return part + y.repeat(count);
}

function generateWordNotInLanguage(i: number): string {
  const choice = Math.floor(Math.random() * 5);
  switch (choice) {
    case 0:
      return randomLetters(Math.floor(Math.random() * 26) + 5);
    case 1: {
      const x = randomLetters(Math.floor(Math.random() * i) + 1);
      const y = randomLetters(Math.floor(Math.random() * i) + 1);
      const z = randomLetters(Math.floor(Math.random() * i) + 1);
      return x + "a" + y + z + "b" + y.repeat(2);
    }
    case 2: {
      const x = randomLetters(Math.floor(Math.random() * i) + 1);
      const y = randomLetters(Math.floor(Math.random() * i) + 1);
      return x + "a" + y + x + y.repeat(2);
    }
    case 3: {
      const x = randomLetters(Math.floor(Math.random() * i) + 1);
      const y = randomLetters(Math.floor(Math.random() * i) + 1);
      return x + "a" + y + x + "b" + y + randomLetters(3);
    }
    default:
      return randomLetters(Math.floor(Math.random() * 40) + 1);
  }
}

function testParsers(n = 40, i = 10) {
  const parser1 = buildParser();

  const wordsInLang = Array.from({ length: n }, () =>
    generateWordInLanguage(i)
  );

  const wordsNotInLang = Array.from({ length: n }, () =>
    generateWordNotInLanguage(i)
  );

  const allWords = [...wordsInLang, ...wordsNotInLang];

  let totalTimeParser1 = 0;
  let totalTimeParser2 = 0;

  for (const word of allWords) {
    const t0 = performance.now();
    const res1 = parser1(word, 0, {}).length > 0;
    const t1 = performance.now();
    const timeParser1 = t1 - t0;
    totalTimeParser1 += timeParser1;

    const t2 = performance.now();
    const res2 = optimalParser(word).length > 0;
    const t3 = performance.now();
    const timeParser2 = t3 - t2;
    totalTimeParser2 += timeParser2;

    if (res1 !== res2) console.log("Ошибка", word, res1, res2);
  }

  const count = n * 2;
  console.log("parser1:", totalTimeParser1 / count);
  console.log("parser2:", totalTimeParser2 / count);
}

testParsers();
