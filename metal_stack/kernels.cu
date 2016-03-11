#include "kernels.cuh"


void muli_vs(float *v, float s, int N) {
  int num_threads = min(N, MAX_THREADS_PER_BLOCK);
  int num_blocks = (N + MAX_THREADS_PER_BLOCK - 1) / MAX_THREADS_PER_BLOCK;
  k_muli_vs<<<num_blocks, num_threads>>>(v, s, N);
}

__global__ k_muli_vs(float *v, float s, int N) {
  int idx = blockIdx.x * blockDim.x + threadIdx.x;
  if (idx >= N) return;

  v[idx] *= s;
}


void addi_vv(float *v1, const float *v2, float v1_coeff, float v2_coeff,
    int N) {
  if (v1_coeff != 1.0)
    muli_vs(v1, v1_coeff, N);

  cublasSaxpy(handle, N, v2_coeff, v2, 1, v1, 1);
}


void subtensor1(float *dst, const float *src, const float *idxs, int N, int D,
    float idx_scal_shift, float idx_vec_shift_coeff, float *idx_vec_shift) {
  int num_threads = min(D, MAX_THREADS_PER_BLOCK);
  int num_blocks = min(N, MAX_BLOCKS);
  k_subtensor1<<<num_blocks, num_threads>>>(dst, src, idxs, N, D,
      idx_scal_shift, idx_vec_shift_coeff, idx_vec_shift);
}

__global__ void k_subtensor1(float *dst, const float *src, const float *idxs,
    int N, int D, int idx_scal_shift, int idx_vec_shift_coeff,
    float *idx_vec_shift) {
  for (int i0 = blockIdx.x; i0 < N; i0 += gridDim.x) {
    int src_idx = idxs[i0] + idx_scal_shift;
    src_idx += idx_vec_shift_coeff * idx_vec_shift[i0];
    src_idx = (int) src_idx;

    int src_offset = src_idx * D;
    int dst_offset = i0 * D;
    for (int i1 = threadIdx.x; i1 < D; i1 += blockDim.x)
      dst[dst_offset + i1] = src[src_offset + i1];
  }
}


void set_subtensor1i_s(float *dst, float src, const float *idxs, int N,
    int idx_scal_shift, float idx_vec_shift_coeff, float *idx_vec_shift) {
  int num_threads = min(N, MAX_THREADS_PER_BLOCK);
  int num_blocks = (N + MAX_THREADS_PER_BLOCK - 1) / MAX_THREADS_PER_BLOCK;
  k_set_subtensor1i_s<<<num_blocks, num_threads>>>(
      dst, src, idxs, N, idx_scal_shift, idx_vec_shift_coeff, idx_vec_shift);
}

__global__ k_set_subtensor1i_s(float *dst, float src, const float *idxs, int N,
    float idx_scal_shift, float idx_vec_shift_coeff, float *idx_vec_shift) {
  int k_idx = blockIdx.x * blockDim.x + threadIdx.x;
  if (idx >= N) return;

  idx = idxs[k_idx] + idx_scal_shift;
  idx += idx_vec_shift_coeff * idx_vec_shift[k_idx];
  idx = (int) idx;

  dst[idx] = src;
}


void switch_m(float *dst, const float *mask, const float *ift, const float *iff,
    int N, int D) {
  int num_threads = min(D, MAX_THREADS_PER_BLOCK);
  int num_blocks = min(N, MAX_BLOCKS);
  k_switch_m<<<num_blocks, num_threads>>>(dst, mask, ift, iff, N, D);
}

__global__ k_switch_m(float *dst, const float *mask, const float *ift,
    const float *iff, int N, int D) {
  for (int i0 = blockIdx.x; i0 < N; i0 += gridDim.x) {
    const float *src = (int) mask[i0] ? ift : iff;
    int offset = i0 * D;
    for (int i1 = threadIdx.x; i1 < D; i1 += blockDim.x)
      dst[offset + i1] = src[offset + i1];
  }
}