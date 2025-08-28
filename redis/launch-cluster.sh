# ssh to first server and launch primary
ssh cc@129.114.108.171 "cd $HOME/projects/Raft-Consensus-Benchmark/raft-engines/redis/src/; 
./redis-server ./redis/fsync-disk-primary.conf"

# ssh to second server and launch replica
ssh cc@129.114.108.179 "cd $HOME/projects/Raft-Consensus-Benchmark/raft-engines/redis/src/; 
./redis-server ./redis/fsync-disk-replica.conf"

# ssh to third server and launch replica
ssh cc@129.114.108.190 "cd $HOME/projects/Raft-Consensus-Benchmark/raft-engines/redis/src/; 
./redis-server ./redis/fsync-disk-replica.conf"

# launch replica
ssh cc@129.114.108.179 "cd $HOME/projects/Raft-Consensus-Benchmark/raft-engines/redis/src/; ./redis-server ./redis/fsync-disk-replica.conf"

# launch in-mem primary
./raft-engines/redis/src/redis-server ./redis/in-mem-primary.conf

