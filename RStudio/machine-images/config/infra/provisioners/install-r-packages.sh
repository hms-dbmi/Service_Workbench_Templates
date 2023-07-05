#!/usr/bin/env bash

# Restart RStudio server
sudo systemctl restart rstudio-server

#SELinux stuff
sudo /sbin/selinuxenabled >& /dev/null
if [ $? -eq 0 ]; then
  #/tmp context won't allow building packages
  export tmpDir="/home/ec2-user/tmp/r-cran"
else
  export tmpDir="/tmp/r-cran"
fi

# Create temporary package installation script for R
mkdir -p $tmpDir
tmpFile="$tmpDir/packages.R"

# Setup Rprofile for default options
echo 'options(repos=c(CRAN="https://cran.rstudio.com"))' | sudo tee -a /root/.Rprofile
echo 'options(Ncpus=parallel::detectCores() * 2)' | sudo tee -a /root/.Rprofile

sudo cat << END >> "$tmpFile"
install.packages('devtools')

packages <- c(
'tidyverse=1.3.2',
'dplyr=1.1.0',
'tidyr=1.3.0',
'ggplot2=3.4.1',
'data.table=1.14.6,
'kableExtra=1.3.4',
'survival=3.5.3',
'survminer=0.4.9',
'MASS=7.3.58.2',
'quantreg=5.94',
'DescTools=0.99.47',
'rentrez=1.2.3',
'XML=3.99.0.13',
'Matrix=1.5.3',
'irlba=2.3.5.1',
'threejs=0.3.3',
'seqinr=4.2.23',
'urltools=1.7.3',
'bitops=1.0.7',
'maptools=1.1.6',
'randomForest=4.7.1.1',
'RCurl=1.98.1.10',
'arsenal=3.6.3',
)

for (pkg in packages) {
  pkg_split <- strsplit(pkg, "=")[[1]]
  pkg_name <- pkg_split[1]
  pkg_version <- pkg_split[2]
  devtools::install_version(pkg_name, version = pkg_version, dependencies = TRUE)
}

# Install and load remotes package
install.packages('remotes', version='2.4.2')
library('remotes')

remotes::install_github('YuLab-SMU/ggtree', version='3.7.1.2', dep=TRUE)

# Install repos that need a specific order
remotes::install_github('rstudio/httpuv', version='1.6.9', dep=TRUE)
install.packages('shiny', version='1.7.4') # needs httpuv
install.packages('devtools', version='2.4.5') # needs shiny
install.packages('adegenet', version='2.1.10') # needs devtools
END

# Execute installation script
sudo su - -c "R -e \"source('$tmpFile')\""

# Output R library packages
sudo su - -c "R -e \"installed.packages(lib.loc='/usr/local/lib64/R/library')[,'Version']\""

# Cleanup tmp folder
sudo rm -rf "$tmpDir"
