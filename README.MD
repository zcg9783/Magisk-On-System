![](docs/images/logo.png)

# Magisk On System

## 介绍

无需修改 Boot/Recovery 即可安装 Magisk

## 安装

### 方式一：Patch System

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

### 方式二：在已有root的基础上进行安装  

#### Step 1:前往Release页面  
打开本仓库的[release](https://gitee.com/zcg9783/magisk-on-system/releases)页面下载以Magisk On System.apk 

#### Step 2：直接安装
打开Magisk On System，确认已授予ROOT权限。然后依次点击  
安装 → 直接安装（推荐） → 下一步 → 重启
即可集成Magisk On System

## 事项

如果您正在使用“虚拟机”/“云手机”等设备,请检查**Release**是否有相关已适配的版本


### 分支

Magisk On VMOS 云手机 (已停更): https://gitee.com/enmmmmmm/magisk-on-vmos-cloudphone

Magisk On VMOS Pro（已停更）: https://gitee.com/enmmmmmm/magisk-on-vmos-pro

### 贡献者
1.Enmmmmmmmm
2.早茶光
