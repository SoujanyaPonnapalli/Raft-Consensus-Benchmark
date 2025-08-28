mkdir raft-engines
mkdir -p /dev/shm/datadir
mkdir -p /home/cc/datadir

git clone https://github.com/etcd-io/etcd.git raft-engines/etcd-raft
git clone https://github.com/hashicorp/raft.git raft-engines/hashicorp-raft
git clone https://github.com/tikv/tikv.git raft-engines/tikv
git clone https://github.com/tikv/raft-rs.git raft-engines/tikv-raft
git clone https://github.com/redis/redis.git raft-engines/redis

# Install go
if [ ! -d "/usr/local/go" ]; then
    wget https://go.dev/dl/go1.25.0.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.25.0.linux-amd64.tar.gz
else
    echo "Go already installed"
fi

# Add go to path
if ! grep -q "GOROOT" ~/.bashrc; then
    echo "export GOROOT=/usr/local/go" >> ~/.bashrc
    echo "export GOPATH=$HOME/projects" >> ~/.bashrc
    echo "export PATH=$PATH:$GOROOT/bin:$GOPATH/bin" >> ~/.bashrc
else
    go version
    echo "Go already in path"
fi
source ~/.bashrc

# Install cargo
if ! command -v rustup &> /dev/null; then
    sudo apt-get install rustup
else
    echo "Rustup already installed"
fi
if ! rustc --version &> /dev/null; then
    rustup install stable
    rustup update
fi
