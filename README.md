本脚本支持在LINUX6/7安装ORACLE 11GR2/12CR2/18C/19C版本。 包括Single、Oracle Restart、Oracle Cluster选项。

一、脚本命令 1、如何安装Single模式

11G:

```shellscript
cd /soft
./OracleShellInstall.sh -i 10.211.55.100 `#Public ip`\
-n s11g `# hostname`\
-o s11g `# oraclesid`\
-op oracle `# oracle user password`\
-b /oracle/app `# install basedir`\
-s AL32UTF8 `# characterset`\
-opa 31537677 `# oracle psu number`
```

2、如何安装Oracle Restart模式

11G:

```shellscript
cd /soft
./OracleShellInstall.sh -i 10.211.55.100 `#Public ip`\
-n asm11g `# hostname`\
-o asm11g `# oraclesid`\
-op oracle `# oracle user password`\
-gp oracle `# grid user password`\
-b /u01/app `# install basedir`\
-s AL32UTF8 `# characterset`\
-dd /dev/sde,/dev/sdf `# asm data disk`\
-dr EXTERNAL `# asm data redundancy`\
-gpa 31718723 `# grid psu number`
```

3、如何安装Oracle Rac模式

11G:

```shellscript
cd /soft
./OracleShellInstall.sh -i 10.211.55.100 `#Public ip`\
-n rac `# hostname`\
-rs oracle `# root password`\
-op oracle `# oracle password`\
-gp oracle `# grid password`\
-b /u01/app `# install basedir`\
-o lucifer `# oraclesid`\
-c TRUE `# cdb` \
-pb luciferpdb `# pdb` \
-s AL32UTF8 `# characterset`\
##Network
-pb1 10.211.55.100 -pb2 10.211.55.101 `# node public ip`\
-vi1 10.211.55.102 -vi2 10.211.55.103 `# node virtual ip`\
-pi1 10.10.1.1 -pi2 10.10.1.2 `# node private ip`\
-pi3 1.1.1.1 -pi4 1.1.1.2 `# node private ip`\
-puf eth0 -prf eth1 -prf1 eth2 `# network fcname`\
-si 10.211.55.104,10.211.55.105,10.211.55.106 `# scan ip`\
##ASM DISK
-dd /dev/sde,/dev/sdf `# asm data disk`\
-od /dev/sdb,/dev/sdc,/dev/sdd `# asm ocr disk`\
-or EXTERNAL `# asm ocr redundancy`\
-dr EXTERNAL `# asm data redundancy`\
-on OCR `# asm ocr diskgroupname`\
-dn DATA `# asm data diskgroupname`\
##timeserver
-ts 10.211.55.18 `# timeserver`\
##DNS SCAN
-dns Y `# DNS` \
-dnsn lucifer.com `# DNS SERVER NAME` \
-dnsi 10.211.55.200 `# DNS SERVER IP` \
##PSU&&RU(RUR)
-gpa 32580003 `# GRID PATCH` \
##tuxinghua
-txh Y `#tuxinghua`
```

二、脚本参数

```Para
-i,		--PUBLICIP			PUBLICIP NETWORK ADDRESS
-n,		--HOSTNAME			HOSTNAME(orcl)
-o,		--ORACLE_SID			ORACLE_SID(orcl)
-c,		--ISCDB				IS CDB OR NOT(TRUE|FALSE)
-pb,		--PDBNAME			PDBNAME(pdb01)
-op,		--ORAPASSWD			ORACLE USER PASSWORD(oracle)
-b,		--ENV_BASE_DIR			ORACLE BASE DIR(/u01/app)
-s,		--CHARACTERSET			ORACLE CHARACTERSET(ZHS16GBK|AL32UTF8)
-m,		--ONLYCONFIGOS			ONLY CONFIG SYSTEM PARAMETER(Y|N)
-g,		--ONLYINSTALLGRID 		ONLY INSTALL GRID SOFTWARE(Y|N)
-w,		--ONLYINSTALLORACLE 		ONLY INSTALL ORACLE SOFTWARE(Y|N)
-ocd,		--ONLYCREATEDB		        ONLY CREATE DATABASE(Y|N)
-gpa,		--GRID RELEASE UPDATE		GRID RELEASE UPDATE(32072711)
-opa,		--ORACLE RELEASE UPDATE		ORACLE RELEASE UPDATE(32072711)
-rs,		--ROOTPASSWD			ROOT USER PASSWORD
-gp,		--GRIDPASSWD			GRID USER PASSWORD(oracle)
-pb1,		--RAC1PUBLICIP			RAC NODE ONE PUBLIC IP
-pb2,		--RAC2PUBLICIP			RAC NODE SECONED PUBLIC IP
-vi1,		--RAC1VIP			RAC NODE ONE VIRTUAL IP
-vi2,		--RAC2VIP			RAC NODE SECOND VIRTUAL IP
-pi1,		--RAC1PRIVIP			RAC NODE ONE PRIVATE IP(10.10.1.1)
-pi2,		--RAC2PRIVIP			RAC NODE SECOND PRIVATE IP(10.10.1.2)
-pi3,		--RAC1PRIVIP1			RAC NODE ONE PRIVATE IP(10.1.1.1)
-pi4,		--RAC2PRIVIP1			RAC NODE SECOND PRIVATE IP(10.1.1.2)
-si,		--RACSCANIP			RAC SCAN IP
-sn,		--RACSCANNAME			RAC SCAN NAME(orcl-scan)
-cn,		--CLUSTERNAME			RAC CLUSTER NAME(orcl-cluster)
-dn,		--ASMDATANAME			RAC ASM DATADISKGROUP NAME(DATA)
-on,		--ASMOCRNAME			RAC ASM OCRDISKGROUP NAME(OCR)
-dd,		--DATA_BASEDISK			RAC DATADISK DISKNAME
-od,		--OCRP_BASEDISK			RAC OCRDISK DISKNAME
-or,		--OCRREDUN			RAC OCR REDUNDANCY(EXTERNAL|NORMAL|HIGH)
-dr,		--DATAREDUN			RAC DATA REDUNDANCY(EXTERNAL|NORMAL|HIGH)
-puf,		--RACPUBLICFCNAME	        RAC PUBLIC FC NAME
-prf,		--RACPRIVFCNAME			RAC PRIVATE FC NAME
-prf1,		--RACPRIVFCNAME1		RAC PRIVATE FC NAME
-ts,            --TIMESERVER                    RAC TIME SERVER IP
-txh            --TuXingHua                     Tu Xing Hua Install
-udev           --UDEV                          Whether Auto Set UDEV
-dns            --DNS                           RAC CONFIGURE DNS(Y|N)
-dnss            --DNSSERVER                    RAC CONFIGURE DNSSERVER LOCAL(Y|N)
-dnsn           --DNSNAME                       RAC DNSNAME(orcl.com)
-dnsi           --DNSIP                         RAC DNS IP
```

三、前置准备

1. 把脚本放入软件目录，例如：/soft
2. 挂载ISO
3. 把需要本地安装的rpm和software上传到软件目录
4. 设置好主机IP