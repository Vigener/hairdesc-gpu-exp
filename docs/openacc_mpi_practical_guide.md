# OpenACC マルチGPUプログラミング中級編の解説と実装マッピング

資料「HAIRDESC_Practical_MPI_OpenACC_C_20260325.pdf」の内容に基づき、マルチGPU化（MPI通信）の基本概念と、本プロジェクト(`hairdesc-gpu-exp`)での実装（特に `src/diffusion3d_openacc.cpp` と `wrapper.sh`）を対応させて解説します。

---

## 1. マルチGPU化の3つのアプローチ (資料 Section 2)

単一GPUで動くコードを複数のGPUに拡張する際、プロセス間の通信（MPI通信）とGPUメモリをどう連携させるかで3つのアプローチがあります。

1. **Managed/Unified Memory を使う方法**
   - コードを変更せず、既存のMPI関数にホスト（CPU）側のポインタを渡すだけ。GPU上の最新データはバックエンドが自動でCPUへ持ってきてから通信し、受信後に再びGPUへ自動転送されます。
   - 楽ですが、PCIeバスを経由するため通信が遅くなります。
2. **手動でCPU-GPU間のデータ転送を記述する方法**
   - MPI通信の直前に `#pragma acc update host` で明示的にGPUからCPUへデータを降ろし、通信後に `#pragma acc update device` で戻す方法（先ほど質問いただいた内容です）。
   - 環境に依存せず確実に動きますが、やはりCPUメモリを経由します。
3. **GPU-Aware MPI を用いる方法 (★本プロジェクトで採用)**
   - **MPI関数の引数に、CPUのアドレスではなく「GPUメモリ上のアドレス」を直接指定する**方法。
   - 最も高性能で実装もシンプルです。

---

## 2. 通信の裏側：NVLinkとGPUDirect RDMA (資料 Section 1)

「なぜGPU-Aware MPIが一番速いのか？」という理由が資料前半のハードウェアの図解にあります。

* **ノード内通信 (NVLink):** 同じ計算ノード内のGPU同士なら、CPUメモリ（PCIeバス）を経由せず、専用の高速な橋（NVLink）を直接通って通信できます。
* **ノード間通信 (GPUDirect RDMA):** 異なる計算ノードのGPU同士でも、CPUメモリを経由せず、ネットワークカード(InfiniBand)を介してGPUメモリ間で直接データを転送(RDMA)できます。

GPU-Aware MPI（Approach 3）を使うと、**MPIライブラリが自動的にこれらのハードウェアの近道を判断して使ってくれる**ため、ユーザーが複雑な制御を書かなくても最高性能が出ます。

---

## 3. 実装コードへのマッピング: GPU-Aware MPI

実際のコード `src/diffusion3d_openacc.cpp` を見てみましょう。
拡散方程式のシミュレーション領域をZ軸方向（高さ方向）に1次元分割し、各GPUが担当領域を持ちます。毎ステップごとに隣のGPUと「袖領域（境界データ）」を交換する必要があります。

**GPU-Aware MPI の実装部分**
```cpp
// src/diffusion3d_openacc.cpp
// 袖領域の交換
#pragma acc host_data use_device(f)
{
    if (rank_up != MPI_PROC_NULL) {
        MPI_Isend(&f[nx * ny * nz], nx * ny, MPI_FLOAT, rank_up, tag, MPI_COMM_WORLD, &reqs[num_reqs++]);
        MPI_Irecv(&f[nx * ny * (nz + mgn)], nx * ny, MPI_FLOAT, rank_up, tag, MPI_COMM_WORLD, &reqs[num_reqs++]);
    }
    // ... rank_downとの通信 ...
}
```
> **解説:** これが資料Page 14で解説されている `use_device` の実例です。
> OpenACCの `host_data use_device(f)` で囲むことにより、内部の `MPI_Isend/Irecv` に渡されるポインタ `&f[...]` はCPU上のアドレスから**GPU上のデバイスアドレスにすり替わります**。
> これにより、GPUメモリ上の袖領域データが、CPUを介さずに直接隣のGPUへ送信（GPUDirect / NVLink）されます。

---

## 4. 実行時のGPU割り当て制御 (`wrapper.sh`)

資料Page 18の「環境変数を用いたGPUマッピング」についてです。
1つの計算ノードに複数GPU（例えば4基）が載っている場合、4つのMPIプロセスがそれぞれ「別々のGPU（GPU0, GPU1, GPU2, GPU3）」を使うように割り当てる必要があります。何もしないと全員がGPU0を使ってクラッシュや性能低下を起こします。

これを防ぐためのスクリプトが、プロジェクトルートにある `wrapper.sh` です。

```bash
#!/bin/bash
# wrapper.sh の中身
local_rank=${OMPI_COMM_WORLD_LOCAL_RANK:-0}
export CUDA_VISIBLE_DEVICES=${local_rank}
exec "$@"
```
> **解説:** 
> `OMPI_COMM_WORLD_LOCAL_RANK` は、OpenMPIが自動で付与する「ノード内での通し番号 (0, 1, 2, 3...)」です。
> このスクリプトをかませることで、
> - MPIプロセス0番 → `CUDA_VISIBLE_DEVICES=0` （GPU0しか見えなくなる）
> - MPIプロセス1番 → `CUDA_VISIBLE_DEVICES=1` （GPU1しか見えなくなる）
> というように、各プロセスが自動的に被ることなく別々のGPUを専有する設定になっています。
> `job_ppx_test_2nodes.sh` などのバッチスクリプト内で、`mpirun ./wrapper.sh ./bin/nbody_hybrid` のように利用されています。

---

## まとめ
中級編の資料で学べる「マルチGPU化のためのベストプラクティス（GPU-Aware MPIとラッパースクリプト）」は、現在の実装に完璧な形で組み込まれています。
これにより、複数のGPUスパコン（PPX、Pegasus、Miyabiなど）においても、ノード内・ノード間を問わず最高の通信性能を発揮するコードになっています。
