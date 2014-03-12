#!/bin/bash

ROOT=$(pwd)
argv=$@
TRAPMSG=

xthome=/usr/local/xtuple
logfile=$ROOT/install.log
xtremote_pass=
xt_adminpw=
xtversion=1.8.0   # parameterize this; bad coupling with install.js
pgversion=9.1
plv8version=1.4.0
nginxverison=1.4.6

install_xtuple () {
  xtversion=$1

  versiondir=$xthome/src/$xtversion
  mkdir -p $versiondir

  appdir=$versiondir/xtuple
  cd $versiondir
  #mkdir -p src/private-extensions
  #mkdir -p src/xtuple-extensions

  rm -rf installer
  rm -rf xtuple-extensions
  rm -rf private-extensions
  rm -rf xtuple

  git config --global credential.helper 'cache --timeout=1800'

  log "Downloading installers...\n"
  git clone --recursive https://github.com/xtuple/xtuple-scripts.git installer
  git clone --recursive https://github.com/xtuple/xtuple-extensions.git
  git clone https://github.com/xtuple/private-extensions.git
  git clone --recursive https://github.com/xtuple/xtuple.git

  # TODO install using npm

  cd $appdir
  tag="v$xtversion"
  git checkout $tag
  sudo npm install

  log "Cloned xTuple $tag."

  cd ../installer
  #git checkout $tag
  sudo npm install
  eval "sudo node lib/sys/install.js install \
    --xt-version $xtversion --xt-appdir $appdir --xt-adminpw $xt_adminpw $argv"
}

install_rhel () {
  echo "TODO support rhel"
  exit 1;

  #sudo useradd -p $MAINTENANCEPASS remote
  #sudo usermod -G wheel xtremote

  #yum install postgres93-server
  #plv8 is in here: http://yum.postgresql.org/news-packagelist.php
}

install_debian () {
  log "Checking Operating System..."
  os=$(lsb_release -s -d)
  dist=$(lsb_release -s -c)
  log "   Found $os\n"
  [[ $os =~ '12.04' ]] || die "Operating System not supported"

  if [[ -z $(which node npm) ]]; then
    log "Adding Debian Repositories..."

    sudo apt-get -q -y update | tee -a $logfile
    sudo apt-get -q -y autoremove --force-yes
    sudo apt-get -q -y install python-software-properties --force-yes
    
    sudo wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null
    sudo add-apt-repository ppa:nginx/stable -y
    sudo add-apt-repository ppa:chris-lea/node.js-legacy -y
    sudo add-apt-repository ppa:chris-lea/node.js -y
    sudo add-apt-repository ppa:git-core/ppa -y
   
    log "Installing Debian Packages..."
    sudo apt-get -q -y update | tee -a $logfile
    # TODO versionize postgres
    sudo apt-get -q -y --force-yes install curl build-essential libssl-dev openssh-server cups \
      git=1:1.9.0-1~ppa0~${dist}1 \
      postgresql-$pgversion postgresql-server-dev-$pgversion postgresql-contrib-$pgversion \
      postgresql-$pgversion-plv8=$plv8version.ds-2.pgdg12.4+1 \
      nginx-full=$nginxversion-1+${dist}0 \
      nodejs=0.8.26-1chl1~${dist}1 \
      npm=1.3.0-1chl1~${dist}1 \
    | tee -a $logfile
  fi
}

setup_policy () {
  if [[ -z $(id -u xtuple) && -z $(id -u xtremote) ]]; then
    log "Creating users..."

    xtremote_pass=$(head -c 8 /dev/urandom | base64 | sed "s/[=\s]//g")
    xt_adminpw=$(head -c 4 /dev/urandom | base64 | sed "s/[=\s]//g")
   
    sudo addgroup xtuple
    sudo adduser xtuple  --system --home /usr/local/xtuple
    sudo adduser xtuple xtuple
    sudo useradd -p $xtremote_pass xtremote -d /usr/local/xtuple
    sudo usermod -a -G xtuple,www-data,postgres,lpadmin xtremote
    sudo chown :xtuple /usr/local/xtuple
  elif [[ -z $(service xtuple) ]]; then
    echo -e "It looks like an installation was started, but did not complete successfully."
    echo -e "Please restore the system to a clean state"
    exit 1
  else
    echo -e "xTuple is already installed."
    service xtuple
    exit 2
  fi

  echo ""
  log "SSH Remote Access Credentials"
  log "   username: xtremote"
  echo "[xtuple]    password: $xtremote_pass"
  echo ""
  log "WRITE THIS DOWN. This information is about to be destroyed forever."
  log "You have been warned."
  echo ""
  log "Press Enter to continue installation..."

  read
  xtremote_pass=

  # TODO remove root from sshd config
  # TODO set root shell to limbo
}

log() {
  echo -e "[xtuple] $@"
  echo -e "[xtuple] $@" >> $logfile
}
die() {
  TRAPMSG="$@"
  log $@
  exit 1
}

trap 'CODE=$? ; log "\n\nxTuple Install Aborted:\n  line: $BASH_LINENO \n  cmd: $BASH_COMMAND \n  code: $CODE\n  msg: $TRAPMSG\n" ; exit 1' ERR EXIT

log "This program will install xTuple\n"
log "         xxx     xxx"
log "          xxx   xxx "
log "           xxx xxx  "
log "            xxxxx   "
log "           xxx xxx  "
log "          xxx   xxx "
log "         xxx     xxx\n"

if [[ ! -z $(which yum) ]]; then
  install_rhel
elif [[ ! -z $(which apt-get) ]]; then
  install_debian
  echo ''
else
  log "supported package manager not found"
  exit 1;
fi

setup_policy
install_xtuple $1
