# Ubuntu Automation
This project contains a series of scripts that allow you to automate the installation of an Ubuntu 14.04 server. It is simpler to maintain than say Puppet or Chef - and is ideal when you are working with small numers of server installations. It automatically hardens Apache and installs antivirus and other protective measures.

## 

## Usage

Install a fresh Ubuntu 14.04 server with no other options than OpenSSH server. Then connect to the machine using ssh as root user. When connected as a non root user - you can su to root like this:   

```
sudo su root
```

Then run an apt update and install Git.  
 
```
apt-get update
apt-get install git
```

Now clone the script to the server.  

```
cd /tmp
git clone https://github.com/lauritssn/ubuntu-automation.git
```

Then run the installation script.  

```
cd ubuntu-automation
bash install.sh
```

## License
Please see the LICENSE file for licensing questions. These scripts are licensed under **Apache License Version 2.0**.



