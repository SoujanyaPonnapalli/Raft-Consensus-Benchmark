
sudo firewall-cmd --add-port=6379/tcp --permanent
sudo firewall-cmd --add-port=6380/tcp --permanent
sudo firewall-cmd --reload


cd $HOME/projects/Raft-Consensus-Benchmark

cd raft-engines/redis/; make

cd $HOME/projects/Raft-Consensus-Benchmark/raft-engines/redis/src/

./redis-server --port 6379 --protected-mode no --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes --appendfilename "appendonly.aof" --appendfsync everysec --dir /tmp/redis/ --dbfilename dump.rdb