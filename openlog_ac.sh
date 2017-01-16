#!/bin/sh /etc/rc.common
OpenlogDebugLog=/tmp/openlog_debuglog
LogList=/tmp/openlog_list

DebugLog() {
   echo "["$(date +"%Y/%m/%d %H:%M:%S")"] "$* 2>&1 | tee -a ${OpenlogDebugLog} 
}

CheckArg() {
    if [ -z ${MAC} ]; then
        DebugLog "ERROR: --mac not found"
        exit
    fi
    if [ -z ${Action} ]; then
        DebugLog "ERROR: --action not found"
        exit
    fi
    if [ "$Action" = "read" -a -z "$Filename" ]; then
        DebugLog "ERROR: --filename not found !"
        exit
    fi
    if [ -n "$ReadStart" -a -n "$ReadEnd" ]; then
        if [ $ReadStart -eq 0 -a $ReadEnd -eq 0 ]; then
            DebugLog "ReadStart= $ReadStart"
            DebugLog "ReadEnd= $ReadEnd"
        elif [ $ReadStart -ge $ReadEnd ]; then
            DebugLog "ERROR: ReadStart must be less than ReadEnd !"
            exit
        elif [ $ReadStart -lt 0 ]; then
            DebugLog "ERROR: ReadStart must be greater than 0 !"
            exit
#        elif [ $ReadStart -ge $FileSize ]; then
#            DebugLog "ERROR: ReadStart must be less than Log file size !"
#            exit
#        elif [ $ReadEnd -gt $FileSize ]; then
#            DebugLog "ERROR: ReadEnd must be less than Log file size !"
#            exit
#        else
#            FileSize=$((${ReadEnd} - ${ReadStart}))
#            DebugLog "FileSize= "$FileSize
        fi
    elif [ -z "$ReadStart" -a -n "$ReadEnd" ]; then
        DebugLog "ERROR: --readstart not found !"
        exit
    elif [ -n "$ReadStart" -a -z "$ReadEnd" ]; then
        DebugLog "ERROR: --readend not found !"
        exit
    fi
}

LogHelp() {
    echo "\nUsage: sh "$0" --mac MAC --Action Action [--Filename FILENAME] [--LogId LOG_INDEX] [--timeout WumTimeout]"
    echo "--mac : wtp MAC ADDRESS"
    echo "                   MAC address format: XX:XX:XX:XX:XX:XX"
    echo "--action : Action"
    echo "  enable           Enable openlog console"
    echo "  disable          Disable openlog console"
    echo "  status           Show openlog console status"
    echo "  list             List log files"
    echo "  read             Read log file. <sh "$0" -a read -s MaxFileSize>"
    echo "  export           Export log file. Only available for command MODE (-c 0)"
    echo "  delete           Delete log file"
    echo "  reset            Reset log file index to 0"
    echo "  auto             Automatically enable openlog console, export all logs, upload to tftp server, delete uploaded logs from SD card, and disable console"
    echo "--maxfilesize : MaxFileSize"
    echo "                   MaxFileSize is the max. size (byes) of each log file."
    echo "                   Specifying the value carefully to avoid log file is too big for free memory"
    echo "--filename : FILENAME"
    echo "                   Log FILENAME to read/delete/export."
    echo "                   Using \"all\" can delete all log files when Action is \"delete\" (-a delete)" 
    echo "--logid : LOG_INDEX (required when --Action export)"
    echo "                   Log index to export"
    echo "--readstart : ReadStart (required enter with --readend)"
    echo "                   start byte of log to read"
    echo "--readend : ReadEnd (required enter with --readstart)"
    echo "                   End byte of log to read" 
    echo "--tftpsrv : TftpSrv (default: diagnosis.engeniusnetworks.com)"
    echo "                   IP or hostname of tftp server for uploading log"
    echo "--wumtimeout : WumTimeout (default: 60 secs)"
    echo "                   Timeout for wum. Extend the timeout if openlog response slowly" 
}

DebugLog "############ openlog_ac Main START ############"

[ $(ls -l $OpenlogDebugLog | awk '{print $5}') -ge 3000000 ] && rm $OpenlogDebugLog

while [ $# -ge 1 ]
do
    argv="$1"
    case $argv in
        --mac)
            MAC="$2"
            #echo "Action="$Action
            shift 2
            ;;

        --action)
            Action="$2"
            #echo "Action="$Action
            case $Action in
                enable )    ;;
                disable )   ;;
                status )    ;;
                list )      ;;
                showlist)   ;;
                read )      ;;
                export )    ;;
                delete )    ;;
                reset )     ;; 
                auto )      ;;  
                "")         LogHelp
                            exit
                            ;;
                * )         DebugLog "ERROR: Invalid Action"
                            exit
                            ;;
            esac
            shift 2
            ;;
        --maxfilesize)
            MaxFileSize="$2"
            #echo "MaxFileSize="${MaxFileSize}
            case ${MaxFileSize} in
                ''|*[!0-9]*)    DebugLog "ERROR: MaxFileSize is not a number\n"
                                exit
                                ;;
                *)              if [ ${MaxFileSize} -le 0 ]; then
                                    DebugLog "ERROR: MaxFileSize must be more than 0\n"
                                    exit
                                fi
                                ;;
            esac
            shift 2
            ;;
        --filename)
            Filename="$2"
            #echo "Filename="${Filename}
            shift 2
            ;;
        --logid)
            LogId="$2"
            #echo "LogId="${LogId}
            case ${LogId} in
                ''|*[!0-9]*)    DebugLog "ERROR: LOG_INDEX is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            shift 2
            ;;
        --readstart)
            ReadStart="$2"
            case ${ReadStart} in
                ''|*[!0-9]*)    DebugLog "ERROR: ReadStart is not a number"
                                exit
                                ;;
                *)              
                                ;;
            esac
            shift 2
            ;;
        --readend)
            ReadEnd="$2"
            case ${ReadEnd} in
                ''|*[!0-9]*)    DebugLog "ERROR: ReadEnd is not a number"
                                exit
                                ;;
                *)              
                                ;;
            esac
            shift 2
            ;;
        --tftpsrv)
            TftpSrv="$2"
            #echo "TftpSrv="${TftpSrv}
            shift 2
            ;;
        --wumtimeout)
            WumTimeout="$2"
            #echo "WumTimeout="${WumTimeout}
            case ${WumTimeout} in
                ''|*[!0-9]*)    DebugLog "ERROR: wum TIMEOUT is not a number\n"
                                exit
                                ;;
                *)              
                                ;;
            esac
            shift 2
            ;;
        -h|--help)
            LogHelp
            exit
            ;;
        *)
            DebugLog "Invalid argument"
            exit
            ;;
    esac
done

CheckArg
#WumTimeout=$((${read_timeout} + 60))
#echo "wum_time="${WumTimeout}
DebugLog "Action= "$Action
if [ ${Action} = "showlist" ]; then
    COMM_tmp="cat ${LogList}"
else
    COMM_tmp="sh /usr/sbin/openlog.sh --action ${Action}"
    [ "$MaxFileSize" != "" ] && COMM_tmp="${COMM_tmp} --maxfilesize ${MaxFileSize}"
    [ "$Filename" != "" ] && COMM_tmp="${COMM_tmp} --filename ${Filename}"
    [ "$ReadStart" != "" ] && COMM_tmp="${COMM_tmp} --readstart ${ReadStart}"
    [ "$ReadEnd" != "" ] && COMM_tmp="${COMM_tmp} --readend ${ReadEnd}"
    [ "$LogId" != "" ] && COMM_tmp="${COMM_tmp} --logid ${LogId}"   
    [ "$TftpSrv" != "" ] && COMM_tmp="${COMM_tmp} --tftpsrv ${TftpSrv}"
    COMM_tmp="${COMM_tmp} &"
fi

if [ "$WumTimeout" = "" ]; then
    DebugLog "/usr/share/ezmaster/bin/ac/wum sh --mac $MAC --cmd $COMM_tmp"
    /usr/share/ezmaster/bin/ac/wum sh --mac $MAC --cmd "$COMM_tmp"
else
    DebugLog "/usr/share/ezmaster/bin/ac/wum sh --mac $MAC --timeout ${WumTimeout} --cmd $COMM_tmp"
    /usr/share/ezmaster/bin/ac/wum sh --mac $MAC --timeout ${WumTimeout} --cmd "$COMM_tmp" 
fi

DebugLog "############ openlog_ac Main END ############"