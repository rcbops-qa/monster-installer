change_creds(){
  echo "Please enter the username of the Rackspace Public Cloud account for your Monster server: "; read CHEF_USER
  echo "Please enter the account number for $CHEF_USER: "; read CHEF_ID
  echo "Please enter the API Key for $CHEF_USER: "; read CHEF_API
  echo "Please enter the region for the Monster server (DFW, IAD, ORD): "; read REGION1

  printf "export OS_AUTH_URL=https://identity.api.rackspacecloud.com/v2.0/\nexport OS_AUTH_SYSTEM=rackspace\nexport OS_REGION_NAME=$REGION1\nexport OS_USERNAME=$CHEF_USER\nexport OS_TENANT_NAME=$CHEF_ID\nexport NOVA_RAX_AUTH=1\nexport OS_PASSWORD=$CHEF_API\nexport OS_PROJECT_ID=$CHEF_ID\nexport OS_NO_CACHE=1" > ~/.bash_profile
  chmod 600 ~/.bash_profile
  source ~/.bash_profile
  nova credentials 2> nova.error
  NOVA_ERROR=$( cat nova.error | wc -l )
  if [ $NOVA_ERROR == "1" ]; then
    echo "The credentials for $CHEF_USER are invalid. This program will now terminate."
    exit
  fi
}

install_nova(){
  apt-get install python-pip -y > /dev/null
  pip install rackspace-novaclient > /dev/null
  apt-get install git -y > /dev/null
  git clone git://github.com/openstack/python-novaclient.git > /dev/null
  cd ~/python-novaclient
  sudo pip install --requirement requirements.txt > /dev/null
  sudo python setup.py install > /dev/null

  change_creds
}

verify_creds(){
  source ~/.bash_profile
  nova credentials 2> nova.error
  NOVA_ERROR=$( cat nova.error | wc -l )
  if [ $NOVA_ERROR == "1" ]; then
    echo "The credentials for $CHEF_USER are invalid. This program will now terminate."
    exit
  fi
}

wait_with_message() {
  printf "Commencing Monster build...5";sleep 1
  printf "\b4";sleep 1
  printf "\b3";sleep 1
  printf "\b2";sleep 1
  printf "\b1";sleep 1
  printf "\b0\n"
}

build_server(){
  PASSWORD=$( nova boot --image 80fbcb55-b206-41f9-9bc2-2dd7aac6c061 --flavor 4 $chef_name | grep adminPass | awk '{print $4}' )
  STATE=$( nova list | grep $chef_name | awk '{print $6}' )
  PROGRESS=$( nova show $chef_name | grep progress | awk '{print $4}' )
  echo "$STATE $PROGRESS%"
  while [[ $STATE != "ACTIVE" ]]
  do
    sleep 15
    STATE=$( nova list | grep $chef_name | awk '{print $6}' )
    PROGRESS=$( nova show $chef_name | grep progress | awk '{print $4}' )
    echo $STATE $PROGRESS%
  done
  IP=$( nova show $chef_name | grep accessIPv4 | awk '{print $4}' )
}

reset
NOVA=$(which nova)
CHEF_USER="-NO RECORD-"

if [ -z $NOVA ]; then
  echo "Nova is not installed. You will need to install it to continue."
  while true; do
    read -p "Would you like to install Nova now?" yn
    case $yn in
      [Yy][Ee][Ss] )
              install_nova
              break;;
      [Nn][Oo] ) exit;;
      * ) echo "Please answer yes or no.";;
    esac
  done
else
  CHEF_USER=$( cat ~/.bash_profile | grep OS_USERNAME | sed 's/^.*USERNAME=//' )
  while true; do
    read -p "You currently have nova configured for $CHEF_USER. Would you like to use this account? " yn
    case $yn in
      [Yy][Ee][Ss] )
              verify_creds
              break;;
      [Nn][Oo] )
              change_creds
              verify_creds
              break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
fi




PASSWORD="-NO RECORD-"
IP="-NO RECORD-"

echo "Please select what you would like to do."
select op in "Create new Monster server" "Set up Monster on an existing server" "Quit";
do
  case $op in
    "Create new Monster server" )
        echo "Please enter the name for the new Monster server: "; read chef_name
        wait_with_message
        build_server
        printf "Server instance created (Monster is not yet installed):\nIP: $IP\nPassword: $PASSWORD\n"
        break;;
    "Set up Monster on an existing server" )
        echo "Retrieving list of servers..."
        LIST_LINES=$( nova list | wc -l )
        if [ $LIST_LINES == 4 ]; then
          echo "There are no existing servers on this account."
          exit
        fi
        nova list
        echo "Please enter the name of the existing server to install Monster on: "; read chef_name
        IP=$( nova show $chef_name | grep accessIPv4 | awk '{print $4}' )
        break;;
    "Quit" ) exit;;
    * ) echo "Please select 1..3";;
  esac
done

echo "You will now need to install and configure Monster on $chef_name."

echo "Please enter the username for the account that Monster will build in: "; read node_user
echo "Please enter the password for $node_user: "; read node_password
echo "Please enter the API Key for $node_user: "; read node_api
echo "Please enter the region for the Monster server (DFW, IAD, ORD): "; read REGION2
echo "Please enter the Razor IP (if you have one): "; read razor_ip
echo "Please enter the default password for nodes in the cluster: "; read default_pass

sudo apt-get install sshpass -y
echo "Password: $PASSWORD"
sshpass -p $PASSWORD ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet -l root $IP 'source <(curl -s https://raw.githubusercontent.com/rcbops/support-tools/master/chef-install/install-chef-server.sh)> /dev/null;exit'
echo "Password: $PASSWORD"
sshpass -p $PASSWORD ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet -l root $IP "
  apt-get install -y git python-pip virtualenvwrapper python-dev libevent-dev python-software-properties > /dev/null;
  add-apt-repository -y ppa:rwky/redis
  apt-get update
  apt-get install -y redis-server
  git clone https://github.com/rcbops-qa/rcbops-qa.git /opt/cookbooks/rcbops-qa > /dev/null;
  git clone https://github.com/opscode-cookbooks/yum.git /opt/cookbooks/yum > /dev/null;
  knife cookbook upload -a -o /opt/cookbooks/ > /dev/null;
  git clone https://github.com/rcbops-qa/monster.git ~/monster > /dev/null;
  virtualenv -p `which python2` ~/monster/.venv;
  source ~/monster/.venv/bin/activate;
  pip install -r ~/monster/requirements.txt > /dev/null;
  cd ~/monster;
  python setup.py install;
  printf \"rackspace:\n  user: $node_user\n  api_key: $node_api\n  auth_url: https://identity.api.rackspacecloud.com/v2.0/\n  region: $REGION2\n  plugin: rackspace\ncloudfiles:\n  user: $node_user\n  password: $node_password\nrazor:\n    ip: $razor_ip\ndefault_pass: $default_pass\" > secret.yaml"
rm nova.error
printf "Monster has been installed and configured on $chef_name!\nIP: $IP\nPassword: $PASSWORD\n"
printf "The configuration file can be found in the file root@$IP:~/monster/secret.yaml\n"
