#!/bin/sh /etc/rc.common

#prints each command before it executes. enable: set -o xtrace , disable: set +o xtrace
#set -o xtrace
OpenlogVersion="1.0.1"
Inittab=/etc/inittab
ScreenConfig=/etc/screenrc
ScreenLog=/tmp/screenlog.0
LOGLIST=/tmp/openlog_list
Terminal=/dev/ttyS0
OpenlogState=/tmp/openlogstate
OpenlogDebugLog=/tmp/openlog_debugLog
Mode='1'
Filename="EMPTY_FILENAME"
ReadTimeout="10"
MAC=$(ifconfig br-lan | grep HWaddr | sed 's/\ //g' | sed 's/.*HWaddr//' | sed 's/\://g')
TftpSrv=diagnosis.engeniusnetworks.com
ExportTime=$(date +"%Y%m%d_%H%M%S")
EndChar=">"
EscapeChar="2<"
RunLogList=0
MaxStoreSize=10000000000

DebugLog() {
    if [ $Debuglvl -eq 1 ]; then
        echo "[$(date +"%Y/%m/%d %H:%M:%S")] $*" 2>&1 | tee -a ${OpenlogDebugLog}
    else
        echo "[$(date +"%Y/%m/%d %H:%M:%S")] $*" >> ${OpenlogDebugLog}
    fi
}

ConsoleEnable() {
    DebugLog "Function: ConsoleEnable"
    DebugLog "Enabling openlog console, please wait..."

    if [ -n "$(screen -ls | grep tached)" ]; then
        echo > $ScreenLog
        screen -r -p 0 -X eval 'stuff \015'
        local i=0
        while [ $i -lt 15 ]; do
            DebugLog $(echo "1.i= "$i", prompt= "$(tail -1 ${ScreenLog}))
            if [ "$(tail -1 ${ScreenLog})" != "${EndChar}" ] && [ "$(tail -1 ${ScreenLog})" != "${EscapeChar}" ]; then
                sleep 1
            else
                DebugLog "Openlog console is already enabled"
                break
            fi
            i=$(($i+1))
        done
    fi

    if [ "$(tail -1 ${ScreenLog})" != "${EndChar}" ] && [ "$(tail -1 ${ScreenLog})" != "${EscapeChar}" ]; then
        killall screen
        echo -e '::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\n#ttyS0::askfirst:/bin/login' > ${Inittab}
        init -q
        sleep 5
        echo -e "startup_message off\nlogfile $ScreenLog" > ${ScreenConfig}
        screen -c ${ScreenConfig} -dmL ${Terminal} 115200,cs8
        sleep 2
        #screen -ls | grep tached | cut -d. -f1 | awk '{print $1}' | xargs kill &> /dev/null
        screen -r -p 0 -X eval 'stuff $$$'
        sleep 5
        screen -r -p 0 -X eval 'stuff q1\015'
        sleep 5
        screen -r -p 0 -X eval 'stuff q2\015'
        sleep 5
        screen -r -p 0 -X eval 'stuff q3\015'
        sleep 5
        killall screen &> /dev/null
        sleep 2
        screen -dmL ${Terminal} 115200,cs8
        sleep 2
        screen -r -p 0 -X eval 'stuff q4\015\015\015\015\015\015\015\015\015\015\015'
        sleep 2
        echo -e '::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\nttyS0::askfirst:/bin/login' > ${Inittab}
        #echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
        
        i=0
        while [ $i -lt 15 ]; do
            if [ "$(tail -1 ${ScreenLog})" = "${EndChar}" ]; then
                DebugLog $(echo "2.i= "$i", prompt= "$(tail -1 ${ScreenLog}))
                echo "ConsoleEnable OK" 2>&1 | tee ${OpenlogState}
                DebugLog "ConsoleEnable OK"
                break
            elif [ $i -lt 14 ]; then
                DebugLog $(echo "2.i= "$i", prompt= "$(tail -1 ${ScreenLog}))
                sleep 1
            else
                DebugLog $(echo "2.i= "$i", prompt= "$(tail -1 ${ScreenLog}))
                DebugLog "ERROR: Failed to enable openlog console, please try again."
                exit
            fi
            i=$(($i+1))
        done
    fi
}

ConsoleDisable() {
    DebugLog "Function: ConsoleDisable"
    DebugLog "Disabling openlog console, please wait..."
    echo > ${ScreenLog}
    screen -r -p 0 -X eval 'stuff reset\015'
    local i=0
    while [ $i -lt 15 ]; do
        if [ "$(tail -c 2 ${ScreenLog})" = "${EscapeChar}" ]; then
            DebugLog $(echo "i= "$i", tail ScreenLog result= "$(tail -c 2 ${ScreenLog}))
            killall screen &> /dev/null
            echo -e '::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\nttyS0::askfirst:/bin/login' > ${Inittab}
            init -q
            rm ${OpenlogState}
            DebugLog "ConsoleDisable OK"
            break
        elif [ $i -lt 14 ]; then
            DebugLog $(echo "i= "$i", prompt= "$(tail -1 ${ScreenLog}))
            sleep 1
        else
            DebugLog $(echo "i= "$i", prompt= "$(tail -1 ${ScreenLog}))
            DebugLog "ERROR: Failed to disable openlog console, please try again."
            exit
        fi
        i=$(($i+1))
    done

    if [ $(ls -l $OpenlogDebugLog | grep -v .gz | awk '{print $5}') -gt 1000000 ]; then
        rm ${OpenlogDebugLog}.gz
        gzip ${OpenlogDebugLog}
    fi
}

CheckConsoleStatus() {
    DebugLog "Function: CheckConsoleStatus"
    screen -r -p 0 -X eval 'stuff q0\015'
    local i=0
    while [ $i -le 15 ]; do
        DebugLog "Prompt= "$(tail -c 2 ${ScreenLog})
        if [ "$(tail -c 2 ${ScreenLog})" = "${EscapeChar}" ]; then
            DebugLog 'Prompt= Escape Char'
            break
        elif [ "$(tail -c 1 ${ScreenLog})" = "${EndChar}" ]; then
            DebugLog 'Prompt= End Char'
            break
        elif [ $i -eq 14 ]; then
            DebugLog "ERROR: Failed to access openlog console !"
            exit
        fi
        i=$(($i+1))
        sleep 1
    done
    if [ $ACTION = "status" ]; then
        if [ -f "${OpenlogState}" -a -n "$(screen -ls | grep tached)" ]; then
            DebugLog "Openlog console is ebabled\n"
            exit
        else
            DebugLog "Openlog console is disabled\n"
            exit
        fi
    elif [ ! -f "${OpenlogState}" -o -z "$(screen -ls | grep tached)" ] || [ "$(tail -c 2 ${ScreenLog})" = "${EscapeChar}" ]; then
        DebugLog "ERROR: Openlog console is disabled, please run \"sh "$0" enable\" first.\n"
        exit
    fi  
}

LogList() {
    DebugLog "Function: LogList"
    DebugLog "RunLogList= "$RunLogList
    if [ $RunLogList != 1 ]; then
        ConsoleEnable
        echo > ${ScreenLog}
        screen -r -p 0 -X eval 'stuff ls\015'
        #echo -e "ls\015" > ${Terminal}
        local i=0
        while [ "$(tail -1 ${ScreenLog})" != ">" ]; do
            DebugLog "Reading file list, please wait...$i"
            sleep 1
            i=`expr $i + 1`
            if [ $i -gt 60 ]; then
                DebugLog "ERROR: Failed to read file list, please try again"
                exit
            fi
        done
        grep LOG ${ScreenLog} | grep -v "    LOG" | grep -v "_LOG" > ${LOGLIST}

        file_num=$(wc -l < ${LOGLIST})
        DebugLog "file_num="$file_num
        echo "ID:Name          Size"
        grep -n . ${LOGLIST} 2>&1 | tee -a ${OpenlogDebugLog} 
        #echo > ${ScreenLog}
        #echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
    fi
    RunLogList=1
    DebugLog "LogList OK"
}

LogRead() {
    DebugLog "Function: LogRead"
    DebugLog "ReadTimeout="${ReadTimeout}
    if [ ${Mode} = '1' ]; then
        if [ "$Filename" = "EMPTY_FILENAME" ]; then
            DebugLog "ERROR: Filename not found !"
            exit
        fi
        LogList   
        if [ -z "$(grep -w ${Filename} ${LOGLIST})" ]; then
            DebugLog "ERROR: Invalid FILENAME"
            exit
        else
            LoopConf
            if [ -z ${LogId} ]; then
                LogId=0
                while [ ${LogId} -le ${Loop} ]; do
                    DebugLog "LogId="${LogId}
                    LogReadSub
                    cat ${ScreenLog}
                    LogId=$((${LogId}+1))                            
                done
            else
                LogReadSub
                cat ${ScreenLog}
            fi
  #         echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
            DebugLog "LogRead OK"
        fi
    elif [ ${Mode} = '0' ]; then
        LogList
        #http://stackoverflow.com/questions/226703/how-do-i-prompt-for-input-in-a-linux-shell-script 
        while true; do
            echo > ${ScreenLog}
            read -p "Which file ID you want to read ? (or input \"ls\" for print file list, \"N/n\" for exit) " file_id
            case $file_id in
                [0-9]* )    DebugLog "file_id="$file_id
                            if [ ${file_id} = '0' ] || [ ${file_id} -gt ${file_num} ] ; then
                                DebugLog "File ID doesn't exist"
                            else
                                Filename="$(sed ${file_id}'!d' ${LOGLIST} | awk '{print $1}')"
                                DebugLog "Filename="${Filename}
                                FileSize="$(sed ${file_id}'!d' ${LOGLIST} | awk '{print $2}')"
                                DebugLog "FileSize="${FileSize}
                                LoopConf

                                LogId=0
                                while [ ${LogId} -le ${Loop} ]; do
                                    LogReadSub
                                    cat ${ScreenLog}
                                    DebugLog "LogRead OK"
                                    LogExport
                                    LogId=$((${LogId}+1))                            
                                done
                            fi
                            ;;

                ls )        grep -n . ${LOGLIST}
                            ;;

                [Nn] )      echo > ${ScreenLog}
                            DebugLog "LogList exit"
                            echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
                            exit
                            ;;

                * )         DebugLog "Please input file ID."
                            ;;
            esac
        done
    fi
    echo > ${ScreenLog}
}

LoopConf() {
    DebugLog "Function: LoopConf"
    grep -w ${Filename} ${LOGLIST}
    MemFree=$(($(cat /proc/meminfo | grep MemFree | awk '{print $2}') * 1024))
    DebugLog "MemFree= "${MemFree}
    if [ -z ${MaxFileSize_tmp} ]; then
        MaxFileSize=$((${MemFree} / 3))
    else
        MaxFileSize=${MaxFileSize_tmp}
    fi
    DebugLog "MaxFileSize= "${MaxFileSize}
    if [ ${MemFree} -le 10000000 ]; then
        DebugLog "ERROR: Free memory is less than 10,000 kB, not enough free memory !!"
        exit
    elif [ ${MaxFileSize} -gt $((${MemFree} / 2)) ]; then
        DebugLog "ERROR: MaxFileSize is too big, please decrease it !!"
        exit
    fi

    FileSize="$(grep -w ${Filename} ${LOGLIST} | awk '{print $2}')"
    DebugLog "FileSize= $FileSize"
    DebugLog "ReadStart= $ReadStart"
    DebugLog "ReadEnd= $ReadEnd"
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
        elif [ $ReadStart -ge $FileSize ]; then
            DebugLog "ERROR: ReadStart must be less than Log file size !"
            exit
        elif [ $ReadEnd -gt $FileSize ]; then
            DebugLog "ERROR: ReadEnd must be less than Log file size !"
            exit
        else
            FileSize=$((${ReadEnd} - ${ReadStart}))
            DebugLog "FileSize= "$FileSize
        fi
    elif [ -z "$ReadStart" -a -n "$ReadEnd" ]; then
        DebugLog "ERROR: ReadStart not found !"
        exit
    elif [ -n "$ReadStart" -a -z "$ReadEnd" ]; then
        DebugLog "ERROR: ReadEnd not found !"
        exit
    else
        ReadStart=0
        ReadEnd=0
    fi
    DebugLog "FileSize= "$FileSize
    Loop=$((${FileSize} / ${MaxFileSize}))
    DebugLog "Loop= "$Loop
    LoopRemainder=$((${FileSize} % ${MaxFileSize}))
    DebugLog "LoopRemainder= "$LoopRemainder
}

LogReadSub() {
    DebugLog "Function: LogReadSub"
    DebugLog "LogId= ${LogId}"
    DebugLog "Reading ${Filename}.${LogId}, please wait..."
    echo > ${ScreenLog}
    if [ ${LogId} -gt ${Loop} ]; then
        DebugLog "ERROR: Invalid log ID"
        exit
    else
        if [ ${LogId} -lt ${Loop} ]; then
            ReadLength=${MaxFileSize}
        else
            ReadLength=${LoopRemainder}
        fi
        DebugLog "ReadLength= "$ReadLength
        DebugLog "LogId= $LogId"
        DebugLog "MaxFileSize= $MaxFileSize"
        DebugLog "ReadStart= $ReadStart"
        DebugLog "ReadEnd= $ReadEnd"
        ReadStartTmp=$((${LogId} * ${MaxFileSize}))
        DebugLog="ReadStartTmp.0= $ReadStartTmp"
        ReadStartTmp=$(($ReadStartTmp + $ReadStart))
        DebugLog="ReadStartTmp.1= $ReadStartTmp"
        screen -r -p 0 -X eval "stuff 'read ${Filename} ${ReadStartTmp} ${ReadLength}'\015"
        sleep ${ReadTimeout}
        
        while [ $(ls -l ${ScreenLog} | awk '{print $5}') -lt ${ReadLength} ] || [ $(tail -c 1 ${ScreenLog}) != ${EndChar} ]; do
            DebugLog "Reading ${Filename}.${LogId}, "$(($(ls -l ${ScreenLog} | awk '{print $5}') * 100 / ${ReadLength}))"% completed."
            sleep ${ReadTimeout}
        done
    fi
    DebugLog "Reading ${Filename}.${LogId}, 100% completed."
}

LogExport() {
    DebugLog "Function: LogExport"

    if [ "${Filename}" = "EMPTY_FILENAME" ]; then
        DebugLog "ERROR: -s FILENAME not found"
        exit
    elif [ -z "${LogId}" ]; then
        DebugLog "ERROR: -i LOG_INDEX not found"
        exit
    fi

    ConsoleEnable
    
    if [ ${Mode} = '1' ]; then
        LogList
        if [ -z "$(grep -w ${Filename} ${LOGLIST})" ]; then
            DebugLog "ERROR: Invalid FILENAME"
        else
            LoopConf
            LogReadSub
            LogExportSub
        fi
    elif [ ${Mode} = '0' ]; then
        while true; do
            read -p "Do you want to export "${Filename}"? (y/n) " yn
            case $yn in
                [Yy] )      LogExportSub
                            break;;

                [Nn] )      DebugLog "LogExport exit"
                            break;;

                * )         DebugLog "Please input Y/y or N/n.";;
            esac
        done
    fi 

#    echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
#    echo "LogExport OK"   
}

LogExportSub() {
    DebugLog "Function: LogExportSub"
#    echo "ExportTime="${ExportTime}
    EXPORT_FILENAME=$(echo ${MAC}"_"${Filename}"."${LogId}"_"${ExportTime})
#    echo "EXPORT_FILENAME="${EXPORT_FILENAME}
    DebugLog "Exporting "${Filename}" to /tmp/"${EXPORT_FILENAME}".gz, please wait..."
    gzip -c ${ScreenLog} > /tmp/${EXPORT_FILENAME}.gz
    DebugLog "/tmp/"${EXPORT_FILENAME}".gz file size="$(ls -l /tmp/${EXPORT_FILENAME}.gz | awk '{print $5}')" bytes"
    DebugLog $(cat /proc/meminfo |grep MemFree 2>&1 | tee ${OpenlogState})
    echo > ${ScreenLog}
}

LogDelete() {
    DebugLog 'Function: LogDelete'
    if [ ${Mode} = '1' ]; then
        [ "$ACTION" != "auto" ] && LogList
        if [ ${Filename} = "all" ]; then
            while read output
            do
                output2=$(echo $output | awk '{print $1}')
                if [ $output2 != "" ]; then
                    DebugLog "Deleting "${output2}, "please wait..."
                    screen -r -p 0 -X eval "stuff 'rm ${output2}'\015"
                    sleep 1
                fi
            done < ${LOGLIST}
        elif [ -z "$(grep -w ${Filename} ${LOGLIST})" ]; then
            DebugLog "ERROR: Invalid FILENAME"
        else
            grep -w ${Filename} ${LOGLIST}
            DebugLog "Deleting '${Filename}', please wait..."
            screen -r -p 0 -X eval "stuff 'rm ${Filename}'\015"
            sleep 1
        fi
    elif [ ${Mode} = '0' ]; then
        while true; do
            LogList
            #http://stackoverflow.com/questions/226703/how-do-i-prompt-for-input-in-a-linux-shell-script 
            read -p "Which file ID you want to delete ? (Input \"all\" for delete all log files or N/n for exit) " file_id
            case $file_id in
                [0-9]* )    #echo "file_id="$file_id
                            if [ $file_id = '0' ] || [ $file_id -gt $file_num ]; then
                                DebugLog "File ID doesn't exist"
                            else
                                Filename="$(sed ${file_id}'!d' ${LOGLIST} | awk '{print $1}')"
                                #echo "Filename="${Filename}
                                DebugLog "Deleting '${Filename}', please wait..."
                                screen -r -p 0 -X eval "stuff 'rm ${Filename}'\015"
                                sleep 1
                                echo > ${ScreenLog}
#                                echo "LogDelete OK"
                            fi
                            ;;
                all )       while read output
                            do
                                output2=$(echo $output | awk '{print $1}')
                                if [ $output2 != "" ]; then
                                    DebugLog "Deleting "${output2}, "please wait..."
                                    screen -r -p 0 -X eval "stuff 'rm ${output2}'\015"
                                    sleep 1
                                fi
                            done < ${LOGLIST}
                            LogReset
                            break
                            ;;
                [Nn] )      DebugLog "LogDelete exit"
                            break
                            ;;
                * )         DebugLog "Please input file ID."
                            ;;
            esac
        done
    fi

    echo > ${ScreenLog}
#    echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
#    echo "LogDelete OK"
}

LogReset() {
    DebugLog "Function: LogReset"
    CheckConsoleStatus

    echo > ${ScreenLog}
    screen -r -p 0 -X eval 'stuff set\015'
    sleep 1
    screen -r -p 0 -X eval 'stuff 4\015'
    DebugLog "LogReset OK"
#    echo -e "Remember to run \"sh "$0" --action disable\" when finished using "$0
}

TftpUpload()
{
    DebugLog "Function: TftpUpload"
    UPLOAD_FILENAME=$(echo ${EXPORT_FILENAME}".gz")
    DebugLog "Uploading ${UPLOAD_FILENAME}..."
    cd /tmp
    local i=0
    #TftpResult=$(tftp -p -l ${UPLOAD_FILENAME} ${TftpSrv})
    #DebugLog "TftpResult= $TftpResult"
#    if $(tftp -p -l ${UPLOAD_FILENAME} ${TftpSrv}); then
#        DebugLog "Upload ${UPLOAD_FILENAME} successfully"
#    elif ! $(tftp -p -l ${UPLOAD_FILENAME} ${TftpSrv}); then
#        DebugLog "ERROR: Upload ${UPLOAD_FILENAME} failed"
#        exit
#    fi
    while ! $(tftp -p -l ${UPLOAD_FILENAME} ${TftpSrv}); do
        i=$(($i+1))
        DebugLog "Upload ${UPLOAD_FILENAME} failed, Retry.$i"
        sleep 1
        if [ $i -ge 5 ]; then
            DebugLog "ERROR: Upload ${UPLOAD_FILENAME} failed"
            exit
        fi
    done
    DebugLog "Upload ${UPLOAD_FILENAME} successfully"
    rm ${UPLOAD_FILENAME}
}

Auto() {
    DebugLog "Function: Auto"
    if [ $Mode != "1" ]; then
        DebugLog "Mode must be 1"
        exit
    fi

    LogList

    if [ "$Filename" != "EMPTY_FILENAME" ]; then
        if [ -z "$(grep -w ${Filename} ${LOGLIST})" ]; then
            DebugLog "ERROR: Invalid FILENAME"
            exit
        else
            LogId=0
            LoopConf
            while [ ${LogId} -le ${Loop} ]; do
                DebugLog "LogId= "${LogId}
                LogReadSub
                LogExportSub
                TftpUpload
                LogId=$((${LogId}+1))
            done
        fi
    else
         while read output; do
            output2=$(echo $output | awk '{print $1}')
            if [ $output2 != "" ]; then
                Filename=${output2}
                LogId=0
                LoopConf
                while [ ${LogId} -le ${Loop} ]; do
                    DebugLog "LogId="${LogId}
                    LogReadSub
                    LogExportSub
                    TftpUpload
                    LogId=$((${LogId}+1))                            
                done     
            fi
        done < ${LOGLIST}
        Filename="all"
        LogDelete
        LogReset
    fi
    ConsoleDisable
}

CatFileList() {
    cat ${LOGLIST}
}

CheckStorage() {
    LogList
    if [ -f ${LOGLIST} ]; then
        TotalSize=0
        while read output
        do
                DebugLog "FileSize="${output}
                TotalSize=`expr $TotalSize + $(echo $output | awk '{print $2}')`
                DebugLog "TotalSize="${TotalSize}
        done < ${LOGLIST}
        DebugLog "TotalSize="${TotalSize}
        if [ $TotalSize -gt $MaxStoreSize ]; then
            Filename="all"
            DebugLog "TotalSize greater than $MaxStoreSize bytes"
            LogDelete
            LogReset
        fi
    else
        DebugLog "ERROR: ${LOGLIST} not found !!"
    fi
    ConsoleDisable
}

SetTimeZone() {
    DebugLog "Function: SetTimeZone"
    case $TimeZone in
        -12)
            echo "UTC12" > /tmp/TZ
            ;;
        -11)
            echo "UTC11" > /tmp/TZ
            ;;
        -10)
            echo "UTC10" > /tmp/TZ
            ;;
        -9)
            echo "UTC9" > /tmp/TZ
            ;;
        -8)
            echo "UTC8" > /tmp/TZ
            ;;
        -7)
            echo "UTC7" > /tmp/TZ
            ;;
        -6)
            echo "UTC6" > /tmp/TZ
            ;;
        -5)
            echo "UTC5" > /tmp/TZ
            ;;
        -4)
            echo "UTC4" > /tmp/TZ
            ;;
        -3)
            echo "UTC3" > /tmp/TZ
            ;;
        -2)
            echo "UTC2" > /tmp/TZ
            ;;
        -1)
            echo "UTC1" > /tmp/TZ
            ;;
        0)
            echo "UTC0" > /tmp/TZ
            ;;
        +12)
            echo "UTC-12" > /tmp/TZ
            ;;
        +11)
            echo "UTC-11" > /tmp/TZ
            ;;
        +10)
            echo "UTC-10" > /tmp/TZ
            ;;
        +9)
            echo "UTC-9" > /tmp/TZ
            ;;
        +8)
            echo "UTC-8" > /tmp/TZ
            ;;
        +7)
            echo "UTC-7" > /tmp/TZ
            ;;
        +6)
            echo "UTC-6" > /tmp/TZ
            ;;
        +5)
            echo "UTC-5" > /tmp/TZ
            ;;
        +4)
            echo "UTC-4" > /tmp/TZ
            ;;
        +3)
            echo "UTC-3" > /tmp/TZ
            ;;
        +2)
            echo "UTC-2" > /tmp/TZ
            ;;
        +1)
            echo "UTC-1" > /tmp/TZ
            ;;
        *)
            DebugLog "Invalid argument"
            exit
            ;;
    esac
    DebugLog "$(date)"
    ExportTime=$(date +"%Y%m%d_%H%M%S")
}

LogHelp() {
    echo -e "\nopenlog version: $OpenlogVersion"
#    echo -e "\nUsage: sh "$0" --Mode Mode --action ACTION [--maxfilesize MaxFileSize] [--Filename FILENAME] [--logid LOG_INDEX] [--timeout TIMEOUT]"
    echo -e "\nUsage: sh "$0" --action ACTION [--Mode Mode] [--Filename FILENAME] [--logid LOG_INDEX] [--timeout TIMEOUT]"
    echo -e "--action : ACTION"
    echo -e "  checkstorage     "
    echo -e "  enable           Enable openlog console"
    echo -e "  disable          Disable openlog console"
    echo -e "  status           Show openlog console status"
    echo -e "  list             List log files"
    echo -e "  read             Read log file. <sh "$0" -a read -s MaxFileSize>"
    echo -e "  export           Export log file. Only available for command Mode (-c 0)"
    echo -e "  delete           Delete log file"
    echo -e "  LogReset         Reset log file index to 0"
    echo -e "  auto             Automatically enable openlog console, export all logs, upload to tftp server, delete uploaded logs from SD card, and disable console"
    #echo -e "--Mode : Mode"
    #echo -e "  1                Command Mode"
    #echo -e "  0                Interactive Mode"
    echo -e "--maxfilesize : MaxFileSize"
    echo -e "                   MaxFileSize is the max. size (byes) of each log file."
    echo -e "                   Specifying the value carefully to avoid log file is too big for free memory"
    echo -e "--Filename : FILENAME"
    echo -e "                   Log FILENAME to read/delete/export."
    echo -e "                   Using \"all\" can delete all log files when ACTION is \"delete\" (-a delete)" 
    echo -e "--logid : LOG_INDEX (required when --action export)"
    echo -e "                   Log index to export"
    echo -e "--readstart : ReadStart (required enter with --readend)"
    echo -e "                   start byte of log to read"
    echo -e "--readend : ReadEnd (required enter with --readstart)"
    echo -e "                   End byte of log to read" 
    echo -e "--tftpsrv : TftpSrv (default: diagnosis.engeniusnetworks.com)"
    echo -e "                   IP or hostname of tftp server for uploading log"
    echo -e "--timezone : Set AP timezone"
    echo -e "                   -8, +8, 0"
}

Debuglvl=1
DebugLog "####################################"
DebugLog "######## openlog Main START ########"
DebugLog "####################################"

ps | grep $0 | grep -v grep | grep -v "/bin/sh" > $OpenlogState
    DebugLog "ProcessNum = $(cat $OpenlogState | wc -l)"
if [ $(cat $OpenlogState | wc -l) -gt 1 ]; then
    DebugLog "[$(date +"%Y/%m/%d %H:%M:%S")] ProcessNum = $(cat $OpenlogState | wc -l)"
    DebugLog "[$(date +"%Y/%m/%d %H:%M:%S")] ERROR: Another openlog.sh process is running !"
    exit
fi
#Debuglvl=0

echo > $ScreenLog
[ $(ls -l $OpenlogDebugLog | awk '{print $5}') -ge 3000000 ] && rm $OpenlogDebugLog

while [[ $# -ge 1 ]]
do
    argv="$1"
    case $argv in
#        --Mode)
#            Mode="$2"
#            echo "Mode="${Mode}
#            if [ ${Mode} != "0" -a ${Mode} != "1" ]; then
#                echo -e "ERROR: Invalid Mode"
#                exit
#            fi
#            shift 2
#            ;;
        --action)
            ACTION="$2"
            shift 2
            ;;
        --maxfilesize)
            MaxFileSize_tmp="$2"
            case ${MaxFileSize_tmp} in
                ''|*[!0-9]*)    DebugLog "ERROR: MaxFileSize is not a number\n"
                                exit
                                ;;
                *)              if [ ${MaxFileSize_tmp} -le 0 ]; then
                                    DebugLog "ERROR: MaxFileSize must be more than 0"
                                    exit
                                fi
                                ;;
            esac
            shift 2
            ;;
        --filename)
            Filename="$2"
            shift 2
            ;;
        --logid)
            LogId="$2"
            case ${LogId} in
                ''|*[!0-9]*)    DebugLog "ERROR: LOG_INDEX is not a number"
                                exit
                                ;;
                *)
                                ;;
            esac
            shift 2
            ;;
        --tftpsrv)
            TftpSrv="$2"
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
        --timezone)
            TimeZone="$2"
            SetTimeZone
            shift 2
            ;;
        -v)
            Debuglvl=1
            shift 1
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

case $ACTION in
    checkstorage)
        CheckStorage
        ;;
    enable)
        ConsoleEnable
        ;;
    disable)
        ConsoleDisable
        ;;
    status)
        CheckConsoleStatus
        ;;
    list)
        LogList
        ;;
    read)
        LogRead
        ;;
    export)
        LogExport
        ;;
    delete)
        LogDelete
        ;;
    reset)
        LogReset
        ;;
    show)
        CatFileList
        ;;
#    upload)
#        TftpUpload
#        ;;   
    auto)
        Auto
        ;;
    * )
        DebugLog "ERROR: Invalid action"
        ;;
esac
DebugLog "######## openlog Main END ########"