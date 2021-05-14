# 一、介绍

本脚本旨在通过无人值守方式初始化安装Oracle软件。

### 功能：

    1.配置操作系统
    2.安装Grid软件
    3.安装Oracle软件
    4.安装PSU&&RU补丁
    5.创建数据库
    6.数据库优化

### 目前支持：

##### ORACLE版本： 11GR2、12CR2、18C、19C。

##### 操作系统版本： Linux6(x86_64)、Linux7(x86_64)。

##### 包括Single、Oracle Restart、Oracle Real Cluster模式。

# 二、使用

### 2.1 安装准备

#### 2.1.1 创建软件目录，例如：/soft

`mkdir /soft`

#### 2.1.2 挂载镜像 ISO

```shell script
## 通过cdrom挂载
mount /dev/cdrom /mnt
or
##通过安装镜像源挂载
mount -o loop /soft/rhel-server-7.9-x86_64-dvd.iso /mnt
```

#### 2.1.3 上传安装介质和脚本到软件目录

#### 2.1.4 设置好主机IP（Public&&Private）

```shell script
#For Example:
##Linux 6
vi /etc/sysconfig/network-scripts/ifcfg-eth0
IPADDR=10.211.55.100
NETMASK=255.255.255.0
GATEWAY=10.211.55.1

##Linux 7
nmcli connection modify eth0 ipv4.addresses 10.211.55.100/24 ipv4.gateway 10.211.55.1 ipv4.method manual autoconnect yes
```

#### 2.1.5 如果需要安装Rac，需提前配置ASM共享磁盘

```
##For Example
##通过iscsi配置共享盘
1.StarWind(Windows)
2.Openfiler(Linux)

##假设已配置好共享存储服务器，IP为10.211.55.18。
##配置iscsi连接共享存储
yum install -y iscsi-initiator-utils*
##输出targetname
iscsiadm -m discovery -t st -p 10.211.55.18
##连接共享存储
iscsiadm -m node -T iqn.2008-08.com.starwindsoftware:10.211.55.18-lucifer -p 10.211.55.18 -l
```

[共享存储之--StarWind高级配置](https://blog.csdn.net/m0_50546016/article/details/116135134)

[共享存储之--Openfiler高级配置](https://www.bilibili.com/video/BV1oJ411q7h3?p=2)

### 2.2 脚本参数

##### 2.2.1 通过运行 `./OracleShellInstall --help` 可以查看参数：

```Para
-i,		--PUBLICIP			PUBLICIP NETWORK ADDRESS
-n,		--HOSTNAME			HOSTNAME(orcl)
-rs,		--ROOTPASSWD			ROOT USER PASSWORD(oracle)
-gp,		--GRIDPASSWD			GRID USER PASSWORD(oracle)
-op,		--ORAPASSWD			ORACLE USER PASSWORD(oracle)
-b,		--ENV_BASE_DIR			ORACLE BASE DIR(/u01/app)
-o,		--ORACLE_SID			ORACLE_SID(orcl)
-s,		--CHARACTERSET			ORACLE CHARACTERSET(AL32UTF8)
-c,		--ISCDB				IS CDB OR NOT(FALSE)
-pb,		--PDBNAME			PDBNAME(pdb01)
-pb1,		--RAC1PUBLICIP			RAC NODE ONE PUBLIC IP
-pb2,		--RAC2PUBLICIP			RAC NODE SECONED PUBLIC IP
-vi1,		--RAC1VIP			RAC NODE ONE VIRTUAL IP
-vi2,		--RAC2VIP			RAC NODE SECOND VIRTUAL IP
-pi1,		--RAC1PRIVIP			RAC NODE ONE PRIVATE IP
-pi2,		--RAC2PRIVIP			RAC NODE SECOND PRIVATE IP
-pi3,		--RAC1PRIVIP1			RAC NODE ONE PRIVATE IP
-pi4,		--RAC2PRIVIP1			RAC NODE SECOND PRIVATE IP
-puf,		--RACPUBLICFCNAME	        RAC PUBLIC FC NAME
-prf,		--RACPRIVFCNAME			RAC PRIVATE FC NAME
-prf1,		--RACPRIVFCNAME1		RAC PRIVATE FC NAME
-si,		--RACSCANIP			RAC SCAN IP
-dn,		--ASMDATANAME			RAC ASM DATADISKGROUP NAME(DATA)
-on,		--ASMOCRNAME			RAC ASM OCRDISKGROUP NAME(OCR)
-dd,		--DATA_BASEDISK			RAC DATADISK DISKNAME
-od,		--OCRP_BASEDISK			RAC OCRDISK DISKNAME
-or,		--OCRREDUN			RAC OCR REDUNDANCY(EXTERNAL|NORMAL|HIGH)
-dr,		--DATAREDUN			RAC DATA REDUNDANCY(EXTERNAL|NORMAL|HIGH)
-ts,            --TIMESERVER                    RAC TIME SERVER IP
-txh            --TuXingHua                     Tu Xing Hua Install
-udev           --UDEV                          Whether Auto Set UDEV
-dns            --DNS                           RAC CONFIGURE DNS(Y|N)
-dnss           --DNSSERVER                     RAC CONFIGURE DNSSERVER LOCAL(Y|N)
-dnsn           --DNSNAME                       RAC DNSNAME(orcl.com)
-dnsi           --DNSIP                         RAC DNS IP
-m,		--ONLYCONFIGOS			ONLY CONFIG SYSTEM PARAMETER(Y|N)
-g,		--ONLYINSTALLGRID 		ONLY INSTALL GRID SOFTWARE(Y|N)
-w,		--ONLYINSTALLORACLE 		ONLY INSTALL ORACLE SOFTWARE(Y|N)
-ocd,		--ONLYCREATEDB		        ONLY CREATE DATABASE(Y|N)
-gpa,		--GRID RELEASE UPDATE		GRID RELEASE UPDATE(32072711)
-opa,		--ORACLE RELEASE UPDATE		ORACLE RELEASE UPDATE(32072711)
```

### 2.3 脚本运行

<font color=#FF000 >***Notes：必须提前上传所需安装介质，否则安装失败！***</font>

___cdb 12C后开始支持容器，只需要加上如下参数即可：___

```shellscript
-c TRUE `# cdb`
-pb singlepdb `# pdbname`
```
<font color=#FF000 >***脚本须Root用户下执行：***</font>

`chmod +x OracleShellInstall.sh`
#### 2.3.1 Single模式安装

```shellscript
cd /soft
./OracleShellInstall.sh -i 10.211.55.100 `#Public ip`\
-n single `# hostname`\
-o nocdb `# oraclesid`\
-op oracle `# oracle user password`\
-b /oracle/app `# install basedir`\
-s AL32UTF8 `# characterset`\
-opa 31537677 `# oracle psu number`
```

#### 2.3.2 Oracle Restart模式安装

```shellscript
cd /soft
./OracleShellInstall.sh -i 10.211.55.100 `#Public ip`\
-n restart `# hostname`\
-o nocdb `# oraclesid`\
-gp oracle `# grid user password`\
-op oracle `# oracle user password`\
-b /u01/app `# install basedir`\
-s AL32UTF8 `# characterset`\
-dd /dev/sde,/dev/sdf `# asm data disk`\
-dn DATA `# asm data diskgroupname`\
-dr EXTERNAL `# asm data redundancy`\
-gpa 31718723 `# grid psu number`
```

#### 2.3.3 Oracle Rac模式安装
```shellscript
cd /soft
./OracleShellInstall.sh -i 10.211.55.100 `#Public ip`\
-n rac `# hostname`\
-rs oracle `# root password`\
-op oracle `# oracle password`\
-gp oracle `# grid password`\
-b /u01/app `# install basedir`\
-o nocdb `# oraclesid`\
-s AL32UTF8 `# characterset`\
-pb1 10.211.55.100 -pb2 10.211.55.101 `# node public ip`\
-vi1 10.211.55.102 -vi2 10.211.55.103 `# node virtual ip`\
-pi1 10.10.1.1 -pi2 10.10.1.2 `# node private ip`\
-pi3 1.1.1.1 -pi4 1.1.1.2 `# node private ip`\
-puf eth0 -prf eth1 `# network fcname`\
-si 10.211.55.105 `# scan ip`\
-dd /dev/sde,/dev/sdf `# asm data disk`\
-od /dev/sdb,/dev/sdc,/dev/sdd `# asm ocr disk`\
-or EXTERNAL `# asm ocr redundancy`\
-dr EXTERNAL `# asm data redundancy`\
-on OCR `# asm ocr diskgroupname`\
-dn DATA `# asm data diskgroupname`\
-gpa 32580003 `# GRID PATCH`
```