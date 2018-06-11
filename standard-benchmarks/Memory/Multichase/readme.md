# Multichase - a pointer chaser benchmark
## 1. BUILD

Please clone the official `multichase` github repository and run make as follows:

```
git clone "https://github.com/google/multichase.git "
cd multichase
make
```

## 2. INSTALL
Just run from current directory or copy `multichase` wherever you need to.

## 3. RUN
We have proveded a few scripts to run the benchmark. Please copy them to the multichase directory and run them;




By default, multichase will perform a pointer chase through an array size of 256MB and a stride size of 256 bytes for 2.5 seconds on a single thread:

```bash 
 multichase
```

> For more information, please refer to https://github.com/google/multichase/blob/master/README

