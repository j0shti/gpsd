#!/bin/sh

MAX_TIME=120 # Time limit for checking the status of the DAEMONs after boot [seconds]
MAX_SYNC_TIME=1200 # Time limit for checking the system time synchronization with the GPS time [seconds]

user="$(whoami)"

LOG_PATH='/home/'$user'/gpsd/logs/'
ENV_PATH='/home/'$user'/cam/zwo/'
PROGRAM=$ENV_PATH'autostartcam.sh'

ST="$(date +%s)"

while :
do
  sleep 1 # sleep 1 second
  # Check the status of the DAEMONs (gpsd, chronyd)
  ET="$(date +%s)"
  ELAPSED=$(($ET-$ST))
  echo $ELAPSED > ${LOG_PATH}'run_gps.log'
  STAT_GPSD="$(systemctl is-active gpsd)"
  STAT_CHRONYD="$(systemctl is-active chronyd)"
  if [ "$STAT_GPSD" = 'active' ] && [ "$STAT_GPSD" = 'active' ] ; then
#    echo sleep 10 seconds before run gpspipe
    sleep 10 # sleep 10 seconds before running gpspipe
    ET='$(date +%s)'
#    echo 'Run gpspipe'
    echo 'Run gpspipe (gpsd: '$STAT_GPSD', chronyd: '$STAT_CHRONYD') in '$ELAPSED' sec after boot' >> ${LOG_PATH}'run_gps.log'
    gpspipe -dlr -o /dev/null
#    echo sleep 20 seconds before killing gpspipe
    sleep 20 # sleep 20 seconds before killing gpspipe
    PID=`ps -ef | grep "gpspipe" | grep -v 'grep' | awk '{print $2}'`
#    echo 'PID='$PID
    if [ -z "$PID" ] ; then
      echo '[ERROR] gpspipe is not running - It should be running [Start rebooting]' >> ${LOG_PATH}'run_gps.log'
      sudo reboot
    else
      kill -9 "$PID"
#      echo 'gpspipe has been killed'
      echo 'gpspipe has been killed' >> ${LOG_PATH}'run_gps.log'
    fi
    break
  else
    if [ $ELAPSED -ge $MAX_TIME ] ; then
      echo 'Cannot run gpspipe (gpsd: '$STAT_GPSD', chronyd: '$STAT_CHRONYD') in '$ELAPSED' sec after boot' >> ${LOG_PATH}'run_gps.log'
      # Attempt final procedure (start DAEMON manually)
      sleep 30 # sleep 30 seconds before starting DAEMONs manually
      if [ "$STAT_GPSD" != 'active' ] ; then
        sudo systemctl start gpsd
      fi
      if [ $? -ne 0 ] ; then
        echo '[ERROR] Failed to start gpsd DAEMON manually [Start rebooting]' >> ${LOG_PATH}'run_gps.log'
        sudo reboot
      fi
      if [ "STAT_CHRONYD" != 'active' ] ; then
        sudo systemctl start chronyd
      fi
      if [ $? -ne 0 ] ; then
        echo '[ERROR] Failed to start chronyd DAEMON manually [Start rebooting]' >> ${LOG_PATH}'run_gps.log'
        sudo reboot
      fi
      sleep 10 # sleep 10 seconds before running gpspipe
      ET='$(date +%s)'
      ELAPSED=$(($ET-$ST))
#      echo $ELAPSED
#      echo 'Run gpspipe'
      echo 'Run gpspipe (gpsd: '$STAT_GPSD', chronyd: '$STAT_CHRONYD') in '$ELAPSED' sec after boot after running DAEMONs manually' >> ${LOG_PATH}'run_gps.log'
      gpspipe -dlr -o /dev/null
#      echo sleep 20 seconds before killing gpspipe
      sleep 20 # sleep 20 seconds before killing gpspipe
      PID=`ps -ef | grep "gpspipe" | grep -v 'grep' | awk '{print $2}'`
#      echo 'PID='$PID
      if [ -z "$PID" ] ; then
        echo '[ERROR] gpspipe is not running - It should be running [Start rebooting]' >> ${LOG_PATH}'run_gps.log'
        sudo reboot
      else
        kill -9 $PID
#        echo 'gpspipe has been killed'
        echo 'gpspipe has been killed' >> ${LOG_PATH}'run_gps.log'
      fi
    fi
  fi
done

# Checking Reach to achieve stable SYSTEM CLOCK
echo Checking Reach to achieve stable SYSTEM CLOCK >> ${LOG_PATH}'run_gps.log'
ST="$(date +%s)"
SYNC_COUNT=0
while :
do
  sleep 5
  SYNC_COUNT=$(($SYNC_COUNT+5))
  if [ $SYNC_COUNT -gt $MAX_SYNC_TIME ] ; then
    echo '[ERROR] Failed to sync the SYSTEM CLOCK with the GPS time within '$(($MAX_SYNC_TIME/60))' minutes [Start rebooting]' >> ${LOG_PATH}'run_gps.log'
    sudo reboot
  fi
  REACH="$(chronyc sources | awk 'NR == 4 {print $5}')"
  echo '  Waiting for stable SYSTEM CLOCK (Reach='$REACH' / Elapsed time='$SYNC_COUNT' seconds)...' >> ${LOG_PATH}'run_gps.log'
  ET="$(date +%s)"
  ELAPSED=$(($ET-$ST))
  if [ $REACH -eq 377 ] ; then
    TIMESTAMP="$(date +'%F %T %Z')"
    echo $TIMESTAMP' - SYSTEM CLOCK has become stable in '$SYNC_COUNT' seconds!' >> ${LOG_PATH}'run_gps.log'
    break
  fi
done

# Launch ZWO software
echo $(date +'%F %T %Z')' - Launch ASC control software' >> ${LOG_PATH}'run_gps.log'
#. $ENV_PATH'bin/activate'
$PROGRAM
echo $(date +'%F %T %Z')' - [ERROR] - ASC control software has been terminated unexpectedly [Start rebooting]' >> ${LOG_PATH}'run_gps.log'
echo $(date +'%F %T %Z')' - Unexpected software termination' >> ${LOG_PATH}'crash.log'
echo Check asc_control_rev1.py >> ${LOG_PATH}'crash.log'
ps -ef | grep asc_control_rev1.py >> ${LOG_PATH}'crash.log'
echo Check run_gps.sh >> ${LOG_PATH}'crash.log'
ps -ef | grep run_gps.sh >> ${LOG_PATH}'crash.log'
sleep 1800 # Safety time for preventing unstoppable rebooting
sudo reboot
