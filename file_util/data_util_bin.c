void read_data(char *path, double *buff, int size)
{
  FILE *fpr;
  double tmp;
  struct stat filestat;
  int ended;

  if ((fpr = fopen(path, "r")) == NULL) {
    printf("file not found\n");
    exit(1);
  }
  stat(path, &filestat);

  if (filestat.st_size != size * sizeof(double)) {
    printf("wrong file size\n");
    exit(1);
  }
  ended = 0;

  while (1) {
    ended += fread(buff + ended, 1, sizeof(double) * size - ended, fpr);
    if (ended >= sizeof(double) * size)
      break;
  }
  fclose(fpr);
}

void write_data(double *buff, char *path, int size)
{
  FILE *fpw;
  double tmp;
  struct stat filestat;
  int ended;
  
  if ((fpw = fopen(path, "w")) == NULL) {
    printf("file open error\n");
    exit(1);
  }
  ended = 0;
  
  while (1) {
    ended += fwrite(buff + ended, 1, sizeof(double) * size - ended, fpw);
    if (ended >= sizeof(double) * size)
      break;
  }
  fclose(fpw);
}