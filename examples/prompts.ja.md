# 例のプロンプト

スキルを入れたあとに、そのまま試せる依頼です。それぞれに、エージェントがすべきことを書いています。英語版は [prompts.md](prompts.md) にあり、試験の結果はそちらに記録しています。

## 1. 純ゲージの HMC を回して確かめる

> SU(3) の純ゲージを 4⁴ の格子で HMC して、正しく動いているか確かめて。

すべきこと：
- 設定の表を見せ、既定値で埋めた項目はそうと分かるように示します。
- まず `check_hmc.jl` を走らせ、検査ごとに PASS か FAIL かを報告します。
- `hmc_puregauge.jl` で短い鎖を走らせ、`monitor.jl` の結果を報告します。熱化で捨てた数と、WARN があればその内容も含めます。

## 2. 物理のパラメータが足りない依頼

> SU(4) の 3 次元の純ゲージを HMC して、熱化したか教えて。

すべきこと：
- β や格子の大きさを作り話で埋めません。聞くか、値を提案するならエージェント自身の提案だと示します。
- 鎖を走らせる前に、3 次元の格子で `check_hmc.jl colors=4` を走らせます。

## 3. 古いコードを直す

> 昔の台本の一部です。今の JuliaQCD で動くようにして。
> ```julia
> U = Initialize_Gaugefields(3, 0, 4, 4, 4, 4, condition = "hot")
> temps = Temporalfields(U[1], num=2)
> println(calculate_Plaquette(U, temps[1], temps[2]))
> ```

すべきこと：
- `import JACC; JACC.@init_backend` から始め、`gauge_configuration` と `measure_plaquette` で書き直します。
- 小さな格子で走らせ、ホットスタートのプラケットが 0 に近いことを確かめます。

## 4. 群の表現の種類

> G₂ の 7 次元表現は、複素・実・擬実のどれ？数値で示して。

すべきこと：
- 実だと答えます。
- `check_group.jl G2` を走らせ、Frobenius–Schur 指標の行（⟨tr U²⟩ ≈ +1）を示します。

## 5. JuliaQCD にないゲージ群

> JuliaQCD で SO(3) のゲージ理論をシミュレーションしたい。何が必要？

すべきこと：
- JuliaQCD v1 にあるのは SU(N) と U(1) だけだと言います。
- 使い回せる既存の部品と、足りないものを表にします。
- `GaugeGroups.jl` と `check_group.jl SO 3` を正解の基準に使い、本体を改造するより JuliaQCD に依存する別のパッケージとして作るよう勧めます。

## 6. ない機能

> QCDMeasurements で staggered の Dirac 演算子の固有値を測って。

すべきこと：
- QCDMeasurements の固有値の測定は Wilson だけに対応していると言います。
- 代わりに LatticeDiracOperators の `eigensystem` を示します。
- staggered 用の QCDMeasurements の設定を作り話で書きません。
