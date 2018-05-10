# Latter
The latter tool is a wrapper script around two industry standard benchmarks, **lat_mem_rd** and **STREAM**. 

This tool is used to measure the performance of all levels of the memory hierarchy. 
## Description
Program to measure memory load latency and memory bandwidth latency in nanoseconds. Allocates memory on Chip X, Bind/walk each chip, touch buffer. Latency results should show the symmetry in measurement across all the nodes. Bandwidth is measured using the STREAM benchmark

## Notes
- COPY (or link) the [stream](../Stream/) and [lat_mem_rd](../lat_mem_rd_lmbench/) binaries to the directory where the **latter.sh** script resides, for it to work correctly
