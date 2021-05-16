#!/bin/bash
echo "####################################################################################"
echo "##Author 	: LuciferLiu"
echo "##Blog   	: https://blog.csdn.net/m0_50546016"
echo "##Github        : https://github.com/pc-study/InstallOracleshell"
echo "##Version	: 1.0"
echo "##Function   	: Oracle 11g/12c/18c/19c(Single and Rac) install on Linux 6/7/8"
echo "####################################################################################"
echo "#执行脚本前："
echo "#    1. 把脚本放入软件目录，例如：/soft"
echo "#    2. 挂载ISO"
echo "#    3. 把需要本地安装的rpm和software上传到软件目录"
echo "#    4. 设置好主机IP"
echo "####################################################################################"
####################################################################################
# Parameters For Install
####################################################################################
#Oracle Install Mode(RAC/Single/RESTART)
OracleInstallMode=
SOFTWAREDIR=$(pwd)
DAYTIME=$(date +%Y%m%d)
RELS=$(more /etc/system-release)
OS_VER_PRI=$(echo "${RELS#*release}" | awk '{print $1}' | cut -f 1 -d '.')
memTotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')
swapTotal=$(grep -i 'swaptotal' /proc/meminfo | awk '{print $2}')
shmTotal=$(df -k /dev/shm | awk '{print $2}' | head -n 2 | tail -n 1)
HOSTNAME=orcl
PUBLICIP=
ORACLE_SID=orcl
ISCDB=FALSE
PDBNAME=pdb01
ROOTPASSWD=oracle
ORAPASSWD=oracle
GRIDPASSWD=oracle
ENV_BASE_DIR=/u01/app
ORADATADIR=/oradata
ARCHIVEDIR=/archivelog
BACKUPDIR=/backup
SCRIPTSDIR=/home/oracle/scripts
CHARACTERSET=AL32UTF8
GRID_SID=+ASM
RACPUBLICFCNAME=
RACPRIVFCNAME=
RACPRIVFCNAME1=
RAC1PUBLICIP=
RAC2PUBLICIP=
RAC1VIP=
RAC2VIP=
RAC1PRIVIP=
RAC2PRIVIP=
RAC1PRIVIP1=
RAC2PRIVIP1=
RACSCANIP=
scan_sum=0
ASMDATANAME=DATA
ASMOCRNAME=OCR
OCR_BASEDISK=
DATA_BASEDISK=
OCRREDUN=EXTERNAL
DATAREDUN=EXTERNAL
num1=0
num2=0
TIMESERVERIP=
ONLYCONFIGOS=N
ONLYINSTALLGRID=N
ONLYINSTALLORACLE=N
ONLYCREATEDB=N
GPATCH=
OPATCH=
nodeNum=1
DB_VERSION=
OracleInstallMode=
TuXingHua=N
UDEV=Y
#DNS
DNS=N
DNSSERVER=N
DNSNAME=
DNSIP=
###################################################################################
##The following is a custom function：
####################################################################################
#Type stty erase '^H' before read
stty erase '^H'
#Add colors to fonts through variables
#Define a c1() function here, if you want to change the font color later, you can call it directly
c1() {
  RED_COLOR='\E[1;31m'
  GREEN_COLOR='\E[1;32m'
  YELLOW_COLOR='\E[1;33m'
  BLUE_COLOR='\E[1;34m'
  PINK_COLOR='\E[1;35m'
  WHITE_BLUE='\E[47;34m'
  DOWN_BLUE='\E[4;36m'
  FLASH_RED='\E[5;31m'
  RES='\E[0m'

  #Here it is judged whether the incoming parameters are not equal to 2, if not equal to 2, prompt and exit
  if [ $# -ne 2 ]; then
    echo "Usage $0 content {red|yellow|blue|green|pink|wb|db|fr}"
    exit
  fi

  case "$2" in
  red | RED)
    echo -e "${RED_COLOR}$1${RES}"
    ;;
  yellow | YELLOW)
    echo -e "${YELLOW_COLOR}$1${RES}"
    ;;
  green | GREEN)
    echo -e "${GREEN_COLOR}$1${RES}"
    ;;
  blue | BLUE)
    echo -e "${BLUE_COLOR}$1${RES}"
    ;;
  pink | PINK)
    echo -e "${PINK_COLOR}$1${RES}"
    ;;
  wb | WB)
    echo -e "${WHITE_BLUE}$1${RES}"
    ;;
  db | DB)
    echo -e "${DOWN_BLUE}$1${RES}"
    ;;
  fr | FR)
    echo -e "${FLASH_RED}$1${RES}"
    ;;
  *)
    echo -e "Please enter the specified color code：{red|yellow|blue|green|pink|wb|db|fr}"
    ;;
  esac
}

##Example
##c1 "Program installation error！" red
##c1 "The program is successfully installed！" green
##c1 "Output related annotation information" blue
SSHTrust() {
  DEST_USER=$1
  PASSWORD=$2
  HOSTS_FILE=$3
  if [ $# -ne 3 ]; then
    echo "Usage:"
    echo "$0 remoteUser remotePassword hostsFile"
    exit 1
  fi
  if [ "${DEST_USER}" != "root" ]; then
    cd /home/"${DEST_USER}"/ || return
  fi

  SSH_DIR=~/.ssh
  SCRIPT_PREFIX=./tmp
  echo ===========================
  # 1. prepare  directory .ssh
  mkdir $SSH_DIR
  chmod 700 $SSH_DIR

  # 2. generat ssh key
  TMP_SCRIPT=$SCRIPT_PREFIX.sh
  {
    echo "#!/usr/bin/expect"
    echo "spawn ssh-keygen -b 1024 -t rsa"
    echo "expect *key*"
    echo "send \r"
  } >>$TMP_SCRIPT
  if [ -f $SSH_DIR/id_rsa ]; then
    {
      echo "expect *verwrite*"
      echo "send y\r"
    } >>$TMP_SCRIPT
  fi
  {
    echo "expect *passphrase*"
    echo "send \r"
    echo "expect *again:"
    echo "send \r"
    echo "interact"
  } >>$TMP_SCRIPT

  chmod +x $TMP_SCRIPT

  /usr/bin/expect $TMP_SCRIPT
  rm -rf $TMP_SCRIPT

  # 3. generat file authorized_keys
  cat $SSH_DIR/id_rsa.pub >>$SSH_DIR/authorized_keys

  # 4. chmod 600 for file authorized_keys
  chmod 600 $SSH_DIR/authorized_keys
  echo ===========================
  # 5. copy all files to other hosts
  for ip in $(<"${HOSTS_FILE}"); do
    if [ "x$ip" != "x" ]; then
      echo -------------------------
      TMP_SCRIPT=${SCRIPT_PREFIX}.$ip.sh
      # check known_hosts
      val=$(ssh-keygen -F "${ip}")
      if [ "x$val" == "x" ]; then
        echo "$ip not in $SSH_DIR/known_hosts, need to add"
        val=$(ssh-keyscan "${ip}" 2>/dev/null)
        if [ "x$val" == "x" ]; then
          echo "ssh-keyscan $ip failed!"
        else
          echo "${val}" >>$SSH_DIR/known_hosts
        fi
      fi
      echo "copy $SSH_DIR to $ip"
      {
        echo "#!/usr/bin/expect"
        echo "spawn scp -r  $SSH_DIR $DEST_USER@$ip:~/"
        echo "expect *assword*"
        echo "send $PASSWORD\r"
        echo "interact"
      } >"$TMP_SCRIPT"

      chmod +x "$TMP_SCRIPT"

      /usr/bin/expect "$TMP_SCRIPT"
      rm -rf "$TMP_SCRIPT"
      echo "copy done."
    fi
  done

  # 6. date ssh
  for ip in $(<"$HOSTS_FILE"); do
    if [ "x$ip" != "x" ]; then
      {
        echo "#!/usr/bin/expect"
        echo "spawn ssh $DEST_USER@$ip date"
        echo "expect *yes*"
        echo "send yes\r"
        echo "interact"
      } >"$TMP_SCRIPT"

      chmod +x "$TMP_SCRIPT"

      /usr/bin/expect "$TMP_SCRIPT"
      rm -rf "$TMP_SCRIPT"
      echo "copy done."
    fi
  done
}

help() {
  c1 "Desc: For ALL Oracle Silent Install" green
  echo
  c1 "Usage: OracleShellInstall [OPTIONS] OBJECT { COMMAND | help }" green
  echo
  c1 "Excute: " green
  c1 "1.chmod +x OracleShellInstall.sh" green
  echo
  c1 "OPTIONS: " green
  c1 "-i,		--PUBLICIP			PUBLICIP NETWORK ADDRESS" green
  c1 "-n,		--HOSTNAME			HOSTNAME(orcl)" green
  c1 "-o,		--ORACLE_SID			ORACLE_SID(orcl)" green
  c1 "-c,		--ISCDB				IS CDB OR NOT(TRUE|FALSE)" green
  c1 "-pb,		--PDBNAME			PDBNAME(pdb01)" green
  c1 "-op,		--ORAPASSWD			ORACLE USER PASSWORD(oracle)" green
  c1 "-b,		--ENV_BASE_DIR			ORACLE BASE DIR(/u01/app)" green
  c1 "-s,		--CHARACTERSET			ORACLE CHARACTERSET(ZHS16GBK|AL32UTF8)" green
  c1 "-rs,		--ROOTPASSWD			ROOT USER PASSWORD" green
  c1 "-gp,		--GRIDPASSWD			GRID USER PASSWORD(oracle)" green
  c1 "-pb1,		--RAC1PUBLICIP			RAC NODE ONE PUBLIC IP" green
  c1 "-pb2,		--RAC2PUBLICIP			RAC NODE SECONED PUBLIC IP" green
  c1 "-vi1,		--RAC1VIP			RAC NODE ONE VIRTUAL IP" green
  c1 "-vi2,		--RAC2VIP			RAC NODE SECOND VIRTUAL IP" green
  c1 "-pi1,		--RAC1PRIVIP			RAC NODE ONE PRIVATE IP(10.10.1.1)" green
  c1 "-pi2,		--RAC2PRIVIP			RAC NODE SECOND PRIVATE IP(10.10.1.2)" green
  c1 "-pi3,		--RAC1PRIVIP1			RAC NODE ONE PRIVATE IP(10.1.1.1)" green
  c1 "-pi4,		--RAC2PRIVIP1			RAC NODE SECOND PRIVATE IP(10.1.1.2)" green
  c1 "-puf,		--RACPUBLICFCNAME	        RAC PUBLIC FC NAME" green
  c1 "-prf,		--RACPRIVFCNAME			RAC PRIVATE FC NAME" green
  c1 "-prf1,		--RACPRIVFCNAME1		RAC PRIVATE FC NAME" green
  c1 "-si,		--RACSCANIP			RAC SCAN IP" green
  c1 "-dn,		--ASMDATANAME			RAC ASM DATADISKGROUP NAME(DATA)" green
  c1 "-on,		--ASMOCRNAME			RAC ASM OCRDISKGROUP NAME(OCR)" green
  c1 "-dd,		--DATA_BASEDISK			RAC DATADISK DISKNAME" green
  c1 "-od,		--OCRP_BASEDISK			RAC OCRDISK DISKNAME" green
  c1 "-or,		--OCRREDUN			RAC OCR REDUNDANCY(EXTERNAL|NORMAL|HIGH)" green
  c1 "-dr,		--DATAREDUN			RAC DATA REDUNDANCY(EXTERNAL|NORMAL|HIGH)" green
  c1 "-tsi,            --TIMESERVERIP                    RAC TIME SERVER IP" green
  c1 "-txh            --TuXingHua                     Tu Xing Hua Install" green
  c1 "-udev           --UDEV                          Whether Auto Set UDEV" green
  c1 "-dns            --DNS                           RAC CONFIGURE DNS(Y|N)" green
  c1 "-dnss           --DNSSERVER                     RAC CONFIGURE DNSSERVER LOCAL(Y|N)" green
  c1 "-dnsn           --DNSNAME                       RAC DNSNAME(orcl.com)" green
  c1 "-dnsi           --DNSIP                         RAC DNS IP" green
  c1 "-m,		--ONLYCONFIGOS			ONLY CONFIG SYSTEM PARAMETER(Y|N)" green
  c1 "-g,		--ONLYINSTALLGRID 		ONLY INSTALL GRID SOFTWARE(Y|N)" green
  c1 "-w,		--ONLYINSTALLORACLE 		ONLY INSTALL ORACLE SOFTWARE(Y|N)" green
  c1 "-ocd,		--ONLYCREATEDB		        ONLY CREATE DATABASE(Y|N)" green
  c1 "-gpa,		--GRID RELEASE UPDATE		GRID RELEASE UPDATE(32072711)" green
  c1 "-opa,		--ORACLE RELEASE UPDATE		ORACLE RELEASE UPDATE(32072711)" green
  exit 0
}

echo
while [ -n "$1" ]; do #Here by judging whether $1 exists
  case $1 in
  -i | --PUBLICIP)
    PUBLICIP=$2 #$2 Is the parameter we want to output
    shift 2
    ;; # Move the parameter back by 2 and enter the judgment of the next parameter
  -n | --HOSTNAME)
    HOSTNAME=$2
    shift 2
    ;;
  -o | --ORACLE_SID)
    ORACLE_SID=$2
    shift 2
    ;;
  -c | --ISCDB)
    ISCDB=$2
    shift 2
    ;;
  -pb | --PDBNAME)
    PDBNAME=$2
    shift 2
    ;;
  -op | --ORAPASSWD)
    ORAPASSWD=$2
    shift 2
    ;;
  -b | --ENV_BASE_DIR)
    ENV_BASE_DIR=$2
    shift 2
    ;;
  -s | --CHARACTERSET)
    CHARACTERSET=$2
    shift 2
    ;;
  -m | --ONLYCONFIGOS)
    ONLYCONFIGOS=$2
    shift 2
    ;;
  -g | --ONLYINSTALLGRID)
    ONLYINSTALLGRID=$2
    shift 2
    ;;
  -w | --ONLYINSTALLORACLE)
    ONLYINSTALLORACLE=$2
    shift 2
    ;;
  -ocd | --ONLYCREATEDB)
    ONLYCREATEDB=$2
    shift 2
    ;;
  -gpa | --GPATCH)
    GPATCH=$2
    shift 2
    ;;
  -opa | --OPATCH)
    OPATCH=$2
    shift 2
    ;;
  -gp | --GRIDPASSWD)
    GRIDPASSWD=$2
    shift 2
    ;;
  -pb1 | --RAC1PUBLICIP)
    RAC1PUBLICIP=$2
    shift 2
    ;;
  -pb2 | --RAC2PUBLICIP)
    RAC2PUBLICIP=$2
    shift 2
    ;;
  -vi1 | --RAC1VIP)
    RAC1VIP=$2
    shift 2
    ;;
  -vi2 | --RAC2VIP)
    RAC2VIP=$2
    shift 2
    ;;
  -pi1 | --RAC1PRIVIP)
    RAC1PRIVIP=$2
    shift 2
    ;;
  -pi2 | --RAC2PRIVIP)
    RAC2PRIVIP=$2
    shift 2
    ;;
  -pi3 | --RAC1PRIVIP1)
    RAC1PRIVIP1=$2
    shift 2
    ;;
  -pi4 | --RAC2PRIVIP1)
    RAC2PRIVIP1=$2
    shift 2
    ;;
  -si | --RACSCANIP)
    RACSCANIP=$2
    shift 2
    ;;
  -sn | --RACSCANNAME)
    RACSCANNAME=$2
    shift 2
    ;;
  -cn | --CLUSTERNAME)
    CLUSTERNAME=$2
    shift 2
    ;;
  -dn | --ASMDATANAME)
    ASMDATANAME=$2
    shift 2
    ;;
  -on | --ASMOCRNAME)
    ASMOCRNAME=$2
    shift 2
    ;;
  -dd | --DATA_BASEDISK)
    DATA_BASEDISK=$2
    shift 2
    ;;
  -od | --OCR_BASEDISK)
    OCR_BASEDISK=$2
    shift 2
    ;;
  -or | --OCRREDUN)
    OCRREDUN=$2
    shift 2
    ;;
  -dr | --DATAREDUN)
    DATAREDUN=$2
    shift 2
    ;;
  -rs | --ROOTPASSWD)
    ROOTPASSWD=$2
    shift 2
    ;;
  -puf | --RACPUBLICFCNAME)
    RACPUBLICFCNAME=$2
    shift 2
    ;;
  -prf | --RACPRIVFCNAME)
    RACPRIVFCNAME=$2
    shift 2
    ;;
  -prf1 | --RACPRIVFCNAME1)
    RACPRIVFCNAME1=$2
    shift 2
    ;;
  -tsi | --TIMESERVERIP)
    TIMESERVERIP=$2
    shift 2
    ;;
  -node | --nodeNum)
    nodeNum=$2
    shift 2
    ;;
  -installmode | --OracleInstallMode)
    OracleInstallMode=$2
    shift 2
    ;;
  -dbv | --DB_VERSION)
    DB_VERSION=$2
    shift 2
    ;;
  -txh | --TuXingHua)
    TuXingHua=$2
    shift 2
    ;;
  -udev | --UDEV)
    UDEV=$2
    shift 2
    ;;
  -dns | --DNS)
    DNS=$2
    shift 2
    ;;
  -dnss | --DNSSERVER)
    DNSSERVER=$2
    shift 2
    ;;
  -dnsn | --DNSNAME)
    DNSNAME=$2
    shift 2
    ;;
  -dnsi | --DNSIP)
    DNSIP=$2
    shift 2
    ;;
  -h | --help) help ;; # function help is called
  --)
    shift
    break
    ;; # end of options
  -*)
    echo "Error: Option '$1' is unknown, try './OracleShellInstall.sh --help'."
    exit 1
    ;;
  *) break ;;
  esac
done
####################################################################################
## Log Write
####################################################################################
if [ "$(find "${SOFTWAREDIR}" -maxdepth 1 -name 'oracleAllSilent_*.log' | wc -l)" -gt 0 ]; then
  rm -rf "${SOFTWAREDIR}"/oracleAllSilent_*.log
fi

oracleinstalllog="${SOFTWAREDIR}"/oracleAllSilent_$(date +"20%y%m%d%H%M%S").log

logwrite() {
  {
    c1 "####################################################################################" green
    echo
    c1 "# $1" blue
    echo
    c1 "####################################################################################" green
    echo
    echo "$1 :"
    echo
    echo "$2" >"${SOFTWAREDIR}"/ex.sh
    chmod +x "${SOFTWAREDIR}"/ex.sh
    "${SOFTWAREDIR}"/ex.sh
    rm -rf "${SOFTWAREDIR}"/ex.sh
    echo
  } >>"${oracleinstalllog}"
}

##Example
##logwrite "HostName" "hostname"
##logwrite "Firewalld" "systemctl status firewalld"
echo
##Judge whether user is root, if it is not, exit
if [ "$USER" != "root" ]; then
  echo
  c1 "The user must be root,and now you user is $USER,please su to root." red
  exit 1
fi

if [ "${nodeNum}" -eq 1 ]; then
  echo
  c1 "Please Choose Oracle Install Mode(single/restart/rac) :" blue
  echo
  read -r OracleInstallMode
  echo
  c1 "Please Choose Oracle Database Version(11g/12c/18c/19c) :" blue
  echo
  read -r DB_VERSION
  echo
fi

if [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "rac" ]; then
  RAC1HOSTNAME=${HOSTNAME}01
  RAC2HOSTNAME=${HOSTNAME}02
fi

##Judge whether ip or dbversion is empty, if it is empty, exit
if [ "${nodeNum}" -eq 1 ]; then
  # [WARNING] [INS-13001] Oracle Database is not supported on this operating system. Installer will not perform prerequisite checks on the system.
  if [ "${OS_VER_PRI}" -eq 6 ]; then
    if [[ "${DB_VERSION}" == "19c" ]] || [[ "${DB_VERSION}" == "19C" ]] || [[ "${DB_VERSION}" == "19" ]]; then
      c1 "Sorry, 19C Must Install on Linux 7." red
      c1 "[INS-13001] Oracle Database is not supported on this operating system. Installer will not perform prerequisite checks on the system." blue
      exit 99
    fi
  fi
  if [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "rac" ]; then
    ##IF Configure DNS
    if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
      if [ -z "${DNSIP}" ] || [ -z "${DNSNAME}" ]; then
        c1 "Sorry, If you Wanna Configure DNS, you must set -dnsn and -dnsi First. " red
        exit 99
      fi
    fi
    if [ "${DB_VERSION}" = "11.2.0.4" ] && [ "${OS_VERSION}" = "linux7" ]; then
      if [ ! -f "${SOFTWAREDIR}"/p18370031_112040_Linux-x86-64.zip ]; then
        c1 "Make sure the Patch 18370031 is in the ${SOFTWAREDIR} directory:" red
        c1 "p18370031_112040_Linux-x86-64.zip" blue
        exit 99
      fi
    fi
    # 12c rac grid install on linux7 with bug
    if [[ "${DB_VERSION}" == "12c" ]] || [[ "${DB_VERSION}" == "12C" ]] || [[ "${DB_VERSION}" == "12" ]]; then
      if [ -z "${GPATCH}" ] && [ "${OS_VER_PRI}" -eq 7 ]; then
        c1 "Sorry, 12C RAC Grid Install on Linux 7 must -applyPSU First, Please Set -gpa patchnum." red
        exit 99
      fi
    fi
    if [ -z "${HOSTNAME}" ] || [ -z "${RAC1PUBLICIP}" ] || [ -z "${RAC2PUBLICIP}" ] || [ -z "${RAC1VIP}" ] || [ -z "${RAC2VIP}" ] || [ -z "${RAC1PRIVIP}" ] || [ -z "${RAC2PRIVIP}" ] || [ -z "${RACSCANIP}" ] || [ -z "${DATA_BASEDISK}" ] || [ -z "${OCR_BASEDISK}" ] || [ -z "${RACPUBLICFCNAME}" ] || [ -z "${RACPRIVFCNAME}" ]; then
      echo
      c1 "IF Chosse RAC.Then HOSTNAME,RAC1PUBLICIP,RAC2PUBLICIP,RAC1VIP,RAC1PRIVIP,RAC2PRIVIP,RAC2VIP,RACSCANIP,DATA_BASEDISK,OCR_BASEDISK,RACPUBLICFCNAME,RACPRIVFCNAME are required parameters, try'./OracleShellInstall.sh --help' to execute the script" red
      echo
      exit 99
    else
      ##create node2 script
      {
        echo -e "${SOFTWAREDIR}/OracleShellInstall.sh -i ${RAC2PUBLICIP}\c"
        echo -e " -n ${HOSTNAME}\c"
        echo -e " -o ${ORACLE_SID}\c"
        echo -e " -b ${ENV_BASE_DIR}\c"
        echo -e " -rs ${ROOTPASSWD}\c"
        echo -e " -op ${ORAPASSWD}\c"
        echo -e " -gp ${GRIDPASSWD}\c"
        echo -e " -s ${CHARACTERSET}\c"
        echo -e " -pb1 ${RAC1PUBLICIP} -pb2 ${RAC2PUBLICIP}\c"
        echo -e " -vi1 ${RAC1VIP} -vi2 ${RAC2VIP}\c"
        echo -e " -pi1 ${RAC1PRIVIP} -pi2 ${RAC2PRIVIP}\c"
        echo -e " -si ${RACSCANIP}\c"
        echo -e " -dd ${DATA_BASEDISK}\c"
        echo -e " -od ${OCR_BASEDISK}\c"
        echo -e " -or ${OCRREDUN}\c"
        echo -e " -dr ${DATAREDUN}\c"
        echo -e " -puf ${RACPUBLICFCNAME} -prf ${RACPRIVFCNAME}\c"
        echo -e " -node 2\c"
        echo -e " -installmode ${OracleInstallMode}\c"
        echo -e " -dbv ${DB_VERSION}\c"
        echo -e " -txh ${TuXingHua}\c"
        echo -e " -udev ${UDEV}\c"
        echo -e " -dns ${DNS}\c"
      } >"${SOFTWAREDIR}"/racnode2.sh
      ##TimeServer
      if [ -n "${TIMESERVERIP}" ]; then
        echo -e " -tsi ${TIMESERVERIP}\c" >>"${SOFTWAREDIR}"/racnode2.sh
      fi

      ##Two Private ip
      if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
        echo -e " -pi3 ${RAC1PRIVIP1} -pi4 ${RAC2PRIVIP1} -prf1 ${RACPRIVFCNAME1}\c" >>"${SOFTWAREDIR}"/racnode2.sh
      fi
      ## DNS Server Conf
      if [ "${DNSSERVER}" = "y" ] || [ "${DNSSERVER}" = "Y" ]; then
        echo -e " -dnss ${DNSSERVER}\c" >>"${SOFTWAREDIR}"/racnode2.sh
      fi
      ##Do not Configure local DNS Server
      if [ -n "${DNSIP}" ] && [ -n "${DNSNAME}" ]; then
        {
          echo -e " -dnsn ${DNSNAME}\c"
          echo -e " -dnsi ${DNSIP}\c"
        } >>"${SOFTWAREDIR}"/racnode2.sh
      fi

    fi
  else
    if [ -z "${PUBLICIP}" ]; then
      echo
      c1 "PUBLICIP and DB_VERSION is a required parameter, try'./OracleShellInstall.sh --help' to execute the script" red
      echo
      exit 99
    fi
  fi
fi

{
  c1 "####################################################################################" green
  echo
  c1 "# Installation Logging" wb
  echo
  c1 "####################################################################################" green
  echo
} >>"${oracleinstalllog}"
####################################################################################
# OS Version
####################################################################################
if [ "$OS_VER_PRI" -eq 7 ]; then
  OS_VERSION=linux7
elif [ "$OS_VER_PRI" -eq 6 ]; then
  OS_VERSION=linux6
elif [ "$OS_VER_PRI" -eq 8 ]; then
  OS_VERSION=linux8
else
  c1 "sorry, this operating system is not supported!!!" red
  exit 99
fi

logwrite "OS Version" "echo ${OS_VERSION}"
####################################################################################
# Choice DB Version
####################################################################################
if [[ "${DB_VERSION}" == "19c" ]] || [[ "${DB_VERSION}" == "19C" ]] || [[ "${DB_VERSION}" == "19" ]]; then
  DB_VERSION=19.3.0.0
elif [[ "${DB_VERSION}" == "18c" ]] || [[ "${DB_VERSION}" == "18C" ]] || [[ "${DB_VERSION}" == "18" ]]; then
  DB_VERSION=18.0.0.0
elif [[ "${DB_VERSION}" == "12c" ]] || [[ "${DB_VERSION}" == "12C" ]] || [[ "${DB_VERSION}" == "12" ]]; then
  DB_VERSION=12.2.0.1
elif [[ "${DB_VERSION}" == "11g" ]] || [[ "${DB_VERSION}" == "11G" ]] || [[ "${DB_VERSION}" == "11" ]]; then
  DB_VERSION=11.2.0.4
else
  c1 "Sorry, DB VERSION Input Error, exit" red
  exit 99
fi

logwrite "DB Version" "echo ${DB_VERSION}"

####################################################################################
# ScanIP
####################################################################################
SCANIParse() {
  for i in ${RACSCANIP//,/ }; do
    scan_sum=$((scan_sum + 1))
    if [ "${scan_sum}" = "0" ]; then
      c1 "Sorry, Please Set SCANIP by -si!" red
      exit 99
    elif [ "${scan_sum}" = "1" ]; then
      RACSCANIP1="${i}"
    elif [ "${scan_sum}" = "2" ]; then
      RACSCANIP2="${i}"
    elif [ "${scan_sum}" = "3" ]; then
      RACSCANIP3="${i}"
    else
      c1 "Sorry, Only Support 3 SCANIP!" red
      exit 99
    fi
  done
}
####################################################################################
# Choice DB HOME
####################################################################################
ENV_ORACLE_BASE=$ENV_BASE_DIR/oracle
ENV_GRID_BASE=$ENV_BASE_DIR/grid
ENV_ORACLE_INVEN=$ENV_BASE_DIR/oraInventory
if [ "${DB_VERSION}" = "11.2.0.4" ]; then
  ENV_ORACLE_HOME=$ENV_ORACLE_BASE/product/11.2.0/db
  ENV_GRID_HOME=$ENV_BASE_DIR/11.2.0/grid
elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
  ENV_ORACLE_HOME=$ENV_ORACLE_BASE/product/12.2.0/db
  ENV_GRID_HOME=$ENV_BASE_DIR/12.2.0/grid
elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
  ENV_ORACLE_HOME=$ENV_ORACLE_BASE/product/18.0.0/db
  ENV_GRID_HOME=$ENV_BASE_DIR/18.0.0/grid
elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
  ENV_ORACLE_HOME=$ENV_ORACLE_BASE/product/19.3.0/db
  ENV_GRID_HOME=$ENV_BASE_DIR/19.3.0/grid
else
  c1 "Sorry, Error database version! please check again!" red
  exit
fi

####################################################################################
# Check Swap
####################################################################################
SwapCheck() {
  COUNT=
  if [ "${memTotal}" -ge 1048576 ] && [ "${memTotal}" -le 2097152 ]; then
    swapNeed=$((memTotal * 3 / 2))
    if [[ ${swapNeed} -gt ${swapTotal} ]]; then
      COUNT=$((swapNeed - swapTotal))
    fi
  elif [ "${memTotal}" -gt 2097152 ] && [ "${memTotal}" -le 16777216 ]; then
    swapNeed=$memTotal
    if [[ ${swapNeed} -gt ${swapTotal} ]]; then
      COUNT=$((swapNeed - swapTotal))
    fi
  elif [ "${memTotal}" -gt 16777216 ]; then
    swapNeed=16777216
    if [[ ${swapNeed} -gt ${swapTotal} ]]; then
      COUNT=$((swapNeed - swapTotal))
    fi
  else
    echo
    c1 "At least 1 GB RAM for Oracle Database installations. 2 GB RAM recommended." red
    exit 99
  fi

  ##set swap space
  if [ -n "${COUNT}" ] && [ ! -f /swapfile ] && [ ${COUNT} -gt 40 ]; then
    c1 "Now Setting SWAP SPACE........" blue
    COUNT=$((COUNT / 1024 / 1024 + 1))
    dd if=/dev/zero of=/swapfile bs=1G count=${COUNT}
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >>/etc/fstab
  fi
}

if [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "rac" ]; then
  # echo
  # c1 "Please Choose Current node(1 or 2):" blue
  # echo
  # read -r nodeNum
  # echo
  if [ "${nodeNum}" -eq 1 ]; then
    c1 "Current node：1" wb
    hostname=${RAC1HOSTNAME}
    GRID_SIDTemp=${GRID_SID}$nodeNum
    ORACLE_SIDTemp=${ORACLE_SID}$nodeNum
  elif [ "${nodeNum}" -eq 2 ]; then
    c1 "Current node：2" wb
    hostname=${RAC2HOSTNAME}
    GRID_SIDTemp=${GRID_SID}$nodeNum
    ORACLE_SIDTemp=${ORACLE_SID}$nodeNum
  else
    c1 "Node Number Input Error, exit" red
    exit
  fi
elif [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
  hostname=${HOSTNAME}
  ORACLE_SIDTemp=${ORACLE_SID}
  GRID_SIDTemp=${GRID_SID}
else
  hostname=${HOSTNAME}
  ORACLE_SIDTemp=${ORACLE_SID}
fi

##get scanname and clustername
if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
  RACSCANNAME=${HOSTNAME}-scan
  CLUSTERNAME=${HOSTNAME}-cluster
fi

####################################################################################
#install rpm that oracle is necessary for installing
####################################################################################
InstallRPM() {
  ####################################################################################
  # Judge ISO file mount status
  ####################################################################################
  mountPatch=$(mount | grep -E "iso|ISO" | awk '{print $3}')
  if [ ! "${mountPatch}" ]; then
    echo
    c1 "The ISO file is not mounted on system." red
    exit 99
  else
    if [ ! -f /etc/yum.repos.d/local.repo ]; then
      if [ "${OS_VERSION}" = "linux6" ] || [ "${OS_VERSION}" = "linux7" ]; then
        {
          echo "[server]"
          echo "name=server"
          echo "baseurl=file://""${mountPatch}"
          echo "enabled=1"
          echo "gpgcheck=1"
        } >/etc/yum.repos.d/local.repo
      elif [ "${OS_VERSION}" = "linux8" ]; then
        {
          echo "[BaseOS]"
          echo "name=BaseOS"
          echo "baseurl=file:///${mountPatch}/BaseOS"
          echo "enabled=1"
          echo "gpgcheck=1"
          echo "[AppStream]"
          echo "name=AppStream"
          echo "baseurl=file:///${mountPatch}/AppStream"
          echo "enabled=1"
          echo "gpgcheck=1"
        } >/etc/yum.repos.d/local.repo
      fi
      rpm --import "${mountPatch}"/RPM-GPG-KEY-redhat-release
    fi
    if [ "${OS_VERSION}" = "linux6" ]; then
      if [ "${TuXingHua}" = "y" ] || [ "${TuXingHua}" = "Y" ]; then
        #LINUX 6
        yum groupinstall -y "X Window System"
        yum groupinstall -y "Desktop"
        yum install -y nautilus-open-terminal
        yum install -y tigervnc*
      fi
      if [ "$(rpm -q bc binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ elfutils-libelf elfutils-libelf-devel glibc glibc-devel libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXrender make net-tools smartmontools sysstat e2fsprogs e2fsprogs-libs expect unzip openssh-clients readline psmisc ksh nfs-utils --qf '%{name}.%{arch}\n' | grep -E -c "not installed")" -gt 0 ]; then
        yum install -y bc \
          binutils \
          compat-libcap1 \
          compat-libstdc++-33 \
          gcc \
          gcc-c++ \
          elfutils-libelf \
          elfutils-libelf-devel \
          glibc \
          glibc-devel \
          libaio libaio-devel \
          libgcc \
          libstdc++ \
          libstdc++-devel \
          libxcb \
          libX11 \
          libXau \
          libXi \
          libXrender \
          make \
          net-tools \
          smartmontools \
          sysstat \
          e2fsprogs \
          e2fsprogs-libs \
          expect \
          unzip \
          openssh-clients \
          readline* \
          psmisc \
          ksh \
          nfs-utils --skip-broken
      fi
    elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
      if [ "${TuXingHua}" = "y" ] || [ "${TuXingHua}" = "Y" ]; then
        #LINUX 7 && LINUX 8
        yum groupinstall -y "Server with GUI"
        yum install -y tigervnc*
      fi
      if [ "$(rpm -q bc binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ elfutils-libelf elfutils-libelf-devel glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXtst libXrender libXrender-devel make net-tools nfs-utils smartmontools sysstat e2fsprogs e2fsprogs-libs fontconfig-devel expect unzip openssh-clients readline psmisc --qf '%{name}.%{arch}\n' | grep -E -c "not installed")" -gt 0 ]; then
        yum install -y bc \
          binutils \
          compat-libcap1 \
          compat-libstdc++-33 \
          gcc \
          gcc-c++ \
          elfutils-libelf \
          elfutils-libelf-devel \
          glibc \
          glibc-devel \
          ksh \
          libaio \
          libaio-devel \
          libgcc \
          libstdc++ \
          libstdc++-devel \
          libxcb \
          libX11 \
          libXau \
          libXi \
          libXtst \
          libXrender \
          libXrender-devel \
          make \
          net-tools \
          nfs-utils \
          smartmontools \
          sysstat \
          e2fsprogs \
          e2fsprogs-libs \
          fontconfig-devel \
          expect \
          unzip \
          openssh-clients \
          readline* \
          psmisc --skip-broken
      fi
      ##Solutions: error while loading shared libraries: libnsl.so.1: cannot open shared object
      ##Requirements for Installing Oracle Database/Client 19c on OL8 or RHEL8 64-bit (x86-64) (Doc ID 2668780.1)
      if [ "${OS_VERSION}" = "linux8" ]; then
        dnf install -y librdmacm
        dnf install -y libnsl*
        dnf install -y libibverbs
        ##Linux Troubleshooting – semanage command not found in CentOS 7/8 And RHEL 7/8
        dnf install -y policycoreutils-python-utils
      fi
    fi

  fi
  ## yum install -y openssh
  if [ "$nodeNum" -eq 1 ]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      if echo "${ROOTPASSWD}" | passwd --stdin root; then
        EXPECT=/usr/bin/expect
        USER_PROMPT="*# "
        $EXPECT <<EOF
spawn ssh "$RAC2PUBLICIP" yum install -y openssh-client*
expect "*(yes/no?*" {
        send -- "yes\r"
        expect "*?assword:*"
        send -- "$ROOTPASSWD\r"
    } "*?assword:*" {send -- "$ROOTPASSWD\r"}
expect "$USER_PROMPT"
EOF
      fi
      ##SSHTRUST ROOT
      cat <<EOF >"${SOFTWAREDIR}"/sshhostList.cfg
$RAC2PUBLICIP
EOF
      rm -rf /root/.ssh
      if echo "${ROOTPASSWD}" | passwd --stdin root; then
        SSHTrust root "${ROOTPASSWD}" "${SOFTWAREDIR}/sshhostList.cfg"
      fi
      if [ -f "${SOFTWAREDIR}"/sshhostList.cfg ]; then
        rm -rf "${SOFTWAREDIR}"/sshhostList.cfg
      fi
    fi
  fi

  if [ "${OS_VERSION}" = "linux7" ]; then
    if [ "$nodeNum" -eq 1 ]; then
      if [ "${DB_VERSION}" = "11.2.0.4" ]; then
        if [ -f "${SOFTWAREDIR}"/pdksh-5.2.14-37.el5.x86_64.rpm ]; then
          if rpm -e ksh-20120801-142.el7.x86_64; then
            if rpm -ivh pdksh-5.2.14-37.el5.x86_64.rpm; then
              if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
                scp "${SOFTWAREDIR}"/pdksh-5.2.14-37.el5.x86_64.rpm "${RAC2PUBLICIP}":/root
                ssh "$RAC2PUBLICIP" rpm -ivh /root/pdksh-5.2.14-37.el5.x86_64.rpm
              fi
              rm -rf "${SOFTWAREDIR}"/pdksh-5.2.14-37.el5.x86_64.rpm
            fi
          fi
        fi
      fi
      if [ -f "${SOFTWAREDIR}"/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm ]; then
        if rpm -ivh "${SOFTWAREDIR}"/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm; then
          if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
            scp "${SOFTWAREDIR}"/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm "${RAC2PUBLICIP}":/root
            ssh "$RAC2PUBLICIP" rpm -ivh /root/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm
          fi
          rm -rf "${SOFTWAREDIR}"/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm
        fi
      fi
    fi
  fi

  # libc.so.6: version `GLIBC_2.14' not found
  # if [ "${OS_VERSION}" = "linux6" ] && [ "${DB_VERSION}" = "19.3.0.0" ] && [ "$(strings /lib64/libc.so.6 | grep -c GLIBC_2.14)" -eq 0 ]; then
  #     if [ -f "${SOFTWAREDIR}"/glibc-2.14.tar.gz ]; then
  #         tar -xvf "${SOFTWAREDIR}"/glibc-2.14.tar.gz
  #         cd "${SOFTWAREDIR}"/glibc-2.14 || return
  #         mkdir build && cd build && ../configure --prefix=/usr && make -j4 && make install && make localedata/install-locales
  #         export LD_LIBRARY_PATH=/opt/glibc-2.14/lib:$LD_LIBRARY_PATH
  #     else
  #         c1 "Sorry ,glibc-2.14.tar.gz is not found in the directory ${SOFTWAREDIR},Please Upload it."
  #         exit 99
  #     fi
  # fi

  if [ "${OS_VERSION}" = "linux6" ]; then
    logwrite "RPM Check" "rpm -q bc binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ elfutils-libelf elfutils-libelf-devel glibc glibc-devel libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXrender make net-tools smartmontools sysstat e2fsprogs e2fsprogs-libs expect unzip openssh-clients readline"
  elif [ "${OS_VERSION}" = "linux7" ]; then
    logwrite "RPM Check" "rpm -q bc binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ elfutils-libelf elfutils-libelf-devel glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXtst libXrender libXrender-devel make net-tools nfs-utils smartmontools sysstat e2fsprogs e2fsprogs-libs fontconfig-devel expect unzip openssh-clients readline"
  elif [ "${OS_VERSION}" = "linux8" ]; then
    logwrite "RPM Check" "rpm -q bc binutils gcc gcc-c++ elfutils-libelf elfutils-libelf-devel glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libxcb libX11 libXau libXi libXtst libXrender libXrender-devel make net-tools nfs-utils smartmontools sysstat e2fsprogs e2fsprogs-libs fontconfig-devel expect unzip openssh-clients readline librdmacm libnsl libibverbs policycoreutils-python-utils"
  fi
}

####################################################################################
# Configure hostname
####################################################################################
SetHostName() {
  if [ "${OS_VERSION}" = "linux6" ]; then
    Hostname=$(grep -E "HOSTNAME=" /etc/sysconfig/network)
    if [[ $(grep -E "${hostname}" /etc/sysconfig/network) != "${hostname}" ]]; then
      /bin/hostname "$hostname"
      sed -i "s/${Hostname}/HOSTNAME=${hostname}/" /etc/sysconfig/network
    fi
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    if [[ $(grep -E "${hostname}" /etc/hostname) != "${hostname}" ]]; then
      /usr/bin/hostnamectl set-hostname "${hostname}"
    fi
  fi
}

logwrite "HOSTNAME" "echo ${hostname}"

####################################################################################
# Configure /etc/hosts
####################################################################################
SetHosts() {
  if [ "$(grep -E -c "#OracleBegin" /etc/hosts)" -eq 0 ]; then
    [ ! -f /etc/hosts."${DAYTIME}" ] && cp /etc/hosts /etc/hosts."${DAYTIME}"
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      ##Configure DNS HOSTS
      if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
        cat <<EOF >>/etc/hosts
##OracleBegin
##Public IP
$RAC1PUBLICIP ${RAC1HOSTNAME}.${DNSNAME} $RAC1HOSTNAME
$RAC2PUBLICIP ${RAC2HOSTNAME}.${DNSNAME} $RAC2HOSTNAME

##Private IP
$RAC1PRIVIP ${RAC1HOSTNAME}-priv.${DNSNAME} ${RAC1HOSTNAME}-priv
$RAC2PRIVIP ${RAC2HOSTNAME}-priv.${DNSNAME} ${RAC2HOSTNAME}-priv

##Virtual IP
$RAC1VIP ${RAC1HOSTNAME}-vip.${DNSNAME} ${RAC1HOSTNAME}-vip
$RAC2VIP ${RAC2HOSTNAME}-vip.${DNSNAME} ${RAC2HOSTNAME}-vip

EOF
        if [ "${scan_sum}" = "1" ]; then
          cat <<EOF >>/etc/hosts
##SCAN IP
##${RACSCANIP1} ${RACSCANNAME}.${DNSNAME} ${RACSCANNAME}
EOF
        elif [ "${scan_sum}" = "2" ]; then
          cat <<EOF >>/etc/hosts
##SCAN IP
##${RACSCANIP1} ${RACSCANNAME}.${DNSNAME} ${RACSCANNAME}
##${RACSCANIP2} ${RACSCANNAME}.${DNSNAME} ${RACSCANNAME}
EOF
        elif [ "${scan_sum}" = "3" ]; then
          cat <<EOF >>/etc/hosts
##SCAN IP
##${RACSCANIP1} ${RACSCANNAME}.${DNSNAME} ${RACSCANNAME}
##${RACSCANIP2} ${RACSCANNAME}.${DNSNAME} ${RACSCANNAME}
##${RACSCANIP3} ${RACSCANNAME}.${DNSNAME} ${RACSCANNAME}
EOF
        fi
        if [ -n "${RAC1PRIVIP1}" ]; then
          cat <<EOF >>/etc/hosts

##Private IP 2
$RAC1PRIVIP1 ${RAC1HOSTNAME}-priv1.${DNSNAME} ${RAC1HOSTNAME}-priv1
$RAC2PRIVIP1 ${RAC2HOSTNAME}-priv1.${DNSNAME} ${RAC2HOSTNAME}-priv1
EOF
        fi
      else
        cat <<EOF >>/etc/hosts
##OracleBegin
##Public IP
$RAC1PUBLICIP $RAC1HOSTNAME
$RAC2PUBLICIP $RAC2HOSTNAME

##Private IP
$RAC1PRIVIP $RAC1HOSTNAME-priv
$RAC2PRIVIP $RAC2HOSTNAME-priv

##Virtual IP
$RAC1VIP $RAC1HOSTNAME-vip
$RAC2VIP $RAC2HOSTNAME-vip

##Scan IP
$RACSCANIP $RACSCANNAME
EOF
      fi
    else
      cat <<EOF >>/etc/hosts
##OracleBegin
#Public IP
$PUBLICIP	$HOSTNAME
EOF
    fi
  fi

  logwrite "/etc/hosts" "cat /etc/hosts"
}

####################################################################################
# DNS SERVER CONFIGURE
####################################################################################
DNSServerConf() {
  ##install bind
  yum install -y bind-libs bind bind-utils
  if [ "${OS_VERSION}" = "linux6" ]; then
    chkconfig named on
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    systemctl enable named
  fi
  if [ "$nodeNum" -eq 1 ]; then
    RacPublicIPFX=$(echo "${RAC1PUBLICIP}" | awk 'BEGIN {FS="."}{print $3"."$2"."$1"."}')
    RacPrivFX=$(echo "${RAC1PRIVIP}" | awk 'BEGIN {FS="."}{print $3"."$2"."$1"."}')
    RacPriv1FX=$(echo "${RAC1PRIVIP1}" | awk 'BEGIN {FS="."}{print $3"."$2"."$1"."}')
    Rac1Public=$(echo "${RAC1PUBLICIP}" | awk 'BEGIN {FS="."}{print $4}')
    Rac2Public=$(echo "${RAC2PUBLICIP}" | awk 'BEGIN {FS="."}{print $4}')
    Rac1Priv=$(echo "${RAC1PRIVIP}" | awk 'BEGIN {FS="."}{print $4}')
    Rac2Priv=$(echo "${RAC2PRIVIP}" | awk 'BEGIN {FS="."}{print $4}')
    Rac1Priv1=$(echo "${RAC1PRIVIP1}" | awk 'BEGIN {FS="."}{print $4}')
    Rac2Priv1=$(echo "${RAC2PRIVIP1}" | awk 'BEGIN {FS="."}{print $4}')
    Rac1Vip=$(echo "${RAC1VIP}" | awk 'BEGIN {FS="."}{print $4}')
    Rac2Vip=$(echo "${RAC2VIP}" | awk 'BEGIN {FS="."}{print $4}')
    RacScan1=$(echo "${RACSCANIP1}" | awk 'BEGIN {FS="."}{print $4}')
    RacScan2=$(echo "${RACSCANIP2}" | awk 'BEGIN {FS="."}{print $4}')
    RacScan3=$(echo "${RACSCANIP3}" | awk 'BEGIN {FS="."}{print $4}')
    cat <<EOF >/etc/named.conf
options {
	listen-on port 53 { any; };
	listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	recursing-file  "/var/named/data/named.recursing";
	secroots-file   "/var/named/data/named.secroots";
	allow-query     { any; };
	recursion yes;
	dnssec-enable yes;
	dnssec-validation yes;
	bindkeys-file "/etc/named.root.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};
zone "." IN {
	type hint;
	file "named.ca";
};
include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF
    if [ "$(grep -E -c "#OracleBegin" /etc/named.rfc1912.zones)" -eq 0 ]; then
      [ ! -f /etc/named.rfc1912.zones."${DAYTIME}" ] && cp /etc/named.rfc1912.zones /etc/named.rfc1912.zones."${DAYTIME}" >/dev/null 2>&1
      cat <<EOF >>/etc/named.rfc1912.zones
#OracleBegin
zone "${DNSNAME}" IN {
        type master;
        file "${DNSNAME}.zone";
        allow-update { none; };
};
zone "${RacPublicIPFX}in-addr.arpa." IN {
        type master;
        file "${RacPublicIPFX}arpa";
        allow-update { none; };
};

zone "${RacPrivFX}in-addr.arpa." IN {
        type master;
        file "${RacPrivFX}arpa";
        allow-update { none; };
};
EOF
      if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
        if [ "$(grep -E -c "${RacPriv1FX}in-addr.arpa" /etc/named.rfc1912.zones)" -eq 0 ]; then
          cat <<EOF >>/etc/named.rfc1912.zones
zone "${RacPriv1FX}in-addr.arpa." IN {
        type master;
        file "${RacPriv1FX}arpa";
        allow-update { none; };
};
#OracleEnd
EOF
        else
          cat <<EOF >>/etc/named.rfc1912.zones
#OracleBegin
EOF
        fi
      fi
    fi
    cat <<EOF >/var/named/"${DNSNAME}".zone
\$TTL 1D
@    IN SOA   ${DNSNAME}. root.${DNSNAME}. (
                    0    ; serial
                    1D    ; refresh
                    1H    ; retry
                    1W    ; expire
                    3H )    ; minimum
@   IN  NS  ns.${DNSNAME}.
ns  IN  A   ${DNSIP}
$RAC1HOSTNAME  IN  A    ${RAC1PUBLICIP}
$RAC2HOSTNAME  IN  A    ${RAC2PUBLICIP}
$RAC1HOSTNAME-priv IN   A   ${RAC1PRIVIP}
$RAC2HOSTNAME-priv IN   A   ${RAC2PRIVIP}
$RAC1HOSTNAME-vip IN   A   ${RAC1VIP}
$RAC2HOSTNAME-vip IN   A   ${RAC2VIP}
EOF
    cat <<EOF >/var/named/"${RacPublicIPFX}"arpa
\$TTL 1D
@	IN SOA	${DNSNAME}. root.${DNSNAME}. (
					0	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	NS	ns.${DNSNAME}.
ns	A	${DNSIP}
${Rac1Public}	PTR	$RAC1HOSTNAME.${DNSNAME}.	
${Rac2Public}	PTR	$RAC2HOSTNAME.${DNSNAME}.			
${Rac1Vip}	PTR	$RAC1HOSTNAME-vip.${DNSNAME}. 	
${Rac2Vip}	PTR	$RAC2HOSTNAME-vip.${DNSNAME}.
EOF
    if [ "${scan_sum}" = "1" ]; then
      cat <<EOF >>/var/named/"${RacPublicIPFX}"arpa
${RacScan1}	PTR	$RACSCANNAME.${DNSNAME}.
EOF
      cat <<EOF >>/var/named/"${DNSNAME}".zone
$RACSCANNAME IN   A   ${RACSCANIP1}
EOF
    elif [ "${scan_sum}" = "2" ]; then
      cat <<EOF >>/var/named/"${RacPublicIPFX}"arpa
${RacScan1}	PTR	$RACSCANNAME.${DNSNAME}.
${RacScan2}	PTR	$RACSCANNAME.${DNSNAME}.
EOF
      cat <<EOF >>/var/named/"${DNSNAME}".zone
$RACSCANNAME IN   A   ${RACSCANIP1}
$RACSCANNAME IN   A   ${RACSCANIP2}
EOF
    elif [ "${scan_sum}" = "3" ]; then
      cat <<EOF >>/var/named/"${RacPublicIPFX}"arpa
${RacScan1}	PTR	$RACSCANNAME.${DNSNAME}.
${RacScan2}	PTR	$RACSCANNAME.${DNSNAME}.
${RacScan3}	PTR	$RACSCANNAME.${DNSNAME}.
EOF
      cat <<EOF >>/var/named/"${DNSNAME}".zone
$RACSCANNAME IN   A   ${RACSCANIP1}
$RACSCANNAME IN   A   ${RACSCANIP2}
$RACSCANNAME IN   A   ${RACSCANIP3}
EOF
    fi
    ##Configure Private ip arpa
    cat <<EOF >/var/named/"${RacPrivFX}"arpa
\$TTL 1D
@	IN SOA	${DNSNAME}. root.${DNSNAME}. (
					0	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	NS	ns.${DNSNAME}.
ns	A	${DNSIP}
${Rac1Priv}	PTR	$RAC1HOSTNAME-priv.${DNSNAME}.	
${Rac2Priv}	PTR	$RAC2HOSTNAME-priv.${DNSNAME}.         
EOF
    ##Two Private IP Need to add 2 rules
    if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
      cat <<EOF >>/var/named/"${DNSNAME}".zone
$RAC1HOSTNAME-priv1 IN   A   ${RAC1PRIVIP1}
$RAC2HOSTNAME-priv1 IN   A   ${RAC2PRIVIP1}
EOF
      ##Configure Private ip arpa
      cat <<EOF >/var/named/"${RacPriv1FX}"arpa
\$TTL 1D
@	IN SOA	${DNSNAME}. root.${DNSNAME}. (
					0	; serial
					1D	; refresh
					1H	; retry
					1W	; expire
					3H )	; minimum
	NS	ns.${DNSNAME}.
ns	A	${DNSIP}
${Rac1Priv1}	PTR	$RAC1HOSTNAME-priv1.${DNSNAME}.	
${Rac2Priv1}	PTR	$RAC2HOSTNAME-priv1.${DNSNAME}.         
EOF
    fi
  fi
  systemctl restart named
}

####################################################################################
# Nslookup Check Function
####################################################################################
NslookupFunc() {
  ##install bind
  yum install -y bind-libs bind bind-utils
  ssh "${RAC2HOSTNAME}" "yum install -y bind-libs bind bind-utils"
  cat <<EOF >/etc/resolv.conf
search ${DNSNAME}
nameserver ${DNSIP}
options rotate
options timeout:2
options attempts:5
EOF

  scp /etc/resolv.conf "${RAC2HOSTNAME}":/etc/
  nslookup "${RAC1HOSTNAME}"
  nslookup "${RAC2HOSTNAME}"
  nslookup "${RAC1HOSTNAME}"-priv
  nslookup "${RAC2HOSTNAME}"-priv
  if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ]; then
    nslookup "${RAC1HOSTNAME}"-priv1
    nslookup "${RAC2HOSTNAME}"-priv1
  fi
  nslookup "${RAC1HOSTNAME}"-vip
  nslookup "${RAC2HOSTNAME}"-vip
  nslookup "${RACSCANNAME}"

  logwrite "NSLOOKUP CHECK" "host -l ${DNSNAME}"
}

####################################################################################
# create user and groups
####################################################################################
CreateUsersAndDirs() {
  ####################################################################################
  # create user and groups
  ####################################################################################
  if [ "$(grep -E -c "oinstall" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54321 oinstall
  fi
  if [ "$(grep -E -c "dba" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54322 dba
  fi
  if [ "$(grep -E -c "oper" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54323 oper
  fi
  if [ "$(grep -E -c "backupdba" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54324 backupdba
  fi
  if [ "$(grep -E -c "dgdba" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54325 dgdba
  fi
  if [ "$(grep -E -c "kmdba" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54326 kmdba
  fi
  if [ "$(grep -E -c "racdba" /etc/group)" -eq 0 ]; then
    /usr/sbin/groupadd -g 54330 racdba
  fi

  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    if [ "$(grep -E -c "asmdba" /etc/group)" -eq 0 ]; then
      /usr/sbin/groupadd -g 54327 asmdba
    fi
    if [ "$(grep -E -c "asmoper" /etc/group)" -eq 0 ]; then
      /usr/sbin/groupadd -g 54328 asmoper
    fi
    if [ "$(grep -E -c "asmadmin" /etc/group)" -eq 0 ]; then
      /usr/sbin/groupadd -g 54329 asmadmin
    fi

    ##Create grid user
    if [ "$(grep -E -c "grid" /etc/passwd)" -eq 0 ]; then
      if ! /usr/sbin/useradd -u 11012 -g oinstall -G asmadmin,asmdba,asmoper,dba,racdba,oper grid; then
        echo "Command failed to adding user grid."
        exit 93
      fi
    else
      /usr/sbin/usermod -g oinstall -G asmadmin,asmdba,asmoper,dba,racdba,oper grid
    fi

    ##Set user grid's password
    if ! echo "${GRIDPASSWD}" | passwd --stdin grid; then
      c1 "User grid is not existing." red
      exit 92
    fi

    logwrite "Create user and groups(grid)" "id grid"
  fi

  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    ##Create oracle user with RAC
    if [ "$(grep -E -c "oracle" /etc/passwd)" -eq 0 ]; then
      if ! /usr/sbin/useradd -u 54321 -g oinstall -G asmdba,dba,backupdba,dgdba,kmdba,racdba,oper oracle; then
        echo "Command failed to adding user --oracle."
        exit 93
      fi
    else
      /usr/sbin/usermod -g oinstall -G asmdba,dba,backupdba,dgdba,kmdba,racdba,oper oracle
    fi
  else
    ##Create oracle user with Single
    if [ "$(grep -E -c "oracle" /etc/passwd)" -eq 0 ]; then
      if ! /usr/sbin/useradd -u 54321 -g oinstall -G dba,backupdba,dgdba,kmdba,racdba,oper oracle; then
        echo "Command failed to adding user --oracle."
        exit 93
      fi
    else
      /usr/sbin/usermod -g oinstall -G dba,backupdba,dgdba,kmdba,racdba,oper oracle
    fi
  fi

  ##Set user oracle's password
  if ! echo "${ORAPASSWD}" | passwd --stdin oracle; then
    c1 "User oracle is not existing." red
    exit 92
  fi

  logwrite "Create user and groups(oracle)" "id oracle"

  ####################################################################################
  #make directory
  ####################################################################################
  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    [ ! -d "${ENV_GRID_BASE}" ] && mkdir -p "${ENV_GRID_BASE}"
    [ ! -d "${ENV_GRID_HOME}" ] && mkdir -p "${ENV_GRID_HOME}"
    [ ! -d "${ENV_ORACLE_HOME}" ] && mkdir -p "${ENV_ORACLE_HOME}"
    [ ! -d "${ENV_ORACLE_INVEN}" ] && mkdir -p "${ENV_ORACLE_INVEN}"
    [ ! -d "${BACKUPDIR}" ] && mkdir -p "${BACKUPDIR}"
    [ ! -d "${SCRIPTSDIR}" ] && mkdir -p "${SCRIPTSDIR}"
    chown -R oracle:oinstall "${SCRIPTSDIR}"
    chown -R oracle:oinstall "${BACKUPDIR}"
    chown -R grid:oinstall "${ENV_BASE_DIR}"
    chown -R grid:oinstall "${ENV_GRID_HOME}"
    chown -R grid:oinstall "${ENV_ORACLE_INVEN}"
    chown -R oracle:oinstall "${ENV_ORACLE_BASE}"
    chmod -R 775 "${ENV_BASE_DIR}"
  else
    [ ! -d "${ENV_ORACLE_HOME}" ] && mkdir -p "${ENV_ORACLE_HOME}"
    [ ! -d "${ENV_ORACLE_INVEN}" ] && mkdir -p "${ENV_ORACLE_INVEN}"
    [ ! -d "${ORADATADIR}" ] && mkdir -p "${ORADATADIR}"
    [ ! -d "${ARCHIVEDIR}" ] && mkdir -p "${ARCHIVEDIR}"
    [ ! -d "${BACKUPDIR}" ] && mkdir -p "${BACKUPDIR}"
    [ ! -d "${SCRIPTSDIR}" ] && mkdir -p "${SCRIPTSDIR}"
    chown -R oracle:oinstall "${SCRIPTSDIR}"
    chown -R oracle:oinstall "${ORADATADIR}"
    chown -R oracle:oinstall "${ARCHIVEDIR}"
    chown -R oracle:oinstall "${BACKUPDIR}"
    chown -R oracle:oinstall "${ENV_BASE_DIR}"
    chmod -R 775 "${ENV_BASE_DIR}"
  fi

  if [ "${DB_VERSION}" = "12.2.0.1" ]; then
    touch /etc/oraInst.loc
    echo "inventory_loc=${ENV_ORACLE_INVEN}" >>/etc/oraInst.loc
    echo "inst_group=oinstall" >>/etc/oraInst.loc
  fi

  ## Judge DISK SPACE
  if [ "${OS_VERSION}" = "linux6" ]; then
    BASEDIR_SPACE=$(df "${ENV_BASE_DIR}" | tail -n 1 | awk '{printf $3}')
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    BASEDIR_SPACE=$(df "${ENV_BASE_DIR}" | tail -n 1 | awk '{printf $4}')
  fi
  BASEDIR_SPACE=$((BASEDIR_SPACE / 1024 / 1024))
  if [ "${BASEDIR_SPACE}" -lt 50 ]; then
    c1 "${ENV_BASE_DIR} Disk Space ${BASEDIR_SPACE}G is not enough (50G), Install Maybe Failed." red
    sleep 3
  fi
}

####################################################################################
# Configure SSH
####################################################################################
Rac_Auto_SSH() {
  cat <<EOF >"${SOFTWAREDIR}"/sshhostList.cfg
$RAC1HOSTNAME
$RAC2HOSTNAME
$RAC1HOSTNAME-priv
$RAC2HOSTNAME-priv
EOF
  rm -rf /root/.ssh
  rm -rf /home/oracle/.ssh
  rm -rf /home/grid/.ssh

  ## change root password
  if echo "${ROOTPASSWD}" | passwd --stdin root; then
    SSHTrust root "${ROOTPASSWD}" "${SOFTWAREDIR}/sshhostList.cfg"
  fi

  export -f SSHTrust
  su grid -c "SSHTrust grid ${GRIDPASSWD} ${SOFTWAREDIR}/sshhostList.cfg"
  su oracle -c "SSHTrust oracle ${ORAPASSWD} ${SOFTWAREDIR}/sshhostList.cfg"
}

####################################################################################
#Configure Udev+Multipath ASMDISK
####################################################################################
UDEV_ASMDISK() {
  # Install multipath
  yum install -y device-mapper*
  mpathconf --enable --with_multipathd y

  # Configure multipath
  cat <<EOF >/etc/multipath.conf
defaults {
    user_friendly_names yes
}
 
blacklist {
  devnode "^sda"
}

multipaths {
EOF
  ocrdisk_sum=0
  for i in ${OCR_BASEDISK//,/ }; do
    ##judge whether disk is null,if disk is not null
    ocrdisk_size=$(lsblk "${i}" | awk '{print $4}' | head -n 2 | tail -n 1)
    ocrdisk_size=${ocrdisk_size//G/}
    ocrdisk_sum=$((ocrdisk_sum + ocrdisk_size))
    if [ "$nodeNum" -eq 1 ]; then
      if [ "$(hexdump -n 1024 -C "${i}" | grep -c "${ASMOCRNAME}")" -gt 0 ]; then
        c1 "[FATAL] [INS-30516] Please specify unique disk groups." red
        echo
        echo "${i} :"
        hexdump -n 1024 -C "${i}" | grep "${ASMOCRNAME}"
        echo
        c1 "The ""${ASMOCRNAME}"" diskgroup name provided already exists on the disk. Whether Format the disk $i ?(Y|N)" blue
        read -r formatocrdisk
        if [ "$formatocrdisk" = "Y" ] || [ "$formatocrdisk" = "y" ]; then
          c1 "Now Formatting Disk ${i} ........" red
          dd if=/dev/zero of="${i}" bs=10M count=10
        else
          c1 "Install Failed. [INS-30516] Please specify unique disk groups." red
          exit 99
        fi
      fi
    fi
    num1=$((num1 + 1))
    if [ "${OS_VERSION}" = "linux6" ]; then
      cat <<EOF >>/etc/multipath.conf
  multipath {
  wwid "$(scsi_id -g -u "${i}")"
  alias ocr_${num1}
  }
EOF
    elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
      cat <<EOF >>/etc/multipath.conf
  multipath {
  wwid "$(/usr/lib/udev/scsi_id -g -u "${i}")"
  alias ocr_${num1}
  }
EOF
    fi
  done

  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
    if [ "${DB_VERSION}" = "12.2.0.1" ]; then
      if [ "$OCRREDUN" = "NORMAL" ]; then
        ocrdisk_sum=$((ocrdisk_sum / 2))
      elif [ "$OCRREDUN" = "HIGH" ]; then
        ocrdisk_sum=$((ocrdisk_sum / 3))
      fi
      if [ $ocrdisk_sum -lt 40 ]; then
        c1 "Install Failed. OCR DISK SIZE ${ocrdisk_sum}G MUST GRATER THAN 40G." red
        exit 99
      fi
    fi
  fi
  for i in ${DATA_BASEDISK//,/ }; do
    if [ "$nodeNum" -eq 1 ]; then
      if [ "$(hexdump -n 1024 -C "${i}" | grep -c "${ASMDATANAME}")" -gt 0 ]; then
        c1 "[FATAL] [INS-30516] Please specify unique disk groups." red
        echo "${i} :"
        hexdump -n 1024 -C "${i}" | grep "${ASMDATANAME}"
        echo
        c1 "The ""${ASMDATANAME}"" diskgroup name provided already exists on the disk. Whether Format the disk $i ?(Y|N)" blue
        read -r formatdatadisk
        if [ "$formatdatadisk" = "Y" ] || [ "$formatdatadisk" = "y" ]; then
          c1 "Now Formatting Disk ${i} ........" red
          dd if=/dev/zero of="${i}" bs=10M count=10
        else
          c1 "Install Failed. [INS-30516] Please specify unique disk groups." red
          exit 99
        fi
      fi
    fi
    num2=$((num2 + 1))
    if [ "${OS_VERSION}" = "linux6" ]; then
      cat <<EOF >>/etc/multipath.conf
  multipath {
  wwid "$(scsi_id -g -u "${i}")"
  alias data_${num2}
  }
EOF
    elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
      cat <<EOF >>/etc/multipath.conf
  multipath {
  wwid "$(/usr/lib/udev/scsi_id -g -u "${i}")"
  alias data_${num2}
  }
EOF
    fi
  done

  echo "}" >>/etc/multipath.conf

  multipath -F
  multipath -v2
  multipath -r
  multipath -F
  multipath -v2

  logwrite "multipath info:" "multipath -ll"

  ####################################################################################
  # Configure udev
  ####################################################################################
  if [ -f /dev/mapper/udev_info ]; then
    rm -rf /dev/mapper/udev_info
  fi
  cd /dev/mapper || return
  for i in ocr_* data_*; do
    printf "%s %s\n" "$i" "$(udevadm info --query=all --name=/dev/mapper/"$i" | grep -i dm_uuid)" >>udev_info
  done
  cd ~ || return

  if [ -f /etc/udev/rules.d/99-oracle-asmdevices.rules ]; then
    rm -rf /etc/udev/rules.d/99-oracle-asmdevices.rules
  fi
  while read -r line; do
    dm_uuid=$(echo "$line" | awk -F'=' '{print $2}')
    disk_name=$(echo "$line" | awk '{print $1}')
    echo "KERNEL==\"dm-*\",ENV{DM_UUID}==\"${dm_uuid}\",SYMLINK+=\"asm_${disk_name}\",OWNER=\"grid\",GROUP=\"asmadmin\",MODE=\"0660\"" >>/etc/udev/rules.d/99-oracle-asmdevices.rules
  done </dev/mapper/udev_info

  if [ "${OS_VERSION}" = "linux6" ]; then
    start_udev
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    udevadm control --reload-rules
    udevadm trigger --type=devices
  fi

  sleep 2

  if [ -f "${SOFTWAREDIR}"/ocr_temp ]; then
    rm -rf "${SOFTWAREDIR}"/ocr_temp
  fi
  if [ -f "${SOFTWAREDIR}"/ocr_fail_temp ]; then
    rm -rf "${SOFTWAREDIR}"/ocr_fail_temp
  fi
  cd "${SOFTWAREDIR}" || return
  for i in /dev/asm_ocr*; do
    echo -n "${i}", >>ocr_temp
    echo -n "${i}",, >>ocr_fail_temp
    OCRDISK=$(cat ocr_temp)
    OCRFailureDISK=$(cat ocr_fail_temp)
    OCRDISK=${OCRDISK%*,}
    OCRFailureDISK=${OCRFailureDISK%*,}
  done
  if [ -f "${SOFTWAREDIR}"/data_temp ]; then
    rm -rf "${SOFTWAREDIR}"/data_temp
  fi
  if [ -f "${SOFTWAREDIR}"/data_fail_temp ]; then
    rm -rf "${SOFTWAREDIR}"/data_fail_temp
  fi
  cd "${SOFTWAREDIR}" || return
  for i in /dev/asm_data*; do
    if [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      echo -n "${i}", >>data_temp
      echo -n "${i}",, >>data_fail_temp
      DATAFailureDISK=$(cat data_fail_temp)
      DATAFailureDISK=${DATAFailureDISK%*,}
    else
      echo -n "'${i}'," >>data_temp
    fi
    DATADISK=$(cat data_temp)
    DATADISK=${DATADISK%*,}
  done

  logwrite "udev asm info:" "ls /dev/asm_*"
  if [ "$(find "${SOFTWAREDIR}" -mindepth 1 -name '*temp' | wc -l)" -gt 0 ]; then
    rm -rf "${SOFTWAREDIR}"/*temp
  fi
}

####################################################################################
# NODE2 Excute shell script
####################################################################################
NodeTwoExec() {
  ##rac send node2 script and & excute
  ssh "$RAC2PUBLICIP" mkdir "${SOFTWAREDIR}"
  ##cp racnode2.sh to node2
  scp "${SOFTWAREDIR}"/racnode2.sh "${RAC2PUBLICIP}":"${SOFTWAREDIR}"
  ##cp OracleShellInstall.sh to node2
  scp "${SOFTWAREDIR}"/OracleShellInstall.sh "${RAC2PUBLICIP}":"${SOFTWAREDIR}"
  #excute racnode2.sh on node2
  c1 "Now Excute Script on Node2:" blue
  ssh "$RAC2PUBLICIP" chmod +x "${SOFTWAREDIR}"/racnode2.sh
  ##https://www.cnblogs.com/youngerger/p/9104144.html
  ssh -t "$RAC2PUBLICIP" "cd ${SOFTWAREDIR};sh ${SOFTWAREDIR}/racnode2.sh"
  if [ -f "${SOFTWAREDIR}"/racnode2.sh ]; then
    rm -rf "${SOFTWAREDIR}"/racnode2.sh
  fi
  c1 "Node2 Setup Finish." blue
}

####################################################################################
#Time dependent Settings
####################################################################################
TimeDepSet() {
  if [ "${OS_VERSION}" = "linux6" ]; then
    if [ "$(grep -E -c "Asia/Shanghai" /etc/sysconfig/clock)" -eq 0 ]; then
      [ ! -f /etc/sysconfig/clock."${DAYTIME}" ] && cp /etc/sysconfig/clock /etc/sysconfig/clock."${DAYTIME}"
      cat <<EOF >/etc/sysconfig/clock
ZONE="Asia/Shanghai"
EOF
      /bin/cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    fi
    if [ "$(chkconfig --list | grep ntpd | grep -c on)" -gt 0 ]; then
      service ntpd stop
      chkconfig ntpd off
    fi

    logwrite "ntpd" "service ntpd status"

    [ -f /etc/ntp.conf ] && mv /etc/ntp.conf /etc/ntp.conf.orig
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    timedatectl set-timezone Asia/Shanghai
    if [ "$(systemctl status chronyd | grep -c running)" -gt 0 ]; then
      systemctl stop chronyd.service
      systemctl disable chronyd.service
    fi

    logwrite "chronyd" "systemctl status chronyd"
  fi
  ##ntpdate configure
  if [[ -n "${TIMESERVERIP}" ]]; then
    if [ "${OS_VERSION}" = "linux6" ] || [ "${OS_VERSION}" = "linux7" ]; then
      yum install -y ntpdate
      if [ ! -f /var/spool/cron/root ]; then
        echo "##For ntpupdate" >>/var/spool/cron/root
      fi
      if [ "$(grep -E -c "#OracleBegin" /var/spool/cron/root)" -eq 0 ]; then
        [ ! -f /var/spool/cron/root."${DAYTIME}" ] && cp /var/spool/cron/root /var/spool/cron/root."${DAYTIME}" >/dev/null 2>&1
        {
          echo "#OracleBegin"
          echo "00 12 * * * /usr/sbin/ntpdate -u ${TIMESERVERIP} && /usr/sbin/hwclock -w"
          echo "#OracleEnd"
        } >>/var/spool/cron/root
      fi
      /usr/sbin/ntpdate -u "${TIMESERVERIP}" && /usr/sbin/hwclock -w
    elif [ "${OS_VERSION}" = "linux8" ]; then
      if [ ! -f /var/spool/cron/root ]; then
        echo "##For ntpupdate" >>/var/spool/cron/root
      fi
      if [ "$(grep -E -c "#OracleBegin" /var/spool/cron/root)" -eq 0 ]; then
        [ ! -f /var/spool/cron/root."${DAYTIME}" ] && cp /var/spool/cron/root /var/spool/cron/root."${DAYTIME}" >/dev/null 2>&1
        {
          echo "#OracleBegin"
          echo "00 12 * * * /usr/sbin/chronyd -q \"server ${TIMESERVERIP} iburst \" && timedatectl set-local-rtc 0"
          echo " #OracleEnd"
        } >>/var/spool/cron/root
      fi
      chronyd -q "server ${TIMESERVERIP} iburst" && timedatectl set-local-rtc 0
    fi
    logwrite "Time ntpdate" "crontab -l"
  fi

  logwrite "Time dependent" "date"

}

####################################################################################
#Stop avahi deamon
####################################################################################
Disableavahi() {
  if [ "${OS_VERSION}" = "linux6" ]; then
    yum install -y avahi*
    if [ "$(chkconfig --list | grep avahi-daemon | grep -c '3:on')" -gt 0 ]; then
      service avahi-daemon stop
      chkconfig avahi-daemon off
    fi
    logwrite "avahi-daemon" "service avahi-daemon  status"

  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    yum install -y avahi*
    if [ "$(systemctl status avahi-daemon | grep -c running)" -gt 0 ]; then
      systemctl stop avahi-daemon.socket
      systemctl stop avahi-daemon.service
      pgrep -f avahi-daemon | awk '{print "kill -9 "$2}'
    fi
    systemctl disable avahi-daemon.service
    systemctl disable avahi-daemon.socket
    logwrite "avahi-daemon" "systemctl status avahi-daemon"
  fi
}

####################################################################################
# Stop firefall
####################################################################################
DisableFirewall() {
  if [ "${OS_VERSION}" = "linux6" ]; then
    if [ "$(chkconfig --list | grep tables | grep -c on)" -gt 0 ]; then
      service iptables stop
      chkconfig iptables off
      service ip6tables stop
      chkconfig ip6tables off
    fi
    logwrite "Iptables" "service iptables status"
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    if [ "$(systemctl status firewalld.service | grep -c running)" -gt 0 ]; then
      systemctl stop firewalld.service
      systemctl disable firewalld.service
    fi
    logwrite "Firewalld" "systemctl status firewalld"
  fi
}

####################################################################################
# Disable Selinux
####################################################################################
DisableSelinux() {
  if [[ "$(/usr/sbin/getenforce)" != "Disabled" ]]; then
    /usr/sbin/setenforce 0
  fi
  if [ "$(grep -E -c "SELINUX=enforcing" /etc/selinux/config)" -gt 0 ]; then
    [ ! -f /etc/selinux/config."${DAYTIME}" ] && cp /etc/selinux/config /etc/selinux/config."${DAYTIME}"
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  fi

  logwrite "SELINUX" "getenforce"
}

####################################################################################
# Disable transparent_hugepages&&numa
####################################################################################
DisableTHPAndNUMA() {
  if [ "${OS_VERSION}" = "linux6" ]; then
    if [ "$(grep -E -c "/sys/kernel/mm/transparent_hugepage/enabled" /etc/rc.d/rc.local)" -eq 0 ]; then
      cat >>/etc/rc.d/rc.local <<EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
    fi
    if [ "$(grep -E -c "numa=off" /boot/grub/grub.conf)" -eq 0 ]; then
      [ ! -f /boot/grub/grub.conf."${DAYTIME}" ] && cp /boot/grub/grub.conf /boot/grub/grub.conf."${DAYTIME}"
      sed -i 's/quiet/quiet numa=off/' /boot/grub/grub.conf
    fi
    logwrite "/boot/grub/grub.conf" "cat /boot/grub/grub.conf"
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    if [ "$(grep -E -c "transparent_hugepage=never numa=off" /etc/default/grub)" -eq 0 ]; then
      [ ! -f /etc/default/grub."${DAYTIME}" ] && cp /etc/default/grub /etc/default/grub."${DAYTIME}"
      sed -i 's/quiet/quiet transparent_hugepage=never numa=off/' /etc/default/grub
      grub2-mkconfig -o /boot/grub2/grub.cfg
    fi

    logwrite "/etc/default/grub" "cat /etc/default/grub"
  fi

  logwrite "Transparent_hugepages" "cat /sys/kernel/mm/transparent_hugepage/enabled"
  logwrite "NUMA" "cat /proc/cmdline"
}

####################################################################################
# Disable NetworkManager
####################################################################################
DisableNetworkManager() {
  if [ "${OS_VERSION}" = "linux6" ]; then
    if [ "$(chkconfig --list | grep NetworkManager | grep -c on)" -gt 0 ]; then
      service NetworkManager stop
      chkconfig NetworkManager off
      service NetworkManager off
    fi
    logwrite "NetworkManager" "service NetworkManager status"
  elif [ "${OS_VERSION}" = "linux7" ] || [ "${OS_VERSION}" = "linux8" ]; then
    #Turn off the NetworkManager(Linux 7)
    if [ "$(systemctl status NetworkManager.service | grep -c running)" -gt 0 ]; then
      systemctl stop NetworkManager.service
      systemctl disable NetworkManager.service
    fi
    logwrite "NetworkManager" "systemctl status NetworkManager"
  fi
}

EditParaFiles() {
  ####################################################################################
  # Edit sysctl.conf
  ####################################################################################
  ##shmmal's Calculation formula: physical memory 8G：(8*1024*1024*1024)/4096=2097152
  ##shmmax's Calculation formula: physical memory 8G：(8/2)*1024*1024*1024 -1=4294967295

  totalMemory=$((memTotal / 2048))
  shmall=$((memTotal / 4))
  if [ $shmall -lt 2097152 ]; then
    shmall=2097152
  fi
  shmmax=$((memTotal * 1024 - 1))
  if [ "$shmmax" -lt 4294967295 ]; then
    shmmax=4294967295
  fi
  if [ "$(grep -E -c "#OracleBegin" /etc/sysctl.conf)" -eq 0 ]; then
    [ ! -f /etc/sysctl.conf."${DAYTIME}" ] && cp /etc/sysctl.conf /etc/sysctl.conf."${DAYTIME}"
    cat <<EOF >>/etc/sysctl.conf
#OracleBegin
##shmmal's Calculation formula: physical memory 8G：(8*1024*1024*1024)/4096=2097152
##shmmax's Calculation formula: physical memory 8G：(8/2)*1024*1024*1024 -1=4294967295
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = $shmall
kernel.shmmax = $shmmax
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
EOF
    if [ "${OS_VERSION}" = "linux8" ]; then
      cat <<EOF >>/etc/sysctl.conf
# sysctl kernel.numa_balancing
kernel.numa_balancing = 0
EOF
    fi
    if [ -n "${RACPUBLICFCNAME}" ] && [ -n "${RACPRIVFCNAME}" ]; then
      cat <<EOF >>/etc/sysctl.conf
net.ipv4.conf.${RACPUBLICFCNAME}.rp_filter = 1
net.ipv4.conf.${RACPRIVFCNAME}.rp_filter = 2
EOF
    fi
    if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
      cat <<EOF >>/etc/sysctl.conf
net.ipv4.conf.${RACPRIVFCNAME1}.rp_filter = 2
#OracleEnd
EOF
    else
      cat <<EOF >>/etc/sysctl.conf
#OracleEnd
EOF
    fi
    sysctl -p
    logwrite "/etc/sysctl.conf" "sysctl -p"
  fi

  ####################################################################################
  # Edit nsysctl.conf
  ####################################################################################
  if [ "$(grep -E -c "#OracleBegin" /etc/sysconfig/network)" -eq 0 ]; then
    [ ! -f /etc/sysconfig/network."${DAYTIME}" ] && cp /etc/sysconfig/network /etc/sysconfig/network."${DAYTIME}"
    {
      echo "#OracleBegin"
      echo "NOZEROCONF=yes"
      echo "#OracleEnd"
    } >>/etc/sysconfig/network
  fi

  logwrite "NOZEROCONF" "cat /etc/sysconfig/network"

  ####################################################################################
  # Edit limits.conf
  ####################################################################################
  if [ "${OS_VERSION}" = "linux7" ]; then
    sed -i 's/*          soft    nproc     4096/*          -       nproc     16384/g' /etc/security/limits.d/20-nproc.conf
    logwrite "/etc/security/limits.d/20-nproc.conf" "cat /etc/security/limits.d/20-nproc.conf | grep -v \"^\$\"|grep -v \"^#\""
  fi
  if [ "$(grep -E -c "#OracleBegin" /etc/security/limits.conf)" -eq 0 ]; then
    [ ! -f /etc/security/limits.conf."${DAYTIME}" ] && cp /etc/security/limits.conf /etc/security/limits.conf."${DAYTIME}"
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      cat <<EOF >>/etc/security/limits.conf
#OracleBegin
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
oracle hard stack 32768
oracle soft nproc 2047
oracle hard nproc 16384
oracle hard memlock 134217728
oracle soft memlock 134217728

grid soft nofile 1024
grid hard nofile 65536
grid soft stack 10240
grid hard stack 32768
grid soft nproc 2047
grid hard nproc 16384
#OracleEnd
EOF
    else
      cat <<EOF >>/etc/security/limits.conf
#OracleBegin
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
oracle hard stack 32768
oracle soft nproc 2047
oracle hard nproc 16384
oracle hard memlock 134217728
oracle soft memlock 134217728
#OracleEnd
EOF
    fi
  fi

  logwrite "/etc/security/limits.conf" "cat /etc/security/limits.conf | grep -v \"^\$\"|grep -v \"^#\""

  ##Configure pam.d
  if [ "$(grep -E -c "#OracleBegin" /etc/pam.d/login)" -eq 0 ]; then
    cat <<EOF >>/etc/pam.d/login
#OracleBegin
session required pam_limits.so 
session required /lib64/security/pam_limits.so
#OracleEnd
EOF
  fi

  logwrite "/etc/pam.d/login" "cat /etc/pam.d/login | grep -v \"^\$\"|grep -v \"^#\""

  ####################################################################################
  # Configure /dev/shm
  ####################################################################################
  if [ "$(grep -E -c "/dev/shm" /etc/fstab)" -eq 0 ]; then
    [ ! -f /etc/fstab."${DAYTIME}" ] && cp /etc/fstab /etc/fstab."${DAYTIME}"
    cat <<EOF >>/etc/fstab
tmpfs /dev/shm tmpfs size=${memTotal}k 0 0
EOF
    mount -o remount /dev/shm
  else
    if [ "$shmTotal" -lt "$memTotal" ]; then
      shmTotal=$memTotal
      [ ! -f /etc/fstab."${DAYTIME}" ] && cp /etc/fstab /etc/fstab."${DAYTIME}"
      line=$(grep -n "/dev/shm" /etc/fstab | awk -F ":" '{print $1}')
      sed -i "${line} d" /etc/fstab
      cat <<EOF >>/etc/fstab
tmpfs /dev/shm tmpfs size=${memTotal}k 0 0
EOF
      mount -o remount /dev/shm
    fi

  fi

  logwrite "/etc/fstab" "cat /etc/fstab | grep -v \"^\$\"|grep -v \"^#\""
  logwrite "shm" "df -Th /dev/shm"
  logwrite "df -hP" "df -hP"

  ####################################################################################
  # Edit bash_profile
  ####################################################################################
  ##ROOT:
  if [ "$OS_VER_PRI" -eq 6 ]; then
    root_profile=/root/.profile
  elif [ "$OS_VER_PRI" -eq 7 ] || [ "$OS_VER_PRI" -eq 8 ]; then
    root_profile=/root/.bash_profile
  fi
  if [ "$(grep -E -c "#OracleBegin" ${root_profile})" -eq 0 ]; then
    cat <<EOF >>${root_profile}
################OracleBegin#########################
alias so='su - oracle'
export PS1="[\`whoami\`@\`hostname\`:"'\$PWD]\$ '
EOF
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      cat <<EOF >>${root_profile}
alias crsctl='${ENV_GRID_HOME}/bin/crsctl'
alias sg='su - grid'
################OracleEnd###########################
EOF
    else
      cat <<EOF >>${root_profile}
################OracleEnd###########################
EOF
    fi
  fi
  logwrite "ROOT Profile" "cat ${root_profile} | grep -v \"^\$\"|grep -v \"^#\""

  ##ORALCE:
  if [ "$(grep -E -c "#OracleBegin" /home/oracle/.bash_profile)" -eq 0 ]; then
    cat <<EOF >>/home/oracle/.bash_profile
################OracleBegin#########################
umask 022
export TMP=/tmp
export TMPDIR=\$TMP
export NLS_LANG=AMERICAN_AMERICA.${CHARACTERSET} #AL32UTF8,ZHS16GBK
export ORACLE_BASE=${ENV_ORACLE_BASE}
export ORACLE_HOME=${ENV_ORACLE_HOME}
export ORACLE_HOSTNAME=${hostname}
export ORACLE_TERM=xterm
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export ORACLE_SID=${ORACLE_SIDTemp}
export PATH=/usr/sbin:\$PATH
export PATH=\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch:\$PATH
alias sas='sqlplus / as sysdba'
alias alert='tail -500f \$ORACLE_BASE/diag/rdbms/\$ORACLE_SID/\$ORACLE_SID/trace/alert_\$ORACLE_SID.log|more'
export PS1="[\`whoami\`@\`hostname\`:"'\$PWD]\$ '
EOF
    ##Users are strongly recommended to go with 19.9 DB RU (or later) to minimize the number of Patches to be installed.19.9 OJVM & OCW RU Patches are also recommended to be applied,during/after the Installation.
    if [ "${OS_VERSION}" = "linux8" ]; then
      cat <<EOF >>/home/oracle/.bash_profile
export CV_ASSUME_DISTID=OL7
EOF
    fi
    if rlwrap -v >/dev/null 2>&1; then
      cat <<EOF >>/home/oracle/.bash_profile
alias sqlplus='rlwrap sqlplus'
alias rman='rlwrap rman'
alias lsnrctl='rlwrap lsnrctl'
alias asmcmd='rlwrap asmcmd'
alias adrci='rlwrap adrci'
alias ggsci='rlwrap ggsci'
alias dgmgrl='rlwrap dgmgrl'
################OracleEnd###########################
EOF
    else
      cat <<EOF >>/home/oracle/.bash_profile
################OracleEnd###########################
EOF
    fi
  else
    ##if oraclesid oraclehome oraclebase is not the same of bash_profile , will update
    oracleSid=$(grep "ORACLE_SID=" /home/oracle/.bash_profile | awk '{print $2}')
    oracleHostname=$(grep "ORACLE_HOSTNAME=" /home/oracle/.bash_profile | awk '{print $2}')
    oracleHostname=${oracleHostname#*=}
    oracleBase=$(grep "ORACLE_BASE=" /home/oracle/.bash_profile | awk '{print $2}')
    oracleBase=${oracleBase#*=}
    oracleHome=$(grep "ORACLE_HOME=" /home/oracle/.bash_profile | awk '{print $2}')
    oracleHome=${oracleHome#*=}

    if [ "${oracleSid}" != "${ORACLE_SIDTemp}" ]; then
      sed -i "s/ORACLE_SID=${oracleSid}/ORACLE_SID=${ORACLE_SIDTemp}/" /home/oracle/.bash_profile
    fi
    if [ "${oracleHostname}" != "${hostname}" ]; then
      sed -i "s/ORACLE_HOSTNAME=${oracleHostname}/ORACLE_HOSTNAME=${hostname}/" /home/oracle/.bash_profile
    fi
    if [ "${oracleBase}" != "${ENV_ORACLE_BASE}" ]; then
      sed -i "s#ORACLE_BASE=${oracleBase}#ORACLE_BASE=${ENV_ORACLE_BASE}#" /home/oracle/.bash_profile
    fi
    if [ "${oracleHome}" != "${ENV_ORACLE_HOME}" ]; then
      sed -i "s#ORACLE_HOME=${oracleHome}#ORACLE_HOME=${ENV_ORACLE_HOME}#" /home/oracle/.bash_profile
    fi
  fi
  logwrite "Oracle Profile" "cat /home/oracle/.bash_profile | grep -v \"^\$\"|grep -v \"^#\""

  ##GRID:
  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    if [ "$(grep -E -c "#OracleBegin" /home/grid/.bash_profile)" -eq 0 ]; then
      cat <<EOF >>/home/grid/.bash_profile
################OracleBegin#########################
umask 022
export TMP=/tmp
export TMPDIR=\$TMP
export NLS_LANG=AMERICAN_AMERICA.${CHARACTERSET} #AL32UTF8,ZHS16GBK
export ORACLE_BASE=${ENV_GRID_BASE}
export ORACLE_HOME=${ENV_GRID_HOME}
export ORACLE_TERM=xterm
export TNS_ADMIN=\$ORACLE_HOME/network/admin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export ORACLE_SID=${GRID_SIDTemp}
export PATH=/usr/sbin:\$PATH
export PATH=\$ORACLE_HOME/bin:\$ORACLE_HOME/OPatch:\$PATH
alias sas='sqlplus / as sysasm'
export PS1="[\`whoami\`@\`hostname\`:"'\$PWD]\$ '
EOF

      if rlwrap -v >/dev/null 2>&1; then
        cat <<EOF >>/home/grid/.bash_profile
alias sqlplus='rlwrap sqlplus'
alias rman='rlwrap rman'
alias lsnrctl='rlwrap lsnrctl'
alias asmcmd='rlwrap asmcmd'
alias adrci='rlwrap adrci'
################OracleEnd###########################
EOF
      else
        cat <<EOF >>/home/grid/.bash_profile
################OracleEnd###########################
EOF
      fi
    fi
    logwrite "Grid Profile" "cat /home/grid/.bash_profile | grep -v \"^\$\"|grep -v \"^#\""
  fi
}

####################################################################################
# Install rlwrap
####################################################################################
InstallRlwrap() {
  if [ "$(find "${SOFTWAREDIR}" -maxdepth 1 -name 'rlwrap-*.gz' | wc -l)" -gt 0 ]; then
    if ! rlwrap -v >/dev/null 2>&1; then
      yum install -y tar
      mkdir "${SOFTWAREDIR}"/rlwrap
      tar -zxvf "${SOFTWAREDIR}"/rlwrap*tar.gz --strip-components 1 -C "${SOFTWAREDIR}"/rlwrap
      cd "${SOFTWAREDIR}"/rlwrap || return
      ./configure && make && make install
    fi
    logwrite "rlwrap" "rlwrap -v"
    if [ "$(find "${SOFTWAREDIR}" -mindepth 1 -name 'rlwrap*' | wc -l)" -gt 0 ]; then
      cd ~ || return
      rm -rf "${SOFTWAREDIR}/"rlwrap*
    fi
  fi

}

####################################################################################
#unzip Grid
####################################################################################
UnzipGridSoft() {
  ##remove ORACLE_HOME's files
  ##echo "${ORACLE_HOME}" | awk -F"/" '{if($NF=="") {print "rm -rf "$0"*"} else {print "rm -rf "$0"/*"}}' | bash
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    if [ -d "${SOFTWAREDIR}"/grid ]; then
      cd ~ || return
      rm -rf "${SOFTWAREDIR}"/grid
    fi
    if unzip -o "${SOFTWAREDIR}"/p13390677_112040_Linux-x86-64_3of7.zip -d "${SOFTWAREDIR}"; then
      rm -rf "${SOFTWAREDIR}"/p13390677_112040_Linux-x86-64_3of7.zip
      chown -R grid:oinstall "${SOFTWAREDIR}"/grid
    else
      c1 "Make sure the grid installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "p13390677_112040_Linux-x86-64_3of7.zip" blue
      exit 99
    fi
  elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
    if [ -f "${ENV_GRID_HOME}" ]; then
      if [ "$(find "${ENV_GRID_HOME}" -mindepth 1 | wc -l)" -gt 0 ]; then
        cd ~ || return
        rm -rf "${ENV_GRID_HOME}"
        rm -rf "${ENV_GRID_HOME}/".*
      fi
    fi
    if unzip -o "${SOFTWAREDIR}"/LINUX.X64_122010_grid_home.zip -d "${ENV_GRID_HOME}"; then
      rm -rf "${SOFTWAREDIR}"/LINUX.X64_122010_grid_home.zip
      chown -R grid:oinstall "${ENV_GRID_HOME}"
    else
      c1 "Make sure the grid installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "LINUX.X64_122010_grid_home.zip" blue
      exit 99
    fi
  elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
    if [ -f "${ENV_GRID_HOME}" ]; then
      if [ "$(find "${ENV_GRID_HOME}" -mindepth 1 | wc -l)" -gt 0 ]; then
        cd ~ || return
        rm -rf "${ENV_GRID_HOME}"
        rm -rf "${ENV_GRID_HOME}/".*
      fi
    fi
    if unzip -o "${SOFTWAREDIR}"/LINUX.X64_180000_grid_home.zip -d "${ENV_GRID_HOME}"; then
      rm -rf "${SOFTWAREDIR}"/LINUX.X64_180000_grid_home.zip
      chown -R grid:oinstall "${ENV_GRID_HOME}"
    else
      c1 "Make sure the grid installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "LINUX.X64_180000_grid_home.zip" blue
      exit 99
    fi
  elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
    if [ -f "${ENV_GRID_HOME}" ]; then
      if [ "$(find "${ENV_GRID_HOME}" -mindepth 1 | wc -l)" -gt 0 ]; then
        cd ~ || return
        rm -rf "${ENV_GRID_HOME}"
        rm -rf "${ENV_GRID_HOME}/".*
      fi
    fi
    if unzip -o "${SOFTWAREDIR}"/LINUX.X64_193000_grid_home.zip -d "${ENV_GRID_HOME}"; then
      rm -rf "${SOFTWAREDIR}"/LINUX.X64_193000_grid_home.zip
      chown -R grid:oinstall "${ENV_GRID_HOME}"
    else
      c1 "Make sure the grid installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "LINUX.X64_193000_grid_home.zip" blue
      exit 99
    fi
  else
    c1 "Error grid version! please check again!" red
    exit
  fi
  ## Install cvuqdisk
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    if [ "$(rpm -qa | grep -c cvuqdisk)" -eq 0 ]; then
      if [ -f "${SOFTWAREDIR}"/grid/rpm/cvuqdisk-1.0.9-1.rpm ]; then
        rpm -ivh "${SOFTWAREDIR}"/grid/rpm/cvuqdisk-1.0.9-1.rpm
        if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
          scp "${SOFTWAREDIR}"/grid/rpm/cvuqdisk-1.0.9-1.rpm "$RAC2HOSTNAME":"${SOFTWAREDIR}"
          ssh "$RAC2HOSTNAME" rpm -ivh "${SOFTWAREDIR}"/cvuqdisk-1.0.9-1.rpm
          ssh "$RAC2HOSTNAME" rm -rf "${SOFTWAREDIR}"/cvuqdisk-1.0.9-1.rpm
        fi
      else
        c1 "Make sure the cvuqdisk installation package is in the ${SOFTWAREDIR}/grid/rpm directory:" red
        c1 "cvuqdisk-1.0.9-1.rpm" blue
        exit 99
      fi
    fi

  elif [ "${DB_VERSION}" = "12.2.0.1" ] || [ "${DB_VERSION}" = "18.0.0.0" ] || [ "${DB_VERSION}" = "19.3.0.0" ]; then
    if [ "$(rpm -qa | grep -c cvuqdisk)" -eq 0 ]; then
      if [ -f "${ENV_GRID_HOME}"/cv/rpm/cvuqdisk-1.0.10-1.rpm ]; then
        rpm -ivh "${ENV_GRID_HOME}"/cv/rpm/cvuqdisk-1.0.10-1.rpm
        if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
          scp "${ENV_GRID_HOME}"/cv/rpm/cvuqdisk-1.0.10-1.rpm "$RAC2HOSTNAME":"${SOFTWAREDIR}"
          ssh "$RAC2HOSTNAME" rpm -ivh "${SOFTWAREDIR}"/cvuqdisk-1.0.10-1.rpm
          ssh "$RAC2HOSTNAME" rm -rf "${SOFTWAREDIR}"/cvuqdisk-1.0.10-1.rpm
        fi
      else
        c1 "Make sure the cvuqdisk installation package is in the ${ENV_GRID_HOME}/cv/rpm directory:" red
        c1 "cvuqdisk-1.0.10-1.rpm" blue
        exit 99
      fi
    fi
  else
    c1 "Error database version! please check again!" red
    exit
  fi
}

####################################################################################
# runcluvfy.sh
####################################################################################
Runcluvfy() {
  # if [[ "${DB_VERSION}" = "11.2.0.4" ]]; then
  #     cvufix=CVU_11.2.0.4.0_grid
  # elif [[ "${DB_VERSION}" = "12.2.0.1" ]]; then
  #     cvufix=CVU_12.2.0.1.0_grid
  # elif [[ "${DB_VERSION}" = "18.0.0.0" ]]; then
  #     cvufix=CVU_18.0.0.0.0_grid
  # elif [[ "${DB_VERSION}" = "19.3.0.0" ]]; then
  #     cvufix=CVU_19.0.0.0.0_grid
  # fi

  if [[ "${DB_VERSION}" == "11.2.0.4" ]]; then
    if [ -f "${SOFTWAREDIR}"/grid/runcluvfy.sh ]; then
      su - grid -c "${SOFTWAREDIR}/grid/runcluvfy.sh stage -pre crsinst -n $RAC1HOSTNAME,$RAC2HOSTNAME -fixup -verbose" | tee "${SOFTWAREDIR}"/runcluvfy.out
      # /tmp/$cvufix/runfixup.sh
      # ssh "$RAC2HOSTNAME" /tmp/$cvufix/runfixup.sh
    fi
  elif [[ "${DB_VERSION}" == "12.2.0.1" ]] || [[ "${DB_VERSION}" == "18.0.0.0" ]]; then
    if [ -f "${ENV_GRID_HOME}"/runcluvfy.sh ]; then
      # /tmp/$cvufix/runfixup.sh
      # if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      #     ssh "$RAC2HOSTNAME" /tmp/$cvufix/runfixup.sh
      # fi
      EXPECT=/usr/bin/expect
      USER_PROMPT="*# "
      $EXPECT <<EOF
      su - grid -c "${ENV_GRID_HOME}/runcluvfy.sh stage -pre crsinst -n $RAC1HOSTNAME,$RAC2HOSTNAME -fixup -verbose  -method root" | tee "${SOFTWAREDIR}"/runcluvfy.out
      expect "*password*" {
        send -- "$ROOTPASSWD\r"
    } "*?assword:*" {send -- "$ROOTPASSWD\r"}
expect "$USER_PROMPT"
EOF
    fi
  elif [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
    if [ -f "${ENV_GRID_HOME}"/runcluvfy.sh ]; then
      ##PRVG-11250 : The check "RPM Package Manager database" was not performed because
      ##Cluvfy Fail with PRVG-11250 The Check “RPM Package Manager Database” Was Not Performed (Doc ID 2548970.1)
      ##su - grid -c "${ENV_GRID_HOME}/runcluvfy.sh stage -pre crsinst -n $RAC1HOSTNAME,$RAC2HOSTNAME -fixup -verbose -method root" | tee "${SOFTWAREDIR}"/runcluvfy.out
      # /tmp/$cvufix/runfixup.sh
      # if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      #     ssh "$RAC2HOSTNAME" /tmp/$cvufix/runfixup.sh
      # fi
      EXPECT=/usr/bin/expect
      USER_PROMPT="*# "
      $EXPECT <<EOF
spawn su - grid -c "${ENV_GRID_HOME}/runcluvfy.sh stage -pre crsinst -n $RAC1HOSTNAME,$RAC2HOSTNAME -fixup -verbose -method root" | tee "${SOFTWAREDIR}"/runcluvfy.out
expect "*password*" {
        send -- "$ROOTPASSWD\r"
    } "*?assword:*" {send -- "$ROOTPASSWD\r"}
expect "$USER_PROMPT"
EOF

    fi

  fi

}

####################################################################################
# Install Grid Software
####################################################################################
InstallGridsoftware() {

  ####################################################################################
  # Unzip grid OPATCH&&RU
  ####################################################################################
  if [ -n "${GPATCH}" ]; then
    if [ "${DB_VERSION}" = "12.2.0.1" ]; then
      if ! su - grid -c "unzip -o ${SOFTWAREDIR}/p6880880_122010_Linux-x86-64.zip -d ${ENV_GRID_HOME}"; then
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_122010_Linux-x86-64.zip" blue
        exit 92
      fi
    elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
      if ! su - grid -c "unzip -o ${SOFTWAREDIR}/p6880880_180000_Linux-x86-64.zip -d ${ENV_GRID_HOME}"; then
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_180000_Linux-x86-64.zip" blue
        exit 92
      fi
    elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
      if ! su - grid -c "unzip -o ${SOFTWAREDIR}/p6880880_190000_Linux-x86-64.zip -d ${ENV_GRID_HOME}"; then
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_190000_Linux-x86-64.zip" blue
        exit 92
      fi
    fi

    if [ ! -d "${SOFTWAREDIR}/""${GPATCH}" ]; then
      chown -R grid:oinstall "${SOFTWAREDIR}"
      if su - grid -c "unzip -o ${SOFTWAREDIR}/*p${GPATCH}* -d ${SOFTWAREDIR}"; then
        rm -rf "${SOFTWAREDIR}"/*p"${GPATCH}"*
      else
        c1 "Make sure the grid release update ${GPATCH} is in the ${SOFTWAREDIR} directory:" red
        c1 "p${GPATCH}.......zip" blue
        exit 99
      fi
    fi

    ## RAC scp OPatch and Patches to node2
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      if [[ "${DB_VERSION}" == "11.2.0.4" ]] || [[ "${DB_VERSION}" == "12.2.0.1" ]]; then
        ##scp Patches
        scp -r "${SOFTWAREDIR}/""${GPATCH}" "${RAC2HOSTNAME}":"${SOFTWAREDIR}"
        ssh "${RAC2HOSTNAME}" chown -R grid:oinstall "${SOFTWAREDIR}/""${GPATCH}"
      fi
    fi

  fi

  #Create grid.rsp
  if [ -f "${SOFTWAREDIR}"/grid.rsp ]; then
    rm -rf "${SOFTWAREDIR}"/grid.rsp
  fi
  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
    if [ ${DB_VERSION} = 11.2.0.4 ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v11_2_0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
SELECTED_LANGUAGES=en
oracle.install.option=CRS_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
ORACLE_HOME=${ENV_GRID_HOME}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.gpnp.scanName=${RACSCANNAME}
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.clusterName=${CLUSTERNAME}
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.storageOption=ASM_STORAGE
oracle.install.crs.config.sharedFileSystemStorage.diskDriveMapping=
oracle.install.crs.config.sharedFileSystemStorage.votingDiskLocations=
oracle.install.crs.config.sharedFileSystemStorage.votingDiskRedundancy=NORMAL
oracle.install.crs.config.sharedFileSystemStorage.ocrLocations=
oracle.install.crs.config.sharedFileSystemStorage.ocrRedundancy=NORMAL
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMOCRNAME}
oracle.install.asm.diskGroup.redundancy=${OCRREDUN}
oracle.install.asm.diskGroup.AUSize=1
oracle.install.asm.diskGroup.disks=${OCRDISK}
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.crs.upgrade.clusterNodes=
oracle.install.asm.upgradeASM=false
oracle.installer.autoupdates.option=SKIP_UPDATES
oracle.installer.autoupdates.downloadUpdatesLoc=
AUTOUPDATES_MYORACLESUPPORT_USERNAME=
AUTOUPDATES_MYORACLESUPPORT_PASSWORD=
PROXY_HOST=
PROXY_PORT=0
PROXY_USER=
PROXY_PWD=
PROXY_REALM=
EOF
      if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
ORACLE_HOSTNAME=${hostname}.${DNSNAME}
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}.${DNSNAME}:${RAC1HOSTNAME}-vip.${DNSNAME},${RAC2HOSTNAME}.${DNSNAME}:${RAC2HOSTNAME}-vip.${DNSNAME}
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
ORACLE_HOSTNAME=${hostname}
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}:${RAC1HOSTNAME}-vip,${RAC2HOSTNAME}:${RAC2HOSTNAME}-vip
EOF
      fi
      if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:2,$RACPRIVFCNAME1:${RAC1PRIVIP1%.*}.0:2
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:2
EOF
      fi
    elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
      cat <<EOF >"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v12.2.0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
oracle.install.option=CRS_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.gpnp.scanName=${RACSCANNAME}
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=${CLUSTERNAME}
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=
oracle.install.crs.config.gpnp.gnsClientDataFile=
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.sites=
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.storageOption=               
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.storageOption=ASM
oracle.install.asmOnNAS.ocrLocation=
oracle.install.asmOnNAS.configureGIMRDataDG=false
oracle.install.asmOnNAS.gimrLocation=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMOCRNAME}
oracle.install.asm.diskGroup.redundancy=${OCRREDUN}
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=
oracle.install.asm.diskGroup.disksWithFailureGroupNames=${OCRFailureDISK}
oracle.install.asm.diskGroup.disks=${OCRDISK}
oracle.install.asm.diskGroup.quorumFailureGroupNames=
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.asm.gimrDG.name=
oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=true
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false               
oracle.install.config.managementOption=NONE
oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=
oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
EOF
      if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}.${DNSNAME}:${RAC1HOSTNAME}-vip.${DNSNAME}:HUB,${RAC2HOSTNAME}.${DNSNAME}:${RAC2HOSTNAME}-vip.${DNSNAME}:HUB
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}:${RAC1HOSTNAME}-vip:HUB,${RAC2HOSTNAME}:${RAC2HOSTNAME}-vip:HUB
EOF
      fi
      if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:5,$RACPRIVFCNAME1:${RAC1PRIVIP1%.*}.0:5
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:5
EOF
      fi
    elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
      cat <<EOF >"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v18.0.0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
oracle.install.option=CRS_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.SCANClientDataFile=
oracle.install.crs.config.gpnp.scanName=${RACSCANNAME}
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=${CLUSTERNAME}
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=
oracle.install.crs.config.gpnp.gnsClientDataFile=
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.sites=
oracle.install.crs.configureGIMR=false
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.storageOption=               	
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.storageOption=ASM
oracle.install.asmOnNAS.ocrLocation=
oracle.install.asmOnNAS.configureGIMRDataDG=false
oracle.install.asmOnNAS.gimrLocation=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMOCRNAME}
oracle.install.asm.diskGroup.redundancy=${OCRREDUN}
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=
oracle.install.asm.diskGroup.disksWithFailureGroupNames=${OCRFailureDISK}
oracle.install.asm.diskGroup.disks=${OCRDISK}
oracle.install.asm.diskGroup.quorumFailureGroupNames=
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.asm.gimrDG.name=
oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false               	
oracle.install.config.managementOption=NONE
oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=
oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
oracle.install.crs.deleteNode.nodes=
EOF
      if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}.${DNSNAME}:${RAC1HOSTNAME}-vip.${DNSNAME}:HUB,${RAC2HOSTNAME}.${DNSNAME}:${RAC2HOSTNAME}-vip.${DNSNAME}:HUB
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}:${RAC1HOSTNAME}-vip:HUB,${RAC2HOSTNAME}:${RAC2HOSTNAME}-vip:HUB
EOF
      fi
      if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:5,$RACPRIVFCNAME1:${RAC1PRIVIP1%.*}.0:5
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:5
EOF
      fi
    elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
      cat <<EOF >"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
oracle.install.option=CRS_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.SCANClientDataFile=
oracle.install.crs.config.gpnp.scanName=${RACSCANNAME}
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=${CLUSTERNAME}
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=
oracle.install.crs.config.gpnp.gnsClientDataFile=
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.sites=
oracle.install.crs.configureGIMR=false
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.storageOption=CLIENT_ASM_STORAGE
oracle.install.crs.config.sharedFileSystemStorage.votingDiskLocations=
oracle.install.crs.config.sharedFileSystemStorage.ocrLocations=               	
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMOCRNAME}
oracle.install.asm.diskGroup.redundancy=${OCRREDUN}
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=
oracle.install.asm.diskGroup.disksWithFailureGroupNames=${OCRFailureDISK}
oracle.install.asm.diskGroup.disks=${OCRDISK}
oracle.install.asm.diskGroup.quorumFailureGroupNames=
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.asm.gimrDG.name=
oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false               	
oracle.install.config.managementOption=NONE
oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=
oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
oracle.install.crs.deleteNode.nodes=
EOF
      if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}.${DNSNAME}:${RAC1HOSTNAME}-vip.${DNSNAME},${RAC2HOSTNAME}.${DNSNAME}:${RAC2HOSTNAME}-vip.${DNSNAME}
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.clusterNodes=${RAC1HOSTNAME}:${RAC1HOSTNAME}-vip,${RAC2HOSTNAME}:${RAC2HOSTNAME}-vip
EOF
      fi
      if [ -n "${RAC1PRIVIP1}" ] && [ -n "${RAC2PRIVIP1}" ] && [ -n "${RACPRIVFCNAME1}" ]; then
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:5,$RACPRIVFCNAME1:${RAC1PRIVIP1%.*}.0:5
EOF
      else
        cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.crs.config.networkInterfaceList=$RACPUBLICFCNAME:${RAC1PUBLICIP%.*}.0:1,$RACPRIVFCNAME:${RAC1PRIVIP%.*}.0:5
EOF
      fi
    fi
  elif [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    if [ ${DB_VERSION} = 11.2.0.4 ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v11_2_0
ORACLE_HOSTNAME=${hostname}
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
SELECTED_LANGUAGES=en
oracle.install.option=HA_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
ORACLE_HOME=${ENV_GRID_HOME}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.gpnp.scanName=
oracle.install.crs.config.gpnp.scanPort=
oracle.install.crs.config.clusterName=
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.clusterNodes=
oracle.install.crs.config.networkInterfaceList=
oracle.install.crs.config.storageOption=
oracle.install.crs.config.sharedFileSystemStorage.diskDriveMapping=
oracle.install.crs.config.sharedFileSystemStorage.votingDiskLocations=
oracle.install.crs.config.sharedFileSystemStorage.votingDiskRedundancy=NORMAL
oracle.install.crs.config.sharedFileSystemStorage.ocrLocations=
oracle.install.crs.config.sharedFileSystemStorage.ocrRedundancy=NORMAL
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMDATANAME}
oracle.install.asm.diskGroup.redundancy=${DATAREDUN}
oracle.install.asm.diskGroup.AUSize=1
oracle.install.asm.diskGroup.disks=${DATADISK}
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.crs.upgrade.clusterNodes=
oracle.install.asm.upgradeASM=false
oracle.installer.autoupdates.option=SKIP_UPDATES
oracle.installer.autoupdates.downloadUpdatesLoc=
AUTOUPDATES_MYORACLESUPPORT_USERNAME=
AUTOUPDATES_MYORACLESUPPORT_PASSWORD=
PROXY_HOST=
PROXY_PORT=0
PROXY_USER=
PROXY_PWD=
PROXY_REALM=
EOF
    elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v12.2.0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
oracle.install.option=HA_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.gpnp.scanName=
oracle.install.crs.config.gpnp.scanPort=
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=CREATE_NEW_GNS
oracle.install.crs.config.gpnp.gnsClientDataFile=
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.sites=
oracle.install.crs.config.clusterNodes=
oracle.install.crs.config.networkInterfaceList=
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.storageOption=               	
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.storageOption=ASM
oracle.install.asmOnNAS.ocrLocation=
oracle.install.asmOnNAS.configureGIMRDataDG=false
oracle.install.asmOnNAS.gimrLocation=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMDATANAME}
oracle.install.asm.diskGroup.redundancy=${DATAREDUN}
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=
oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DATAFailureDISK}
oracle.install.asm.diskGroup.disks=${DATADISK}
oracle.install.asm.diskGroup.quorumFailureGroupNames=
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.asm.gimrDG.name=
oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false               	
oracle.install.config.managementOption=NONE
oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=
oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
EOF
    elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v18.0.0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
oracle.install.option=HA_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.SCANClientDataFile=
oracle.install.crs.config.gpnp.scanName=
oracle.install.crs.config.gpnp.scanPort=
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=CREATE_NEW_GNS
oracle.install.crs.config.gpnp.gnsClientDataFile=
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.sites=
oracle.install.crs.config.clusterNodes=
oracle.install.crs.config.networkInterfaceList=
oracle.install.crs.configureGIMR=true
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.storageOption=               	
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.storageOption=ASM
oracle.install.asmOnNAS.ocrLocation=
oracle.install.asmOnNAS.configureGIMRDataDG=false
oracle.install.asmOnNAS.gimrLocation=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMDATANAME}
oracle.install.asm.diskGroup.redundancy=${DATAREDUN}
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=
oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DATAFailureDISK}
oracle.install.asm.diskGroup.disks=${DATADISK}
oracle.install.asm.diskGroup.quorumFailureGroupNames=
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.asm.gimrDG.name=
oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false               	
oracle.install.config.managementOption=NONE
oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=
oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
oracle.install.crs.deleteNode.nodes=
EOF
    elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/grid.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
oracle.install.option=HA_CONFIG
ORACLE_BASE=${ENV_GRID_BASE}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.SCANClientDataFile=
oracle.install.crs.config.gpnp.scanName=
oracle.install.crs.config.gpnp.scanPort=
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=CREATE_NEW_GNS
oracle.install.crs.config.gpnp.gnsClientDataFile=
oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=
oracle.install.crs.config.sites=
oracle.install.crs.config.clusterNodes=
oracle.install.crs.config.networkInterfaceList=
oracle.install.crs.configureGIMR=false
oracle.install.asm.configureGIMRDataDG=false
oracle.install.crs.config.storageOption=
oracle.install.crs.config.sharedFileSystemStorage.votingDiskLocations=
oracle.install.crs.config.sharedFileSystemStorage.ocrLocations=               	
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=
oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
oracle.install.asm.diskGroup.name=${ASMDATANAME}
oracle.install.asm.diskGroup.redundancy=${DATAREDUN}
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=
oracle.install.asm.diskGroup.disksWithFailureGroupNames=${DATAFailureDISK}
oracle.install.asm.diskGroup.disks=${DATADISK}
oracle.install.asm.diskGroup.quorumFailureGroupNames=
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm*
oracle.install.asm.monitorPassword=${GRIDPASSWD}
oracle.install.asm.gimrDG.name=
oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false               	
oracle.install.config.managementOption=NONE
oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=
oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
oracle.install.crs.deleteNode.nodes=
EOF
    fi
  fi

  logwrite "${SOFTWAREDIR}/grid.rsp" "cat ${SOFTWAREDIR}/grid.rsp"

  #Install Database software
  chown grid:oinstall "${SOFTWAREDIR}"

  if [[ "${DB_VERSION}" == "11.2.0.4" ]]; then
    if ! su - grid -c "${SOFTWAREDIR}/grid/runInstaller -silent -showProgress -ignoreSysPrereqs -ignorePrereq -waitForCompletion -responseFile ${SOFTWAREDIR}/grid.rsp"; then
      c1 "Sorry, Grid Install Failed." red
      exit 99
    fi
  elif [[ "${DB_VERSION}" == "12.2.0.1" ]] || [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
    if [ -n "${GPATCH}" ]; then
      if [[ "${DB_VERSION}" == "12.2.0.1" ]]; then
        if ! su - grid -c "${ENV_GRID_HOME}/gridSetup.sh -silent -force -responseFile ${SOFTWAREDIR}/grid.rsp -ignorePrereqFailure -waitForCompletion -skipPrereqs -applyPSU ${SOFTWAREDIR}/${GPATCH}"; then
          c1 "Sorry, Grid Install Failed." red
          exit 99
        fi
      elif [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
        if ! su - grid -c "${ENV_GRID_HOME}/gridSetup.sh -silent -force -responseFile ${SOFTWAREDIR}/grid.rsp -waitForCompletion -skipPrereqs -applyRU ${SOFTWAREDIR}/${GPATCH}"; then
          c1 "Sorry, Grid Install Failed." red
          exit 99
        fi
      fi
    else
      if ! su - grid -c "${ENV_GRID_HOME}/gridSetup.sh -silent -force -responseFile ${SOFTWAREDIR}/grid.rsp -waitForCompletion -skipPrereqs"; then
        c1 "Sorry, Grid Install Failed." red
        exit 99
      fi
    fi
  fi

  logwrite "Grid OPatch Version" "su - grid -c \"opatch version\""

  ## Oracle Grid/RAC 11.2.0.4 on Oracle Linux 7
  ## Oracle High Availability Service has timed out waiting for init.ohasd to be started.
  #     if [ "${DB_VERSION}" = "11.2.0.4" ] && [ "${OS_VERSION}" = "linux7" ]; then
  #         #create script ohas.service
  #         if [ ! -d /usr/lib/systemd/system ]; then
  #             mkdir -p /usr/lib/systemd/system
  #         fi
  #         cat <<EOF >/usr/lib/systemd/system/ohas.service
  # [Unit]
  # Description=Oracle High Availability Services
  # After=syslog.target
  # [Service]
  # ExecStart=/etc/init.d/init.ohasd run >/dev/null 2>&1 Type=simple
  # Restart=always
  # [Install]
  # WantedBy=multi-user.target
  # EOF

  #         ##edit scripts start_ohas.sh
  #         cat <<EOF >"${SOFTWAREDIR}"/start_ohas.sh
  # #/bin/bash
  # while true; do
  # if [ -f /etc/init.d/init.ohasd ]; then
  # systemctl start ohas.service
  # systemctl status ohas.service
  # break
  # fi
  # done
  # EOF
  #         chmod +x "${SOFTWAREDIR}"/start_ohas.sh
  #         #start service
  #         systemctl daemon-reload
  #         systemctl enable ohas.service

  #         ##RAC scp  to  node 2
  #         if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
  #             ssh "$RAC2HOSTNAME" "mkdir -p /usr/lib/systemd/system"
  #             scp /usr/lib/systemd/system/ohas.service "$RAC2HOSTNAME":/usr/lib/systemd/system
  #             scp "${SOFTWAREDIR}"/start_ohas.sh "$RAC2HOSTNAME":"${SOFTWAREDIR}"
  #             ssh "$RAC2HOSTNAME" "chmod +x ""${SOFTWAREDIR}""/start_ohas.sh"
  #             ssh "$RAC2HOSTNAME" "systemctl daemon-reload"
  #             ssh "$RAC2HOSTNAME" "systemctl enable ohas.service"
  #         fi
  #     fi

  ##Patch 18370031
  if [ "${DB_VERSION}" = "11.2.0.4" ] && [ "${OS_VERSION}" = "linux7" ]; then
    chown -R grid:oinstall "${SOFTWAREDIR}"/p18370031_112040_Linux-x86-64.zip
    if ! su - grid -c "unzip -o ${SOFTWAREDIR}/p18370031_112040_Linux-x86-64.zip -d ${SOFTWAREDIR}"; then
      c1 "Make sure the Patch 18370031 is in the ${SOFTWAREDIR} directory:" red
      c1 "p18370031_112040_Linux-x86-64.zip" blue
      exit 92
    else
      su - grid -c "${ENV_GRID_HOME}/OPatch/opatch napply -oh ${ENV_GRID_HOME} -local ${SOFTWAREDIR}/18370031 -silent"
      ##RAC scp  to  node 2
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        scp -r "${SOFTWAREDIR}"/18370031 "$RAC2HOSTNAME":"${SOFTWAREDIR}"
        ssh "$RAC2HOSTNAME" chown -R grid:oinstall "${SOFTWAREDIR}"/18370031
        su - grid -c "ssh ${RAC2HOSTNAME} ${ENV_GRID_HOME}/OPatch/opatch napply -oh ${ENV_GRID_HOME} -local ${SOFTWAREDIR}/18370031 -silent"
      fi
    fi
  fi

  #CLSRSC-614: failed to get the list of configured diskgroups
  #Died at /u01/app/12.2.0/grid/crs/install/oraasm.pm line 2069
  # The command '/u01/app/12.2.0/grid/perl/bin/perl -I/u01/app/12.2.0/grid/perl/lib -I/u01/app/12.2.0/grid/crs/install /u01/app/12.2.0/grid/crs/install/rootcrs.pl ' execution failed
  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
    if [ "${DB_VERSION}" = "12.2.0.1" ]; then
      /usr/bin/make -f "${ENV_GRID_HOME}"/rdbms/lib/ins_rdbms.mk client_sharedlib libasmclntsh12.ohso libasmperl12.ohso ORACLE_HOME="${ENV_GRID_HOME}"
      ssh "$RAC2HOSTNAME" /usr/bin/make -f "${ENV_GRID_HOME}"/rdbms/lib/ins_rdbms.mk client_sharedlib libasmclntsh12.ohso libasmperl12.ohso ORACLE_HOME="${ENV_GRID_HOME}"
    fi

    if [ "${DB_VERSION}" = "18.0.0.0" ]; then
      /usr/bin/make -f "${ENV_GRID_HOME}"/rdbms/lib/ins_rdbms.mk client_sharedlib libasmclntsh18.ohso libasmperl18.ohso ORACLE_HOME="${ENV_GRID_HOME}"
      ssh "$RAC2HOSTNAME" /usr/bin/make -f "${ENV_GRID_HOME}"/rdbms/lib/ins_rdbms.mk client_sharedlib libasmclntsh18.ohso libasmperl18.ohso ORACLE_HOME="${ENV_GRID_HOME}"
    fi
  fi

  if [ -f "${ENV_ORACLE_INVEN}"/orainstRoot.sh ] || [ -f "${ENV_GRID_HOME}"/root.sh ]; then
    if [ -f "${ENV_ORACLE_INVEN}"/orainstRoot.sh ]; then
      "${ENV_ORACLE_INVEN}"/orainstRoot.sh
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ssh "$RAC2HOSTNAME" "$ENV_ORACLE_INVEN"/orainstRoot.sh
      fi
    fi
    if [ -f "${ENV_GRID_HOME}"/root.sh ]; then
      # if [ "${DB_VERSION}" = "11.2.0.4" ] && [ "${OS_VERSION}" = "linux7" ]; then
      #     # "${SOFTWAREDIR}"/start_ohas.sh &
      #     "${ENV_GRID_HOME}"/root.sh
      #     if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      #         ssh "$RAC2HOSTNAME" nohup "${SOFTWAREDIR}"/start_ohas.sh >/dev/null 2>&1 &
      #         ssh "$RAC2HOSTNAME" "$ENV_GRID_HOME"/root.sh
      #     fi
      # else
      "${ENV_GRID_HOME}"/root.sh
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ssh "$RAC2HOSTNAME" "$ENV_GRID_HOME"/root.sh
      fi
      # fi
    fi
  else
    echo
    c1 "Grid software installation failed, please check the log." red
    exit 99
  fi

  ## Complete Grid Infrastructure Configuration Assistant(Plug-in) if OUI is not Available (Doc ID 1360798.1)
  if [ -f /home/grid/cfgrsp.propertiesc ]; then
    rm -rf /home/grid/cfgrsp.propertiesc
  fi
  if [ ! -f /home/grid/cfgrsp.propertiesc ]; then
    if [[ "${DB_VERSION}" == "11.2.0.4" ]]; then
      cat <<EOF >>/home/grid/cfgrsp.properties

      #         elif [ "${DB_VERSION}" = "18.0.0.0" ] || [ "${DB_VERSION}" = "19.3.0.0" ]; then
      #             cat <<EOF >>/home/grid/cfgrsp.rsp
      # oracle.install.asm.SYSASMPassword=${GRIDPASSWD}
      # oracle.install.asm.monitorPassword=${GRIDPASSWD}
      # EOF
oracle.assistants.asm|S_ASMPASSWORD=${GRIDPASSWD}
oracle.assistants.asm|S_ASMMONITORPASSWORD=${GRIDPASSWD}
EOF

    fi

  fi

  if [[ "${DB_VERSION}" == "11.2.0.4" ]]; then
    if su - grid -c "$ENV_GRID_HOME/cfgtoollogs/configToolAllCommands RESPONSE_FILE=/home/grid/cfgrsp.properties"; then
      rm -rf /home/grid/cfgrsp.properties
    fi
    ## How to Use ASMCA in Silent Mode to Configure ASM For a Stand-Alone Server (Doc ID 1068788.1)
    if [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      if [ "$(pgrep -f "asm_smon_+ASM" | wc -l)" -eq 0 ]; then
        su - grid -c "$ENV_GRID_HOME/bin/asmca -silent -sysAsmPassword ${GRIDPASSWD} -asmsnmpPassword ${GRIDPASSWD} -oui_internal -configureASM -diskString '/dev/asm*' -diskGroupName ${ASMDATANAME} -diskList ${DATADISK} -redundancy ${DATAREDUN} -au_size 1"
      fi
    fi
  else
    ## 12.2:Post upgrade steps for Grid infrastructure reports INS-32601 error (Doc ID 2380863.1)
    su - grid -c "$ENV_GRID_HOME/gridSetup.sh -executeConfigTools -all -responseFile ${SOFTWAREDIR}/grid.rsp -silent"
  fi

  ## 11G grid software install successful , then patch PSU
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    if [ -n "${GPATCH}" ]; then
      if ! su - grid -c "unzip -o ${SOFTWAREDIR}/p6880880_112000_Linux-x86-64.zip -d ${ENV_GRID_HOME}"; then
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_112000_Linux-x86-64.zip" blue
        exit 92
      fi

      ## scp OPatch
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        scp -r "${ENV_GRID_HOME}"/OPatch "${RAC2HOSTNAME}":"${ENV_GRID_HOME}"
        ssh "${RAC2HOSTNAME}" chown -R grid:oinstall "${ENV_GRID_HOME}"/OPatch
      fi
      ##bug with linux7 install 11g rac and PSU,but without apply opatch to fix
      #             if [ "${OS_VERSION}" = "linux7" ]; then
      #                 ##edit scripts opatch restart_ohas.sh
      #                 cat <<EOF >"${SOFTWAREDIR}"/opatch_restart_ohas.sh
      # #/bin/bash
      # ${ENV_GRID_HOME}/OPatch/opatch auto ${SOFTWAREDIR}/${GPATCH} -oh ${ENV_GRID_HOME} | tee ${SOFTWAREDIR}/opatchauto-${GPATCH}.log
      # while true; do
      # if [ \$(grep -c "CRS-4124" <${SOFTWAREDIR}/opatchauto-${GPATCH}.log) -gt 0 ] || [ \$(grep -c "CRS-4000" <${SOFTWAREDIR}/opatchauto-${GPATCH}.log) -gt 0 ]; then
      # systemctl restart ohas.service
      # ${ENV_GRID_HOME}/bin/crsctl start crs
      # break
      # elif [ \$(grep -c "CRS-4123" <${SOFTWAREDIR}/opatchauto-${GPATCH}.log) -gt 0 ]; then
      # break
      # fi
      # done
      # EOF
      #                 chmod +x "${SOFTWAREDIR}"/opatch_restart_ohas.sh
      ## node1
      # sh "${SOFTWAREDIR}"/opatch_restart_ohas.sh
      #     if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      #         ## node2
      #         scp "${SOFTWAREDIR}"/opatch_restart_ohas.sh "$RAC2HOSTNAME":"${SOFTWAREDIR}"
      #         ssh "$RAC2HOSTNAME" "chmod +x ""${SOFTWAREDIR}""/opatch_restart_ohas.sh"
      #         ssh "$RAC2HOSTNAME" "sh ${SOFTWAREDIR}/opatch_restart_ohas.sh"
      #     fi
      # else
      ## node1
      "${ENV_GRID_HOME}"/OPatch/opatch auto "${SOFTWAREDIR}/""${GPATCH}" -oh "${ENV_GRID_HOME}"
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ## node2
        ssh "$RAC2HOSTNAME" "${ENV_GRID_HOME}"/OPatch/opatch auto "${SOFTWAREDIR}/""${GPATCH}" -oh "${ENV_GRID_HOME}"
      fi
      #         fi
    fi
  fi
  logwrite "Grid RDBMS" "su - grid -c \"sqlplus -V\""
  logwrite "Grid Status" "su - grid -c \"crsctl stat res -t\""
  logwrite "OPatch lspatches" "su - grid -c \"opatch lspatches\""

}

####################################################################################
# ASM CREATE DATA DISKGROUP
####################################################################################
ASM_DATA_CREATE() {

  if ! su - grid -c "asmca -silent -createDiskGroup -diskGroupName ${ASMDATANAME} -diskList ${DATADISK} -redundancy ${DATAREDUN}"; then
    c1 "Sorry, Asm group ${ASMDATANAME} create filed" red
    exit 99
  fi

  cat <<EOF >>/home/grid/selectasm.sql
set line222
col name for a20
col state for a20
col Per_Free for a20
col path for a60
select NAME,TOTAL_MB/1024 "TOTAL/G",FREE_MB/1024 "FREE/G",round(FREE_MB/TOTAL_MB*100)||'%' Per_Free,state from v\$asm_diskgroup;
select mode_status,name,state,path from v\$asm_disk;
exit;
EOF
  logwrite "ASM CHECK" "su - grid -c \"sqlplus / as sysasm @/home/grid/selectasm.sql\""
}

####################################################################################
# Unzip DB Software
####################################################################################
UnzipDBSoft() {
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    if [ -d "${SOFTWAREDIR}"/database ]; then
      cd ~ || return
      rm -rf "${SOFTWAREDIR}"/database
    fi
    if unzip -o "${SOFTWAREDIR}"/p13390677_112040_Linux-x86-64_1of7.zip -d "${SOFTWAREDIR}"; then
      rm -rf "${SOFTWAREDIR}"/p13390677_112040_Linux-x86-64_1of7.zip
      chown -R oracle:oinstall "${SOFTWAREDIR}"/database
    else
      c1 "Make sure the database installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "p13390677_112040_Linux-x86-64_1of7.zip" blue
      exit 99
    fi

    if unzip -o "${SOFTWAREDIR}"/p13390677_112040_Linux-x86-64_2of7.zip -d "${SOFTWAREDIR}"; then
      rm -rf "${SOFTWAREDIR}"/p13390677_112040_Linux-x86-64_2of7.zip
      chown -R oracle:oinstall "${SOFTWAREDIR}"/database
    else
      c1 "Make sure the database installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "p13390677_112040_Linux-x86-64_2of7.zip" blue
      exit 99
    fi
  elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
    if [ -d "${SOFTWAREDIR}"/database ]; then
      cd ~ || return
      rm -rf "${SOFTWAREDIR}"/database
    fi
    if unzip -o "${SOFTWAREDIR}"/LINUX.X64_122010_db_home.zip -d "${SOFTWAREDIR}"; then
      rm -rf "${SOFTWAREDIR}"/LINUX.X64_122010_db_home.zip
      chown -R oracle:oinstall "${SOFTWAREDIR}"/database
    else
      c1 "Make sure the database installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "LINUX.X64_122010_db_home.zip" blue
      exit 99
    fi
  elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
    if [ "$(find "${ENV_ORACLE_HOME}" -mindepth 1 | wc -l)" -gt 0 ]; then
      cd ~ || return
      rm -rf "${ENV_ORACLE_HOME}"
    fi
    if unzip -o "${SOFTWAREDIR}"/LINUX.X64_180000_db_home.zip -d "${ENV_ORACLE_HOME}"; then
      rm -rf "${SOFTWAREDIR}"/LINUX.X64_180000_db_home.zip
      chown -R oracle:oinstall "${ENV_ORACLE_HOME}"
    else
      c1 "Make sure the database installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "LINUX.X64_180000_db_home.zip" blue
      exit 99
    fi
  elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
    if [ "$(find "${ENV_ORACLE_HOME}" -mindepth 1 | wc -l)" -gt 0 ]; then
      cd ~ || return
      rm -rf "${ENV_ORACLE_HOME}"
    fi
    if unzip -o "${SOFTWAREDIR}"/LINUX.X64_193000_db_home.zip -d "${ENV_ORACLE_HOME}"; then
      rm -rf "${SOFTWAREDIR}"/LINUX.X64_193000_db_home.zip
      chown -R oracle:oinstall "${ENV_ORACLE_HOME}"
    else
      c1 "Make sure the database installation package is in the ${SOFTWAREDIR} directory:" red
      c1 "LINUX.X64_193000_db_home.zip" blue
      exit 99
    fi
  else
    c1 "Error database version! please check again!" red
    exit
  fi
}

####################################################################################
# Install DB Software
####################################################################################
InstallDBsoftware() {

  ####################################################################################
  # Unzip oracle OPATCH&&RU
  ####################################################################################
  if [ -n "${OPATCH}" ] || [ -n "${GPATCH}" ]; then
    ## 18C
    if [ "${DB_VERSION}" = "18.0.0.0" ]; then
      if su - oracle -c "unzip -o ${SOFTWAREDIR}/p6880880_180000_Linux-x86-64.zip -d ${ENV_ORACLE_HOME}"; then
        rm -rf "${SOFTWAREDIR}"/p6880880_180000_Linux-x86-64.zip
      else
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_180000_Linux-x86-64.zip" blue
        exit 92
      fi
    ## 19C
    elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
      if su - oracle -c "unzip -o ${SOFTWAREDIR}/p6880880_190000_Linux-x86-64.zip -d ${ENV_ORACLE_HOME}"; then
        rm -rf "${SOFTWAREDIR}"/p6880880_190000_Linux-x86-64.zip
      else
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_190000_Linux-x86-64.zip" blue
        exit 92
      fi
    fi

    ##IF GPATCH IS NOT EXISTS , THEN CHECK OPATCH
    if [ -z "${GPATCH}" ]; then
      if [ ! -d "${SOFTWAREDIR}"/"${OPATCH}" ]; then
        chown -R oracle:oinstall "${SOFTWAREDIR}"
        if su - oracle -c "unzip -o ${SOFTWAREDIR}/*p${OPATCH}* -d ${SOFTWAREDIR}"; then
          rm -rf "${SOFTWAREDIR}"/*p"${OPATCH}"*
        else
          c1 "Make sure the database release update ${OPATCH} is in the ${SOFTWAREDIR} directory:" red
          c1 "p${OPATCH}.......zip" blue
          exit 99
        fi
      fi
    fi
  fi

  ## chown oracle&&grid Patch
  chown -R oracle:oinstall "${SOFTWAREDIR}"/"${GPATCH}"
  chown -R oracle:oinstall "${SOFTWAREDIR}"/"${OPATCH}"
  chmod -R 775 "${SOFTWAREDIR}"/"${GPATCH}"
  chmod -R 775 "${SOFTWAREDIR}"/"${OPATCH}"

  #Create db.rsp
  if [ -f "${SOFTWAREDIR}"/db.rsp ]; then
    rm -rf "${SOFTWAREDIR}"/db.rsp
  fi
  if [ ${DB_VERSION} = 11.2.0.4 ]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME=${hostname}
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_BASE_DIR}/oraInventory
SELECTED_LANGUAGES=en,zh_CN
ORACLE_HOME=${ENV_ORACLE_HOME}
ORACLE_BASE=${ENV_ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=oper
oracle.install.db.CLUSTER_NODES=${RAC1HOSTNAME},${RAC2HOSTNAME}
DECLINE_SECURITY_UPDATES=true
oracle.installer.autoupdates.option=SKIP_UPDATES
EOF
    else
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME=${hostname}
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_BASE_DIR}/oraInventory
SELECTED_LANGUAGES=en,zh_CN
ORACLE_HOME=${ENV_ORACLE_HOME}
ORACLE_BASE=${ENV_ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=oper
DECLINE_SECURITY_UPDATES=true
oracle.installer.autoupdates.option=SKIP_UPDATES
EOF
    fi
  elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
ORACLE_HOME=${ENV_ORACLE_HOME}
ORACLE_BASE=${ENV_ORACLE_BASE}     
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.CLUSTER_NODES=${RAC1HOSTNAME},${RAC2HOSTNAME}
EOF
    else
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
ORACLE_HOME=${ENV_ORACLE_HOME}
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
ORACLE_BASE=${ENV_ORACLE_BASE}
SELECTED_LANGUAGES=en,zh_CN
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
EOF
    fi
  elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v18.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
ORACLE_BASE=${ENV_ORACLE_BASE}     
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.CLUSTER_NODES=${RAC1HOSTNAME},${RAC2HOSTNAME}
EOF
    else
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v18.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
ORACLE_BASE=${ENV_ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
EOF
    fi
  elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
ORACLE_BASE=${ENV_ORACLE_BASE}     
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.CLUSTER_NODES=${RAC1HOSTNAME},${RAC2HOSTNAME}
oracle.install.db.rootconfig.executeRootScript=false
oracle.install.db.rootconfig.configMethod=
EOF
    else
      cat <<EOF >>"${SOFTWAREDIR}"/db.rsp
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ENV_ORACLE_INVEN}
ORACLE_BASE=${ENV_ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.rootconfig.executeRootScript=false
oracle.install.db.rootconfig.configMethod=
EOF
    fi
  fi

  logwrite "${SOFTWAREDIR}/db.rsp" "cat ${SOFTWAREDIR}/db.rsp"

  #Install Database software
  chown oracle:oinstall "${SOFTWAREDIR}"/db.rsp

  ##Juge whether ${ENV_ORACLE_INVEN}/ContentsXML/inventory.xml contains ${ENV_ORACLE_HOME},if exists ,delete it
  # if [ -f "${ENV_ORACLE_INVEN}/ContentsXML/inventory.xml" ] && [ "$(grep -E -c "${ENV_ORACLE_HOME}" "${ENV_ORACLE_INVEN}"/ContentsXML/inventory.xml)" -gt 0 ]; then
  #     line=$(grep -n "${ENV_ORACLE_HOME}" "${ENV_ORACLE_INVEN}"/ContentsXML/inventory.xml | awk -F ":" '{print $1}')
  #     sed -i "${line} d" "${ENV_ORACLE_INVEN}"/ContentsXML/inventory.xml
  # fi

  if [[ "${DB_VERSION}" == "12.2.0.1" ]] || [[ "${DB_VERSION}" == "11.2.0.4" ]]; then
    ##INSTALL DB SOFTWARE
    if ! su - oracle -c "${SOFTWAREDIR}/database/runInstaller -silent -force -showProgress -ignoreSysPrereqs -waitForCompletion -responseFile ${SOFTWAREDIR}/db.rsp -ignorePrereq"; then
      c1 "Sorry, ORALCE Software Install Failed." red
      exit 99
    fi
  ## 18C AND 19C -applyRU
  elif [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
    if [ -n "${GPATCH}" ]; then
      ##RAC OR RESTART
      su - oracle -c "${ENV_ORACLE_HOME}/runInstaller -silent -force -responseFile ${SOFTWAREDIR}/db.rsp -ignorePrereq -waitForCompletion -applyRU ${SOFTWAREDIR}/${GPATCH}"
    elif [ -n "${OPATCH}" ]; then
      ##RAC OR RESTART
      su - oracle -c "${ENV_ORACLE_HOME}/runInstaller -silent -force -responseFile ${SOFTWAREDIR}/db.rsp -ignorePrereq -waitForCompletion -applyRU ${SOFTWAREDIR}/${OPATCH}"
    else
      ##NO PATCH
      su - oracle -c "${ENV_ORACLE_HOME}/runInstaller -silent -force -responseFile ${SOFTWAREDIR}/db.rsp -ignorePrereq -waitForCompletion"
      createNetca
    fi

  fi

  if [ -d "/${SOFTWAREDIR}/"database ]; then
    cd ~ || return
    rm -rf "/${SOFTWAREDIR:?}/"database
  fi

  if [ -f "${ENV_ORACLE_INVEN}"/orainstRoot.sh ] || [ -f "${ENV_ORACLE_HOME}"/root.sh ]; then
    if [ -f "${ENV_ORACLE_INVEN}"/orainstRoot.sh ]; then
      "${ENV_ORACLE_INVEN}"/orainstRoot.sh
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ssh "$RAC2HOSTNAME" "${ENV_ORACLE_INVEN}"/orainstRoot.sh
      fi
    fi
    if [ -f "${ENV_ORACLE_HOME}"/root.sh ]; then
      "${ENV_ORACLE_HOME}"/root.sh
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ssh "$RAC2HOSTNAME" "${ENV_ORACLE_HOME}"/root.sh
      fi
    fi
  else
    echo
    c1 "Oracle software installation failed, please check the log." red
    exit 99
  fi

  ##Oracle APPLY Patches
  ## 11G AND 12C opatch auto / opatchauto
  ## AFTER INSTALL ,APPLY PATCH
  if [ -n "${GPATCH}" ] || [ -n "${OPATCH}" ]; then
    ## 11G
    if [ "${DB_VERSION}" = "11.2.0.4" ]; then
      if su - oracle -c "unzip -o ${SOFTWAREDIR}/p6880880_112000_Linux-x86-64.zip -d ${ENV_ORACLE_HOME}"; then
        rm -rf "${SOFTWAREDIR}"/p6880880_112000_Linux-x86-64.zip
      else
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_112000_Linux-x86-64.zip" blue
        exit 92
      fi
      ## 12C
    elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
      if su - oracle -c "unzip -o ${SOFTWAREDIR}/p6880880_122010_Linux-x86-64.zip -d ${ENV_ORACLE_HOME}"; then
        rm -rf "${SOFTWAREDIR}"/p6880880_122010_Linux-x86-64.zip
      else
        c1 "Make sure the Patch 6880880 is in the ${SOFTWAREDIR} directory:" red
        c1 "p6880880_122010_Linux-x86-64.zip" blue
        exit 92
      fi
    fi

    ## RAC
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ## scp OPatch
        if [ "${DB_VERSION}" = "11.2.0.4" ] || [ "${DB_VERSION}" = "12.2.0.1" ]; then
          scp -r "${ENV_ORACLE_HOME}"/OPatch "${RAC2HOSTNAME}":"${ENV_ORACLE_HOME}"
          ssh "${RAC2HOSTNAME}" chown -R oracle:oinstall "${ENV_ORACLE_HOME}"/OPatch
          ssh "${RAC2HOSTNAME}" chown -R oracle:oinstall "${SOFTWAREDIR}/""${GPATCH}"
        fi
      fi
      if [[ "${DB_VERSION}" == "11.2.0.4" ]]; then
        "${ENV_ORACLE_HOME}"/OPatch/opatch auto "${SOFTWAREDIR}/""${GPATCH}" -oh "${ENV_ORACLE_HOME}"
        if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
          ssh "$RAC2HOSTNAME" "${ENV_ORACLE_HOME}"/OPatch/opatch auto "${SOFTWAREDIR}/""${GPATCH}" -oh "${ENV_ORACLE_HOME}"
        fi
      elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
        "${ENV_ORACLE_HOME}"/OPatch/opatchauto apply "${SOFTWAREDIR}/""${GPATCH}" -oh "${ENV_ORACLE_HOME}"
        if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
          ssh "$RAC2HOSTNAME" "${ENV_ORACLE_HOME}"/OPatch/opatchauto apply "${SOFTWAREDIR}/""${GPATCH}" -oh "${ENV_ORACLE_HOME}"
        fi
      fi
    else
      if [ "${DB_VERSION}" = "11.2.0.4" ] || [[ "${DB_VERSION}" == "12.2.0.1" ]]; then
        createNetca
        ## NOT RAC
        su - oracle <<EOF
cd ${SOFTWAREDIR}/${OPATCH} || return
${ENV_ORACLE_HOME}/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -ph ./
${ENV_ORACLE_HOME}/OPatch/opatch apply -silent
EOF
      fi
    fi
  fi

  #LINUX6 INSTALL 12C,NEED TO SET ioracle irman
  if [ "${DB_VERSION}" = "12.2.0.1" ] && [ "${OS_VERSION}" = "linux6" ]; then
    if ! su - oracle -c "/usr/bin/make -f ${ENV_ORACLE_HOME}/rdbms/lib/ins_rdbms.mk irman" && ! su - oracle -c "/usr/bin/make -f ${ENV_ORACLE_HOME}/rdbms/lib/ins_rdbms.mk ioracle"; then
      su - oracle -c "/usr/bin/make -f ${ENV_ORACLE_HOME}/rdbms/lib/ins_rdbms.mk ioracle"
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        if ! su - oracle -c "ssh ${RAC2HOSTNAME} /usr/bin/make -f ${ENV_ORACLE_HOME}/rdbms/lib/ins_rdbms.mk irman" && ! su - oracle -c "ssh ${RAC2HOSTNAME} /usr/bin/make -f ${ENV_ORACLE_HOME}/rdbms/lib/ins_rdbms.mk ioracle"; then
          su - oracle -c "ssh ${RAC2HOSTNAME} /usr/bin/make -f ${ENV_ORACLE_HOME}/rdbms/lib/ins_rdbms.mk ioracle"
        fi
      fi
    fi
  fi

  ##LINUX7 INSTALL 11G,NEED TO SET -lnnz11
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    sed -i 's/^\(\s*\$(MK_EMAGENT_NMECTL)\)\s*$/\1 -lnnz11/g' "${ENV_ORACLE_HOME}"/sysman/lib/ins_emagent.mk
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      ssh "$RAC2HOSTNAME" "sed -i 's/^\(\s*\$(MK_EMAGENT_NMECTL)\)\s*$/\1 -lnnz11/g' ""${ENV_ORACLE_HOME}""/sysman/lib/ins_emagent.mk"
    fi
  fi

  logwrite "Oracle RDBMS" "su - oracle -c \"sqlplus -V\""
  logwrite "Oracle OPatch Version" "su - oracle -c \"opatch version\""
  logwrite "OPatch lspatches" "su - oracle -c \"opatch lspatches\""
  ## If SOFTWAREDIR is empty, this will end up deleting everything in the system's root directory.("${SOFTWAREDIR}/"*)
  ## Using :? will cause the command to fail if the variable is null or unset. Similarly, you can use :- to set a default value if applicable
  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    if [ -d "/${SOFTWAREDIR}/""${GPATCH}" ] && [ -n "${GPATCH}" ]; then
      cd ~ || return
      rm -rf "/${SOFTWAREDIR:?}/""${GPATCH}"
      ssh "$RAC2HOSTNAME" "/${SOFTWAREDIR:?}/""${GPATCH}"
    fi
  else
    if [ -d "/${SOFTWAREDIR}/""${OPATCH}" ] && [ -n "${OPATCH}" ]; then
      cd ~ || return
      rm -rf "/${SOFTWAREDIR:?}/""${OPATCH}"
      if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
        ssh "$RAC2HOSTNAME" "/${SOFTWAREDIR:?}/""${OPATCH}"
      fi
    fi
  fi
}

####################################################################################
# Create netca.rsp
####################################################################################
createNetca() {
  if [ -f "${SOFTWAREDIR}"/netca.rsp ]; then
    cd ~ || return
    rm -rf "${SOFTWAREDIR}"/netca.rsp
  fi
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    RESPONSEFILE_VERSION=11.2
  elif [ "${DB_VERSION}" = "12.2.0.1" ]; then
    RESPONSEFILE_VERSION=12.2
  elif [ "${DB_VERSION}" = "18.0.0.0" ]; then
    RESPONSEFILE_VERSION=18.0
  elif [ "${DB_VERSION}" = "19.3.0.0" ]; then
    RESPONSEFILE_VERSION=19.3
  fi

  cat <<EOF >>"${SOFTWAREDIR}"/netca.rsp
[GENERAL]
RESPONSEFILE_VERSION="${RESPONSEFILE_VERSION}"
CREATE_TYPE="CUSTOM"
[oracle.net.ca]
INSTALLED_COMPONENTS={"server","net8","javavm"}
INSTALL_TYPE=""typical""
LISTENER_NUMBER=1
LISTENER_NAMES={"LISTENER"}
LISTENER_PROTOCOLS={"TCP;1521"}
LISTENER_START=""LISTENER""
NAMING_METHODS={"TNSNAMES","ONAMES","HOSTNAME"}
NSN_NUMBER=1
NSN_NAMES={"EXTPROC_CONNECTION_DATA"}
NSN_SERVICE={"PLSExtProc"}
NSN_PROTOCOLS={"TCP;HOSTNAME;1521"}
EOF

  logwrite "${SOFTWAREDIR}/netca.rsp" "cat ${SOFTWAREDIR}/netca.rsp"

  if ! su - oracle -c "netca -silent -responsefile ${SOFTWAREDIR}/netca.rsp"; then
    c1 "Sorry, Listener Create Failed." red
  fi
}

####################################################################################
## Create database
####################################################################################
createDB() {
  if [ "${DB_VERSION}" = "11.2.0.4" ]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      if ! su - oracle -c "dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbName ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword oracle -systemPassword oracle -asmsnmpPassword oracle -datafileDestination ${ASMDATANAME} -redoLogFileSize 120 -recoveryAreaDestination ${ASMDATANAME} -storageType ASM  -sampleSchema true -responseFile NO_VALUE -characterSet ${CHARACTERSET} -nationalCharacterSet AL16UTF16 -continueOnNonFatalErrors false -disableSecurityConfiguration ALL -diskGroupName ${ASMDATANAME} -emConfiguration NONE -listeners LISTENER -automaticMemoryManagement false -totalMemory ${totalMemory} -nodeinfo ${RAC1HOSTNAME},${RAC2HOSTNAME} -databaseType OLTP"; then
        c1 "Sorry, Database Create Failed." red
        exit 99
      fi
    elif [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      if ! su - oracle -c "dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbName ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword oracle -systemPassword oracle -asmsnmpPassword oracle -datafileDestination ${ASMDATANAME} -redoLogFileSize 120 -recoveryAreaDestination ${ASMDATANAME} -storageType ASM  -sampleSchema true -responseFile NO_VALUE -characterSet ${CHARACTERSET} -nationalCharacterSet AL16UTF16 -continueOnNonFatalErrors false -disableSecurityConfiguration ALL -diskGroupName ${ASMDATANAME} -emConfiguration NONE -listeners LISTENER -automaticMemoryManagement false -totalMemory ${totalMemory} -databaseType OLTP"; then
        c1 "Sorry, Database Create Failed." red
        exit 99
      fi
    else
      su - oracle -c "lsnrctl start"
      if ! su - oracle -c "dbca -silent -createDatabase -templateName General_Purpose.dbc -responseFile NO_VALUE -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword oracle -systemPassword oracle -redoLogFileSize 120 -storageType FS -datafileDestination ${ORADATADIR} -sampleSchema true -characterSet ${CHARACTERSET} -nationalCharacterSet AL16UTF16 -emConfiguration NONE -automaticMemoryManagement false -totalMemory ${totalMemory} -databaseType OLTP"; then
        c1 "Sorry, Database Create Failed." red
        exit 99
      fi
    fi
    if [ -d "${SOFTWAREDIR}"/database ]; then
      cd ~ || return
      rm -rf "${SOFTWAREDIR:?}"/database
    fi
  elif [ "${DB_VERSION}" = "12.2.0.1" ] || [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      ASMDATANAME="+${ASMDATANAME}"
      if ! su - oracle -c "dbca -silent -createDatabase -ignorePrereqFailure -templateName General_Purpose.dbc -responseFile NO_VALUE -gdbName ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword oracle -systemPassword oracle -redoLogFileSize 120 -storageType ASM -enableArchive true -archiveLogDest ${ASMDATANAME} -databaseConfigType RAC -sampleSchema true -characterset ${CHARACTERSET} -nationalCharacterSet AL16UTF16 -datafileDestination ${ASMDATANAME} -emConfiguration NONE -automaticMemoryManagement false -totalMemory ${totalMemory} -nodeinfo ${RAC1HOSTNAME},${RAC2HOSTNAME} -databaseType OLTP -createAsContainerDatabase ${ISCDB}"; then
        c1 "Sorry, Database Create Failed." red
        exit 99
      fi
    elif [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      ASMDATANAME="+${ASMDATANAME}"
      if [ "${DB_VERSION}" = "12.2.0.1" ]; then
        ## 12.2 Oracle Restart: LFI-00133 LFI-01517 occurred when using srvctl (Doc ID 2387137.1)
        if [ ! -f "${ENV_ORACLE_HOME}"/log/"${ORACLE_SID}" ]; then
          mkdir -p "${ENV_ORACLE_HOME}"/log/"${ORACLE_SID}"
        fi
        chown -R oracle:oinstall "${ENV_ORACLE_HOME}"/log/"${ORACLE_SID}"
        ## DBCA : ORA-01017: invalid username/password; logon denied (Doc ID 2624344.1)
        # usermod -a -G racdba grid
        # su - oracle -c "relink all"
      fi
      if ! su - oracle -c "dbca -silent -createDatabase -ignorePrereqFailure -templateName General_Purpose.dbc -responseFile NO_VALUE -gdbName ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword oracle -systemPassword oracle -redoLogFileSize 120 -storageType ASM -enableArchive true -archiveLogDest ${ASMDATANAME} -databaseConfigType SINGLE -sampleSchema true -characterset ${CHARACTERSET} -nationalCharacterSet AL16UTF16 -datafileDestination ${ASMDATANAME} -emConfiguration NONE -automaticMemoryManagement false -totalMemory ${totalMemory} -databaseType OLTP -createAsContainerDatabase ${ISCDB}"; then
        c1 "Sorry, Database Create Failed." red
        exit 99
      fi
    else
      su - oracle -c "lsnrctl start"
      if ! su - oracle -c "dbca -silent -createDatabase -ignorePrereqFailure -templateName General_Purpose.dbc -responseFile NO_VALUE -gdbName ${ORACLE_SID} -sid ${ORACLE_SID} -sysPassword oracle -systemPassword oracle -redoLogFileSize 120 -storageType FS  -databaseConfigType SINGLE -datafileDestination ${ORADATADIR} -enableArchive true -archiveLogDest ${ARCHIVEDIR} -sampleSchema true -characterset ${CHARACTERSET} -nationalCharacterSet AL16UTF16 -emConfiguration NONE -automaticMemoryManagement false -totalMemory ${totalMemory} -databaseType OLTP -createAsContainerDatabase ${ISCDB}"; then
        c1 "Sorry, Database Create Failed." red
        exit 99
      fi
    fi
  fi

  logwrite "ORACLE Instance" "su - oracle -c \"lsnrctl status\""
}

####################################################################################
# Configure DBParaSet
####################################################################################
DBParaSet() {
  if [ "$(find "/home/oracle" -maxdepth 1 -name '*.sql' | wc -l)" -gt 0 ]; then
    cd ~ || return
    rm -rf /home/oracle/*.sql
  fi
  if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
    if [ "${DB_VERSION}" = "12.2.0.1" ] || [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
      cat <<EOF >/home/oracle/oracleParaset.sql
--set db_create_file_dest
ALTER SYSTEM SET DB_CREATE_FILE_DEST='${ASMDATANAME}';
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=${ASMDATANAME}';
exit;
EOF
    else
      cat <<EOF >/home/oracle/oracleParaset.sql
--set db_create_file_dest
ALTER SYSTEM SET DB_CREATE_FILE_DEST='+${ASMDATANAME}';
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=+${ASMDATANAME}';
exit;
EOF
    fi
  else
    cat <<EOF >/home/oracle/oracleParaset.sql
--set db_create_file_dest
ALTER SYSTEM SET DB_CREATE_FILE_DEST='${ORADATADIR}';
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=${ARCHIVEDIR}';
exit;
EOF
  fi
  su - oracle -c "sqlplus / as sysdba @/home/oracle/oracleParaset.sql"

  ####################################################################################
  # Create PDB and Set pdb autostart with cdb
  ####################################################################################
  if [ "${ISCDB}" = "TRUE" ]; then
    if [ ! -f /home/oracle/pdbs_save_state.sql ]; then
      cat <<EOF >>/home/oracle/pdbs_save_state.sql
--create pluggable database
create pluggable database ${PDBNAME} admin user admin identified by oracle;
--open pluggable database
alter pluggable database all open;
--set pdb autostart with cdb
alter pluggable database all save state;
exit
EOF
    fi
    su - oracle -c "sqlplus / as sysdba @/home/oracle/pdbs_save_state.sql"
    ####################################################################################
    # Add pdb TNS
    ####################################################################################
    if [ -f "${ENV_ORACLE_HOME}"/network/admin/tnsnames.ora ] && [ "$(grep -E -c "#OracleBegin" "${ENV_ORACLE_HOME}"/network/admin/tnsnames.ora)" -eq 0 ]; then
      [ ! -f "${ENV_ORACLE_HOME}"/network/admin/tnsnames.ora."${DAYTIME}" ] && cp "${ENV_ORACLE_HOME}"/network/admin/tnsnames.ora "${ENV_ORACLE_HOME}"/network/admin/tnsnames.ora."${DAYTIME}"
      su - oracle -c "cat <<EOF >>${ENV_ORACLE_HOME}/network/admin/tnsnames.ora
#OracleBegin
${PDBNAME} =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${hostname})(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${PDBNAME})
    )
  )
#OracleEnd
EOF
"
    else
      su - oracle -c "cat <<EOF >${ENV_ORACLE_HOME}/network/admin/tnsnames.ora
#OracleBegin
${PDBNAME} =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = ${hostname})(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${PDBNAME})
    )
  )
#OracleEnd
EOF
"
    fi
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      scp "${ENV_ORACLE_HOME}"/network/admin/tnsnames.ora "${RAC2HOSTNAME}":"${ENV_ORACLE_HOME}"/network/admin/
    fi
  fi

  ####################################################################################
  # Configure instances autostart with OS start
  ####################################################################################
  if [ "$(grep -E -c "#OracleBegin" /etc/oratab)" -eq 0 ]; then
    [ ! -f /etc/oratab."${DAYTIME}" ] && cp /etc/oratab /etc/oratab."${DAYTIME}"
    sed -i 's/db:N/db:Y/' /etc/oratab
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ] || [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
      if [ "${DB_VERSION}" = "11.2.0.4" ]; then
        "${ENV_GRID_HOME}"/bin/crsctl modify resource "ora.${ORACLE_SID}.db" -attr "AUTO_START=always"
      elif [ "${DB_VERSION}" = "12.2.0.1" ] || [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]]; then
        "${ENV_GRID_HOME}"/bin/crsctl modify resource "ora.${ORACLE_SID}.db" -attr "AUTO_START=always" -unsupported
      fi
    else
      sed -i 's/ORACLE_HOME_LISTNER=$1/ORACLE_HOME_LISTNER=$ORACLE_HOME/' "${ENV_ORACLE_HOME}"/bin/dbstart
      cat <<EOF >>/etc/rc.d/rc.local
#OracleBegin
su oracle -lc "${ENV_ORACLE_HOME}/bin/lsnrctl start"
su oracle -lc ${ENV_ORACLE_HOME}/bin/dbstart
#OracleEnd
EOF

      chmod +x /etc/rc.d/rc.local
    fi
  fi

  ####################################################################################
  # Configure del_arch.sh to crontab
  ####################################################################################
  ##create del_arch.sh
  if [ ! -f ${SCRIPTSDIR}/del_arch.sh ]; then
    {
      echo '#!/bin/bash'
      echo 'source ~/.bash_profile'
      echo 'deltime=`date +"20%y%m%d%H%M%S"`'
      echo "rman target / nocatalog msglog ${SCRIPTSDIR}/del_arch_\${deltime}.log<<EOF"
      echo 'crosscheck archivelog all;'
      echo "delete noprompt archivelog until time 'sysdate-7';"
      echo "delete noprompt force archivelog until time 'SYSDATE-10';"
      echo 'EOF'
    } >>${SCRIPTSDIR}/del_arch.sh
  fi

  ##create dbbackup_lv0.sh
  if [ ! -f ${SCRIPTSDIR}/dbbackup_lv0.sh ]; then
    {
      echo '#!/bin/sh'
      echo 'source ~/.bash_profile'
      echo 'backtime=`date +"20%y%m%d%H%M%S"`'
      echo "rman target / log=${BACKUPDIR}/level0_backup_\${backtime}.log<<EOF"
      echo 'run {'
      echo 'allocate channel c1 device type disk;'
      echo 'allocate channel c2 device type disk;'
      echo 'crosscheck backup;'
      echo 'crosscheck archivelog all; '
      echo 'sql"alter system switch logfile";'
      echo 'delete noprompt expired backup;'
      echo 'delete noprompt obsolete device type disk;'
      echo "backup incremental level 0 database include current controlfile format '${BACKUPDIR}/backlv0_%d_%T_%t_%s_%p';"
      echo 'backup archivelog all DELETE INPUT;'
      echo 'release channel c1;'
      echo 'release channel c2;'
      echo '}'
      echo 'EOF'
    } >>${SCRIPTSDIR}/dbbackup_lv0.sh
  fi

  ##create dbbackup_lv1.sh
  if [ ! -f ${SCRIPTSDIR}/dbbackup_lv1.sh ]; then
    {
      echo '#!/bin/sh'
      echo 'source ~/.bash_profile'
      echo 'backtime=`date +"20%y%m%d%H%M%S"`'
      echo "rman target / log=${BACKUPDIR}/level1_backup_\${backtime}.log<<EOF"
      echo 'run {'
      echo 'allocate channel c1 device type disk;'
      echo 'allocate channel c2 device type disk;'
      echo 'crosscheck backup;'
      echo 'crosscheck archivelog all; '
      echo 'sql"alter system switch logfile";'
      echo 'delete noprompt expired backup;'
      echo 'delete noprompt obsolete device type disk;'
      echo "backup incremental level 1 database include current controlfile format '${BACKUPDIR}/backlv1_%d_%T_%t_%s_%p';"
      echo 'backup archivelog all DELETE INPUT;'
      echo 'release channel c1;'
      echo 'release channel c2;'
      echo '}'
      echo 'EOF'
    } >>${SCRIPTSDIR}/dbbackup_lv1.sh
  fi

  ##create dbbackup_lv2.sh
  if [ ! -f ${SCRIPTSDIR}/dbbackup_lv2.sh ]; then
    {
      echo '#!/bin/sh'
      echo 'source ~/.bash_profile'
      echo 'backtime=$(date +"20%y%m%d%H%M%S")'
      echo "rman target / log=${BACKUPDIR}/level2_backup_\${backtime}.log<<EOF"
      echo 'run {'
      echo 'allocate channel c2 device type disk;'
      echo 'allocate channel c2 device type disk;'
      echo 'crosscheck backup;'
      echo 'crosscheck archivelog all; '
      echo 'sql"alter system switch logfile";'
      echo 'delete noprompt expired backup;'
      echo 'delete noprompt obsolete device type disk;'
      echo "backup incremental level 2 database include current controlfile format '${BACKUPDIR}/backlv2_%d_%T_%t_%s_%p';"
      echo 'backup archivelog all DELETE INPUT;'
      echo 'release channel c2;'
      echo 'release channel c2;'
      echo '}'
      echo 'EOF'
    } >>${SCRIPTSDIR}/dbbackup_lv2.sh
  fi

  ####################################################################################
  # Configure scripts to crontab
  ####################################################################################
  ##Set to oracle crontab
  if [ ! -f /var/spool/cron/oracle ]; then
    echo "##For oracle" >>/var/spool/cron/oracle
  fi
  if [ "$(grep -E -c "#OracleBegin" /var/spool/cron/oracle)" -eq 0 ]; then
    [ ! -f /var/spool/cron/oracle."${DAYTIME}" ] && cp /var/spool/cron/oracle /var/spool/cron/oracle."${DAYTIME}" >/dev/null 2>&1
    chown -R oracle:oinstall ${SCRIPTSDIR}/d*
    chmod +x ${SCRIPTSDIR}/d*
    {
      echo "#OracleBegin"
      echo "#12 00 * * * ${SCRIPTSDIR}/del_arch.sh"
      echo "#00 00 * * 0 ${SCRIPTSDIR}/dbbackup_lv0.sh"
      echo "#00 00 * * 1,2,4,5 ${SCRIPTSDIR}/dbbackup_lv1.sh"
      echo "#00 00 * * 3,6 ${SCRIPTSDIR}/dbbackup_lv2.sh"
      echo "#OracleEnd"
    } >>/var/spool/cron/oracle
  fi

  ####################################################################################
  # Configure PASSWORD_LIFE_TIME UNLIMITED
  ####################################################################################
  if [ "${ISCDB}" = "TRUE" ]; then
    cat <<EOF >/home/oracle/password_unlimt.sql
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
ALTER SYSTEM SET AUDIT_TRAIL=NONE SCOPE=SPFILE;
ALTER SYSTEM SET DEFERRED_SEGMENT_CREATION=FALSE;
ALTER SYSTEM SET "_OPTIMIZER_CARTESIAN_ENABLED"=FALSE;
ALTER SYSTEM SET "_USE_SINGLE_LOG_WRITER"=FALSE SCOPE=SPFILE;
ALTER SYSTEM SET RESULT_CACHE_MAX_SIZE= 0;
ALTER SYSTEM SET event='10949 trace name context forever:28401 trace name context forever,level 1:10849 trace name context forever, level 1:19823 trace name context forever, level 90' scope=spfile;
ALTER SESSION SET CONTAINER=${PDBNAME};
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
GRANT DBA TO ADMIN;
exit;
EOF
  else
    cat <<EOF >/home/oracle/password_unlimt.sql
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
ALTER SYSTEM SET AUDIT_TRAIL=NONE SCOPE=SPFILE;
ALTER SYSTEM SET DEFERRED_SEGMENT_CREATION=FALSE;
ALTER SYSTEM SET "_OPTIMIZER_CARTESIAN_ENABLED"=FALSE;
--ALTER SYSTEM SET "_USE_SINGLE_LOG_WRITER"=FALSE SCOPE=SPFILE;
ALTER SYSTEM SET RESULT_CACHE_MAX_SIZE= 0;
ALTER SYSTEM SET event='10949 trace name context forever:28401 trace name context forever,level 1:10849 trace name context forever, level 1:19823 trace name context forever, level 90' scope=spfile;
exit;
EOF
  fi

  su - oracle -c "sqlplus / as sysdba @/home/oracle/password_unlimt.sql"

  cat <<EOF >/home/oracle/Impliedparameters.sql
col name for a40
col VALUE for a10
col DESCRIB for a60
set lines 200
SHOW PARAMETER AUDIT_TRAIL
SHOW PARAMETER DEFERRED_SEGMENT_CREATION
SHOW PARAMETER RESULT_CACHE_MAX_SIZE
SELECT x.ksppinm NAME, y.ksppstvl VALUE, x.ksppdesc describ
FROM SYS.x\$ksppi x, SYS.x\$ksppcv y
WHERE x.inst_id = USERENV ('Instance')
AND y.inst_id = USERENV ('Instance')
AND x.indx = y.indx
and x.ksppinm in ('_optimizer_cartesian_enabled','_use_single_log_writer','_use_adaptive_log_file_sync');
exit;
EOF
  logwrite "Oracle Implied parameters" "su - oracle -c \"sqlplus / as sysdba @/home/oracle/Impliedparameters.sql\""

  ####################################################################################
  # Sqlnet.ora Configure lower Oracle client to connect
  ####################################################################################
  if [ "${DB_VERSION}" = "18.0.0.0" ] || [[ "${DB_VERSION}" == "19.3.0.0" ]] || [[ "${DB_VERSION}" == "12.2.0.1" ]]; then
    if [ -f "${ENV_ORACLE_HOME}"/network/admin/sqlnet.ora ] && [ "$(grep -E -c "#OracleBegin" "${ENV_ORACLE_HOME}"/network/admin/sqlnet.ora)" -eq 0 ]; then
      [ ! -f "${ENV_ORACLE_HOME}"/network/admin/sqlnet.ora."${DAYTIME}" ] && cp "${ENV_ORACLE_HOME}"/network/admin/sqlnet.ora "${ENV_ORACLE_HOME}"/network/admin/sqlnet.ora."${DAYTIME}"
      su - oracle -c "cat <<EOF >>${ENV_ORACLE_HOME}/network/admin/sqlnet.ora
#OracleBegin
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=8
SQLNET.ALLOWED_LOGON_VERSION_SERVER=8
#OracleEnd
EOF
"
    else
      su - oracle -c "cat <<EOF >${ENV_ORACLE_HOME}/network/admin/sqlnet.ora
#OracleBegin
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=8
SQLNET.ALLOWED_LOGON_VERSION_SERVER=8
#OracleEnd
EOF
"
    fi
    if [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
      scp "${ENV_ORACLE_HOME}"/network/admin/sqlnet.ora "${RAC2HOSTNAME}":"${ENV_ORACLE_HOME}"/network/admin/
    fi
  fi
  if [ "$(find "/home/oracle" -maxdepth 1 -name '*.sql' | wc -l)" -gt 0 ]; then
    cd ~ || return
    rm -rf /home/oracle/*.sql
  fi
}

if [ "${OracleInstallMode}" = "single" ] || [ "${OracleInstallMode}" = "SINGLE" ]; then
  ##FOR SINGLE
  SwapCheck
  InstallRPM
  SetHostName
  SetHosts
  CreateUsersAndDirs
  TimeDepSet
  Disableavahi
  DisableFirewall
  DisableSelinux
  DisableTHPAndNUMA
  #DisableNetworkManager
  InstallRlwrap
  EditParaFiles
  UnzipDBSoft
  ##If ONLY INSTALL ORACLE SOFTWARE
  if [ "${ONLYCONFIGOS}" = 'N' ]; then
    if [ "${ONLYINSTALLORACLE}" = 'Y' ]; then
      InstallDBsoftware
      c1 "Congratulations, Install Successful!" blue
    else
      if [ "${ONLYCREATEDB}" = 'Y' ]; then
        createDB
        DBParaSet
        c1 "Congratulations, Install Successful!" blue
      else
        InstallDBsoftware
        createDB
        DBParaSet
        c1 "Congratulations, Install Successful! Please Reboot Later." blue
      fi
    fi
  fi
elif [ "${OracleInstallMode}" = "rac" ] || [ "${OracleInstallMode}" = "RAC" ]; then
  #For Rac
  SCANIParse
  SwapCheck
  InstallRPM
  SetHostName
  SetHosts
  TimeDepSet
  CreateUsersAndDirs
  if [ "${UDEV}" = "Y" ] || [ "${UDEV}" = "y" ]; then
    if [ ! -f /etc/udev/rules.d/99-oracle-asmdevices.rules ]; then
      UDEV_ASMDISK
    fi
  fi
  if [ "${DNSSERVER}" = "y" ] || [ "${DNSSERVER}" = "Y" ]; then
    DNSServerConf
  fi
  if [ "$nodeNum" -eq 1 ]; then
    ##NODE 2 EXCUTE SCRIPT
    NodeTwoExec
    ##SSHHOST
    if [ ! -f "${SOFTWAREDIR}"/sshhostList.cfg ]; then
      Rac_Auto_SSH
    fi
    ##DNS Configure
    if [ "${DNS}" = "y" ] || [ "${DNS}" = "Y" ]; then
      NslookupFunc
    fi
  fi
  Disableavahi
  DisableFirewall
  DisableSelinux
  DisableTHPAndNUMA
  #DisableNetworkManager
  InstallRlwrap
  EditParaFiles
  if [ "$nodeNum" -eq 1 ]; then
    UnzipGridSoft
    UnzipDBSoft
  fi
  ##Just nodenum 1 to excute
  if [ "$nodeNum" -eq 1 ]; then
    ##If ONLY INSTALL GRID SOFTWARE
    if [ "${ONLYCONFIGOS}" = 'N' ]; then
      if [ "${ONLYINSTALLGRID}" = "Y" ]; then
        Runcluvfy
        InstallGridsoftware
        ASM_DATA_CREATE
        c1 "Congratulations, Install Successful!" blue
      else
        if [ "${ONLYINSTALLORACLE}" = "Y" ]; then
          InstallDBsoftware
          c1 "Congratulations, Install Successful!" blue
        else
          if [ "${ONLYCREATEDB}" = "Y" ]; then
            createDB
            DBParaSet
            c1 "Congratulations, Install Successful!" blue
          else
            Runcluvfy
            InstallGridsoftware
            ASM_DATA_CREATE
            InstallDBsoftware
            createDB
            DBParaSet
            c1 "Congratulations, Install Successful! Please Reboot Later." blue
          fi
        fi
      fi
    fi
  fi
elif [ "${OracleInstallMode}" = "restart" ] || [ "${OracleInstallMode}" = "RESTART" ]; then
  #For RESTART
  SwapCheck
  InstallRPM
  SetHostName
  SetHosts
  CreateUsersAndDirs
  if [ "${UDEV}" = "Y" ] || [ "${UDEV}" = "y" ]; then
    if [ ! -f /etc/udev/rules.d/99-oracle-asmdevices.rules ]; then
      UDEV_ASMDISK
    fi
  fi
  TimeDepSet
  Disableavahi
  DisableFirewall
  DisableSelinux
  DisableTHPAndNUMA
  #DisableNetworkManager
  InstallRlwrap
  EditParaFiles
  UnzipGridSoft
  UnzipDBSoft
  ##If ONLY INSTALL GRID SOFTWARE
  if [ "${ONLYCONFIGOS}" = 'N' ]; then
    if [ "${ONLYINSTALLGRID}" = "Y" ]; then
      InstallGridsoftware
      c1 "Congratulations, Install Successful!" blue
    else
      if [ "${ONLYINSTALLORACLE}" = "Y" ]; then
        InstallDBsoftware
        c1 "Congratulations, Install Successful!" blue
      else
        if [ "${ONLYCREATEDB}" = "Y" ]; then
          createDB
          DBParaSet
          c1 "Congratulations, Install Successful!" blue
        else
          InstallGridsoftware
          InstallDBsoftware
          createDB
          DBParaSet
          c1 "Congratulations, Install Successful! Please Reboot Later." blue
        fi
      fi
    fi
  fi
else
  c1 "Oracle Install Mode Input Error, exit" red
  exit 99
fi
