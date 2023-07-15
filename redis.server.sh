. ./common.sh

read -p "Enter redis version like 5.0.9,6.0.9: " REDIS_VERSION

INSTALL_DIR="/www/server"
CONF_DIR="$INSTALL_DIR/etc"
SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
# redis server source
REDIS_DOWN="http://download.redis.io/releases/redis-$REDIS_VERSION.tar.gz"
REDIS_SRC="redis-$REDIS_VERSION"
REDIS_DIR="$REDIS_SRC"
REDIS_LOCK="$LOCK_DIR/redis.server.lock"

# redis install function
# default dir /usr/local/bin
function install_redis {
    [ -f $REDIS_LOCK ] && return

    echo "install redis..."
    cd $SRC_DIR
    [ ! -f $SRC_DIR/$REDIS_SRC$SRC_SUFFIX ] && wget $REDIS_DOWN
    tar -zxvf $REDIS_SRC$SRC_SUFFIX
    cd $REDIS_SRC
    make clean > /dev/null 2>&1
    make
    [ $? != 0 ] && error_exit "redis make err"
    make install
    [ $? != 0 ] && error_exit "redis install err"
    # copy to default conf dir
    cp -f redis.conf $CONF_DIR/redis.conf
    # config redis
    sed -i 's@^protected-mode yes@protected-mode no@' $CONF_DIR/redis.conf
    sed -i 's@^bind 127.0.0.1@#bind 127.0.0.1@' $CONF_DIR/redis.conf
    sed -i 's@^# requirepass foobared@requirepass password@' $CONF_DIR/redis.conf
    sed -i 's@^# rename-command CONFIG ""@rename-command CONFIG ""@' $CONF_DIR/redis.conf
    sed -i 's@^dbfilename dump.rdb@dbfilename redis.rdb@' $CONF_DIR/redis.conf
    mkdir -p /www/data
    sed -i 's@^dir ./@dir /www/data/@' $CONF_DIR/redis.conf
    if [ $VERS -ge 7 ]; then
        # systemctl require redis run non-daemonised
        sed -i 's@^daemonize yes@daemonize no@' $CONF_DIR/redis.conf
        # auto start script for Centos 7 and Centos 8
        cp $ROOT/redis.server.conf/redis.init.R7 /usr/lib/systemd/system/redis.service 
        systemctl daemon-reload
        systemctl start redis.service
        # auto start when start system
        systemctl enable redis.service
    else
        # only Centos 6 need daemon
        sed -i 's@^daemonize no@daemonize yes@' $CONF_DIR/redis.conf
        # auto start script for Centos 6
        auto_start_dir="/etc/rc.d/init.d"
        cp -f utils/redis_init_script $auto_start_dir/redis
        sed -i '1a# chkconfig: 2345 80 90' $auto_start_dir/redis 
        sed -i 's@^CONF="/etc/redis/${REDISPORT}.conf"@CONF="/www/server/etc/redis.conf"@' $auto_start_dir/redis 
        sed -i 's@$EXEC $CONF@$EXEC $CONF \&@' $auto_start_dir/redis 
        # chkconfig and start
        chkconfig --add redis
        service redis start
    fi
     
    echo  
    echo "install redis complete."
    touch $REDIS_LOCK
}

# Centos 7 install devtoolset
# GCC 5.3 or newer is required for Redis 6.x
function install_devtool {
    apt install -y centos-release-scl
    [ $? != 0 ] && error_exit "scl install err"
    apt install -y devtoolset-7
    [ $? != 0 ] && error_exit "devtool install err"
    echo ""
    echo "Devtoolset-7 install completed. You can install Redis Server now."
    echo ""
    scl enable devtoolset-7 bash
}

# install common dependency
function install_common {
    apt install -y sudo wget tcl
    [ $? != 0 ] && error_exit "common dependence install err"
    $(echo $REDIS_SRC | grep -q "redis-6") && V6=1 || V6=0
    if [[ $V6 -eq 1 && $VERS -eq 7 && ! -f /etc/scl/prefixes/devtoolset-7 ]]; then
        read -p "Redis $REDIS_VERSION require devtoolset on Centos 7, do you want to install? (Y/N) " CONFIRM
        if [[ $CONFIRM == "Y" ]]; then
            install_devtool
        else
            exit
        fi
    fi
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
    [ ! -d $CONF_DIR ] && mkdir -p $CONF_DIR
    install_common
    install_redis
}

start_install
