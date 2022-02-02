#!/bin/bash

##############################################################################
# INSTALLING R, RSTUDIO SERVER AND ALL DEPENDENCIES
##############################################################################

# Add a swap file to prevent build time OOM errors
fallocate -l 16G /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl vm.swappiness=10

sysctl vm.vfs_cache_pressure=50
echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

export DEBIAN_FRONTEND=noninteractive

mkdir -p /root/.ssh /home/ubuntu/.ssh
touch "/root/.ssh/authorized_keys"
touch "/home/ubuntu/.ssh/authorized_keys"

echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGk0PvanXFve78EL4PRq70EL+6/afnBQr3atdKYcRgjA diraol@berta" | tee -a "/root/.ssh/authorized_keys" >> "/home/ubuntu/.ssh/authorized_keys"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBvCjgYwSkK3etS8pdqEKgPjAlVIGWbsbcVbuTz630h infra+amplifica@azmina.com.br" >> "/home/ubuntu/.ssh/authorized_keys"

chown ubuntu:ubuntu "/home/ubuntu/.ssh/authorized_keys"
chmod 700 /home/ubuntu/.ssh
chmod 600 /home/ubuntu/.ssh/authorized_keys

# Download rstudio server in a background task
wget -q https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2021.09.1-372-amd64.deb -O /tmp/rstudio_server_install.deb &
# Download shiny server in a background task
wget -q https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-1.5.17.973-amd64.deb -O /tmp/shiny_server_install.deb &

apt update
apt install --no-install-recommends -yqq \
    software-properties-common \
    dirmngr \
    build-essential \
    zlib1g-dev

apt-key adv \
    --keyserver keyserver.ubuntu.com \
    --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
    sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# Install R-base
apt update
apt install --no-install-recommends r-base -yqq

# Install r-server
apt install /tmp/rstudio_server_install.deb -yqq

# Install shiny package
R --no-save -e "install.packages('shiny', repos='https://cran.rstudio.com/')"

# Install shiny-server
apt install /tmp/shiny_server_install.deb -yqq

# access
mkdir -p /home/shiny/.ssh
chmod 700 /home/shiny/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGk0PvanXFve78EL4PRq70EL+6/afnBQr3atdKYcRgjA diraol@berta" >> "/home/shiny/.ssh/authorized_keys"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBvCjgYwSkK3etS8pdqEKgPjAlVIGWbsbcVbuTz630h infra+amplifica@azmina.com.br" >> "/home/shiny/.ssh/authorized_keys"
chown -R shiny:shiny "/home/shiny/.ssh"
chmod 600 /home/shiny/.ssh/authorized_keys

# Setup the shiny server
mkdir -p /src/shiny-server/amplifica
chown shiny:shiny /src/shiny-server/amplifica
sed -i 's/port 3838/port 80/g' /etc/shiny-server/shiny-server.conf
sed -i 's!site_dir /srv/shiny-server!app_dir /src/shiny-server/amplifica!g' /etc/shiny-server/shiny-server.conf
sed -i 's/directory_index on;/directory_index off;/g' /etc/shiny-server/shiny-server.conf

systemctl restart shiny-server

apt upgrade -yqq
apt autoremove -yqq

CPUS=$(nproc)
if [[ "${CPUS}" != 1 ]]; then
    CPUS=$(( CPUS - 1 ))
fi

# Install additional packages
cat << EOF > r_install_packages.R
update.packages(ask=FALSE,
    Ncpus=${CPUS},
    lib="/usr/local/lib/R/site-library",
    checkBuilt=TRUE,
    quiet=TRUE,
    repos = "http://cran.us.r-project.org")

install.packages(lib="/usr/local/lib/R/site-library",
c(
    "R.utils",
    "stringr",
    "tidyverse"
    ),
    Ncpus=${CPUS},
    ask=FALSE,
    checkBuilt=TRUE,
    quiet=TRUE,
    repos = "http://cran.us.r-project.org"
)

q()
EOF
chmod +rw r_install_packages.R
R --no-save < r_install_packages.R

echo "www-port=80" > /etc/rstudio/rserver.conf
echo "www-thread-pool-size=${CPUS}" >> /etc/rstudio/rserver.conf
echo "session-timeout-minutes=0" >> /etc/rstudio/rsession.conf

systemctl restart rstudio-server.service

# These passwords were generated using:
# perl -e 'print crypt("<MY_PASSWORD>", "password"), "\n"'
useradd -m -p 'paMixc6M.qQlA' -s /bin/bash amplifica
