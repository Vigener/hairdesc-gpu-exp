# OpenACCプログラミング初級編の解説と実装マッピング

提供された資料「HAIRDESC_Basics_OpenACC_C_20260325.pdf」の内容に基づき、OpenACCの基本概念と、本プロジェクト(`hairdesc-gpu-exp`)での実際の実装例（`src/diffusion3d_openacc.cpp` および `src/nbody_openacc.cpp`）を対応させながら解説します。

---

## 1. GPU化の基本方針

資料では、既存のCPU並列化コード（OpenMPなど）をGPUへ移植する際のステップが明確に示されています。

1. **演算部分のGPU実装に注力する**
   - まずはデータの場所（CPUかGPUか）を意識しすぎず、計算ループの並列化（`#pragma omp parallel for` を `#pragma acc parallel loop` に置き換える等）を行います。
   - この段階では、Unified Memory や Managed Memory といったコンパイラ側の自動データ転送機能を活用して動作確認を優先します。
2. **明示的なデータ管理で性能を最適化する**
   - 自動的なメモリ管理で性能が出ない場合、`data`指示文などを使って「CPUとGPUのどちらにデータを置くか」「いつ転送するか」を明示的に指示し、無駄なデータ転送（PCIeバス経由の通信）を削減します。

---

## 2. ループ並列化の構文

GPUでループを並列実行するための主要な構文です。

* **`#pragma acc parallel loop`**
  * ユーザーの責任で「このループは並列化可能である」と保証し、GPUに並列実行させます。OpenMPの `#pragma omp parallel for` の直接的な置き換えとしてよく使われます。
* **`#pragma acc kernels`**
  * ループが並列化可能かどうかをコンパイラに判断させます。コンパイラが依存関係を検出すると並列化されない（逐次実行される）こともあります。

### 追加の最適化指示（節）
* **`independent`**: ループの各反復が完全に独立していることをコンパイラに明示し、強制的に並列化させます。
* **`collapse(n)`**: `n`重の多重ループを1つの大きなループに展開・結合します。外側のループだけでは反復回数（並列度）が足りない場合に有効です。
* **`reduction(op:var)`**: 総和計算（`+ : sum`）など、複数のスレッドが1つの変数に結果を集約する際にデータの競合を防ぎます。

---

## 3. 実装コードへのマッピングと解説

実際にAIが実装したソースコードを紐解き、資料の概念がどう適用されているかを確認します。

### 例1: 拡散方程式 (`src/diffusion3d_openacc.cpp`)

拡散方程式は、計算量に対してメモリの読み書き量が多い**メモリ律速（メモリバンド幅がボトルネックになる）**な問題の代表例です。

**① 多重ループの結合による並列度の確保 (`collapse`)**
```cpp
// src/diffusion3d_openacc.cpp
#pragma acc parallel loop independent collapse(3) present(...)
for (int k = k_start; k < k_end; ++k) {
    for (int j = 0; j < ny; ++j) {
        for (int i = 0; i < nx; ++i) {
            // ... 3次元グリッドの計算 ...
```
> **解説:** 3次元の空間グリッドを計算する3重ループに対し、`collapse(3)` を指定しています。これにより、`k, j, i` の3つのループが1つの巨大な1次元ループとして扱われ、GPUの数千〜数万のコアを埋め尽くすのに十分な並列度（スレッド数）を確保しています。

**② 明示的なメモリ管理 (`data`指示文)**
```cpp
#pragma acc data copy(f[0:ln]) create(fn[0:ln])
{
    for (int step = 0; step < STEPS; ++step) {
        // ... 計算ループ ...
        std::swap(f, fn); // ポインタの入れ替えのみ
    }
}
```
> **解説:** 毎ステップごとにデータをCPU-GPU間でやり取りすると、転送時間が計算時間を上回ってしまいます。`#pragma acc data` を時間ステップのループの外側に配置することで、**シミュレーション開始時に一度だけGPUにデータを送り（`copy`）、シミュレーション終了までGPU上にデータを保持**し続けています。

**③ GPU-Aware MPI (応用編)**
```cpp
#pragma acc host_data use_device(f)
{
    MPI_Isend(&f[...], ...);
    MPI_Irecv(&f[...], ...);
}
```
> **解説:** 資料の「GPUDirect系の機能を活用する際には、GPU上にデータが置かれていることを保証できる実装手法を使いたくなる」という部分に該当します。`host_data use_device` を使うことで、GPU上のデバイスポインタを直接MPI関数に渡し、CPUメモリを経由せずに直接GPU間で通信を行う高度な最適化が施されています。

### 例2: N体計算 (`src/nbody_openacc.cpp`)

N体計算（自己重力多体問題）は、粒子同士の相互作用を計算するため計算量が非常に多い**演算律速**な問題の代表例です。

**① 独立したループの明示 (`independent`)**
```cpp
// src/nbody_openacc.cpp
#pragma acc parallel loop independent
for (int i = start_index; i < end_index; ++i) {
    double ax = 0.0, ay = 0.0, az = 0.0;
    for (int j = 0; j < N; ++j) {
        // ... 重力計算 ...
    }
    // ... 速度・位置の更新 ...
}
```
> **解説:** N体問題では、ある粒子 `i` が受ける力を計算する処理は、他の粒子の計算と完全に独立しています。外側の `i` ループに `independent` を指定し、各スレッドが1つの粒子の時間進化を担当するように並列化しています。

**② 結果の集約とGPUメモリからの直接通信**
```cpp
#pragma acc host_data use_device(np_data, p_data)
{
    MPI_Allgather(np_data, ..., p_data, ...);
}
```
> **解説:** こちらも拡散方程式と同様、毎ステップごとの全粒子の位置同期を、CPUメモリに戻すことなく直接GPUメモリ同士（`use_device`）で `MPI_Allgather` を行っています。

---

## 4. コンパイルと実行時のプロファイリング

資料に記載されている通り、GPU化が成功しているかどうかはコンパイラの出力メッセージや実行時の環境変数で確認できます。

* **コンパイル時の最適化情報出力:**
  Makefile内（例: `Makefile.ppx` や `Makefile.miyabi`）で、コンパイラフラグに `-Minfo=accel` または `-Minfo=opt` を付与することで、`Generating NVIDIA GPU code`（GPUコードの生成成功）や `Loop is parallelizable` といったメッセージを確認できます。
* **実行時の動作確認:**
  ジョブスクリプト（例: `job_ppx_openacc.sh`）で以下のような環境変数を設定して実行すると、実際にGPU上でカーネルが動いたか、データ転送にどれだけ時間がかかったかが標準出力に出力されます。
  * `export NVCOMPILER_ACC_NOTIFY=1` (カーネル実行の通知)
  * `export NVCOMPILER_ACC_TIME=1` (実行時間とデータ転送時間のプロファイリング)

---

## まとめ

今回の実装では、資料で説明されている基礎（`parallel loop` への置き換え）に加え、性能を最大限に引き出すための **「データ指示文によるメモリ移動の最小化」** と **「`host_data use_device` を用いた GPU-Aware MPI 通信」** が既に組み込まれています。

まずはこの資料と解説アーティファクトを元に、実装における「並列化の指示」と「データ配置の指示」の2つの役割がコードのどこに現れているかを把握してみてください。
