#!/bin/bash
# Copyright (c) 2019 The QSTEES Core developers
# Auth: xtdevcoin
#
# modified by cyberd3vil, markhill & aggrohead
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
# */5 * * * * /home/$myuser/infinitynode_expired_solution.sh
#
#
# TODO: 1. upload status of node to server for survey
#       2. chech status of node from explorer
#
#explorer load balancing
sleep $(( ( RANDOM % 240 )  + 30 ))
# TELEGRAM CONFIGURATION
#
# Please edit Telegram.sh and add TOKEN and chatid for telegram to work.
# ----------------------------------------------------
. /home/$(whoami)/Telegram.sh

# EMAIL CONFIGURATION
# ----------------------------------------------------
# Please install sendemail with the follow command line if you haven't done it yet
# sudo apt-get install sendemail libio-socket-ssl-perl libnet-ssleay-perl
# Once done, please edit email.sh and replace <FROM EMAIL>, <TO EMAIL>, smtp if you don't want to use google, <USERNAME>, <PASSWORD>
# Once configured, please change ENABLE=1
. /home/$(whoami)/email.sh

# telegram & email text messages
var1="$HOSTNAME - QSTEES main explorer is down. Using secondary explorer as backup"
var2="$HOSTNAME - Automatically restarting your Infinity Node - start function"
var3="$HOSTNAME - Automatically restarting your Infinity Node - stop_start_node function"
var4="$HOSTNAME - Automatically resyncing your Infinity Node"
var5="$HOSTNAME - Your Infinity node is back online. Blockheight is equal, no resync needed"
var6="$HOSTNAME - Blockheight not synced!"
var7="$HOSTNAME - Unable to check block height with explorer. Explorer maybe down!"
var8="$HOSTNAME - Node is not running!"
var9="$HOSTNAME - Node is not syncing!"
var10="$HOSTNAME - Node is not responding!"
var11="$HOSTNAME - Node is synchronising...please wait!"

function email_send (){
	if [ $eENABLED = "1" ]; then
	#email notification
	sendemail -f $FROM -t $TO -u "$*" -m "$*" -s $SMTP -xu $USERNAME -xp $PASSWORD -o tls=yes
	sleep 3s
	fi
}

function telegram_call () {
	if [ $tENABLED = "1" ]; then
	# telegram notification
	curl -s -X POST $URL -d chat_id=$CHAT_ID -d text="$*"
	fi
}

#Check if script is running
if [ -e "/home/$(whoami)/.qsinbstees/script.running" ]; then
    echo "$(date '+%Y%m%d-%H:%M:%S') : Another instance of the script is running. Aborting." >> ~/.qsinbstees/qsinbstees_control.log
    exit
else
    touch /home/$(whoami)/.qsinbstees/script.running
fi

#another method to check looping script (Method 2)
#if [ $(pgrep -f infinitynode_expired_solution.sh) -gt "1" ]; then
#    echo "Another instance of the script is running. Aborting."
#    exit
#fi

qsinbstees_deamon_name="qsinbsteesd"
qsinbstees_deamon="/home/$(whoami)/qsinbsteesd"
qsinbstees_cli="/home/$(whoami)/qsinbstees-cli"

DATE_WITH_TIME=`date "+%Y%m%d-%H:%M:%S"`

# get current blockheight from QSTEES explorer and infinity node
mn_blockheight=$($qsinbstees_cli getblockcount)
exp_blockheight=$(curl -s http://explorer.qsinbsteesovate.io/getblockcount --max-time 45)
echo "$(date '+%Y%m%d-%H:%M:%S') : Checking link return: $exp_blockheight" >> ~/.qsinbstees/qsinbstees_control.log

if [ -z "$exp_blockheight" -o ${#exp_blockheight} -gt 10 ]; then
	exp_blockheight=$(curl -s http://qsinbstees.ccore.online/api/getblockcount --max-time 45)
	echo "$(date '+%Y%m%d-%H:%M:%S') : QSTEES main explorer is down. Using secondary explorer as backup" >> ~/.qsinbstees/qsinbstees_control.log
	#telegram_call $var1
	#email_send $var1
fi


function script_exit_fix_apply() {
	#exit, remove checking files and notify back online via telegram at next script run
	touch /home/$(whoami)/.qsinbstees/telegram.send
	rm /home/$(whoami)/.qsinbstees/script.running
	echo "$(date '+%Y%m%d-%H:%M:%S') : ------------------" >> ~/.qsinbstees/qsinbstees_control.log
	exit
}

function script_exit() {
	#exit and remove checking files
	rm /home/$(whoami)/.qsinbstees/script.running
	echo "$(date '+%Y%m%d-%H:%M:%S') : ------------------" >> ~/.qsinbstees/qsinbstees_control.log
	exit
}

function start_node() {
	echo "$(date '+%Y%m%d-%H:%M:%S') : delete caches files debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat" >> ~/.qsinbstees/qsinbstees_control.log 
	cd ~/.qsinbstees && rm debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat
	sleep 5

	telegram_call $var2
	email_send $var2

	echo "$(date '+%Y%m%d-%H:%M:%S') : Start qsinbstees deamon $qsinbstees_deamon" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$(date '+%Y%m%d-%H:%M:%S') : QSTEES_START" >> ~/.qsinbstees/qsinbstees_control.log
	$qsinbstees_deamon &
}

function stop_start_node() {
	echo "$(date '+%Y%m%d-%H:%M:%S') : delete caches files debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat" >> ~/.qsinbstees/qsinbstees_control.log 
	cd ~/.qsinbstees && rm debug.log db.log fee_estimates.dat governance.dat mempool.dat mncache.dat mnpayments.dat netfulfilled.dat
	echo "$(date '+%Y%m%d-%H:%M:%S') : kill process by name $qsinbstees_deamon_name" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$(date '+%Y%m%d-%H:%M:%S') : QSTEES_STOP" >> ~/.qsinbstees/qsinbstees_control.log
	pgrep -f $qsinbstees_deamon_name | awk '{print "kill -9 " $1}' | sh >> ~/.qsinbstees/qsinbstees_control.log
	rm /home/$(whoami)/.qsinbstees/qsinbsteesd.pid
	sleep 15

	telegram_call $var3
	email_send $var3

	echo "$(date '+%Y%m%d-%H:%M:%S') : Restart qsinbstees deamon $qsinbstees_deamon" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$(date '+%Y%m%d-%H:%M:%S') : QSTEES_START" >> ~/.qsinbstees/qsinbstees_control.log
	$qsinbstees_deamon &
}

function resync_node() {
        echo "$(date '+%Y%m%d-%H:%M:%S') : kill process by name $qsinbstees_deamon_name" >> ~/.qsinbstees/qsinbstees_control.log
        echo "$(date '+%Y%m%d-%H:%M:%S') : QSTEES_STOP" >> ~/.qsinbstees/qsinbstees_control.log
        #stop service
		sudo systemctl stop qsinbsteesovate.service
		sleep 5s
		#disable cronjob
        crontab -r
		#kill QSTEES
		pgrep -f $qsinbstees_deamon_name | awk '{print "kill -9 " $1}' | sh >> ~/.qsinbstees/qsinbstees_control.log
        sleep 5s
		rm /home/$(whoami)/.qsinbstees/qsinbsteesd.pid
		
		#reindex
        echo "$(date '+%Y%m%d-%H:%M:%S') : Resyncing" >> ~/.qsinbstees/qsinbstees_control.log
        $qsinbstees_deamon -reindex
        sleep 10s

		telegram_call $var4
		email_send $var4
        
        i=0
        while [ $mn_blockheight -lt $exp_blockheight ] && [ $i -lt 60 ] #timeout 60 Minutes
        do
            let i=$i+1
			
            mn_blockheight=$($qsinbstees_cli getblockcount)
            echo "$(date '+%Y%m%d-%H:%M:%S') : Resyncing block: $mn_blockheight / $exp_blockheight" >> ~/.qsinbstees/qsinbstees_control.log
            sleep 1m
        done
        
        #enable cronjob and service
        myuser=$(whoami)
		echo "*/5 * * * * /home/$myuser/infinitynode_expired_solution.sh" | crontab
		sleep 1s
		sudo systemctl start qsinbsteesovate.service
		sleep 5s
        echo "$(date '+%Y%m%d-%H:%M:%S') : Resync done!" >> ~/.qsinbstees/qsinbstees_control.log
}

timeout --preserve-status 10 $qsinbstees_cli getblockcount
CHECK_QSTEES=$?
echo "$(date '+%Y%m%d-%H:%M:%S') : check status of qsinbsteesd: $CHECK_QSTEES" >> ~/.qsinbstees/qsinbstees_control.log

#node is active
if [ "$CHECK_QSTEES" -eq "0" ]; then
    echo "$(date '+%Y%m%d-%H:%M:%S') : qsinbstees deamon is active" >> ~/.qsinbstees/qsinbstees_control.log
    echo "$(date '+%Y%m%d-%H:%M:%S') : Explorer blockheight: $exp_blockheight" >> ~/.qsinbstees/qsinbstees_control.log
	echo "$(date '+%Y%m%d-%H:%M:%S') : Infinity Node blockheight: $mn_blockheight" >> ~/.qsinbstees/qsinbstees_control.log
	QSTEESSTATUS=`$qsinbstees_cli masternode status | grep "successfully" | wc -l`

    #infinitynode is ENABLED
    if [ "$QSTEESSTATUS" -eq "1" ]; then
        echo "$(date '+%Y%m%d-%H:%M:%S') : infinitynode is started." >> ~/.qsinbstees/qsinbstees_control.log
        
        # check blockheight not empty before comparing
		if [ $exp_blockheight -gt 219200 ]; then

            #resync infinitynode if blockheight is not equal to QSTEES explorer
            if [ "$mn_blockheight" -ge  "$exp_blockheight" ] || [ "$(($exp_blockheight - $mn_blockheight))" -le "3" ];then
                echo "$(date '+%Y%m%d-%H:%M:%S') : Blockheight is equal, no resync needed." >> ~/.qsinbstees/qsinbstees_control.log
				if [ -e "/home/$(whoami)/.qsinbstees/telegram.send" ]; then
					telegram_call $var5
					email_send $var5
					rm /home/$(whoami)/.qsinbstees/telegram.send
				fi
				script_exit
            else
                echo "$(date '+%Y%m%d-%H:%M:%S') : Blockheight not synced! Resyncing!" >> ~/.qsinbstees/qsinbstees_control.log
				telegram_call $var6
				email_send $var6
                resync_node
				sleep 10s
				script_exit_fix_apply
            fi
        else
            echo "$(date '+%Y%m%d-%H:%M:%S') : Get blockcount error (qsinbsteesovate-api timeout), abort blockheight-check " >> ~/.qsinbstees/qsinbstees_control.log
			telegram_call $var7
			email_send $var7
			script_exit_fix_apply
        fi

    else
        echo "$(date '+%Y%m%d-%H:%M:%S') : Node is synchronising...please wait!" >> ~/.qsinbstees/qsinbstees_control.log
		telegram_call $var11
		email_send $var11
		script_exit_fix_apply
    fi
fi

#node is stopped by supplier - maintenance
if [ "$CHECK_QSTEES" -eq "1" ]; then
	#find qsinbsteesd
	QSTEESD=`ps -e | grep $qsinbstees_deamon_name | wc -l`
	if [ "$QSTEESD" -eq "0" ]; then
		telegram_call $var8
		email_send $var8
		start_node
		sleep 10s
		script_exit_fix_apply
	else
		telegram_call $var9
		email_send $var9
		stop_start_node
		sleep 10s
		script_exit_fix_apply
	fi
fi

#command not found
if [ "$CHECK_QSTEES" -eq "127" ]; then
	echo "$(date '+%Y%m%d-%H:%M:%S') : Command not found. Please change the path of qsinbstees_deamon and qsinbstees_cli." >> ~/.qsinbstees/qsinbstees_control.log
	script_exit
fi

#node is frozen
if [ "$CHECK_QSTEES" -eq "143" ]; then
	echo "$(date '+%Y%m%d-%H:%M:%S') : qsinbstees deamon will be restarted...." >> ~/.qsinbstees/qsinbstees_control.log
	telegram_call $var10
	email_send $var10
	stop_start_node
	sleep 10s
	script_exit_fix_apply
fi
