#!/bin/bash

HOST=129.114.108.171

NUM_KEYS=10000
FSYNC_OPTIONS="fsync-disk fsync-inmem only-exec-inmem"
#list of fsync options

# read servers from cluster-config.json
SERVERS=$(cat cluster-config.json | jq -r '.servers[] | "\(.ip)"')
# USE ONLY THE FIRST 3 SERVERS

# read username from cluster-config.json
USERNAME=$(cat cluster-config.json | jq -r '.username')
# read ssh_pemfile from cluster-config.json
SSH_PEMFILE=$(cat cluster-config.json | jq -r '.ssh_pemfile')

# Create CSV file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CSV_FILE="redis-fsync-benchmark-${TIMESTAMP}.csv"
LOG_FILE="redis-fsync-benchmark-${TIMESTAMP}.log"

# Write CSV header
echo "fsync_option,cluster_size,clients,size_bytes,requests_per_second,avg_latency_ms,min_latency_ms,p50_latency_ms,p95_latency_ms,p99_latency_ms,max_latency_ms,throughput_mbps" > "$CSV_FILE"

for NUM_SERVERS in 3 5; do
  SERVERS=(${SERVERS[@]:0:$NUM_SERVERS})  
  echo ${SERVERS[@]}
  for size in 1024 4096 8192 16384; do
    for fsync_option in ${FSYNC_OPTIONS[@]}; do
      if [ "$fsync_option" = "fsync-disk" ]; then
          PORT=6379
      elif [ "$fsync_option" = "fsync-inmem" ]; then
          PORT=6380
      elif [ "$fsync_option" = "only-exec-inmem" ]; then
          PORT=6381
      fi
      for clients in 1 10 50 100 200 300 400 500; do

        # clean up data dirs and server logs
        for server in $SERVERS; do
            echo "Cleaning up $server"
            ssh -i $SSH_PEMFILE $USERNAME@$server "rm -rf /home/cc/datadir; mkdir /home/cc/datadir;"
            ssh -i $SSH_PEMFILE $USERNAME@$server "rm -rf /dev/shm/datadir; mkdir /dev/shm/datadir;"
            ssh -i $SSH_PEMFILE $USERNAME@$server "pkill -9 -f redis-server; rm -rf /dev/shm/redis-server*.log; rm -rf /home/cc/redis-server*.log"
        done

        # restart the redis primary and secondary replicas
        server=${SERVERS[0]} # first server is the primary
        echo "Starting primary on $server"
        ssh -i $SSH_PEMFILE $USERNAME@$server "cd projects/Raft-Consensus-Benchmark; ./raft-engines/redis/src/redis-server redis/$fsync_option-primary.conf"
        for server in ${SERVERS[@]:1:$((NUM_SERVERS-1))}; do
            ssh -i $SSH_PEMFILE $USERNAME@$server "cd projects/Raft-Consensus-Benchmark; ./raft-engines/redis/src/redis-server redis/$fsync_option-replica.conf"
        done

        # Update the primary's config to have the correct number of replicas
        ./raft-engines/redis/src/redis-cli -h $HOST -p $PORT -c config set min-replicas-to-write $((NUM_SERVERS-1))
        ./raft-engines/redis/src/redis-cli -h $HOST -p $PORT -c config set min-replicas-max-lag 0

        # wait for the primary to be ready
        echo "Waiting for the primary to be ready"
        sleep 5
        ./raft-engines/redis/src/redis-cli -h $HOST -p $PORT -c info replication

        echo "Testing: clients=$clients, size=${size}B"
        
        # Run benchmark and capture output
        OUTPUT=$(./raft-engines/redis/src/redis-benchmark -h $HOST -p $PORT -t set -n $NUM_KEYS -c $clients -d $size -P 50)
        # append the output to the log file
        echo "$OUTPUT" >> $LOG_FILE
        
        # Check if we got any output
        # Extract performance metrics from the actual output format:
        # Summary:
        #   throughput summary: 2016.54 requests per second
        #   latency summary (msec):
        #           avg       min       p50       p95       p99       max
        #         0.474     0.176     0.471     0.583     0.679     1.383
        
        # Get requests per second from the throughput summary line
        if [ -z "$OUTPUT" ]; then
          echo "Warning: No output from redis-benchmark. Server may not be accessible."
          RPS="0"
          AVG_LATENCY="0"
          MIN_LATENCY="0"
          P50_LATENCY="0"
          P95_LATENCY="0"
          P99_LATENCY="0"
          MAX_LATENCY="0"
          THROUGHPUT="0"
        else
          # Get throughput summary section
          RPS=$(echo "$OUTPUT" | grep "throughput summary:" | awk '{print $3}')
          # Get latency metrics from the latency summary section
          LATENCY_LINE=$(echo "$OUTPUT" | grep -A 2 "latency summary" | tail -1)
          AVG_LATENCY=$(echo "$LATENCY_LINE" | awk '{print $1}')
          MIN_LATENCY=$(echo "$LATENCY_LINE" | awk '{print $2}')
          P50_LATENCY=$(echo "$LATENCY_LINE" | awk '{print $3}')
          P95_LATENCY=$(echo "$LATENCY_LINE" | awk '{print $4}')
          P99_LATENCY=$(echo "$LATENCY_LINE" | awk '{print $5}')
          MAX_LATENCY=$(echo "$LATENCY_LINE" | awk '{print $6}')
          # Calculate throughput in Mbps (size in bytes * requests per second * 8 bits / 1,000,000)
          if [ -n "$RPS" ] && [ "$RPS" != "0" ]; then
            THROUGHPUT=$(echo "scale=2; $size * $RPS * 8 / 1000000" | bc -l 2>/dev/null || echo "0")
          else
            THROUGHPUT="0"
          fi
        fi
        
        # Write to CSV
        echo "$fsync_option,$NUM_SERVERS,$clients,$size,$RPS,$AVG_LATENCY,$MIN_LATENCY,$P50_LATENCY,$P95_LATENCY,$P99_LATENCY,$MAX_LATENCY,$THROUGHPUT" >> "$CSV_FILE"
        echo "Results: fsync_option=$fsync_option,NUM_SERVERS=$NUM_SERVERS,clients=$clients,size=$size,RPS=$RPS,Avg Latency=${AVG_LATENCY}ms,Min Latency=${MIN_LATENCY}ms,P50 Latency=${P50_LATENCY}ms,P95 Latency=${P95_LATENCY}ms,P99 Latency=${P99_LATENCY}ms,Max Latency=${MAX_LATENCY}ms,Throughput=${THROUGHPUT}Mbps"
      done
    done
  done
done

echo "Benchmark completed! Results saved to: $CSV_FILE"
echo "Benchmark completed! Logs saved to: $LOG_FILE"
