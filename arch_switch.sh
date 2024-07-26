#!/usr/bin/env bash
# 传入环境变量控制编译方向 ARCH_SWITCH
echo $ARCH_SWITCH
# 预处理脚本负责编译往 packages 丢编译好的安装包
if [ "${ARCH_SWITCH}" = "aarch64" ];then
    echo ${ARCH_SWITCH}
    # rm -rfv docker-glibc-builder
    # clone sgerrand/docker-glibc-builder 借用 ubuntu 编译 glibc
    git clone "https://github.com/sgerrand/docker-glibc-builder"
    # 检查最新版本 glibc 源码 https://mirrors.kernel.org/gnu/libc/ 为 2.40 版本的 tar.gz
    cd docker-glibc-builder
    # 核心
    sed -i 's;make --jobs=4;make --jobs=16;g' builder
    cat <<'UiLgNoD-lIaMtOh' | tee Dockerfile
FROM ubuntu:22.04
LABEL MAINTAINER="UiLgNoD-lIaMtOh <UiLgNoD.lIaMtOh@hotmail.com>"
ENV DEBIAN_FRONTEND=noninteractive \
    GLIBC_VERSION=2.40 \
    PREFIX_DIR=/usr/glibc-compat
RUN mkdir -pv /glibc-build/ && apt-get -q update \
        && apt-get -qy install \
                bison \
                build-essential \
                gawk \
                gettext \
                openssl \
                python3 \
                texinfo \
                wget \
        ; mv -fv /var/lib/dpkg/info/libc-bin.* /tmp/ \
        ; dpkg --remove --force-remove-reinstreq libc-bin \
        ; dpkg --purge libc-bin \
        ; apt-get -qy install libc-bin \
        ; mv -fv /tmp/libc-bin.* /var/lib/dpkg/info/
COPY configparams /glibc-build/configparams
COPY builder /builder
ENTRYPOINT ["/builder"]
UiLgNoD-lIaMtOh
    # 构建镜像
    docker build --no-cache --platform "linux/arm64/v8" -f Dockerfile -t UiLgNoD-lIaMtOh/glibc-builder:arm64v8-2.40 . ; docker builder prune -fa ; docker rmi $(docker images -qaf dangling=true)

    # 执行 glibc 编译并打包
    docker run --platform "linux/arm64/v8" --rm -e "GLIBC_VERSION=2.40" -e "STDOUT=1" UiLgNoD-lIaMtOh/glibc-builder:arm64v8-2.40 > glibc-bin-2.40-0-aarch64.tar.gz

    # 赋予编译包权限
    chmod -v +x glibc-bin-2.40-0-aarch64.tar.gz
    # clone ljfranklin/alpine-pkg-glibc 为 alpine arm64 编译可支持的 glibc 库
    git clone "https://github.com/ljfranklin/alpine-pkg-glibc" --branch arm64
    # 把 ubuntu 编译好的 glibc 丢给 alpine 编译项目
    cp -fv glibc-bin-2.40-0-aarch64.tar.gz alpine-pkg-glibc/
    # 写入自定义编译配置信息
    cat <<'UiLgNoD-lIaMtOh' | tee alpine-pkg-glibc/APKBUILD
# MAINTAINER UiLgNoD-lIaMtOh <UiLgNoD.lIaMtOh@hotmail.com>
pkgname="glibc"
pkgver="2.40"
_pkgrel="0"
pkgrel="0"
pkgdesc="GNU C Library compatibility layer"
arch="aarch64"
url="https://github.com/sgerrand/alpine-pkg-glibc"
license="LGPL"
source="glibc-bin-$pkgver-$_pkgrel-aarch64.tar.gz
nsswitch.conf
ld.so.conf"
subpackages="$pkgname-bin $pkgname-dev $pkgname-i18n"
triggers="$pkgname-bin.trigger=/lib:/usr/lib:/usr/glibc-compat/lib"
options="lib64"

package() {
    mkdir -p "$pkgdir/lib" "$pkgdir/lib64" "$pkgdir/usr/glibc-compat/lib/locale"  "$pkgdir"/usr/glibc-compat/lib64 "$pkgdir"/etc
    cp -a "$srcdir"/usr "$pkgdir"
    cp "$srcdir"/ld.so.conf "$pkgdir"/usr/glibc-compat/etc/ld.so.conf
    cp "$srcdir"/nsswitch.conf "$pkgdir"/etc/nsswitch.conf
    rm "$pkgdir"/usr/glibc-compat/etc/rpc
    rm -rf "$pkgdir"/usr/glibc-compat/bin
    rm -rf "$pkgdir"/usr/glibc-compat/sbin
    rm -rf "$pkgdir"/usr/glibc-compat/lib/gconv
    rm -rf "$pkgdir"/usr/glibc-compat/lib/getconf
    rm -rf "$pkgdir"/usr/glibc-compat/lib/audit
    rm -rf "$pkgdir"/usr/glibc-compat/share
    rm -rf "$pkgdir"/usr/glibc-compat/var
    ln -s "/usr/glibc-compat/lib/ld-linux-aarch64.so.1" "${pkgdir}/lib/ld-linux-aarch64.so.1"
    ln -s "/usr/glibc-compat/lib/ld-linux-aarch64.so.1" "${pkgdir}/lib64/ld-linux-aarch64.so.1"
    ln -s "/usr/glibc-compat/lib/ld-linux-aarch64.so.1" "${pkgdir}/usr/glibc-compat/lib64/ld-linux-aarch64.so.1"
    ln -s /usr/glibc-compat/etc/ld.so.cache ${pkgdir}/etc/ld.so.cache
}

bin() {
    depends="$pkgname libgcc"
    mkdir -p "$subpkgdir"/usr/glibc-compat
    cp -a "$srcdir"/usr/glibc-compat/bin "$subpkgdir"/usr/glibc-compat
    cp -a "$srcdir"/usr/glibc-compat/sbin "$subpkgdir"/usr/glibc-compat
}

i18n() {
    depends="$pkgname-bin"
    arch="noarch"
    mkdir -p "$subpkgdir"/usr/glibc-compat
    cp -a "$srcdir"/usr/glibc-compat/share "$subpkgdir"/usr/glibc-compat
}
UiLgNoD-lIaMtOh
    # 将 sha512sum 文件信息也写入编译配置文件 
    cat <<UiLgNoD-lIaMtOh | tee -a alpine-pkg-glibc/APKBUILD
sha512sums="
$(sha512sum glibc-bin-2.40-0-aarch64.tar.gz)
478bdd9f7da9e6453cca91ce0bd20eec031e7424e967696eb3947e3f21aa86067aaf614784b89a117279d8a939174498210eaaa2f277d3942d1ca7b4809d4b7e  nsswitch.conf
2912f254f8eceed1f384a1035ad0f42f5506c609ec08c361e2c0093506724a6114732db1c67171c8561f25893c0dd5c0c1d62e8a726712216d9b45973585c9f7  ld.so.conf"
UiLgNoD-lIaMtOh
    #  写入编译过程脚本
    cat <<'UiLgNoD-lIaMtOh' | tee build.sh
chsh -s /bin/bash 
echo -e "$PASSWORD\n$PASSWORD" | adduser "${USERS}" 
echo "${USERS} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERS}  && chmod 0440 /etc/sudoers.d/${USERS}  
usermod -aG ${USERS},$(id -G $USER | sed 's; ;,;g'),abuild ${USERS} 
id ${USERS} 
su ${USERS} bash -c 'sudo cp -rfv /alpine-pkg-glibc ${HOME}/'
su ${USERS} bash -c 'sudo chmod -Rv 0755 ${HOME}/alpine-pkg-glibc ; sudo chown -Rv ${USER}:${USER} ${HOME}/alpine-pkg-glibc'
su ${USERS} bash -c 'git config --global user.name "UiLgNoD-lIaMtOh" ; git config --global user.email "UiLgNoD.eLgOoG@hotmail.com"'
su ${USERS} bash -c 'echo -e "\n" | abuild-keygen -a -i ; ls ${HOME}/.abuild/*rsa*'
su ${USERS} bash -c 'cd ${HOME}/alpine-pkg-glibc ; abuild checksum ; mkdir -pv ${HOME}/packages/${USER} ; abuild -r'
su ${USERS} bash -c 'sudo mv -fv ${HOME}/packages/${USER}/aarch64 ${HOME}/packages/ ; sudo rm -rfv ${HOME}/packages/${USER}'
su ${USERS} bash -c 'sudo cp -rfv ${HOME}/packages /alpine-pkg-glibc'
ls -al /alpine-pkg-glibc/packages/aarch64
cd /alpine-pkg-glibc/packages/aarch64
RSA_PUB=$(tar tvf APKINDEX.tar.gz | grep rsa | sed 's;.SIGN.RSA.;;g' | awk '{print $6}')
su ${USERS} bash -c "sudo cp -fv \${HOME}/.abuild/${RSA_PUB} /alpine-pkg-glibc/packages/aarch64/"
UiLgNoD-lIaMtOh
    #  写入以 alpine 为基础的镜像文件，并以执行脚本为主要执行命令
    cat <<'UiLgNoD-lIaMtOh' | tee Dockerfile
FROM alpine:latest
LABEL MAINTAINER="UiLgNoD-lIaMtOh <UiLgNoD.lIaMtOh@hotmail.com>"
COPY build.sh /build.sh
RUN apk add --no-cache alpine-sdk abuild-rootbld git nano sudo bash shadow
WORKDIR /
CMD ["bash","/build.sh"]
UiLgNoD-lIaMtOh
    # 构建 alpine 编译 glibc 镜像
    docker build --no-cache --platform "linux/arm64/v8" -f Dockerfile -t UiLgNoD-lIaMtOh/glibc-builder:arm64v8-2.40 . ; docker builder prune -fa ; docker rmi $(docker images -qaf dangling=true)
    # 编译支持 alpine 的 glibc 库
    docker run --rm --name "alpine-test" --platform "linux/arm64/v8" -e "USERS=UiLgNoD-lIaMtOh" -e "PASSWORD=123456" -v "./alpine-pkg-glibc:/alpine-pkg-glibc" UiLgNoD-lIaMtOh/glibc-builder:arm64v8-2.40
    # 复制编译好的包到 package 等待下一步指示
    #mkdir -pv ../package-arm64
    #cp -fv alpine-pkg-glibc/packages/aarch64/*  ../package-arm64
    cp -rfv alpine-pkg-glibc/packages/aarch64 ../package/
elif [ "${ARCH_SWITCH}" = "x86_64" ];then
    echo ${ARCH_SWITCH}
    # rm -rfv docker-glibc-builder
    # clone sgerrand/docker-glibc-builder 借用 ubuntu 编译 glibc
    git clone "https://github.com/sgerrand/docker-glibc-builder"
    # 检查最新版本 glibc 源码 https://mirrors.kernel.org/gnu/libc/ 为 2.40 版本的 tar.gz
    cd docker-glibc-builder
    # 核心
    sed -i 's;make --jobs=4;make --jobs=16;g' builder
    cat <<'UiLgNoD-lIaMtOh' | tee Dockerfile
FROM ubuntu:22.04
LABEL MAINTAINER="UiLgNoD-lIaMtOh <UiLgNoD.lIaMtOh@hotmail.com>"
ENV DEBIAN_FRONTEND=noninteractive \
    GLIBC_VERSION=2.40 \
    PREFIX_DIR=/usr/glibc-compat
RUN apt-get -q update \
        && apt-get -qy install \
                bison \
                build-essential \
                gawk \
                gettext \
                openssl \
                python3 \
                texinfo \
                wget
COPY configparams /glibc-build/configparams
COPY builder /builder
ENTRYPOINT ["/builder"]
UiLgNoD-lIaMtOh
    # 构建镜像
    docker build --no-cache --platform "linux/amd64" -f Dockerfile -t UiLgNoD-lIaMtOh/glibc-builder:amd64-2.40 . ; docker builder prune -fa ; docker rmi $(docker images -qaf dangling=true)
    # 执行 glibc 编译并打包
    docker run --platform "linux/amd64" --rm -e "GLIBC_VERSION=2.40" -e "STDOUT=1" UiLgNoD-lIaMtOh/glibc-builder:amd64-2.40 > glibc-bin-2.40-0-x86_64.tar.gz
    # 赋予编译包权限
    chmod -v +x glibc-bin-2.40-0-x86_64.tar.gz
    # clone sgerrand/alpine-pkg-glibc 为 alpine 编译可支持的 glibc 库
    git clone "https://github.com/sgerrand/alpine-pkg-glibc"
    # 把 ubuntu 编译好的 glibc 丢给 alpine 编译项目
    cp -fv glibc-bin-2.40-0-x86_64.tar.gz alpine-pkg-glibc/
    # 写入自定义编译配置信息
    cat <<'UiLgNoD-lIaMtOh' | tee alpine-pkg-glibc/APKBUILD
# MAINTAINER UiLgNoD-lIaMtOh <UiLgNoD.lIaMtOh@hotmail.com>
pkgname="glibc"
pkgver="2.40"
_pkgrel="0"
pkgrel="0"
pkgdesc="GNU C Library compatibility layer"
arch="x86_64"
url="https://github.com/sgerrand/alpine-pkg-glibc"
license="LGPL"
source="glibc-bin-$pkgver-$_pkgrel-x86_64.tar.gz
ld.so.conf"
subpackages="$pkgname-bin $pkgname-dev $pkgname-i18n"
triggers="$pkgname-bin.trigger=/lib:/usr/lib:/usr/glibc-compat/lib"
options="lib64"

package() {
  conflicts="libc6-compat"
  mkdir -p "$pkgdir/lib" "$pkgdir/usr/glibc-compat/lib/locale"  "$pkgdir"/usr/glibc-compat/lib64 "$pkgdir"/etc
  cp -a "$srcdir"/usr "$pkgdir"
  cp "$srcdir"/ld.so.conf "$pkgdir"/usr/glibc-compat/etc/ld.so.conf
  rm "$pkgdir"/usr/glibc-compat/etc/rpc
  rm -rf "$pkgdir"/usr/glibc-compat/bin
  rm -rf "$pkgdir"/usr/glibc-compat/sbin
  rm -rf "$pkgdir"/usr/glibc-compat/lib/gconv
  rm -rf "$pkgdir"/usr/glibc-compat/lib/getconf
  rm -rf "$pkgdir"/usr/glibc-compat/lib/audit
  rm -rf "$pkgdir"/usr/glibc-compat/share
  rm -rf "$pkgdir"/usr/glibc-compat/var
  ln -s /usr/glibc-compat/lib/ld-linux-x86-64.so.2 ${pkgdir}/lib/ld-linux-x86-64.so.2
  ln -s /usr/glibc-compat/lib/ld-linux-x86-64.so.2 ${pkgdir}/usr/glibc-compat/lib64/ld-linux-x86-64.so.2
  ln -s /usr/glibc-compat/etc/ld.so.cache ${pkgdir}/etc/ld.so.cache
}

bin() {
  depends="$pkgname bash libc6-compat libgcc"
  mkdir -p "$subpkgdir"/usr/glibc-compat
  cp -a "$srcdir"/usr/glibc-compat/bin "$subpkgdir"/usr/glibc-compat
  cp -a "$srcdir"/usr/glibc-compat/sbin "$subpkgdir"/usr/glibc-compat
}

i18n() {
  depends="$pkgname-bin"
  arch="noarch"
  mkdir -p "$subpkgdir"/usr/glibc-compat
  cp -a "$srcdir"/usr/glibc-compat/share "$subpkgdir"/usr/glibc-compat
}
UiLgNoD-lIaMtOh
    # 将 sha512sum 文件信息也写入编译配置文件 
    cat <<UiLgNoD-lIaMtOh | tee -a alpine-pkg-glibc/APKBUILD
sha512sums="
$(sha512sum glibc-bin-2.40-0-x86_64.tar.gz)
2912f254f8eceed1f384a1035ad0f42f5506c609ec08c361e2c0093506724a6114732db1c67171c8561f25893c0dd5c0c1d62e8a726712216d9b45973585c9f7  ld.so.conf"
UiLgNoD-lIaMtOh
    #  写入编译过程脚本
    cat <<'UiLgNoD-lIaMtOh' | tee build.sh
chsh -s /bin/bash 
echo -e "$PASSWORD\n$PASSWORD" | adduser "${USERS}" 
echo "${USERS} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERS}  && chmod 0440 /etc/sudoers.d/${USERS}  
usermod -aG ${USERS},$(id -G $USER | sed 's; ;,;g'),abuild ${USERS} 
id ${USERS} 
su ${USERS} bash -c 'sudo cp -rfv /alpine-pkg-glibc ${HOME}/'
su ${USERS} bash -c 'sudo chmod -Rv 0755 ${HOME}/alpine-pkg-glibc ; sudo chown -Rv ${USER}:${USER} ${HOME}/alpine-pkg-glibc'
su ${USERS} bash -c 'git config --global user.name "UiLgNoD-lIaMtOh" ; git config --global user.email "UiLgNoD.eLgOoG@hotmail.com"'
su ${USERS} bash -c 'echo -e "\n" | abuild-keygen -a -i ; ls ${HOME}/.abuild/*rsa*'
su ${USERS} bash -c 'cd ${HOME}/alpine-pkg-glibc ; abuild checksum ; mkdir -pv ${HOME}/packages/${USER} ; abuild -r'
su ${USERS} bash -c 'sudo mv -fv ${HOME}/packages/${USER}/x86_64 ${HOME}/packages/ ; sudo rm -rfv ${HOME}/packages/${USER}'
su ${USERS} bash -c 'sudo cp -rfv ${HOME}/packages /alpine-pkg-glibc'
ls -al /alpine-pkg-glibc/packages/x86_64
cd /alpine-pkg-glibc/packages/x86_64
RSA_PUB=$(tar tvf APKINDEX.tar.gz | grep rsa | sed 's;.SIGN.RSA.;;g' | awk '{print $6}')
su ${USERS} bash -c "sudo cp -fv \${HOME}/.abuild/${RSA_PUB} /alpine-pkg-glibc/packages/x86_64/"
UiLgNoD-lIaMtOh
    #  写入以 alpine 为基础的镜像文件，并以执行脚本为主要执行命令
    cat <<'UiLgNoD-lIaMtOh' | tee Dockerfile
FROM alpine:latest
LABEL MAINTAINER="UiLgNoD-lIaMtOh <UiLgNoD.lIaMtOh@hotmail.com>"
COPY build.sh /build.sh
RUN apk add --no-cache alpine-sdk abuild-rootbld git nano sudo bash shadow
WORKDIR /
CMD ["bash","/build.sh"]
UiLgNoD-lIaMtOh
    # 构建 alpine 编译 glibc 镜像
    docker build --no-cache --platform "linux/amd64" -f Dockerfile -t UiLgNoD-lIaMtOh/glibc-builder:amd64-2.40 . ; docker builder prune -fa ; docker rmi $(docker images -qaf dangling=true)
    # 编译支持 alpine 的 glibc 库
    docker run --rm --name "alpine-test" --platform "linux/amd64" -e "USERS=UiLgNoD-lIaMtOh" -e "PASSWORD=123456" -v "./alpine-pkg-glibc:/alpine-pkg-glibc" UiLgNoD-lIaMtOh/glibc-builder:amd64-2.40
    # 复制编译好的包到 package 等待下一步指示
    #mkdir -pv ../package-arm64
    #cp -fv alpine-pkg-glibc/packages/x86_64/* ../package-amd64/
    cp -rfv alpine-pkg-glibc/packages/x86_64 ../package/
else
    echo "不支持，请自定义编写判断条件，并编译自己设备架构的 alpine glibc 包，退出"
    exit 1
fi
