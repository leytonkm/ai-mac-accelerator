// CUDA baseline for the systolic array comparison.
//
// Build:
//     nvcc -O3 -arch=sm_89 -o matmul_bench bench/matmul_bench.cu
//     (sm_89 is Ada / RTX 4070. Drop -arch to let nvcc pick a default.)
//
// Run:
//     ./matmul_bench
//     ./matmul_bench --jitter-n 64 --jitter-iters 10000
//

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include <algorithm>
#include <chrono>

#define TILE 16

#define CUDA_CHECK(call)                                                       \
    do {                                                                       \
        cudaError_t err__ = (call);                                            \
        if (err__ != cudaSuccess) {                                            \
            const char* s__ = cudaGetErrorString(err__);                       \
            fprintf(stderr, "CUDA error %d (%s) at %s:%d\n",                   \
                    (int)err__, s__ ? s__ : "no description available",        \
                    __FILE__, __LINE__);                                       \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

__global__ void empty_kernel() {}

__global__ void matmul_naive(const int16_t* __restrict__ A,
                             const int16_t* __restrict__ B,
                             int32_t* __restrict__ C, int n)
{
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;
    if (row >= n || col >= n) return;

    int32_t acc = 0;
    for (int k = 0; k < n; ++k)
        acc += (int32_t)A[row * n + k] * (int32_t)B[k * n + col];
    C[row * n + col] = acc;
}

// Shared-memory blocked version. This is the same tiling idea as the FPGA's
// tile controller: stage a TILE x TILE block of each operand, reuse it TILE
// times, move on. The GPU pays for it in shared memory instead of BRAM.
__global__ void matmul_tiled(const int16_t* __restrict__ A,
                             const int16_t* __restrict__ B,
                             int32_t* __restrict__ C, int n)
{
    __shared__ int16_t As[TILE][TILE];
    __shared__ int16_t Bs[TILE][TILE];

    int tx = threadIdx.x, ty = threadIdx.y;
    int row = blockIdx.y * TILE + ty;
    int col = blockIdx.x * TILE + tx;

    int32_t acc = 0;

    for (int t = 0; t < (n + TILE - 1) / TILE; ++t) {
        int aCol = t * TILE + tx;
        int bRow = t * TILE + ty;

        As[ty][tx] = (row < n && aCol < n) ? A[row * n + aCol] : (int16_t)0;
        Bs[ty][tx] = (bRow < n && col < n) ? B[bRow * n + col] : (int16_t)0;
        __syncthreads();

        for (int k = 0; k < TILE; ++k)
            acc += (int32_t)As[ty][k] * (int32_t)Bs[k][tx];
        __syncthreads();
    }

    if (row < n && col < n) C[row * n + col] = acc;
}

static void cpu_reference(const std::vector<int16_t>& A,
                          const std::vector<int16_t>& B,
                          std::vector<int32_t>& C, int n)
{
    for (int i = 0; i < n; ++i)
        for (int j = 0; j < n; ++j) {
            int32_t acc = 0;
            for (int k = 0; k < n; ++k)
                acc += (int32_t)A[i * n + k] * (int32_t)B[k * n + j];
            C[i * n + j] = acc;
        }
}

static double median(std::vector<double> v)
{
    if (v.empty()) return 0.0;
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}

struct Result {
    int    n;
    double kernel_us;
    double launch_us;
    double e2e_us;
    bool   correct;
};

static Result bench_size(int n, bool tiled, int iters, bool verify)
{
    size_t elems = (size_t)n * n;
    std::vector<int16_t> hA(elems), hB(elems);
    std::vector<int32_t> hC(elems), hRef(elems);

    srand(1234 + n);
    for (size_t i = 0; i < elems; ++i) {
        hA[i] = (int16_t)((rand() % 2001) - 1000);
        hB[i] = (int16_t)((rand() % 2001) - 1000);
    }

    int16_t *dA, *dB;
    int32_t *dC;
    CUDA_CHECK(cudaMalloc(&dA, elems * sizeof(int16_t)));
    CUDA_CHECK(cudaMalloc(&dB, elems * sizeof(int16_t)));
    CUDA_CHECK(cudaMalloc(&dC, elems * sizeof(int32_t)));

    dim3 block(TILE, TILE);
    dim3 grid((n + TILE - 1) / TILE, (n + TILE - 1) / TILE);

    CUDA_CHECK(cudaMemcpy(dA, hA.data(), elems * sizeof(int16_t), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(dB, hB.data(), elems * sizeof(int16_t), cudaMemcpyHostToDevice));

    // Warm up: first launch pays one-time context and JIT costs.
    for (int i = 0; i < 10; ++i) {
        if (tiled) matmul_tiled<<<grid, block>>>(dA, dB, dC, n);
        else       matmul_naive<<<grid, block>>>(dA, dB, dC, n);
    }
    CUDA_CHECK(cudaDeviceSynchronize());

    cudaEvent_t evStart, evStop;
    CUDA_CHECK(cudaEventCreate(&evStart));
    CUDA_CHECK(cudaEventCreate(&evStop));

    std::vector<double> kernelTimes, launchTimes, e2eTimes;
    kernelTimes.reserve(iters);
    launchTimes.reserve(iters);
    e2eTimes.reserve(iters);

    for (int i = 0; i < iters; ++i) {
        // kernel only
        CUDA_CHECK(cudaEventRecord(evStart));
        if (tiled) matmul_tiled<<<grid, block>>>(dA, dB, dC, n);
        else       matmul_naive<<<grid, block>>>(dA, dB, dC, n);
        CUDA_CHECK(cudaEventRecord(evStop));
        CUDA_CHECK(cudaEventSynchronize(evStop));
        float ms = 0.f;
        CUDA_CHECK(cudaEventElapsedTime(&ms, evStart, evStop));
        kernelTimes.push_back(ms * 1000.0);

        // launch + sync, wall clock
        auto t0 = std::chrono::high_resolution_clock::now();
        if (tiled) matmul_tiled<<<grid, block>>>(dA, dB, dC, n);
        else       matmul_naive<<<grid, block>>>(dA, dB, dC, n);
        CUDA_CHECK(cudaDeviceSynchronize());
        auto t1 = std::chrono::high_resolution_clock::now();
        launchTimes.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());

        // end to end, copies included
        auto t2 = std::chrono::high_resolution_clock::now();
        CUDA_CHECK(cudaMemcpy(dA, hA.data(), elems * sizeof(int16_t), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(dB, hB.data(), elems * sizeof(int16_t), cudaMemcpyHostToDevice));
        if (tiled) matmul_tiled<<<grid, block>>>(dA, dB, dC, n);
        else       matmul_naive<<<grid, block>>>(dA, dB, dC, n);
        CUDA_CHECK(cudaMemcpy(hC.data(), dC, elems * sizeof(int32_t), cudaMemcpyDeviceToHost));
        auto t3 = std::chrono::high_resolution_clock::now();
        e2eTimes.push_back(std::chrono::duration<double, std::micro>(t3 - t2).count());
    }

    bool correct = true;
    if (verify) {
        CUDA_CHECK(cudaMemcpy(hC.data(), dC, elems * sizeof(int32_t), cudaMemcpyDeviceToHost));
        cpu_reference(hA, hB, hRef, n);
        for (size_t i = 0; i < elems; ++i)
            if (hC[i] != hRef[i]) { correct = false; break; }
    }

    CUDA_CHECK(cudaEventDestroy(evStart));
    CUDA_CHECK(cudaEventDestroy(evStop));
    CUDA_CHECK(cudaFree(dA));
    CUDA_CHECK(cudaFree(dB));
    CUDA_CHECK(cudaFree(dC));

    Result r;
    r.n         = n;
    r.kernel_us = median(kernelTimes);
    r.launch_us = median(launchTimes);
    r.e2e_us    = median(e2eTimes);
    r.correct   = correct;
    return r;
}

static double measure_launch_overhead(int iters)
{
    for (int i = 0; i < 100; ++i) empty_kernel<<<1, 1>>>();
    CUDA_CHECK(cudaDeviceSynchronize());

    std::vector<double> t;
    t.reserve(iters);
    for (int i = 0; i < iters; ++i) {
        auto t0 = std::chrono::high_resolution_clock::now();
        empty_kernel<<<1, 1>>>();
        CUDA_CHECK(cudaDeviceSynchronize());
        auto t1 = std::chrono::high_resolution_clock::now();
        t.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
    }
    return median(t);
}

static void run_jitter(int n, int iters, const char* path)
{
    size_t elems = (size_t)n * n;
    std::vector<int16_t> hA(elems, 3), hB(elems, 5);

    int16_t *dA, *dB;
    int32_t *dC;
    CUDA_CHECK(cudaMalloc(&dA, elems * sizeof(int16_t)));
    CUDA_CHECK(cudaMalloc(&dB, elems * sizeof(int16_t)));
    CUDA_CHECK(cudaMalloc(&dC, elems * sizeof(int32_t)));
    CUDA_CHECK(cudaMemcpy(dA, hA.data(), elems * sizeof(int16_t), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(dB, hB.data(), elems * sizeof(int16_t), cudaMemcpyHostToDevice));

    dim3 block(TILE, TILE);
    dim3 grid((n + TILE - 1) / TILE, (n + TILE - 1) / TILE);

    for (int i = 0; i < 100; ++i) matmul_tiled<<<grid, block>>>(dA, dB, dC, n);
    CUDA_CHECK(cudaDeviceSynchronize());

    std::vector<double> t;
    t.reserve(iters);
    for (int i = 0; i < iters; ++i) {
        auto t0 = std::chrono::high_resolution_clock::now();
        matmul_tiled<<<grid, block>>>(dA, dB, dC, n);
        CUDA_CHECK(cudaDeviceSynchronize());
        auto t1 = std::chrono::high_resolution_clock::now();
        t.push_back(std::chrono::duration<double, std::micro>(t1 - t0).count());
    }

    FILE* f = fopen(path, "w");
    if (!f) { fprintf(stderr, "cannot write %s\n", path); return; }
    fprintf(f, "launch_us\n");
    for (double v : t) fprintf(f, "%.4f\n", v);
    fclose(f);

    std::vector<double> s = t;
    std::sort(s.begin(), s.end());
    double mn = s.front(), mx = s.back();
    double p50 = s[s.size()/2], p99 = s[(size_t)(s.size()*0.99)];
    printf("\njitter, %d x %d, %d launches\n", n, n, iters);
    printf("  min %.2f us   p50 %.2f us   p99 %.2f us   max %.2f us\n",
           mn, p50, p99, mx);
    printf("  spread (max-min) %.2f us\n", mx - mn);
    printf("  wrote %s\n", path);
    printf("  the FPGA figure for this column is 0.00 us: 22 cycles, every time\n");

    CUDA_CHECK(cudaFree(dA));
    CUDA_CHECK(cudaFree(dB));
    CUDA_CHECK(cudaFree(dC));
}

int main(int argc, char** argv)
{
    int jitterN = 64, jitterIters = 10000, iters = 200;
    const char* csvPath    = "bench/results_gpu.csv";
    const char* jitterPath = "bench/results_jitter.csv";

    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--jitter-n") && i + 1 < argc)          jitterN = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--jitter-iters") && i + 1 < argc) jitterIters = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--iters") && i + 1 < argc)        iters = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--csv") && i + 1 < argc)          csvPath = argv[++i];
    }

    // Check the environment before touching the device. A runtime newer than
    // the installed driver fails on the very first call, sometimes without a
    // usable error string, which is confusing to debug otherwise.
    int driverVersion = 0, runtimeVersion = 0;
    cudaDriverGetVersion(&driverVersion);
    cudaRuntimeGetVersion(&runtimeVersion);
    printf("CUDA driver %d.%d, runtime %d.%d\n",
           driverVersion / 1000, (driverVersion % 1000) / 10,
           runtimeVersion / 1000, (runtimeVersion % 1000) / 10);

    int nDev = 0;
    cudaError_t st = cudaGetDeviceCount(&nDev);
    if (st != cudaSuccess || nDev == 0) {
        const char* s = cudaGetErrorString(st);
        fprintf(stderr, "no usable CUDA device: error %d (%s)\n",
                (int)st, s ? s : "no description available");
        if (driverVersion && driverVersion < runtimeVersion)
            fprintf(stderr,
                    "the installed driver is older than the CUDA runtime.\n"
                    "either update the NVIDIA driver, or build with an older\n"
                    "toolkit (CUDA 12.x) that your driver supports.\n");
        return 1;
    }
    printf("devices visible: %d\n", nDev);

    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("device: %s, sm_%d%d, %d SMs, %.1f GB\n",
           prop.name, prop.major, prop.minor, prop.multiProcessorCount,
           prop.totalGlobalMem / 1e9);

    double launchOverhead = measure_launch_overhead(2000);
    printf("empty kernel launch + sync: %.2f us  <- the GPU's fixed floor\n\n",
           launchOverhead);

    const int sizes[] = {8, 16, 32, 64, 128, 256, 512, 1024};
    const int nSizes  = sizeof(sizes) / sizeof(sizes[0]);

    FILE* f = fopen(csvPath, "w");
    if (!f) { fprintf(stderr, "cannot write %s\n", csvPath); return 1; }
    fprintf(f, "n,kernel_us,launch_us,e2e_us,variant,correct\n");

    printf("%6s %12s %12s %12s %10s\n", "N", "kernel_us", "launch_us", "e2e_us", "variant");
    for (int v = 0; v < 2; ++v) {
        bool tiled = (v == 1);
        for (int i = 0; i < nSizes; ++i) {
            int n = sizes[i];
            bool verify = (n <= 256);
            Result r = bench_size(n, tiled, iters, verify);
            printf("%6d %12.2f %12.2f %12.2f %10s%s\n",
                   r.n, r.kernel_us, r.launch_us, r.e2e_us,
                   tiled ? "tiled" : "naive",
                   (verify && !r.correct) ? "  WRONG" : "");
            fprintf(f, "%d,%.4f,%.4f,%.4f,%s,%d\n",
                    r.n, r.kernel_us, r.launch_us, r.e2e_us,
                    tiled ? "tiled" : "naive", r.correct ? 1 : 0);
        }
    }
    fclose(f);
    printf("\nwrote %s\n", csvPath);

    run_jitter(jitterN, jitterIters, jitterPath);
    return 0;
}
