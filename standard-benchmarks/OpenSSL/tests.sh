#!/bin/bash
set -x
#Based on: "OpenSSL Performance with POWER8 In-Core Cryptography" White Paper
#	by Jesse Sathre IBM Systems, 10 March 2016

function run_tests {
  echo "ENCRYPTION"
  numactl --physcpubind=8 openssl speed -evp aes-128-ecb
  numactl --physcpubind=8 openssl speed -evp aes-192-ecb
  numactl --physcpubind=8 openssl speed -evp aes-256-ecb
  numactl --physcpubind=8 openssl speed -evp aes-128-cbc
  numactl --physcpubind=8 openssl speed -evp aes-192-cbc
  numactl --physcpubind=8 openssl speed -evp aes-256-cbc
  numactl --physcpubind=8 openssl speed -evp aes-128-ctr
  numactl --physcpubind=8 openssl speed -evp aes-192-ctr
  numactl --physcpubind=8 openssl speed -evp aes-256-ctr
  numactl --physcpubind=8 openssl speed -evp aes-128-gcm
  numactl --physcpubind=8 openssl speed -evp aes-192-gcm
  numactl --physcpubind=8 openssl speed -evp aes-256-gcm
  echo "DECRYPTION"
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-128-ecb
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-192-ecb
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-256-ecb
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-128-cbc
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-192-cbc
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-256-cbc
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-128-ctr
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-192-ctr
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-256-ctr
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-128-gcm
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-192-gcm
  numactl --physcpubind=8 openssl speed -decrypt -evp aes-256-gcm
  echo "SINGLE"
  numactl --physcpubind=8 openssl speed -evp sha256
  numactl --physcpubind=8 openssl speed -evp sha512
  echo "MULTI"
  numactl --physcpubind=8-9  openssl speed -multi 2 rsa
  numactl --physcpubind=8-9  openssl speed -multi 2 ghash 
  numactl --physcpubind=8-9  openssl speed -multi 2 -evp sha512
  numactl --physcpubind=8-9  openssl speed -multi 2 -evp sha256
  numactl --physcpubind=8-11 openssl speed -multi 4 rsa
  numactl --physcpubind=8-11 openssl speed -multi 4 ghash 
  numactl --physcpubind=8-11 openssl speed -multi 4 -evp sha512
  numactl --physcpubind=8-11 openssl speed -multi 4 -evp sha256
  numactl --physcpubind=8-15 openssl speed -multi 8 ghash
  numactl --physcpubind=8-15 openssl speed -evp sha256 -multi 8
  numactl --physcpubind=8-15 openssl speed -evp sha512 -multi 8
}

which openssl
openssl version

ppc64_cpu --smt=off
run_tests

ppc64_cpu --smt=2
run_tests

ppc64_cpu --smt=4
run_tests

ppc64_cpu --smt=8   # not valid on OpenPOWER9
run_tests           # not valid on OpenPOWER9
