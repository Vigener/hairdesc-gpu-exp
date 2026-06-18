#include <mpi.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <sys/syscall.h>
#include <unistd.h>
#include <omp.h>

#if !defined(__linux__)
#include <sched.h>
#endif

int main(int argc, char **argv) {
  int i, nthread = 0;
  const int MAX_THREADS = 1024;
  unsigned *cpu_ids = (unsigned*)std::calloc(MAX_THREADS, sizeof(unsigned));
  unsigned *numa_ids = (unsigned*)std::calloc(MAX_THREADS, sizeof(unsigned));
  int myrank = 0;
  char myname[256];

  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &myrank);

  int name_len = 0;
  if (MPI_Get_processor_name(myname, &name_len) != MPI_SUCCESS) {
    std::snprintf(myname, sizeof(myname), "unknown");
  }

#pragma omp parallel default(none) shared(cpu_ids, numa_ids, nthread)
  {
    int tid = omp_get_thread_num();
  unsigned cpu_id = 0;
  unsigned numa_id = 0;
#if defined(__linux__)
    syscall(SYS_getcpu, &cpu_id, &numa_id, NULL);
#else
    cpu_id = (unsigned)sched_getcpu();
    numa_id = 0;
#endif
    cpu_ids[tid] = cpu_id;
    numa_ids[tid] = numa_id;
#pragma omp master
    nthread = omp_get_num_threads();
  }

  for (i = 0; i < nthread && i < MAX_THREADS; i++) {
    std::printf("rank=%03d %s id=%3d cpu=%3u numa=%3u\n", myrank, myname, i, cpu_ids[i], numa_ids[i]);
  }

  std::free(cpu_ids);
  std::free(numa_ids);

  MPI_Finalize();
  return 0;
}