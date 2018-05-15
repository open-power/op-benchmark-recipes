# Sysbench
>for more information check https://github.com/akopytov/sysbench.git

1. Clone sysbench github repo and install requirements 
```bash
cd <home>
git clone https://github.com/akopytov/sysbench.git
sudo apt -y install make automake libtool pkg-config libaio-dev
```

2. Install PPC64 lua JIT compiler
```bash
cd <home>/sysbench/third_party/luajit/
git clone https://github.com/PPC64/LuaJIT.git
[ replace /root/sysbench/third_party/luajit/luajit with above luajit ]
```

3. Compile sysbench and install
```bash
cd <home>/sysbench
./autogen.sh
./configure —without-mysql
make install
```

## Tests 

### 100GB Read Memory
```bash   
sysbench --test=memory --memory-block-size=1K --memory-scope=global --memory-total-size=100G --memory-oper=read --num-threads=10 run
```
### 100GB Write Memory
```bash
sysbench --test=memory --memory-block-size=1K --memory-scope=global --memory-total-size=100G --memory-oper=write --num-threads=10 run
```
### Prime Search 200k
```bash   
sysbench --test=cpu --cpu-max-prime=200000 --num-threads=20 run
```

