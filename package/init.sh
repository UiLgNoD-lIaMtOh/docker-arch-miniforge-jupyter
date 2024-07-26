#!/bin/sh

# 换源
# sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories

# 安装一些必备工具
apk add --no-cache tzdata

# 修改时钟
date +'%Y-%m-%d %H:%M:%S'
ln -sfv /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date +'%Y-%m-%d %H:%M:%S'

# 换成 bash
apk add --no-cache bash shadow curl wget grep gcompat

chsh -s /bin/bash

# 安装 glibc alpine 编译包
mkdir -pv /etc/apk/keys

if [ "$(uname -m)" = "aarch64" ];then
    echo aarch64
    cd aarch64
    # aarch64 alpine
    cp -fv *.rsa.pub /etc/apk/keys/
    # 安装编译好的包
    apk add --force-overwrite --no-cache glibc-2.40-r0.apk glibc-bin-2.40-r0.apk glibc-i18n-2.40-r0.apk
    cd -
    rm -rfv aarch64 x86_64
elif [ "$(uname -m)" = "x86_64" ];then
    echo x86_64
    cd x86_64
    cp -fv *.rsa.pub /etc/apk/keys/
    # 安装编译好的包
    apk add --force-overwrite --no-cache glibc-2.40-r0.apk glibc-bin-2.40-r0.apk glibc-i18n-2.40-r0.apk
    cd -
    rm -rfv aarch64 x86_64
    #ls -l /lib64
    #ln -sfv /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2
else
    echo "不支持，请自定义编写判断条件，并编译自己设备架构的 alpine glibc 包，退出"
    exit 1
fi

# 修复一下
apk fix --allow-untrusted --force-overwrite --no-cache
/usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true
echo "export LANG=$LANG" > /etc/profile.d/locale.sh

# 尝试用 bash 环境运行 install.sh
bash install.sh
rm -fv /bin/sh ; echo -e '#!/bin/bash\nbash' > /bin/sh ; chmod -v +x /bin/sh
