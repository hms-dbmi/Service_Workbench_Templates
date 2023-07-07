#!/usr/bin/env bash

# ADD IPtables rules
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo service iptables save

sudo yum-config-manager --setopt="epel.priority=10" epel --save || true

#SELinux stuff
sudo /sbin/selinuxenabled >& /dev/null
if [ $? -eq 0 ]; then
  export SELINUX=true
  sudo yum install -y policycoreutils-python setroubleshoot setools
  sudo setsebool -P httpd_can_network_relay 1
  sudo semanage port -m -t http_port_t -p tcp 8787
  export TMP_DIR="/home/ec2-user"
fi

[ -z "$SELINUX" ] && sudo timedatectl set-timezone UTC

# Various development packages needed to compile R
sudo yum downgrade -y libcurl curl # for curl-7.88
sudo yum install -y gcc-7.3.* gcc-gfortran-7.3.* gcc-c++-7.3.*
sudo yum install -y java-1.8.0-openjdk-devel-1.8.0.*
sudo yum install -y readline-devel-6.2 zlib-devel-1.2.* bzip2-devel-1.0.* xz-devel-5.2.* pcre-devel-8.32
sudo yum install -y libcurl-devel-7.88.* libpng-devel-1.5.* cairo-devel-1.15.* pango-devel-1.42.*
sudo yum install -y xorg-x11-server-devel-1.20.* libX11-devel-1.6.* libXt-devel-1.1.*

# Install R from source (https://docs.rstudio.com/resources/install-r-source/)
R_VERSION="4.1.3"
mkdir -p "$TMP_DIR/tmp/R/"
cd "$TMP_DIR/tmp/R/"
curl -s "https://cran.r-project.org/src/base/R-4/R-${R_VERSION}.tar.gz" > "R-${R_VERSION}.tar.gz"
tar xvf "R-${R_VERSION}.tar.gz"
cd "R-${R_VERSION}/"
./configure --enable-memory-profiling --enable-R-shlib --with-blas --with-lapack --with-pcre1
sudo make
sudo make install
cd "../../.."

# Set permissions for lib
[ -n "$SELINUX" ] && sudo chmod -R 755 /usr/local/lib64


# Cleanup R install tmp folder
sudo rm -rf "$TMP_DIR/tmp/R"

# Install RStudio
rstudio_rpm="rstudio-server-rhel-1.4.1717-x86_64.rpm"
sudo yum install -y "https://download2.rstudio.org/server/centos7/x86_64/${rstudio_rpm}"
[ -n "$SELINUX" ] && sudo chcon -R -t bin_t /usr/lib/rstudio-server/bin/
sudo systemctl enable --now rstudio-server

# Create a user for RStudio to use; its password is set at boot time
sudo useradd -m rstudio-user

#Generate self signed certificate
commonname=$(uname -n)
password=dummypassword
mkdir -p "/tmp/rstudiov2/ssl" "$TMP_DIR/tmp/rstudiov2/ssl"
chmod 700 $TMP_DIR/tmp/rstudiov2/ssl
cd $TMP_DIR/tmp/rstudiov2/ssl
openssl genrsa -des3 -passout pass:$password -out cert.key 2048
#Remove passphrase from the key. Comment the line out to keep the passphrase
openssl rsa -in cert.key -passin pass:$password -out cert.key
openssl req -new -key cert.key -out cert.csr -passin pass:$password \
    -subj "/C=NA/ST=NA/L=NA/O=NA/OU=SWB/CN=$commonname/emailAddress=example.com"
openssl x509 -req -days 365 -in cert.csr -signkey cert.key -out cert.pem
cd "../../.."

# Install and configure nginx
sudo amazon-linux-extras install -y nginx1
sudo openssl dhparam -out "/etc/nginx/dhparam.pem" 2048
sudo mv "$TMP_DIR/tmp/rstudiov2/ssl/cert.pem" "/etc/nginx/"
sudo mv "$TMP_DIR/tmp/rstudiov2/ssl/cert.key" "/etc/nginx/"
sudo mv "/tmp/rstudio/nginx.conf" "/etc/nginx/"
sudo chown -R nginx:nginx "/etc/nginx"
sudo chmod -R 600 "/etc/nginx"
sudo systemctl enable --now nginx

# Install script that sets the service workbench user password at boot
sudo mv "/tmp/rstudio/secret.txt" "/root/"
sudo chown root: "/root/secret.txt"
sudo chmod 600 "/root/secret.txt"
sudo mv "/tmp/rstudio/set-password" "/usr/local/bin/"
sudo chown root: "/usr/local/bin/set-password"
sudo chmod 775 "/usr/local/bin/set-password"
echo '@reboot /usr/local/bin/set-password 2>&1 >> /var/log/set-password.log' | sudo tee -a /var/spool/cron/root

# Install script that checks idle time and shuts down if max idle is reached
sudo mv "/tmp/rstudio/check-idle" "/usr/local/bin/"
sudo chown root: "/usr/local/bin/check-idle"
sudo chmod 775 "/usr/local/bin/check-idle"
echo '*/2 * * * * /usr/local/bin/check-idle 2>&1 >> /var/log/check-idle.log' | sudo tee -a /var/spool/cron/root

# Cleanup RStudio install tmp folder
sudo rm -rf "/tmp/rstudio" "$TMP_DIR/tmp/rstudiov2/ssl"

# Install system packages necessary for installing R packages through RStudio CRAN [devtools, tidyverse]
sudo yum install -y git-2.23.* openssl-devel-1.0.* libxml2-devel-2.9.*
libgit2_rpm="libgit2-0.26.6-1.el7.x86_64.rpm"
libgit2_devel_rpm="libgit2-devel-0.26.6-1.el7.x86_64.rpm"
sudo yum install -y "http://mirror.centos.org/centos/7/extras/x86_64/Packages/${libgit2_rpm}"
sudo yum install -y "http://mirror.centos.org/centos/7/extras/x86_64/Packages/${libgit2_devel_rpm}"

# Other recommended system packages for installing R packages (https://docs.rstudio.com/rsc/post-setup-tool/)
sudo yum groupinstall -y 'Development Tools'            # Compiling tools
sudo yum install -y libssh2-devel-1.4.*                 # Client SSH

# Install CMAKE(3) for packages that need it
sudo yum remove -y cmake || true
sudo yum install -y cmake3
[ -h /usr/bin/cmake ] || sudo ln -fs /usr/bin/cmake3 /usr/bin/cmake

sudo yum install -y libjpeg-turbo-2.0.* libjpeg-turbo-devel-2.0.*    # Images
sudo yum install -y ImageMagick-6.9.* ImageMagick-c++-devel-6.9.*    # Images
sudo yum install -y mesa-libGLU-devel-9.0.*                          # Graphs
sudo yum install -y freetype-devel-2.8 harfbuzz-devel-1.7.*          # Font

sudo yum install -y mariadb-devel-5.5.*                       # MariaDB/MySQL client & server packages
sudo yum install -y unixODBC-devel-2.3.*                      # ODBC API client
sudo yum install -y gmp-devel-6.0.*                           # GNU MP arbitrary precision library
