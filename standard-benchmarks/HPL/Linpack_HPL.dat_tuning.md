# Linpack HPL.dat Tuning
Authors: Fei Fei (shfeifei@cn.ibm.com), Yuanhui Xu (shxuyh@cn.ibm.com)

Target audience: OpenPOWER partners; IBM on-site performance engineers

There some general rules for tuning HPL.dat for performance, namely, N, P, Q and NB.
### N
The value of the N parameter is the problem size. 

The Linpack workload creates a matrix with a total size equal to *(N^2 * 8)* bytes. In general, the best performance comes from a matrix that uses about 70-80% of total memory.

For example, if you have 256 GB of memory, 70% of that is approximately 180 GB. To produce matrix size of that 180 GB, determine the appropriate value of the *N* parameter by using the formula sqrt(180 GB / 8). For this example, the appropriate value of *N* is approximately 155000.

A calculation table is listed below from different memory size to N value.

| Mem Size  |  Mem Size(Byte)     | N = sqrt(mem_byte * 0.7 / 8) |
|:---------:|:-------------------:|:----------------------------:|
|   128GB   |    137,438,953,472  |         109663               |
|   256GB   |    274,877,906,944  |         155086               |
|   512GB   |    549,755,813,888  |         219325               |
|     1TB   |  1,099,511,627,776  |         310173               |
|     2TB   |  2,199,023,255,552  |         438651               |

When tuning, try a few different values of the N parameter to find what gives  you the best score. It can also help performance if you make N evenly divisible by the value of the NB parameter.
### P and Q
The values of the P parameter and the Q parameter represent your process grid, or how many rows and columns you run with. P * Q equals the total number of processes you would like to run. 

It is common to make P smaller than or equal to Q. In some cases, making them  as close as possible to a perfect square can improve the score. To find the  best performing process grid, try different grid sizes when you experiment with tuning.

For example, if you are running SMT off (typically provides best performance) you could try 
    
    For 20 core system, P = 4, Q = 5. 
    For  8 core system, P = 2, Q = 4
    For 10 core system, P = 2, Q = 5
    For 16 core system, P = 4, Q = 4
### NB
The value of the NB parameter is the block size that the system works on. The best value for this parameter can vary, so try a few different sizes when you experiment with tuning. 

Common sizes of NB are 100 - 256. 

The value of the NB should be a multiple of the value of P * Q.

For example, if P * Q = 8, use the NB is a multiple of 8 between 100 and 256, such as 8 * 20 = 160. 

For example, if P * Q = 10, use the NB is a multiple of 8 between 100 and 256, such as 10 * 14 = 140. 

>Note: No matter which number is choose, you need to try to tune it many times in order to find out what is the best.

Reminder: value of N being multiple of NB will help performance.
## Running with mpirun
The mpirun *np* param should match **P x Q**, and the *bind-to-core* param should be added in, because you need use it for the test, i.e 

```bash 
mpirun -np 20 --bind-to-core ./xhpl
```
### HPL.data file 
HPLinpack benchmark input file:

```bash
## Innovative Computing Laboratory, University of Tennessee
HPL.out                             # output file name (if any)
6                                   # device out (6=stdout,7=stderr,file)
1                                   # of problems sizes (N)
[input such as 20000]               # Ns
1                                   # of NBs
[input such as 140]                 # NBs
0                                   # PMAP process mapping (0=Row-,1=Column-major)
1                                   # of process grids (P x Q)
[input such as 2]                   # Ps
[input small than P such as 5]      # Qs
16.0                                # threshold
3                                   # of panel fact
1                                   # PFACTs (0=left, 1=Crout, 2=Right)
1                                   # of recursive stopping criterium
4                                   # NBMINs (>= 1)
1                                   # of panels in recursion
2                                   # NDIVs
1                                   # of recursive panel fact.
2                                   # RFACTs (0=left, 1=Crout, 2=Right)
1                                   # of broadcast
1                                   # BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1                                   # of lookahead depth
1                                   # DEPTHs (>=0)
2                                   # SWAP (0=bin-exch,1=long,2=mix)
32                                  # swapping threshold
0                                   # L1 in (0=transposed,1=no-transposed) form
0                                   # U  in (0=transposed,1=no-transposed) form
1                                   # Equilibration (0=no,1=yes)
16                                  # memory alignment in double (> 0)
```
