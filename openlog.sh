#!/bin/sh /etc/rc.common
# Copyright (C) 2006 OpenWrt.org
INITTAB=/etc/inittab
screen_config=/etc/screenrc
screenlog=/tmp/screenlog.0
log_list=/tmp/openlog_list
terminal=/dev/ttyS0
openlog_state=/tmp/openlog_state
COMM_MODE='1'
log_file="EMPTY_FILENAME"
read_timeout="0"
MAC=$(ifconfig br-lan | grep HWaddr | sed 's/\ //g' | sed 's/.*HWaddr//' | sed 's/\://g')
tftp_srv=diagnosis.engeniusnetworks.com
record_time=""

console_enable() {
    echo "console_enable"

    echo 'Enabling openlog console, please wait...'
    [ -n "$(screen -ls | grep tached)" ] && killall screen
    #screen -ls | grep tached | cut -d. -f1 | awk '{print $1}' | xargs kill &> /dev/null
    echo -e '::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\n#ttyS0::askfirst:/bin/login' > ${INITTAB}
	init -q
    ping -w 5 127.0.0.1 &> /dev/null
	echo -e "startup_message off\nlogfile $screenlog" > ${screen_config}
    screen -dmL ${terminal} 115200,cs8
    ping -w 1 127.0.0.1 &> /dev/null
    screen -r -p 0 -X eval 'stuff $$$'
    ping -w 5 127.0.0.1 &> /dev/null
    screen -r -p 0 -X eval 'stuff q1\015'
    ping -w 5 127.0.0.1 &> /dev/null
    screen -r -p 0 -X eval 'stuff q2\015'
    ping -w 5 127.0.0.1 &> /dev/null
    screen -r -p 0 -X eval 'stuff q3\015'
    ping -w 5 127.0.0.1 &> /dev/null
    killall screen &> /dev/null
    ping -w 1 127.0.0.1 &> /dev/null
    screen -dmL ${terminal} 115200,cs8
    ping -w 1 127.0.0.1 &> /dev/null
    screen -r -p 0 -X eval 'stuff q4\015\015\015\015\015\015\015\015\015\015\015'

    echo -e '::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\nttyS0::askfirst:/bin/login' > ${INITTAB}
    echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
    echo "console_enable OK" 2>&1 | tee ${openlog_state}
}

console_disable() {
    echo "console_disable"
    echo 'Disabling openlog console, please wait...'
    echo > ${screenlog}
    screen -r -p 0 -X eval 'stuff \015\015\015'
    ping -w 3 127.0.0.1 &> /dev/null   
    screen -r -p 0 -X eval 'stuff reset\015'
    ping -w 3 127.0.0.1 &> /dev/null
    killall screen &> /dev/null
    echo -e '::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\nttyS0::askfirst:/bin/login' > ${INITTAB}
    init -q
    rm ${openlog_state}
    echo "console_disable OK"
}

show_console_status() {
    echo "console_status"
    if [ -f "${openlog_state}" -a -n "$(screen -ls | grep tached)" ]; then
        echo -e "\nOpenlog console is enabled\n"
    else
        echo -e "\nOpenlog console is disabled\n"
    fi
    echo "console_status OK"
    echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
}

check_console_status(){
    echo "check_console_status"
    if [ ! -f "${openlog_state}" -o -z "$(screen -ls | grep tached)" ]; then
        echo -e "\nError: Openlog console is disabled, please run \"sh "$0" enable\" first.\n"
        exit
    fi  
}

log_ls() {
    echo "log_ls"
    check_console_status

    echo > ${screenlog}
    echo 'Reading file list, please wait...'
    screen -r -p 0 -X eval 'stuff ls\015'
    #echo -e "ls\015" > ${terminal}
    ping -w 15 127.0.0.1 &> /dev/null
    grep LOG ${screenlog} > ${log_list}

    file_num=$(wc -l < ${log_list})
    echo "file_num="$file_num
    echo "ID:Name          Size"
    grep -n . ${log_list}
    echo > ${screenlog}
    echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
    echo "log_ls OK"
}

log_read() {
    echo 'log_read'
    echo "TIMEOUT="${read_timeout}
    if [ -z "${max_log_size}" ] ; then
                    echo -e "\nError: -s MAX_LOG_SIZE not found"
                    exit
    fi

    check_console_status

    if [ ${COMM_MODE} = '1' ]; then
        log_ls     
        if [ -z "$(grep -w ${log_file} ${log_list})" ]; then
            echo -e "\nError: Invalid filename"
        else
            loop_conf
            if [ -z ${log_id} ]; then
                log_id='0'
                while [ ${log_id} -le ${loop} ]; do
                    echo "log_id="${log_id}
                    log_read_sub
                    cat ${screenlog}
                    #echo > ${screenlog}
                    log_id=$((${log_id}+1))                            
                done
            else
                log_read_sub
                #cat ${screenlog}
                #echo > ${screenlog}
            fi
            echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
            echo "log_read OK"
        fi
    elif [ ${COMM_MODE} = '0' ]; then
        log_ls
        #http://stackoverflow.com/questions/226703/how-do-i-prompt-for-input-in-a-linux-shell-script 
        while true; do
            echo > ${screenlog}
            read -p "Which file ID you want to read ? (or input \"ls\" for print file list, \"N/n\" for exit) " file_id
            case $file_id in
                [0-9]* )    echo "file_id="$file_id
                            if [ ${file_id} = '0' ] || [ ${file_id} -gt ${file_num} ] ; then
                                echo "File ID doesn't exist"
                            else
                                log_file="$(sed ${file_id}'!d' ${log_list} | awk '{print $1}')"
                                echo "log_file="${log_file}
                                log_size="$(sed ${file_id}'!d' ${log_list} | awk '{print $2}')"
                                echo "log_size="${log_size}
                                loop_conf

                                log_id=0
                                while [ ${log_id} -le ${loop} ]; do
                                    log_read_sub
                                    cat ${screenlog}
                                    echo "log_read OK"
                                    log_export
                                    log_id=$((${log_id}+1))                            
                                done
                            fi
                            ;;

                ls )        grep -n . $log_list
                            ;;

                [Nn] )      echo > ${screenlog}
                            echo "log_ls exit"
                            echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
                            exit
                            ;;

                * )         echo "Please input file ID."
                            ;;
            esac
        done
    fi  
}

loop_conf() {
    echo "loop_conf"
    grep -w ${log_file} ${log_list}
    log_size="$(grep -w ${log_file} ${log_list} | awk '{print $2}')"
    echo "log_size="${log_size}
    loop=$((${log_size} / ${max_log_size}))
    echo "loop="${loop}
    loop_remainder=$((${log_size} % ${max_log_size}))
    echo "loop_remainder="${loop_remainder}
}

log_read_sub() {
    echo "log_read_sub"
    echo "log_id="${log_id}
    echo 'Reading '${log_file}', please wait...' 2>&1 | tee ${openlog_state}

    i='1'
    if [ ${log_id} -gt ${loop} ]; then
        echo -e "\nError: Invalid log ID"
        exit
    elif [ ${log_id} -lt ${loop} ]; then
        screen -r -p 0 -X eval "stuff 'read ${log_file} $((${log_id} * ${max_log_size})) ${max_log_size}'\015"
        ping -w ${read_timeout} 127.0.0.1 &> /dev/null
        
        while [ $(ls -l ${screenlog} | awk '{print $5}') -lt ${max_log_size} ]; do
            echo 'Reading '${log_file}', please wait...'$(((${i} * 10) + ${read_timeout}))
            ping -w 10 127.0.0.1 &> /dev/null
            i=$((${i} + 1))
        done

    else
        screen -r -p 0 -X eval "stuff 'read ${log_file} $((${log_id} * ${max_log_size})) ${loop_remainder}'\015"
        ping -w ${read_timeout} 127.0.0.1 &> /dev/null
        
        while [ $(ls -l ${screenlog} | awk '{print $5}') -lt ${loop_remainder} ]; do
            echo 'Reading '${log_file}', please wait...'$(((${i} * 10) + ${read_timeout}))
            ping -w 10 127.0.0.1 &> /dev/null
            i=$((${i} + 1))
        done
    fi
    echo 'log_read_sub OK' 2>&1 | tee ${openlog_state}

}

log_export() {
    echo "log_export"

    if [ ${log_file} = "EMPTY_FILENAME" ]; then
        echo -e "\nError: -s FILENAME not found"
        exit
    elif [ -z "${max_log_size}" ]; then
        echo -e "\nError: -s MAX_LOG_SIZE not found"
        exit
    elif [ -z "${log_id}" ]; then
        echo -e "\nError: -i LOG_INDEX not found"
        exit
    fi

    check_console_status
    
    if [ ${COMM_MODE} = '1' ]; then
        log_ls
        if [ -z "$(grep -w ${log_file} ${log_list})" ]; then
            echo -e "\nError: Invalid filename"
        else
            loop_conf
            log_read_sub
            log_export_sub
        fi
    elif [ ${COMM_MODE} = '0' ]; then
        while true; do
            read -p "Do you want to export "${log_file}"? (y/n) " yn
            case $yn in
                [Yy] )      log_export_sub
                            break;;

                [Nn] )      echo "log_export exit"
                            break;;

                * )         echo "Please input Y/y or N/n.";;
            esac
        done
    fi 

    echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
    echo "log_export OK"   
}

log_export_sub() {
    echo "log_export_sub"
    log_filename=$(echo "openlog_LOG_"${MAC}"_"${log_file}"."${log_id}"_"${record_time})
    echo "log_filename="${log_filename}
    echo "Exporting "${log_file}" to /tmp/"${log_filename}".gz, please wait..."
    gzip -c ${screenlog} > /tmp/${log_filename}.gz
    echo "/tmp/"${log_filename}".gz file size="$(ls -l /tmp/${log_filename}.gz | awk '{print $5}')" bytes"
    cat /proc/meminfo |grep MemFree
    echo > ${screenlog}
}

log_delete() {
    echo 'log_delete'
    check_console_status

    if [ ${COMM_MODE} = '1' ]; then
        log_ls
        if [ ${log_file} = "all" ]; then
            cat ${log_list} | awk '{print $1}' | while read output
            do
            if [ $output != "" ]; then
                echo "Deleting "${output}, "please wait..."
                screen -r -p 0 -X eval "stuff 'rm ${output}'\015"
                ping -w 1 127.0.0.1 &> /dev/null
            fi
            done
            reset
        elif [ -z "$(grep -w ${log_file} ${log_list})" ]; then
            echo -e "\nError: Invalid filename"
        else
            grep -w ${log_file} ${log_list}
            echo 'Deleting '${log_file}', please wait...'
            screen -r -p 0 -X eval "stuff 'rm ${log_file}'\015"
            ping -w 1 127.0.0.1 &> /dev/null
        fi
    elif [ ${COMM_MODE} = '0' ]; then
        while true; do
            log_ls
            #http://stackoverflow.com/questions/226703/how-do-i-prompt-for-input-in-a-linux-shell-script 
            read -p "Which file ID you want to delete ? (Input \"all\" for delete all log files or N/n for exit) " file_id
            case $file_id in
                [0-9]* )    echo "file_id="$file_id
                            if [ $file_id = '0' ] || [ $file_id -gt $file_num ] ; then
                                echo "File ID doesn't exist"
                            else
                                log_file="$(sed ${file_id}'!d' ${log_list} | awk '{print $1}')"
                                echo "log_file="${log_file}
                                echo 'Deleting '${log_file}', please wait...'
                                screen -r -p 0 -X eval "stuff 'rm ${log_file}'\015"
                                ping -w 1 127.0.0.1 &> /dev/null
                                echo > ${screenlog}
                                echo "log_delete OK"
                            fi
                            ;;
                all )   cat ${log_list} | awk '{print $1}' | while read output
                            do
                                if [ $output != "" ]; then
                                    echo "Deleting "${output}, "please wait..."
                                    screen -r -p 0 -X eval "stuff 'rm ${output}'\015"
                                    ping -w 1 127.0.0.1 &> /dev/null
                                fi
                            done
                            reset
                            break
                            ;;
                [Nn] )      echo "log_delete exit"
                            break
                            ;;
                * )         echo "Please input file ID."
                            ;;
            esac
        done
    fi

    echo > ${screenlog}
    echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
    echo "log_delete OK"
}

reset() {
    echo "reset"
    check_console_status

    echo > ${screenlog}
    screen -r -p 0 -X eval 'stuff set\015'
    ping -w 5 127.0.0.1 &> /dev/null
    screen -r -p 0 -X eval 'stuff 4\015'
    echo "reset OK"
    echo -e "Remember to run \"sh "$0" disable\" when finished using "$0
}

auto_export_upload() {
    echo "auto_export_upload"
    if [ $COMM_MODE != "1" ]; then
        echo "COMM_MODE must be 1"
        exit
    fi
    
    record_time=$(date +"%Y%m%d%H%M%S")
    echo "Record time="$(date +"%Y%m%d%H%M%S")

    console_enable
    log_ls

    cat ${log_list} | awk '{print $1}' | while read output
    do
        if [ $output != "" ]; then
            echo "Exporting and Uploading "${output}, "please wait..."
            log_file=${output}
            log_id='0'
            while [ ${log_id} -le ${loop} ]; do
                echo "log_id="${log_id}
                loop_conf
                log_read_sub
                log_export_sub
                tftp_upload
                log_id=$((${log_id}+1))                            
            done     
        fi
    done
    
    #log_file="all"
    #log_delete
    #reset
    #console_disable  
}

tftp_upload()
{
    cd /tmp
    tftp -p -l ${log_filename} ${tftp_srv}
    rm /tmp/${log_filename}
}

log_help() {
    echo -e "\nUsage: sh "$0" -c COMM_MODE -a ACTION [-s MAX_LOG_SIZE] [-f FILENAME] [-i LOG_INDEX] [-t TIMEOUT]"
    echo -e "-c : COMM_MODE"
    echo -e "  1                Command mode"
    echo -e "  0                Interactive mode"
    echo -e "-a : ACTION"
    echo -e "  enable           Enable openlog console"
    echo -e "  disable          Disable openlog console"
    echo -e "  status           Show openlog console status"
    echo -e "  ls               List log files"
    echo -e "  read             Read log file. <sh "$0" -a read -s MAX_LOG_SIZE>"
    echo -e "  export           Export log file. Only available for command COMM_MODE (-c 0)"
    echo -e "  delete           Delete log file"
    echo -e "  reset            Reset log file index to 0"
    echo -e "  auto             Automatically enable openlog console, export all logs, upload to tftp server, delete uploaded logs from SD card, and disable console"
    echo -e "-s : MAX_LOG_SIZE (required when -a read/export)"
    echo -e "                   MAX_LOG_SIZE is the max. size (byes) of each log file."
    echo -e "                   Specifying the value carefully to avoid log file is too big to free memory"
    echo -e "-f : FILENAME"
    echo -e "                   Log filename to read/delete/export."
    echo -e "                   Using \"all\" can delete all log files when ACTION is \"delete\" (-a delete)" 
    echo -e "-i : LOG_INDEX (required when -a export)"
    echo -e "                   Log index to export"
    echo -e "-t : TIMEOUT (default: 15 secs)"
    echo -e "                   Timeout for reading log. Extend the timeout if log is not completed"
    echo -e "-u : Upload TFTP SERVER (default: diagnosis.engeniusnetworks.com)"
    echo -e "                   IP or hostname for tftp server"
}

while getopts “c:a:s:f:i:t:u:?” argv
do
    case $argv in
        c)  COMM_MODE=$OPTARG
            echo "COMM_MODE="${COMM_MODE}
            if [ ${COMM_MODE} != "0" -a ${COMM_MODE} != "1" ]; then
                echo -e "Error: Invalid COMM_MODE"
                exit
            fi
            ;;
        a)  ACTION=$OPTARG
            echo "ACTION="$ACTION
            ;;
        s)  max_log_size=$OPTARG
            echo "max_log_size="${max_log_size}
            case ${max_log_size} in
                ''|*[!0-9]*)    echo -e "\nError: MAX_LOG_SIZE is not a number\n"
                                exit
                                ;;
                *)              if [ ${max_log_size} -le 0 ]; then
                                    echo -e "\nError: MAX_LOG_SIZE must larger than 0\n"
                                    exit
                                fi
                                ;;
            esac
            ;;
        f)  log_file=$OPTARG
            echo "log_file="${log_file}
            ;;
        i)  log_id=$OPTARG
            echo "log_id="${log_id}
            case ${log_id} in
                ''|*[!0-9]*)    echo -e "\nError: LOG_INDEX is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            ;;
        t)  read_timeout=$OPTARG
            echo "timeout="${read_timeout}
            case ${read_timeout} in
                ''|*[!0-9]*)    echo -e "\nError: TIMEOUT is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            ;;
        u)  tftp_srv=$OPTARG
            echo "tftp_srv="${tftp_srv}
            ;;
        ?)  log_help
            exit
            ;;
    esac
done

case $ACTION in
    enable )                console_enable
                            ;;
    disable )               console_disable
                            ;;
    status )                show_console_status
                            ;;
    ls )                    log_ls
                            ;;
    read )                  log_read
                            ;;
    export )                log_export
                            ;;
    delete )                log_delete
                            ;;
    reset )                 reset
                            ;;   
    auto )                  auto_export_upload
                            ;;

    "")                     log_help
                            ;;
    * )                     echo -e "\nError: Invalid action"
                            ;;
esac    