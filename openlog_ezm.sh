#!/bin/sh /etc/rc.common
COMM_MODE="1"
#read_timeout="15"
#wum_timeout="60"
log_file="EMPTY_FILENAME"
max_log_size="100000"
log_id="0"
MAC="0"

log_help() {
    echo "\nUsage: sh "$0" -m MAC -c COMM_MODE -a ACTION [-s MAX_LOG_SIZE] [-f FILENAME] [-i LOG_INDEX] [-t OPENLOG_READING_TIMEOUT] [-w wum_TIMEOUT]"
    echo "-m : wtp MAC ADDRESS"
    echo "                   MAC address format: XX:XX:XX:XX:XX:XX"
    echo "-c : COMM_MODE"
    echo "  1                Command mode"
    echo "  0                Interactive mode"
    echo "-a : ACTION"
    echo "  enable           Enable openlog console"
    echo "  disable          Disable openlog console"
    echo "  status           Show openlog console status"
    echo "  ls               List log files"
    echo "  read             Read log file. <sh "$0" -a read -s MAX_LOG_SIZE>"
    echo "  export           Export log file. Only available for command COMM_MODE (-c 0)"
    echo "  delete           Delete log file"
    echo "  reset            Reset log file index to 0"
    echo "  auto             Automatically enable openlog console, export all logs, upload to tftp server, delete uploaded logs from SD card, and disable console"
    echo "-s : MAX_LOG_SIZE (required when -a read/export, Default:"${max_log_size}
    echo "                   MAX_LOG_SIZE is the max. size (byes) of each log file."
    echo "                   Specifying the value carefully to avoid log file is too big to free memory"
    echo "-f : FILENAME"
    echo "                   Log filename to read/delete/export."
    echo "                   Using \"all\" can delete all log files when ACTION is \"delete\" (-a delete)" 
    echo "-i : LOG_INDEX (required when -a export)"
    echo "                   Log index to export"
    echo "-t : OPENLOG_READING_TIMEOUT (default: 15 secs)"
    echo "                   Timeout for reading log. Extend the timeout if log is not completed"
    echo "-u : Upload TFTP SERVER (default: diagnosis.engeniusnetworks.com)"
    echo "                   IP or hostname for tftp server"
    echo "-w : wum_TIMEOUT (default: 60 secs)"
    echo "                   Timeout for wum. Extend the timeout if openlog response slowly"   
}

while getopts c:a:s:f:i:t:m:u:w:? argv
do
    case $argv in
        c)  COMM_MODE=$OPTARG
            echo "COMM_MODE="${COMM_MODE}
            if [ ${COMM_MODE} != "1" ]; then
                echo "Error: Invalid COMM_MODE"
                exit
            fi
            ;;
        a)  ACTION=$OPTARG
            echo "ACTION="$ACTION
            ;;
        s)  max_log_size=$OPTARG
            echo "max_log_size="${max_log_size}
            case ${max_log_size} in
                ''|*[!0-9]*)    echo "\nError: MAX_LOG_SIZE is not a number\n"
                                exit
                                ;;
                *)              if [ ${max_log_size} -le 0 ]; then
                                    echo "\nError: MAX_LOG_SIZE must larger than 0\n"
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
                ''|*[!0-9]*)    echo "\nError: LOG_INDEX is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            ;;
        t)  read_timeout=$OPTARG
            echo "timeout="${read_timeout}
            case ${read_timeout} in
                ''|*[!0-9]*)    echo "\nError: openlog read TIMEOUT is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            ;;
        m)  MAC=$OPTARG
            echo "MAC="${MAC}
            ;;
        u)  tftp_srv=$OPTARG
            echo "tftp_srv="${tftp_srv}
            ;;
        w)  wum_timeout=$OPTARG
            echo "wum_timeout="${wum_timeout}
            case ${wum_timeout} in
                ''|*[!0-9]*)    echo "\nError: wum TIMEOUT is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            ;;
        ?)  log_help
            exit
            ;;
    esac
done

if [ -z ${MAC} ]; then
	echo "\nError: -m MAC not found"
	exit
fi

case $ACTION in
    enable )    ;;
    disable )   ;;
    status )    ;;
    ls )        ;;
    read )      ;;
    export )    ;;
    delete )    ;;
    reset )     ;;         
    "")         log_help
				exit
                ;;
    * )         echo "\nError: Invalid action"
				exit
                ;;
esac

if [ -z ${read_timeout} ]; then
    # Need around 15 sec per 10KB size to output openlog read to AP/tmp/screenlog.0 completely
    read_timeout="0"
fi

echo "read_timeout="${read_timeout}

wum_timeout=$((${read_timeout} + 60))
echo "wum_time="${wum_timeout}

echo "/usr/share/ezmaster/bin/ac/wum sh --mac "${MAC}" --cmd \"sh /usr/sbin/openlog.sh -c "${COMM_MODE}" -a "${ACTION}" -s "${max_log_size}" -f "${log_file}" -i "${log_id}" -t "${read_timeout}"\" --timeout "${wum_timeout}

BEGIN=$(date)

/usr/share/ezmaster/bin/ac/wum sh --mac ${MAC} --cmd "sh /usr/sbin/openlog.sh -c ${COMM_MODE} -a ${ACTION} -s ${max_log_size} -f ${log_file} -i ${log_id} -t ${read_timeout}" --timeout ${wum_timeout}

END=$(date)

echo "BEGIN="${BEGIN}" , END="${END}