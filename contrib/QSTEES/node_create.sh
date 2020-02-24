#!/bin/bash

# check if we have swap
memory="$(free | grep Swap | tr -s ' ' | cut -d ' ' -f 4)"
if [ -n "$memory" ] && [ "$memory" -eq "$memory" ] 2>/dev/null; then
  if [ "$memory" -eq "0" ]; then
      # make a quick 1gb swap as we only need it for compilation
      dd if=/dev/zero of=/var/swap.img bs=1024k count=1000
          mkswap /var/swap.img
          swapon /var/swap.img
          echo enabled temporary swapfile..
    else
      # a suitable swap file exists
      echo swapfile not required..
  fi
else
  # if we dont understand this, you need a new linux
  echo "can not find information of memory. please check you linux distribution."
  exit
fi

# install the dependencies
apt update
apt install -y openssh-server build-essential git automake autoconf pkg-config libssl-dev libboost-all-dev libprotobuf-dev libdb5.3-dev libdb5.3++-dev protobuf-compiler cmake curl g++-multilib libtool binutils-gold bsdmainutils pkg-config python3 libevent-dev screen libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libqrencode-dev libprotobuf-dev protobuf-compiler
# build fusionx
cd ~
git clone https://github.com/QSTEESOVATEblockchain/QSTEES-core.git && cd QSTEES-core

./autogen.sh
./configure --with-incompatible-bdb CFLAGS=-fPIC CXXFLAGS=-fPIC --enable-shared --disable-tests --disable-bench
make install
cd

# find our public ip
primaryip="$(ip route get 1 | awk '{print $NF;exit}')"
echo "mainnet or testnet"
read -e networktype
if [ "$networktype" -eq "mainnet" ]; then
	port=3337
else
	port=20980
fi
	
echo "paste the masternode privkey (output from 'masternode genkey' or paper wallet) and press enter"
read -e masternodeprivkey

# write our masternode's .qsinbstees/qsinbstees.conf
mkdir .qsinbstees
echo listen=1 > .qsinbstees/qsinbstees.conf
echo server=1 >> .qsinbstees/qsinbstees.conf
echo daemon=1 >> .qsinbstees/qsinbstees.conf
echo staking=0 >> .qsinbstees/qsinbstees.conf
echo rpcuser=testuser >> .qsinbstees/qsinbstees.conf
echo rpcpassword=testpassword >> .qsinbstees/qsinbstees.conf
echo rpcallowip=127.0.0.1 >> .qsinbstees/qsinbstees.conf
echo rpcbind=127.0.0.1 >> .qsinbstees/qsinbstees.conf
echo maxconnections=24 >> .qsinbstees/qsinbstees.conf
echo masternode=1 >> .qsinbstees/qsinbstees.conf
echo masternodeprivkey=$masternodeprivkey >> .qsinbstees/qsinbstees.conf
echo bind=$primaryip >> .qsinbstees/qsinbstees.conf
echo externalip=$primaryip >> .qsinbstees/qsinbstees.conf
echo masternodeaddr=$primaryip:$port >> .qsinbstees/qsinbstees.conf

# sleep because sleeping is good.. sometimes
sleep 1
qsinbsteesd

# finished
echo qsinbsteesd
