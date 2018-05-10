#!/bin/bash
set -x

#source:OpenSSL Performance with POWER8 In-Core Cryptography White Paper
#	by Jesse Sathre IBM Systems, 10 March 2016

function run_tests {
  numactl --physcpubind=0 openssl speed -evp aes-128-ecb
  numactl --physcpubind=0 openssl speed -evp aes-192-ecb
  numactl --physcpubind=0 openssl speed -evp aes-256-ecb
  numactl --physcpubind=0 openssl speed -evp aes-128-cbc
  numactl --physcpubind=0 openssl speed -evp aes-192-cbc
  numactl --physcpubind=0 openssl speed -evp aes-256-cbc
  numactl --physcpubind=0 openssl speed -evp aes-128-ctr
  numactl --physcpubind=0 openssl speed -evp aes-192-ctr
  numactl --physcpubind=0 openssl speed -evp aes-256-ctr
  numactl --physcpubind=0 openssl speed -evp aes-128-gcm
  numactl --physcpubind=0 openssl speed -evp aes-192-gcm
  numactl --physcpubind=0 openssl speed -evp aes-256-gcm
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-128-ecb
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-192-ecb
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-256-ecb
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-128-cbc
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-192-cbc
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-256-cbc
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-128-ctr
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-192-ctr
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-256-ctr
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-128-gcm
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-192-gcm
  numactl --physcpubind=0 openssl speed -decrypt -evp aes-256-gcm
  numactl --physcpubind=0 openssl speed ghash
  numactl --physcpubind=0 openssl speed -evp sha256
  numactl --physcpubind=0 openssl speed -evp sha512
  numactl --physcpubind=0-1 openssl speed ghash -multi 2
  numactl --physcpubind=0-1 openssl speed -evp sha256 -multi 2
  numactl --physcpubind=0-1 openssl speed -evp sha512 -multi 2
  numactl --physcpubind=0-3 openssl speed ghash -multi 4
  numactl --physcpubind=0-3 openssl speed -evp sha256 -multi 4
  numactl --physcpubind=0-3 openssl speed -evp sha512 -multi 4
  numactl --physcpubind=0-7 openssl speed ghash -multi 8
  numactl --physcpubind=0-7 openssl speed -evp sha256 -multi 8
  numactl --physcpubind=0-7 openssl speed -evp sha512 -multi 8
}

ppc64_cpu --smt=off
run_tests

ppc64_cpu --smt=2
run_tests

ppc64_cpu --smt=4
run_tests

ppc64_cpu --smt=8
run_tests


