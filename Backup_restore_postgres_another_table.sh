#!/bin/bash


date=$( date )
echo $date
for i in range {60..400}
do
	#x= let "i-=1"
	x=$((i--))
	start=` date -d " -$x hours " +%s `
	end=` date -d " -$i hours " +%s `

	echo " INSERT INTO history_uint (SELECT * FROM history_uint_old WHERE clock > $start and clock < $end  ) ON CONFLICT (itemid, clock, ns) DO NOTHING;  " | sudo -u postgres psql zabbix &
        sleep 120
	#echo " SELECT * FROM history_uint_old WHERE clock > $start and clock < $end  " | sudo -u postgres psql zabbix

echo $i $x
echo $start $end
done
