# juliaqcd-skills

[English](README.md)

Julia の格子ゲージ理論のパッケージ群 [JuliaQCD](https://github.com/akio-tomiya/LatticeQCD.jl)（v1 以降）を、Claude Code や Codex から使うためのスキル集です。

まだ作り始めたばかりの版です。今は次の 3 つが動き、試験も済んでいます。ほかのスキルは名前と予定の範囲だけで、中身はこれから書きます。

- 純ゲージの HMC と、生成の質の監視（`juliaqcd-generate`）
- 測定。純ゲージのグラディエントフローと t0・w0、Wilson ループと静的ポテンシャル。クエンチ近似での Wilson と clover のクォークによるメソンの相関関数と有効質量（`juliaqcd-measure`）
- ゲージ群の参照実装と検査（`juliaqcd-extend`）

## 何をするものか

スキルを入れたら、日常の言葉で頼めます。たとえば次のような依頼です。

- 「β = 6.0、16⁴ のクエンチ SU(3) の HMC を研究室の計算機で 1000 本回して、プラケットの履歴を見せて」
- 「トポロジカルチャージのヒストグラムを誤差付きで見せて」
- 「arXiv:hep-lat/9707022 の overlap 演算子でプロパゲーターを計算したい。まずは実装して」
- 「このコードのゲージ群を U(1) から SU(N) に変えて」

どの依頼でも、次の順に進めます。

1. 設定の表（群、次元、格子の大きさ、作用と結合定数、アルゴリズム、配位の数、乱数の種）を見せます。読み取れない項目は推測で埋めずに聞きます。
2. 小さな格子で試します。
3. 合否の出る検査を通します。
4. 時間・メモリ・ディスクの見積もりを見せ、了承を得てから本番を走らせます。

スキルの中心は、コードの書き方よりも確かめ方にあります。たとえば純ゲージの HMC では、可逆性、ΔH が刻み幅の 2 乗で小さくなること、リンクが SU(N) に留まること、β = 0・強結合・弱結合での既知の値を、本番の前に小さな格子で確かめます。受理率がよく ⟨exp(−ΔH)⟩ = 1 でも、意図した β の分布を作っているとは限りません。それを示せるのは既知の値との比較だけです。

測定では、JuliaQCD の出す数をすべて、配列だけで書いた別の実装と同じリンクの上で突き合わせます。2 次元では厳密に W(R,T) = u(β)^{RT} が成り立つので、生成から測定までを通してこの値が出ることも確かめています。

検査そのものも、わざと壊したコードで落ちることを確かめています（`selftest*.jl`）。

## スキルの一覧

| スキル | 役目 |
|---|---|
| `juliaqcd` | 入口。依頼を振り分け、共通の進め方を決める |
| `juliaqcd-setup` | 環境、版、GPU、MPI |
| `juliaqcd-generate` | 配位の生成と、生成の質の監視 |
| `juliaqcd-measure` | 測定 |
| `juliaqcd-analyze` | 統計解析と誤差の内訳 |
| `juliaqcd-visualize` | 図と可視化 |
| `juliaqcd-reproduce` | ILDG の配位と arXiv の論文からの再現 |
| `juliaqcd-extend` | 新しい群、作用、演算子、フローの開発 |

## 入れ方

Claude Code では次のようにします。

```
/plugin marketplace add akio-tomiya/juliaqcd-skills
/plugin install juliaqcd-skills@juliaqcd-skills
```

Codex では、`skills/` の下のフォルダを Codex のスキルのフォルダに写してください（まだ試していません）。

JuliaQCD の環境は、スキルの指示に従って一度作れば、あとは使い回せます。

```
julia --project=env -e 'using Pkg; Pkg.add(["Gaugefields", "JACC", "QCDMeasurements", "LatticeDiracOperators", "StableRNGs", "JLD2", "Wilsonloop"])'
```

## 例のプロンプト

[examples/prompts.ja.md](examples/prompts.ja.md) に、そのまま試せる依頼と、エージェントがすべきことを載せています。英語版は [examples/prompts.md](examples/prompts.md) です。

## 対象とする版

Julia 1.11 と 1.12、JuliaQCD v1 以降（Gaugefields 1.1.10 以降など）です。v0.6 以前の書き方のコードは、そのままは動かさず、v1 の書き方に直してから走らせます。対応表は `skills/juliaqcd/references/legacy-api.md` にあります。

## 計算機について

JuliaQCD のコンパイルだけで 1.5 GB ほどのメモリを使います。メモリの少ないノートパソコンでは検査も走らせず、研究室の計算機や計算機センターのノードで走らせてください。スキルもそのように振る舞います。

## 問題の報告

https://github.com/akio-tomiya/juliaqcd-skills/issues に issue を立ててください。日本語でも英語でもかまいません。エージェントに出した依頼、Julia とパッケージの版（環境の `Manifest.toml`）、落ちた検査の出力を添えてください。JuliaQCD のパッケージそのものの不具合はそのパッケージのリポジトリに報告します。どちらの不具合か分からなければ、ここに報告してください。

## 引用

JuliaQCD を使った研究では arXiv:2409.03030 を引用してください。

## ライセンス

MIT
