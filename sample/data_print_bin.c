// 使用例: 
// $./data_print_bin x.double

#include <stdio.h>
#include <sys/stat.h>
#include <stdlib.h>

#define DOUBLE_MIN (1e-10)

int main(int argc, char* argv[])
{
  char *first;
  int i, ended, flag;
  FILE *fp1;
  struct stat stat1;
  double *df, *ds;
  int dsize;
  double double_min;
  double_min = DOUBLE_MIN;
  
  if (argc != 2) {
    printf("usage:  printdouble file\n");
    exit(1);
  }

  if((fp1 = fopen(argv[1], "r")) == NULL) {
    printf("file not found\n");
    exit(1);
  }

  stat(argv[1], &stat1);
  first = (char*)malloc(stat1.st_size);
  ended = 0;

  while (1) {
    ended += fread(first + ended, 1, stat1.st_size-ended, fp1);
    if(ended >= stat1.st_size)
      break;
  }
  fclose(fp1);
  
  dsize = stat1.st_size / (sizeof(double) / sizeof(char));
  df = (double*)first;
  flag = 0;
  for (i = 0; i < dsize; i++) {
    printf("a[%d]=%.20e\n", i, df[i]);
    flag++;
  }
  printf("%d values in %s.\n", flag, argv[1]);
  
  free(first);
  return 0;
}