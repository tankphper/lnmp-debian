. ./common.sh

INSTALL_DIR="/www/server"
LOCK_DIR="$ROOT/lock"
SRC_DIR="$ROOT/src"
SRC_SUFFIX=".tar.gz"
# mysql source
MYSQL_DOWN="https://cdn.mysql.com/archives/mysql-5.7/mysql-5.7.23.tar.gz"
MYSQL_SRC="mysql-5.7.23"
MYSQL_DIR="$MYSQL_SRC"
MYSQL_LOCK="$LOCK_DIR/mysql.lock"
# cmake tool source
CMAKE_DOWN="https://cmake.org/files/v3.11/cmake-3.11.4.tar.gz"
CMAKE_SRC="cmake-3.11.4"
CMAKE_DIR="$CMAKE_SRC"
CMAKE_LOCK="$LOCK_DIR/cmake.lock"
# boost 1.59.0 for mysql 5.7.x, 1.72.0 for mysql 8.x
#BOOST_DOWN="https://gitlab.com/lnmp-shell/lnmp-files/-/raw/master/boost_1_72_0.tar.gz"
BOOST_DOWN="https://gitlab.com/lnmp-shell/lnmp-files/-/raw/master/boost_1_59_0.tar.gz"
BOOST_SRC="boost_1_59_0"
BOOST_DIR="$BOOST_SRC"
BOOST_LOCK="$LOCK_DIR/boost.lock"
# Debian missing rpcgen
RPCGEN_DOWN="https://github.com/thkukuk/rpcsvc-proto/releases/download/v1.4.2/rpcsvc-proto-1.4.2.tar.xz"
RPCGEN_SRC="rpcsvc-proto-1.4.2"
RPCGEN_LOCK="$LOCK_DIR/mysql.rpcgen.lock"
# common dependency fo mysql
COMMON_LOCK="$LOCK_DIR/mysql.common.lock"

# mysql install function
function install_mysql {
    
    [ ! -f /usr/bin/rpcgen ] && install_rpcgen
    [ ! -f /usr/local/bin/cmake ] && install_cmake 
    [ ! -d /usr/local/src/$BOOST_SRC ] && install_boost

    [ -f $MYSQL_LOCK ] && return
    
    echo "install mysql..."
    
    cd $SRC_DIR
    [ ! -f $MYSQL_SRC$SRC_SUFFIX ] && wget $MYSQL_DOWN
    tar -zxvf $MYSQL_SRC$SRC_SUFFIX
    cd $MYSQL_SRC
    make clean > /dev/null 2>&1
    # sure datadir is empty
    # sure boost dir path
    # maybe download boost will timeout
    cmake . -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/$MYSQL_DIR \
        -DMYSQL_DATADIR=$INSTALL_DIR/$MYSQL_DIR/data \
        -DSYSCONFDIR=$INSTALL_DIR/etc \
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_PARTITION_STORAGE_ENGINE=1 \
        -DWITH_FEDERATED_STORAGE_ENGINE=1 \
        -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
        -DWITH_MYISAM_STORAGE_ENGINE=1 \
        -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
        -DWITH_READLINE=1 \
        -DENABLED_LOCAL_INFILE=1 \
        -DENABLE_DTRACE=0 \
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci \
        -DWITH_EMBEDDED_SERVER=1 \
        -DDOWNLOAD_BOOST=0 \
        -DDOWNLOAD_BOOST_TIMEOUT=600 \
        -DWITH_BOOST=/usr/local/src/$BOOST_SRC
    [ $? != 0 ] && error_exit "mysql configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "mysql make err"
    make install
    [ $? != 0 ] && error_exit "mysql install err"
    ln -sf $INSTALL_DIR/$MYSQL_SRC $INSTALL_DIR/mysql
    ln -sf $INSTALL_DIR/mysql/bin/mysql /usr/local/bin/
    ln -sf $INSTALL_DIR/mysql/bin/mysqldump /usr/local/bin/
    ln -sf $INSTALL_DIR/mysql/bin/mysqlslap /usr/local/bin/
    ln -sf $INSTALL_DIR/mysql/bin/mysqladmin /usr/local/bin/
    # bakup config file
    [ -f /etc/my.cnf ] && mv /etc/my.cnf /etc/my.cnf.old
    # new config file
    [ ! -d $INSTALL_DIR/etc ] && mkdir $INSTALL_DIR/etc
    cp -f $ROOT/mysql.conf/my.cnf $INSTALL_DIR/etc/my.cnf
    ln -sf $INSTALL_DIR/etc/my.cnf /etc/my.cnf
    # mysql.sock file dir
    mkdir -p /var/lib/mysql && chmod 777 /var/lib/mysql
    # db file user:group
    #[ ! -d $INSTALL_DIR/mysql/data ] && mkdir $INSTALL_DIR/mysql/data
    #chown -hR mysql:mysql $INSTALL_DIR/mysql/data
    # make sure dir is writable
    chmod -R 755 /www
    # add to env path
    echo "PATH=\$PATH:$INSTALL_DIR/mysql/bin" > /etc/profile.d/mysql.sh
    # add to active lib
    echo "$INSTALL_DIR/mysql" > /etc/ld.so.conf.d/mysql-wdl.conf
    # refresh active lib
    /usr/sbin/ldconfig
    
    # init db for mysql-5.7.x
    # --initialize set password to log file
    # --initialize-insecure set a empty password
    $INSTALL_DIR/mysql/bin/mysqld --initialize-insecure --user=mysql --basedir=$INSTALL_DIR/mysql --datadir=$INSTALL_DIR/mysql/data
    # db dir user:group
    chown -hR mysql:mysql $INSTALL_DIR/mysql/data 
    # slow log file
    touch /var/log/mysql-slow.log && chown -hR mysql:root /var/log/mysql-slow.log
    # auto start script for debian
    cp -f ./support-files/mysql.server /etc/init.d/mysqld
    chmod +x /etc/init.d/mysqld
    sudo update-rc.d mysqld defaults
    systemctl daemon-reload
    systemctl start mysqld.service
    # auto start when start system
    systemctl enable mysqld.service

    # init empty password, set root password like this for mysql-5.7.x
    mysql -u root -e "use mysql;alter user 'root'@'localhost' identified by 'password'"
    
    echo  
    echo "install mysql complete."
    touch $MYSQL_LOCK
}

# cmake install function
# mysql depend cmake to compile
# cmake_dir=/usr
function install_cmake {
    [ -f $CMAKE_LOCK ] && return

    echo "install cmake..."
    cd $SRC_DIR
    [ ! -f $CMAKE_SRC$SRC_SUFFIX ] && wget $CMAKE_DOWN
    tar -zxvf $CMAKE_SRC$SRC_SUFFIX
    cd $CMAKE_SRC
    ./bootstrap --prefix=/usr
    [ $? != 0 ] && error_exit "cmake configure err"
    make
    [ $? != 0 ] && error_exit "cmake make err"
    make install
    [ $? != 0 ] && error_exit "cmake install err"
    cd $SRC_DIR
    rm -fr $CMAKE_SRC

    echo
    echo "install cmake complete."
    touch $CMAKE_LOCK
}

# boost install function
# mysql depend boost library
# boost_dir=/usr/local/src
# cmake option -DDOWNLOAD_BOOST=1 and it will download boost auto
function install_boost {
    [ -f $BOOST_LOCK ] && return

    echo "install boost..."
    cd $SRC_DIR
    [ ! -f $BOOST_SRC$SRC_SUFFIX ] && wget $BOOST_DOWN
    cp $BOOST_SRC$SRC_SUFFIX /usr/local/src
    cd /usr/local/src
    tar -zxvf $BOOST_SRC$SRC_SUFFIX
    rm -fr $BOOST_SRC$SRC_SUFFIX
    
    echo
    echo "install boost complete."
    touch $BOOST_LOCK
}

# Debian install rpcgen
function install_rpcgen {
    [ -f $RPCGEN_LOCK ] && return

    echo "install rcpgen..."
    cd $SRC_DIR
    wget $RPCGEN_DOWN
    xz -d $RPCGEN_SRC.tar.xz
    tar -xvf $RPCGEN_SRC.tar
    cd $RPCGEN_SRC
    ./configure
    [ $? != 0 ] && error_exit "rpcgen configure err"
    make
    [ $? != 0 ] && error_exit "rpcgen make err"
    make install
    [ $? != 0 ] && error_exit "rpcgen install err"
    cd $SRC_DIR
    rm -fr $RPCGEN_SRC

    echo
    echo "install rpcgen complete."
    touch $RPCGEN_LOCK
}


# install common dependency
# build-essential include c++ & g++
# mysql compile need boost default dir=/usr/share/doc/boost-1.59.0
# remove system default cmake
# mysql user:group is mysql:mysql
function install_common {
    [ -f $COMMON_LOCK ] && return
    # libncurses5 libncurses5-dev libncursesw5 libncursesw5-dev
    apt install -y sudo wget gcc build-essential libncurses-dev libtirpc-dev \
        glibc-source bison telnet tcpdump ipset lsof iptables
    [ $? != 0 ] && error_exit "common dependence install err"
    
    # create user for mysql
    #sudo groupadd -g 27 mysql > /dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    #sudo useradd -g 27 -u 27 -d /dev/null -s /sbin/nologin mysql > /dev/null 2>&1
    
    # -U create a group with the same name as the user. so it can instead groupadd and useradd
    sudo useradd -U -d /dev/null -s /sbin/nologin mysql > /dev/null 2>&1
    # set local timezone
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    # syn hardware time to system time
    /usr/sbin/hwclock -w
   
    echo 
    echo "install common dependency complete."
    touch $COMMON_LOCK
}

# install error function
function error_exit {
    echo 
    echo 
    echo "Install error :$1--------"
    echo 
    exit
}

# start install
function start_install {
    [ ! -d $LOCK_DIR ] && mkdir -p $LOCK_DIR
    install_common
    install_mysql
}

start_install
