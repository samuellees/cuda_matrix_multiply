#pragma once

#include "cuda_runtime.h"
#include <iostream>

#ifndef CEIL_DIV
#define CEIL_DIV(x, y) (((x) - 1) / (y) + 1)
#endif

inline int64_t align(int64_t m, int64_t alignment) {
  return CEIL_DIV(m, alignment)*alignment;
}


inline void print_matrix(float* data, int64_t n_row, int64_t n_col) {
  for (int64_t i = 0; i < n_row; ++i) {
      // if (i < 18)
    for (int64_t j = 0; j < n_col; ++j) {
      // if (j < 9)
      printf("%.2f, ", data[i * n_col + j]);
    }
    std::cout << std::endl;
  }
  std::cout << std::endl;
}

__global__ void kernel_unpadding_with_batch(float* A, const float* padA,
                                int64_t M, int64_t N,
                                int64_t padM, int64_t padN,
                                int64_t batch_size) {
  const int64_t n_blocks_y_each_batch = CEIL_DIV(M, blockDim.y);
  const int64_t batch_id = blockIdx.y / n_blocks_y_each_batch;
  const int64_t row_A = (blockIdx.y % n_blocks_y_each_batch) * blockDim.y + threadIdx.y;
  const int64_t col_A = blockIdx.x * blockDim.x + threadIdx.x;
  A += batch_id * M * N;
  padA += batch_id * padM * padN;
  if (row_A < M && col_A < N) {
    A[row_A * N + col_A] = padA[row_A * padN + col_A];
  }
}

float unpadding_with_batch(float * A, float * padA,
            int64_t M, int64_t N,
            int64_t padM, int64_t padN,
            int64_t batch_size) {
  float time = 0;
  const int64_t block_size = 32;
  dim3 dims_block(block_size, block_size);
  dim3 dims_grid(CEIL_DIV(N, block_size), batch_size * CEIL_DIV(M, block_size));
  cudaEvent_t start, stop; 
  CUDA_CHECK(cudaEventCreate(&start)); 
  CUDA_CHECK(cudaEventCreate(&stop));
  CUDA_CHECK(cudaEventRecord(start, 0));
  kernel_unpadding_with_batch<<<dims_grid, dims_block>>>(A, padA, M, N, padM, padN, batch_size);
  CUDA_CHECK(cudaEventRecord(stop, 0)); 
  CUDA_CHECK(cudaEventSynchronize(stop)); 
  CUDA_CHECK(cudaEventElapsedTime(&time, start, stop));
  CUDA_CHECK(cudaEventDestroy(start)); 
  CUDA_CHECK(cudaEventDestroy(stop));
  return time;
}

__global__ void kernel_unpadding(float* A, const float* padA,
                                int64_t M, int64_t N,
                                int64_t padM, int64_t padN) {
  const int64_t row_A = blockIdx.y * blockDim.y + threadIdx.y;
  const int64_t col_A = blockIdx.x * blockDim.x + threadIdx.x;
  if (row_A < M && col_A < N) {
    A[row_A * N + col_A] = padA[row_A * padN + col_A];
  }
}

float unpadding(float * A, float * padA,
            int64_t M, int64_t N,
            int64_t padM, int64_t padN) {
  float time = 0;
  const int64_t block_size = 32;
  dim3 dims_grid(CEIL_DIV(N, block_size), CEIL_DIV(M, block_size));
  dim3 dims_block(block_size, block_size);
  cudaEvent_t start, stop; 
  CUDA_CHECK(cudaEventCreate(&start)); 
  CUDA_CHECK(cudaEventCreate(&stop));
  CUDA_CHECK(cudaEventRecord(start, 0));
  kernel_unpadding<<<dims_grid, dims_block>>>(A, padA, M, N, padM, padN);
  CUDA_CHECK(cudaEventRecord(stop, 0)); 
  CUDA_CHECK(cudaEventSynchronize(stop)); 
  CUDA_CHECK(cudaEventElapsedTime(&time, start, stop));
  CUDA_CHECK(cudaEventDestroy(start)); 
  CUDA_CHECK(cudaEventDestroy(stop));
  return time;
}

__global__ void kernel_padding(const float* A, float* padA,
                               int64_t M, int64_t N,
                               int64_t padM, int64_t padN) {
  const int64_t row_A = blockIdx.y * blockDim.y + threadIdx.y;
  const int64_t col_A = blockIdx.x * blockDim.x + threadIdx.x;
  if (row_A < M && col_A < N) {
    padA[row_A * padN + col_A] = A[row_A * N + col_A];
  } else {
    padA[row_A * padN + col_A] = 0;
  }
}


float padding(float * A, float * padA,
            int64_t M, int64_t N,
            int64_t padM, int64_t padN) {
  float time = 0;
  const int64_t block_size = 32;
  dim3 dims_grid(CEIL_DIV(padN, block_size), CEIL_DIV(padM, block_size));
  dim3 dims_block(block_size, block_size);
  cudaEvent_t start_padding, stop_padding; 
  CUDA_CHECK(cudaEventCreate(&start_padding)); 
  CUDA_CHECK(cudaEventCreate(&stop_padding));
  CUDA_CHECK(cudaEventRecord(start_padding, 0));
  kernel_padding<<<dims_grid, dims_block>>>(A, padA, M, N, padM, padN);
  CUDA_CHECK(cudaEventRecord(stop_padding, 0)); 
  CUDA_CHECK(cudaEventSynchronize(stop_padding)); 
  CUDA_CHECK(cudaEventElapsedTime(&time, start_padding, stop_padding));
  CUDA_CHECK(cudaEventDestroy(start_padding)); 
  CUDA_CHECK(cudaEventDestroy(stop_padding));
  return time;
}