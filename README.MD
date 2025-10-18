![](docs/images/logo.png)

# Magisk On System

## 介绍

无需修改 Boot/Recovery 即可安装 Magisk

## 安装

### 方式一：Patch System  

**不推荐在真机上使用，除非您的设备很特殊(校验boot但不校验逻辑分区)**  

#### Step 1:前往Release页面  
打开本仓库的[release](https://gitee.com/zcg9783/magisk-on-system/releases)页面下载以"MOS_Patch"开头的Zip文件  

#### Step 2：准备设备系统镜像
准备您的设备的system.img和vendor.img(可选)并将其 移动/复制 到合适的位置进行保存  

#### Step 3:开始Patch
(推荐运行环境：Ubuntu 20.04 LTS+)
将 system.img 与 vendor.img 复制到 MOS_Patch 工作目录的images文件夹，然后执行start.sh即可  

```
chmod +x start.sh
./start.sh
```

Patch完成后生成flash_all.bat与镜像到out文件夹  

**注：如果您的设备为动态分区，您需要进入FastbootD模式才可以正常运行flash_all.bat*

### 方式二：在已有root的基础上进行安装  

#### Step 1:前往Release页面  
打开本仓库的[release](https://github.com/zcg9783/magisk-on-system/releases)页面下载app-release.apk  

#### Step 2：直接安装
打开Magisk On System，确认已授予ROOT权限。然后依次点击  
安装 → 直接安装（推荐） → 下一步 → 重启
即可集成Magisk On System

## 事项

如果您正在使用“虚拟机”/“云手机”等设备,请检查**Release**是否有相关已适配的版本

## 已确认适配的虚拟机/云手机

1.中国移动云手机(China Mobile Cloud Phone)  
2.中国移动云手机极致版(China Mobile Cloud Phone Better Version)  
3.星云游戏(XingyunGame)  

### 贡献者
1.Enmmmmmmmm  

2.早茶光
