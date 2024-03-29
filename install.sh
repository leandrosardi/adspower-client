# need a login shell for running rvm and ruby
# reference: https://stackoverflow.com/questions/9336596/rvm-installation-not-working-rvm-is-not-a-function
#
# If you connect via SSH, run this file using the following command:
# /bin/bash --login install.sh

# Install GUI on Contabo VPS
# Reference: https://contabo.com/blog/installation-of-a-graphical-user-interface-for-linux/

# update packages
echo "update packages"
sudo apt -y update
sudo apt -y upgrade

# install other required packages
echo "install other required packages"
sudo apt install -y net-tools
sudo apt install -y gnupg2
#sudo apt install -y nginx
#sudo apt install -y sshpass
#sudo apt install -y xterm
#sudo apt install -y bc
sudo apt install -y unzip
sudo apt install -y curl

# get private key for RVM
echo "get private key for RVM"
gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

# move into a writable location such as the /tmp
echo "move into a writable location such as the /tmp"
cd /tmp

# download RVM
echo "download rvm"
curl -sSL https://get.rvm.io -o rvm.sh
# install the latest stable Rails version
echo "install rvm"
bash /tmp/rvm.sh
# fix the issue "RVM is not a function"
# reference: https://stackoverflow.com/questions/9336596/rvm-installation-not-working-rvm-is-not-a-function
source ~/.rvm/scripts/rvm
type rvm | head -n 1

# fix: 
# Warning: can not check `/etc/sudoers` for `secure_path`, falling back to call via `/usr/bin/env`, this breaks rules from `/etc/sudoers`.
# Run `export rvmsudo_secure_path=1` to avoid the warning, put it in shell initialization to make it persistent.
export rvmsudo_secure_path=1

# install and run Ruby 3.1.2
# reference: https://superuser.com/questions/376669/why-am-i-getting-rvm-command-not-found-on-ubuntu
echo
echo "install Ruby 3.1.2"
rvmsudo rvm install 3.1.2

# set 3.1.2 as default Ruby version
echo "set 3.1.2 as default Ruby version"
rvm --default use 3.1.2

# check ruby installed
ruby -v

# install git
echo "install git"
sudo apt install -y git

# grant me permission on ~/.rvm and all its subdirectories
sudo chmod -R 777 ~/.rvm

# install bundler
echo "install bundler"
gem install bundler -v '2.3.7'

# Install Chrome Driver
# Reference:
# - https://stackoverflow.com/questions/50642308/webdriverexception-unk
#
sudo wget https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/116.0.5845.96/linux64/chromedriver-linux64.zip
sudo chmod 777 chromedriver-linux64.zip
unzip chromedriver-linux64.zip
sudo mv chromedriver-linux64/* /usr/bin
sudo chown root:root /usr/bin/chromedriver
sudo chmod +x /usr/bin/chromedriver
sudo rm -rf ./chromedriver-linux64.zip
sudo rm -rf ./chromedriver-linux64

# Install AdsPower
wget https://version.adspower.net/software/linux-x64-global/AdsPower-Global-5.9.14-x64.deb
sudo chmod 777 AdsPower-Global-5.9.14-x64.deb
sudo dpkg -i AdsPower-Global-5.9.14-x64.deb
sudo apt install -y ./AdsPower-Global-5.9.14-x64.deb
sudo rm -rf ./AdsPower-Global-5.9.14-x64.deb

# Find the location of adspower command
sudo apt --fix-broken install
sudo apt-get install -y apt-file
sudo apt-file update
apt-file search adspower

# install PostgreSQL dev package with header of PostgreSQL
# this is required for calling the gem pg from bundler
sudo apt-get install -y libpq-dev




