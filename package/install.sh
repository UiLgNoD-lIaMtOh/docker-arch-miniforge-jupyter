#!/usr/bin/env bash
# 下载 Mambaforge Openjdk 和 ijava 
download() {
    # 获取操作系统类型
    OS=$(uname)
    case $OS in
      'Linux')
        OS='linux'
        Distro="`cat /etc/*-release | grep '^ID='`"
        if [[ "$Distro" == *"alpine"* ]]; then
          OS="alpine-linux"
        fi
        ;;
      'Darwin') 
        OS='mac'
        ;;
      *)
        echo "Unsupported ositecture: $OS"
        exit 1
        ;;
    esac
    
    # 获取处理器架构类型
    ARCH_RAW=$(uname -m)
    case "$ARCH_RAW" in
    'x86_64') ARCH='x64' ;;
    'aarch64' | 'arm64') ARCH='aarch64' ;;
    *)
        echo "Unsupported architecture: $ARCH_RAW"
        exit 1
        ;;
    esac

    # github 项目 conda-forge/miniforge
    URI="conda-forge/miniforge"
    # 从 conda-forge/miniforge github中提取全部 tag 版本，获取最新版本赋值给 VERSION 后打印
    VERSION=$(curl -sL "https://github.com/$URI/releases" | grep -oP '(?<=\/releases\/tag\/)[^"]+' | head -n 1)
    echo $VERSION
    # 拼接下载链接 URI_DOWNLOAD 后打印版本
    URI_DOWNLOAD="https://github.com/$URI/releases/download/$VERSION/Mambaforge-$VERSION-$(uname -s)-$(uname -m).sh"
    echo $URI_DOWNLOAD
    wget -t 3 -T 5 --verbose --show-progress=on --progress=bar --no-check-certificate --hsts-file=/tmp/wget-hsts -c "${URI_DOWNLOAD}" -O"/tmp/Mambaforge.sh"

    # github 项目 adoptium/temurin22-binaries
    URI="adoptium/temurin22-binaries"
    # 从 adoptium/temurin22-binaries 官网中提取全部 tag 版本，获取最新版本赋值给 VERSIONS 后打印
    VERSIONS=$(curl -sL "https://github.com/$URI/releases" | grep -oP '(?<=\/releases\/tag\/)[^"]+' | head -n 1)
    echo $VERSIONS
    # 进一步获取 VERSION
    VERSION=$(echo ${VERSIONS#jdk-} | sed 's;%2B;_;g')
    echo $VERSION
    # 拼接下载链接 URI_DOWNLOAD 后打印
    URI_DOWNLOAD="https://github.com/$URI/releases/download/${VERSIONS}/OpenJDK22U-jdk_${ARCH}_${OS}_hotspot_${VERSION}.tar.gz"
    echo $URI_DOWNLOAD
    # 下载文件，可续传并打印进度
    wget -t 3 -T 10 --verbose --show-progress=on --progress=bar --no-check-certificate --hsts-file=/tmp/wget-hsts -c "${URI_DOWNLOAD}" -O"/tmp/OpenJDK-jdk_hotspot.tar.gz"

    # github 项目 SpencerPark/IJava
    URI="SpencerPark/IJava"
    # 从 SpencerPark/IJava github中提取全部 tag 版本，获取最新版本赋值给 VERSION 后打印
    VERSION=$(curl -sL "https://github.com/$URI/releases" | grep -oP '(?<=\/releases\/tag\/)[^"]+' | head -n 1)
    echo $VERSION
    # 拼接下载链接 URI_DOWNLOAD 后打印 v1.3.0
    URI_DOWNLOAD="https://github.com/$URI/releases/download/$VERSION/ijava-$(echo $VERSION | sed 's;^v;;g').zip"
    echo $URI_DOWNLOAD
    # 下载文件，可续传并打印进度
    wget -t 3 -T 10 --verbose --show-progress=on --progress=bar --no-check-certificate --hsts-file=/tmp/wget-hsts -c "${URI_DOWNLOAD}" -O"/tmp/ijava.zip"
}

# 配置 mambaforge 安装 python
config_mambaforge() {
    # 将执行脚本移动到可执行目录并授权
    mv -fv run_jupyter /usr/bin/
    chmod -v u+x /usr/bin/run_jupyter
    
    # 写入汉化配置环境
    cat << UiLgNoD-lIaMtOh | tee -a /etc/environment
LANG=zh_CN.UTF-8
LC_CTYPE="zh_CN.UTF-8"
LC_NUMERIC="zh_CN.UTF-8"
LC_TIME="zh_CN.UTF-8"
LC_COLLATE="zh_CN.UTF-8"
LC_MONETARY="zh_CN.UTF-8"
LC_MESSAGES="zh_CN.UTF-8"
LC_PAPER="zh_CN.UTF-8"
LC_NAME="zh_CN.UTF-8"
LC_ADDRESS="zh_CN.UTF-8"
LC_TELEPHONE="zh_CN.UTF-8"
LC_MEASUREMENT="zh_CN.UTF-8"
LC_IDENTIFICATION="zh_CN.UTF-8"
LC_ALL=
UiLgNoD-lIaMtOh
    
    bash /tmp/Mambaforge.sh -b -p /opt/miniforge3
    ln -s /opt/miniforge3/etc/profile.d/conda.sh /etc/profile.d/conda.sh
    echo ". /opt/miniforge3/etc/profile.d/conda.sh" >> $HOME/.bashrc
    echo "conda activate base" >> $HOME/.bashrc
    find /opt/miniforge3/ -follow -type f -name '*.a' -delete
    find /opt/miniforge3/ -follow -type f -name '*.js.map' -delete
    /opt/miniforge3/bin/conda clean -afy
    
    # 写入 miniforge 环境变量
    cat << 'UiLgNoD-lIaMtOh' | tee -a $HOME/.bashrc
export PATH=/opt/miniforge3/bin:$PATH
UiLgNoD-lIaMtOh
    
    export PATH=/opt/miniforge3/bin:$PATH
    
    # 显示请求和进度条
    conda config --set show_channel_urls yes
    
    # 排序
    conda config --get channels
    
    # 清理索引
    conda clean -i -y
    
    # 查看源
    conda config --show-sources

    rm -fv /tmp/Mambaforge.sh
}

# 配置 jdk
config_jdk() {
    # 解压缩
    tar xvf /tmp/OpenJDK-jdk_hotspot.tar.gz -C /opt/
    
    # 写入 java 环境变量
    cat << EOF | tee -a $HOME/.bashrc
export JAVA_HOME=/opt/$(ls -al /opt | grep jdk | awk '{print $9}' | tail -1)
export CLASSPATH=.:\$JAVA_HOME/lib/tools.jar:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
    rm -fv /tmp/OpenJDK-jdk_hotspot.tar.gz
}

# 安装配置 jupyter
install_config_jupyter() {
    # 使用 mamba 创建一个名为cling
    # 参考: https://github.com/jupyter-xeus/xeus-cling#installation-with-mamba-or-conda
    #mamba create -n cling
    #source activate cling

    # 写入 cling 为默认环境
    #cat << 'UiLgNoD-lIaMtOh' | tee -a $HOME/.bashrc
#source activate cling
#UiLgNoD-lIaMtOh

    # 尝试重新安装zlib包，更新 mamba 和 conda
    mamba install -fy zlib
    mamba update -n base -c defaults mamba -y
    conda update -n base -c defaults conda -y

    # 创建 python 软链接
    if [ -e $(command -v python3) ]
    then
        ln -fsv $(command -v python3) /usr/bin/python
        ln -fsv $(command -v pip3) /usr/bin/pip
    else
        echo "python3 没找到"
    fi

    # 安装 C 语言解释器，支持 C 语言扩展
    #mamba install -c conda-forge xeus-cling -y --quiet

    # 并清理缓存
    mamba clean --all -y

    # 获取Python版本
    version=$(python --version 2>&1 | awk '{print $2}')
    IFS='.' read -ra ADDR <<< "$version"

    # 检查版本是否为2
    if [[ ${ADDR[0]} -eq 2 ]]
    then
        echo "版本过低 python2"
    elif [[ ${ADDR[0]} -eq 3 ]]
    then
        # 检查版本是否小于等于3.10
        if [[ ${ADDR[1]} -le 10 ]]
        then
            echo "python 版本 ${ADDR}"
            python -m pip --no-cache-dir install -v --upgrade pip 
            python -m pip --no-cache-dir install -v -r requirements.txt
            # python -m pip --no-cache-dir install -v --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
            # python -m pip --no-cache-dir install -v -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
        else
            echo "python 版本 ${ADDR}"
            python -m pip --no-cache-dir install -v --upgrade pip --break-system-packages
            python -m pip --no-cache-dir install -v -r requirements.txt --break-system-packages
            # python -m pip --no-cache-dir install -v --upgrade pip --break-system-packages -i https://pypi.tuna.tsinghua.edu.cn/simple
            # python -m pip --no-cache-dir install -v -r requirements.txt --break-system-packages -i https://pypi.tuna.tsinghua.edu.cn/simple
        fi
    else
        echo "超出版本预期，脚本需要更新！！"
    fi
    
    # 生成 jupyter 默认配置文件
    echo y | jupyter-notebook --generate-config --allow-root
    
    # 查看 jupyter 版本
    jupyter --version
    rm -fv requirements.txt
}

# 配置 ijava 扩展
config_ijava(){
    # 安装 ijava 支持扩展
    unzip -o -d /tmp/ijava /tmp/ijava.zip
    cd /tmp/ijava
    python install.py --sys-prefix
    rm -fv /tmp/ijava.zip
}

download
config_mambaforge
config_jdk
install_config_jupyter
config_ijava
