#!/bin/bash
CMD=$1
#Control script to start and stop Solr 6 instances form Claudera Manager
case $CMD in
  (start)
    set -e
    SOLR_VAR_DIR=/var/$SOLR_SERVICE
    SOLR_HOME_DIR=/opt/$SOLR_SERVICE
    if [ -f "/proc/version" ]; then
      proc_version=`cat /proc/version`
    else
      proc_version=`uname -a`
    fi

    if [[ $proc_version == *"Debian"* ]]; then
      distro=Debian
    elif [[ $proc_version == *"Red Hat"* ]]; then
      distro=RedHat
    elif [[ $proc_version == *"Ubuntu"* ]]; then
      distro=Ubuntu
    elif [[ $proc_version == *"SUSE"* ]]; then
      distro=SUSE
    else
      echo -e "\nERROR: Your Linux distribution ($proc_version) not supported by this script!\nYou'll need to setup Solr as a service manually using the documentation provided in the Solr Reference Guide.\n" 1>&2
      exit 1
    fi

    if [[ ! -f /etc/init.d/$SOLR_SERVICE ]];
    then
      echo "Service $SOLR_SERVICE not installed, installing a new Solr service"
      # create a symlink for easier scripting
      ln -s $SOLR_INSTALL_DIR $SOLR_HOME_DIR
      chown -h $SOLR_USER: $SOLR_HOME_DIR

      mkdir -p $SOLR_VAR_DIR/data
      mkdir -p $SOLR_VAR_DIR/logs
      cp ${SOLR_INSTALL_DIR}server/solr/solr.xml $SOLR_VAR_DIR/data/
      cp ${SOLR_INSTALL_DIR}server/resources/log4j.properties $SOLR_VAR_DIR/log4j.properties
      sed_expr="s#solr.log=.*#solr.log=\${solr.solr.home}/../logs#"
      sed -i -e "$sed_expr" $SOLR_VAR_DIR/log4j.properties
      chown -R $SOLR_USER: $SOLR_VAR_DIR

      echo "SOLR_PID_DIR=$SOLR_VAR_DIR
SOLR_HOME=$SOLR_VAR_DIR/data
LOG4J_PROPS=$SOLR_VAR_DIR/log4j.properties
SOLR_LOGS_DIR=$SOLR_VAR_DIR/logs
SOLR_PORT=$SOLR_PORT
SOLR_HOST=\$(hostname)\
" >> $SOLR_VAR_DIR/solr.in.sh

      echo "Creating /etc/init.d/$SOLR_SERVICE script ..."
      cp ${SOLR_INSTALL_DIR}bin/init.d/solr /etc/init.d/$SOLR_SERVICE
      chmod 744 /etc/init.d/$SOLR_SERVICE
      chown root:root /etc/init.d/$SOLR_SERVICE

      # do some basic variable substitution on the init.d script
      sed_expr1="s#SOLR_INSTALL_DIR=.*#SOLR_INSTALL_DIR=$SOLR_HOME_DIR#"
      sed_expr2="s#SOLR_ENV=.*#SOLR_ENV=$SOLR_VAR_DIR/solr.in.sh#"
      sed_expr3="s#RUNAS=.*#RUNAS=$SOLR_USER#"
      sed_expr4="s#Provides:.*#Provides: $SOLR_SERVICE#"
      sed -i -e "$sed_expr1" -e "$sed_expr2" -e "$sed_expr3" -e "$sed_expr4" /etc/init.d/$SOLR_SERVICE

      if [[ "$distro" == "RedHat" || "$distro" == "SUSE" ]]; then
        chkconfig $SOLR_SERVICE on
      else
        update-rc.d $SOLR_SERVICE defaults
      fi
      echo "Service $SOLR_SERVICE installed."
    fi
    export SOLR_INCLUDE=$SOLR_VAR_DIR/solr.in.sh
    #All the parameters should be passed as environnment variable understandable by the Solr 6 scripts
    exec $SOLR_HOME_DIR/bin/solr start -f  -V
    ;;
  (stop)
    echo "Stopping Solr  on port $SOLR_PORT"
    export SOLR_INCLUDE=$SOLR_VAR_DIR/solr.in.sh
    SOLR_HOME_DIR=/opt/$SOLR_SERVICE
    $SOLR_HOME_DIR/bin/solr stop -p $SOLR_PORT -V
    ;;
  (*)
    echo "Don't understand [$CMD]"
    ;;
esac