#!/bin/bash
# Copyright (c) 2019 The QSTEES Core developers
# Auth: xtdevcoin
#
# modified by cyberd3vil
#
# this script control the status of node
# 1. node is active
# 2. infinitynode is ENABLED
# 3. if infinitynode is ENABLED compare blockheight with explorer and resync if frozen
# 4. infinitynode is not ENABLED
# 5. node is stopped by supplier - maintenance
# 6. node is frozen - dead lock
#
# Add in crontab when YOUR NODE HAS STATUS ENABLED:
# */5 * * * * /full_path_to/infinitynode_surveyor.sh
#
#
# TODO: 1. upload status of node to server for survey
#       2. chech status of node from explorer
#

qsinbstees_deamon_name="qsinbsteesd"
qsinbstees_deamon="/home/$(whoami)/qsinbsteesd"
qsinbstees_cli="/home/$(whoami)/qsinbstees-cli"

DATE_WITH_TIME=`date "+%Y%m%d-%H:%M:%S"`

# get current blockheight from QSTEES explorer and infinity node
exp_blockheight=$(curl -s http://explorer.qsinbsteesovate.io/api/getblockcount)
mn_blockheight=$($qsinbstees_cli getblockcount)

function start_node() {
	echo "$DATE_WITH_TIME : delete caches files debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat" >> ~/.qsinbstees/qsinbstees_control.log 
	cd ~/.qsinbstees && rm debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat
	sleep 5
	echo "$DATE_WITH_TIME : Start qsinbstees deamon $qsinbstees_deamon" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$DATE_WITH_TIME : QSTEES_START" >> ~/.qsinbstees/qsinbstees_control.log
	$qsinbstees_deamon &
}

function stop_start_node() {
	echo "$DATE_WITH_TIME : delete caches files debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat" >> ~/.qsinbstees/qsinbstees_control.log 
	cd ~/.qsinbstees && rm debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat
	echo "$DATE_WITH_TIME : kill process by name $qsinbstees_deamon_name" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$DATE_WITH_TIME : QSTEES_STOP" >> ~/.qsinbstees/qsinbstees_control.log
	pgrep -f $qsinbstees_deamon_name | awk '{print "kill -9 " $1}' | sh >> ~/.qsinbstees/qsinbstees_control.log
	sleep 15
	echo "$DATE_WITH_TIME : Restart qsinbstees deamon $qsinbstees_deamon" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$DATE_WITH_TIME : QSTEES_START" >> ~/.qsinbstees/qsinbstees_control.log
	$qsinbstees_deamon &
}

function resync_node() {
        echo "$DATE_WITH_TIME : kill process by name $qsinbstees_deamon_name" >> ~/.qsinbstees/qsinbstees_control.log
        echo "$DATE_WITH_TIME : QSTEES_STOP" >> ~/.qsinbstees/qsinbstees_control.log
        pgrep -f $qsinbstees_deamon_name | awk '{print "kill -9 " $1}' | sh >> ~/.qsinbstees/qsinbstees_control.log
        sleep 15
        echo "$DATE_WITH_TIME : Resyncing" >> ~/.qsinbstees/qsinbstees_control.log
        echo "$DATE_WITH_TIME : QSTEES_START" >> ~/.qsinbstees/qsinbstees_control.log
        $qsinbstees_deamon -reindex &
}

timeout --preserve-status 10 $qsinbstees_cli getblockcount
CHECK_QSTEES=$?
echo "$DATE_WITH_TIME : check status of qsinbsteesd: $CHECK_QSTEES" >> ~/.qsinbstees/qsinbstees_control.log
echo "$DATE_WITH_TIME : Explorer blockheight: $exp_blockheight" >> ~/.qsinbstees/qsinbstees_control.log
echo "$DATE_WITH_TIME : Infinity Node blockheight: $mn_blockheight" >> ~/.qsinbstees/qsinbstees_control.log

#node is active
if [ "$CHECK_QSTEES" -eq "0" ]; then
	echo "$DATE_WITH_TIME : qsinbstees deamon is active" >> ~/.qsinbstees/qsinbstees_control.log
	QSTEESSTATUS=`$qsinbstees_cli masternode status | grep "successfully" | wc -l`

	#infinitynode is ENABLED
	if [ "$QSTEESSTATUS" -eq "1" ]; then
		echo "$DATE_WITH_TIME : infinitynode is started." >> ~/.qsinbstees/qsinbstees_control.log
		
		# ping explorer webserver before comparing blockheight
		if ping -c 1 explorer.qsinbsteesovate.io &> /dev/null ;then

			#resync infinitynode if blockheight is not equal to QSTEES explorer
			if [ "$mn_blockheight" -ge  "$exp_blockheight" ] || [ "$(($exp_blockheight - $mn_blockheight))" -eq "1" ];then
			    echo "$DATE_WITH_TIME : Blockheight is equal, no resync needed." >> ~/.qsinbstees/qsinbstees_control.log
			else
			    echo "$DATE_WITH_TIME : Blockheight not synced! Resyncing!" >> ~/.qsinbstees/qsinbstees_control.log
			    resync_node
			fi
			
		fi

	else
		echo "$DATE_WITH_TIME : node is synchronising...please wait!" >> ~/.qsinbstees/qsinbstees_control.log
	fi
fi

#node is stopped by supplier - maintenance
if [ "$CHECK_QSTEES" -eq "1" ]; then
	#find qsinbsteesd
	QSTEESD=`ps -e | grep $qsinbstees_deamon_name | wc -l`
	if [ "$QSTEESD" -eq "0" ]; then
		start_node
	else
		stop_start_node
	fi
fi

#command not found
if [ "$CHECK_QSTEES" -eq "127" ]; then
	echo "$DATE_WITH_TIME : Command not found. Please change the path of qsinbstees_deamon and qsinbstees_cli." >> ~/.qsinbstees/qsinbstees_control.log
fi

#node is frozen
if [ "$CHECK_QSTEES" -eq "143" ]; then
	echo "$DATE_WITH_TIME : qsinbstees deamon will be restarted...." >> ~/.qsinbstees/qsinbstees_control.log
	stop_start_node
fi

echo "$DATE_WITH_TIME : ------------------" >> ~/.qsinbstees/qsinbstees_control.log
