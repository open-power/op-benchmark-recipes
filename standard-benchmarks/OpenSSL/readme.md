# OpenSSL 
## (Secure Sockets Layer/Crypto toolkit)
> For more information please refer to https://www.openssl.org/docs/faq.html or https://github.com/openssl/openssl.

To run a simple set of tests please make sure you have openssl installed
```bash
apt install libsslcommon2 openssl
```

Then run the included shell script, i.e:
```bash
./tests.sh &> log
egrep "ppc64|^aes|^sha|^ghash" log > single_copy_tests.log
egrep "ppc64|^evp|numa.*multi" log > multi_copy_tests.log
```

> There's a bugzilla defect opened against Advanced Toolchain 11.0 with OpenSSL : [defect 167453](https://bugzilla.linux.ibm.com/show_bug.cgi?id=167453)
