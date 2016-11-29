#!/bin/bash

# A simple script that will receive events from a RTL433 SDR
# and filter interesting values that are received.
#
# Filtered values are published to a MQTT broker in a format
# that is understood by Domoticz.
# See also https://www.domoticz.com/wiki/Domoticz_API/JSON_URL's

# Author: Marco Verleun <marco@marcoach.nl>


# Remove hash on next line for debugging
set -x

# When run standalone the rtl_433 will report lines like:
# 2015-09-19 20:44:09 AlectoV1 Wind Sensor 42: Wind speed 0 units = 0.00 m/s: Wind gust 0 units = 0.00 m/s: Direction 270 degrees: Battery OK
# 2015-09-19 20:44:23 AlectoV1 Rain Sensor 8: Rain 1275.25 mm/m2: Battery OK
# 2015-09-19 20:44:40 AlectoV1 Sensor 42 Channel 1: Temperature 14.1 C: Humidity 75 %: Battery OK
#
# And more... So be selective when filtering data.

#
# Remove some kernel modules that will conflict.
# Saves creating a blacklist file

MQTT_HOST=192.168.254.196
#
# Start the listener and enter an endless loop
#
/usr/local/bin/rtl_433 |  while read line
do
	echo $line | \
# Remove hash from following line to record a raw log of events \
#		tee -a /tmp/rtl433-raw.log | \
		egrep '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | \
		sed -e 's/: /; /g' -e 's/ /; /2' | \
		/usr/bin/mosquitto_pub -h $MQTT_HOST -i RTL_433 -l -t "rtl433" -u piotr -P passwd
#
# Wind sensor information is a line that I'm interested in
# 2015-09-19 20:44:09 AlectoV1 Wind Sensor 42: Wind speed 0 units = 0.00 m/s: Wind gust 0 units = 0.00 m/s: Direction 270 degrees: Battery OK
# ^          ^        ^                                             ^				   ^		       ^
# $1         $2       $3       					    $12                           $19                 $22
	if [[ "$line" =~ "AlectoV1 Wind Sensor 42"  ]]
	then 
		WB=$(echo "$line" | awk '{print $22}')
		WS=$(echo "$line" | awk '{print $12}')
		WG=$(echo "$line" | awk '{print $19}')
		case $WB in
			00)	WD=N
				;;
			45)	WD=NE
				;;
			90)	WD=E
				;;
			135)	WD=SE
				;;
			180)	WD=S
				;;
			225)	WD=SW
				;;
			270)	WD=W
				;;
			315)	WD=NW
				;;
		esac
# Publish information in JSON format for a dummy device with index number 19
# See: https://www.domoticz.com/wiki/Domoticz_API/JSON_URL's		
		IDX=19		# From domoticz
		SVALUE="$WB;$WD;$WS;$WG;0;0"
		JSON="{ \"idx\": $IDX, \"nvalue\": 0, \"svalue\": \"$SVALUE\" }"
		echo "$JSON" | /usr/bin/mosquitto_pub -h $MQTT_HOST -l -t "domoticz/in" 
	fi
# 


#Czujnik


	if [[ "$line" =~ "TFA-Twin-Plus-30.3049" ]]
	then
	



	fi		

# Rain information as well
# 2015-09-19 20:44:23 AlectoV1 Rain Sensor 8: Rain 1275.25 mm/m2: Battery OK
#                                                  ^
#						   $8

	if [[ "$line" =~ "AlectoV1 Rain Sensor 136"  ]]
	then 
		RAIN=$(echo "$line" | awk '{print $8}')
	
# Publish information in JSON format for a dummy device with index number 18
# See: https://www.domoticz.com/wiki/Domoticz_API/JSON_URL's		
		IDX=18
		SVALUE="0;$RAIN"
		JSON="{ \"idx\": $IDX, \"nvalue\": 0, \"svalue\": \"$SVALUE\" }"
		echo "$JSON" | /usr/bin/mosquitto_pub -h $MQTT_HOST -l -t "domoticz/in" 
	fi
#
# 2015-09-19 20:44:40 AlectoV1 Sensor 42 Channel 1: Temperature 14.1 C: Humidity 75 %: Battery OK
#                                                               ^	   	 ^
#								$9		 $12
	
	if [[ "$line" =~ "AlectoV1 Sensor 42 Channel 1"  ]]
	then 
		TEMP=$(echo "$line" | awk '{print $9}')
		HUMIDITY=$(echo "$line" | awk '{print $12}')
	
# Publish information in JSON format for a dummy device with index number 18
# See: https://www.domoticz.com/wiki/Domoticz_API/JSON_URL's		
		IDX=20
		SVALUE="$TEMP;$HUMIDITY;0"
		JSON="{ \"idx\": $IDX, \"nvalue\": 0, \"svalue\": \"$SVALUE\" }"
		echo "$JSON" | /usr/bin/mosquitto_pub -h $MQTT_HOST -l -t "domoticz/in" 
	fi
	
done
