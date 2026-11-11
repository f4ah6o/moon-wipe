# moon-wipe 実装計画

`cargo-wipe` に相当する MoonBit 製 CLI。MoonBit のビルド成果物 (`_build`) や
依存ソース (`.mooncakes`) を再帰的に探索し、サイズを報告したうえで任意で削除する。

- 対象ツールチェーン: moon 0.1.20261104 / moonc v0.10.20
- 依存: `moonbitlang/async@0.22.9` のみ

---

## 1. 参照仕様: cargo-wipe

```
cargo wipe <language> [-w|--wipe] [-i|--ignores <abs path>]...
```

| 項目 | cargo-wipe の挙動 |
|---|---|
| `language` | `node` / `rust` / `terraform` |
| 既定動作 | **dry-run**。一覧とサイズを表示するだけ |
| `-w` / `--wipe` | 実際に削除 |
| `-i` / `--ignores` | 絶対パス。小文字化した前方一致で除外 |
| `rust` の判定 | 名前が `target` かつ `.rustc_info.json` を含む |
| `node` の判定 | 名前が `node_modules` |
| 出力 | ヘッダ → 各ディレクトリ行 (パス / サイズ / ファイル数) → 集計 → フッター |

設計上重要な点は 2 つ。

1. **マーカーファイルで判定する**。名前が `target` なだけのディレクトリは消さない。
2. **既定は dry-run**。破壊的操作は明示的なフラグを要求する。

---

## 2. MoonBit 側の対応物 (実測済み)

| 概念 | Rust | MoonBit |
|---|---|---|
| ビルド成果物 | `target/` | `_build/` (モジュール直下) |
| マーカー | `.rustc_info.json` | `.moon_db` (`.moon-lock` も併存) |
| 依存ソース | — | `.mooncakes/` (`.moon-lock` を持つ) |
| グローバルキャッシュ | `~/.cargo/registry` | `~/.moon/cache`, `~/.moon/registry` |
| 掃除コマンド | `cargo clean` | `moon clean` (カレントモジュールのみ) |

`moon clean` はカレントモジュールの `_build` しか消さない。`cargo-wipe` の価値は
「複数プロジェクトを横断して一括で探す」ことにあるので、そこが `moon-wipe` の存在理由になる。

### 落とし穴: `_build` の中に `.mooncakes` が入っている

実測した `_build` の中身:

```
_build/
├── .moon_db
├── .moon-lock
├── index.json
├── packages.json
└── native/debug/build/.mooncakes/moonbitlang/async/...   <- 依存ソースのコピー
```

名前だけで `.mooncakes` を探すと、この内側のコピーを拾ってしまう。実測では
1 プロジェクトに `.mooncakes` が 4 件あり、うち 3 件が `_build` の内側のコピーだった
(偽陽性率 75%)。

```
./.mooncakes                              <- 本物
./_build/wasm/debug/check/.mooncakes      <- 偽陽性
./_build/native/release/build/.mooncakes  <- 偽陽性
./_build/native/debug/build/.mooncakes    <- 偽陽性
```

したがって探索器は**マッチしたディレクトリより下へ降りてはいけない**。
これが本ツールの中心的な設計制約。

---

## 3. 設計

### 3.1 名前と配布

MoonBit には cargo のようなサブコマンド機構がないため、単体バイナリとして配布する。

```
moon install --path ./cmd/moon-wipe
# => ~/.moon/bin/moon-wipe
```

**実測**: `moon install` のバイナリ名は main パッケージの**ディレクトリ名**で決まる。
`cmd/main` だと `main` に、`cmd/moon-wipe` だと `moon-wipe` になる。
よって main パッケージは `cmd/moon-wipe/` に置く。

### 3.2 CLI

```
moon-wipe [TARGET] [OPTIONS]

TARGET:
  moon        _build を探す (既定)
  mooncakes   .mooncakes を探す
  all         moon + mooncakes
  cache       グローバルキャッシュ (~/.moon/cache, ~/.moon/registry)

OPTIONS:
  -w, --wipe              実際に削除する (既定は dry-run)
  -i, --ignore <PATH>     除外パス。複数指定可
      --root <PATH>       探索開始位置 (既定: カレントディレクトリ)
      --min-size <SIZE>   このサイズ未満は報告しない (例: 100M)
      --older-than <DAYS> 最終更新が DAYS 日より古いものだけ対象
      --json              機械可読な JSON で出力
  -h, --help
  -V, --version
```

cargo-wipe との意図的な差分:

- `--root` を追加。cargo-wipe は常に cwd 固定だが、テストと CI では開始位置を
  指定できないと扱いにくい。
- `-i` の一致判定は**大文字小文字を区別する**。cargo-wipe は小文字化して比較するが、
  あれは Windows 向けの挙動で、Unix では別ディレクトリを巻き込む危険がある。
- `--min-size` / `--older-than` を追加。cargo-wipe の issue でも要望が出ていた機能。

### 3.3 探索アルゴリズム

`@fs.walk` は並列実行かつマッチ後も降下するため、この用途には合わない。
`readdir` + `kind` による自前の逐次探索にする (決定的な順序、明示的な枝刈り、
ディレクトリ単位のエラー許容のため)。

```
scan(root, target):
  results = []
  stack   = [root]
  while stack is not empty:
    dir = stack.pop()
    for name in readdir(dir, sort=true):
      p = join(dir, name)
      if kind(p) != Directory: continue
      if name in {".git", ".hg", ".svn"}: continue
      if target.matches_name(name):
        if target.has_marker(p):
          results.push(p)
        # マーカーが無くても降下しない (偽陽性の防止)
        continue
      stack.push(p)
  return results
```

判定規則:

| target | ディレクトリ名 | マーカー |
|---|---|---|
| `moon` | `_build` | `.moon_db` |
| `mooncakes` | `.mooncakes` | `.moon-lock` |

`--target-dir` で `_build` の位置を変えているプロジェクトも、マーカー判定なので拾える。

### 3.4 サイズ計測

各マッチディレクトリ配下を再帰的に走査し、`Regular` ファイルの `file_size` を合計する。

- シンボリックリンクは辿らない (`kind(p, follow_symlink=false)`) — 循環と
  二重計上を避けるため。
- 権限エラーは握りつぶさず、そのエントリの `error` として記録し報告に出す。

### 3.5 出力

```
moon-wipe 0.1.0
Searching for MoonBit build directories in /home/user/code

  /home/user/code/a/_build          1.2 GiB    1,234 files
  /home/user/code/b/_build        340.5 MiB      567 files

Found 2 directories, 1.5 GiB, 1,801 files
Dry run: re-run with -w to delete
```

`-w` 指定時はフッターが `Wiped 2 directories, freed 1.5 GiB` に変わる。
`--json` では `{ "root": ..., "entries": [...], "total": {...} }` を出す。

### 3.6 パッケージ構成

小規模ツールなので、ライブラリは 1 パッケージにまとめ、責務ごとにファイルを分ける。

```
moon-wipe/
├── moon.mod
├── moon.pkg                  # ライブラリ (公開 API)
├── README.mbt.md             # mbt check 付き。README.md はシンボリックリンク
├── target.mbt                # Target enum とマーカー規則
├── scan.mbt                  # 枝刈り付き逐次探索
├── size.mbt                  # ディレクトリサイズ集計
├── report.mbt                # バイト整形・表組み・JSON
├── wipe.mbt                  # 削除
├── cli.mbt                   # 引数パース
├── target_test.mbt
├── scan_test.mbt
├── size_test.mbt
├── report_test.mbt
├── cli_test.mbt
└── cmd/
    └── moon-wipe/
        ├── moon.pkg          # pkgtype(kind: "executable")
        └── main.mbt
```

### 3.7 公開 API

```moonbit
pub(all) enum Target { Moon; Mooncakes; All; Cache }

pub(all) struct Options {
  root : String
  target : Target
  wipe : Bool
  ignores : Array[String]
  min_size : Int64
  older_than_days : Int32?
}

pub(all) struct Entry {
  path : String
  size : Int64
  files : Int32
  ignored : Bool
  error : String?
}

pub async fn scan(options : Options) -> Array[Entry]
pub async fn wipe(entries : Array[Entry]) -> Unit
pub fn Report::render(entries : Array[Entry], options : Options) -> String
```

`scan` と `wipe` は `@fs` を使うので `async`。`Report::render` は純粋関数にして
テストしやすくする。

---

## 4. マイルストーン

| # | 内容 | 完了条件 |
|---|---|---|
| M0 | 足場: `moon.mod`, `moon.pkg`, `cmd/moon-wipe/` | `moon check` が警告なしで通る |
| M1 | CLI: 引数パース、`--help`、`--version` | `cli_test.mbt` が通る |
| M2 | 探索: `moon` ターゲット、枝刈り、サイズ、dry-run 表示 | フィクスチャで偽陽性ゼロを確認 |
| M3 | 削除: `-w`、エラー処理 | フィクスチャ削除の統合テストが通る |
| M4 | 追加ターゲット: `mooncakes`、`cache` | `moon clean --*-cache` 連携が動く |
| M5 | 仕上げ: `--json`、`--min-size`、`--older-than`、README、`moon fmt` | `moon test --target native` 全通過 |

M2 が本丸。ここで枝刈りが正しく効いていないと M3 で事故る。

---

## 5. テスト方針

- **純粋ロジックの単体テスト**: バイト整形、引数パース、マーカー規則、
  除外パスの一致判定、ターゲット名の一致判定。
- **フィクスチャによる統合テスト**: `@fs.mkdir(recursive=true)` と
  `@fs.write_file` で一時ツリーを組み立て、`scan` の結果を検証し、
  `wipe` 後に消えていることを確認する。`async test` を使う。
- **回帰テスト必須**: `_build/.../.mooncakes/...` の偽陽性は必ずフィクスチャに含める。
- スナップショットは `inspect` / `debug_inspect` で取り、`moon test --update` で更新。

検証コマンド:

```
moon check
moon test --target native
moon fmt
```

---

## 6. リスクと未確定事項

| リスク | 対応 |
|---|---|
| `_build` 内の `.mooncakes` を誤検出 | マッチしたディレクトリで必ず枝刈り。回帰テストで固定 |
| `--target-dir` で `_build` が移動している | 名前ではなくマーカーで判定するので追従できる |
| シンボリックリンクの循環 | 辿らない。`follow_symlink=false` |
| 権限エラーで探索全体が落ちる | ディレクトリ単位で捕捉し `Entry.error` に記録 |
| `moon` 実行中に `_build` を消す | v1 では未対応。`.moon-lock` を見て警告するのは将来課題 |
| Windows のパス区切り | v1 は Unix のみ。`/` 前提で実装し、必要になったら分岐 |
| `moon install` のバイナリ名 | 実測済み。main パッケージのディレクトリ名で決まる |

### 未確定

- `cache` ターゲットの実装方法。`@async/shell` で `moon clean --dep-cache` 等を
  呼ぶか、`~/.moon/cache` を直接消すか。前者が安全だが、`moon` のバージョン差で
  フラグ名が変わるリスクがある。M4 で判断する。
- `--older-than` の基準時刻。ディレクトリの `mtime` か、配下の最新ファイルの
  `mtime` か。cargo-sweep は後者。M5 で決める。
