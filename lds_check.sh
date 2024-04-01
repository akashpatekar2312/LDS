#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
#Copying Files : 
ext=".db"
dt=$(date +%Y%m%d)
cd /home/lmslds/
# Checking status of the service
status=$(systemctl status lmsldscore | awk NR==3| awk '{print $2}') 1> /dev/null
if [ ${status} == "active" ]; then 
 echo  -e "\033[0;31m Service is active and running "
 read -p " Do you still want to continue (Y / N) ?  : " confirmation
 echo ''
    if [[ ${confirmation,,} == "no" || ${confirmation,,} == "n" ]]; then 
     echo -e "\033[0;32m Aborting...."
     sleep 5
     exit 1
     
    fi

else  
    echo "Configuring the service.... "
fi

# Making backup of previous files
cp -r /logconfig /home/lmslds/logconfig_root
tar -cf backup_${dt}.tar LCUbuntu  lcubuntuavc.service  LDSDaily  LDSMaster LMLDSCore  Log  logconfig logconfig_root
rm -rf LCUbuntu  lcubuntuavc.service  LDSDaily  LDSMaster LMLDSCore  Log  logconfig /logconfig logconfig_root
echo -e "\033[0;32m Extracting the files.... "
tar -xf lds.tar 1> /dev/null

#Installing sqlite
echo -e "\033[0;32m Installing the SQLITE Package Please wait...."
apt-get purge --remove sqlite3 -y 1> /dev/null
dpkg -i /home/lmslds/sqlite3_3.31.1-4ubuntu0.5_amd64.deb 1> /dev/null
rm /home/lmslds/sqlite3_3.31.1-4ubuntu0.5_amd64.deb 1> /dev/null
# -----------------------------------------
echo -e "\033[0;32m Moving files around please wait...."

sleep 5
cp /home/lmslds/LMLDSCore/lmsldscore.service /lib/systemd/system 1> /dev/null
cp /home/lmslds/LMLDSCore/lmsldscore.service /etc/systemd/system 1> /dev/null
cp /home/lmslds/LMLDSCore/lmsldscore.service /usr/lib/x86_64-linux-gnu/ 1> /dev/null
systemctl daemon-reload 1> /dev/null
systemctl enable lmsldscore.service 1> /dev/null
mv /home/lmslds/logconfig_root /logconfig
mv /home/lmslds/20231030/LMLDSMaster.db /home/lmslds/LDSMaster/
cp -r /home/lmslds/20231030 /home/lmslds/LDSDaily/${dt}
mv /home/lmslds/20231030/20231030.db /home/lmslds/LDSDaily/${dt}/${dt}${ext}
rm -rf /home/lmslds/20231030
cd /home/lmslds/LMLDSCore/
systemctl restart lmsldscore
sleep 10

# -----------------------------------------
echo -e "\033[0;32m Managing Firewall...."
systemctl stop ufw 1> /dev/null
systemctl disable ufw 2> /dev/null
sleep 2
# ------------------------------------------

#Taking USER Inputs :  
echo ''
echo -e "\033[0;32m Please fill the below details : "
echo ''
read -p "Enter the lane id : " lane_id
read -p "Enter the Plaza id : " PlazaID
read -p "Enter the AVC Model : " AVCModel
read -p "Enter the COM Port : " COMPort
read -p "Enter the AVC IP Address : " AVCIPAddress
read -p "Enter the AVC Port : " AVCPort 
read -p "Enter the LMLDS Server IP Address : " Server_IP
read -p "Enter the LC Server IP Address : " LCIPAddress
sleep 5
systemctl stop lmsldscore
log=$(ls /home/lmslds/Log/lmsldscore/ )
hw_id=$(grep '#' /home/lmslds/Log/lmsldscore/$log | awk 'NR==2 {print $NF}')

# ----------------------------------------------------

#Editing ldssettings.json file : 
echo  "    {" > /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"LaneID\" : \"${lane_id}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"PlazaID\" : \"${PlazaID}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"LMLDSDBPath\" : \"/home/lmslds/LDSMaster/SqliteLMLDS.db\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"LMLDSMasterDB\" : \"/home/lmslds/LDSMaster/LMLDSMaster.db\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"AVCModel\" : \"${AVCModel}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"COMPort\" : \"${COMPort}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"AVCIPAddress\" : \"${AVCIPAddress}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"AVCPort\" : \"${AVCPort}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"AVCFolderPath\" : \"/home/lmslds/LDSDaily\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"Server_IP\" : \"${Server_IP}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"LCIPAddress\" : \"${LCIPAddress}\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"CAVCImplemented\" : \"0\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"CAVCIP\" : \"\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"Hardware_ID\" : \"${hw_id}\"", | tr -d '\r' >> /home/lmslds/LMLDSCore/ldssettings.json 
echo -e "\t\"MaxZeroLoopFrameCount\" : \"0\"", >> /home/lmslds/LMLDSCore/ldssettings.json
echo -e "\t\"COMPortString\" : \"\"" >> /home/lmslds/LMLDSCore/ldssettings.json
echo "    }" >> /home/lmslds/LMLDSCore/ldssettings.json

# --------------------------------------
echo ''
echo   "Execute the following query in your database and paste the output below : "
echo ''
read -p "select max(ldsdata_id) from tbl_ldsdata where lane_id=${lane_id}; : " max
sqlite3 /home/lmslds/LDSMaster/LMLDSMaster.db "update tbl_lmldsparam set Last_Record_ID = $max";
echo ''
echo "UPDATE THE HW_CODE IN THE COLUMN LDSHW_CODE OF TBL_LDSCONFIGURATION"
echo  -e "\033[0;33m${hw_id}"
echo ''
echo  -e "\033[0;31m RESTART THE LMSLDSCORE SERVICE AFTER UPDATING HW ID AND AVC MODEL IN THE DATABASE "
# ------------------------------------------------
# Managing Permissions : 
chmod -R 777 /logconfig
chown lmslds:lmslds /logconfig
chmod -R 777 /home/lmslds
chown -R lmslds:lmslds /home/lmslds
